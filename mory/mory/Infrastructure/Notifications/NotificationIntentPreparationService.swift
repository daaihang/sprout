import Foundation

@MainActor
struct NotificationIntentPreparationService {
    private let policy: NotificationPolicy
    private let revisitMinimumAge: TimeInterval
    private let recentCompletionWindow: TimeInterval
    private let stageCandidateWindow: TimeInterval

    init(
        policy: NotificationPolicy = NotificationPolicy(),
        revisitMinimumAge: TimeInterval = 7 * 24 * 60 * 60,
        recentCompletionWindow: TimeInterval = 36 * 60 * 60,
        stageCandidateWindow: TimeInterval = 14 * 24 * 60 * 60
    ) {
        self.policy = policy
        self.revisitMinimumAge = max(24 * 60 * 60, revisitMinimumAge)
        self.recentCompletionWindow = max(60 * 60, recentCompletionWindow)
        self.stageCandidateWindow = max(24 * 60 * 60, stageCandidateWindow)
    }

    @discardableResult
    func prepareNextIntentIfNeeded(
        repository: any NotificationPreparationRepositorying,
        now: Date = .now
    ) throws -> NotificationIntent? {
        let preferences = try repository.fetchIntelligencePreferences()
        let flags = try repository.fetchV6FeatureFlags()
        let existingIntents = try repository.fetchNotificationIntents(status: nil, limit: nil)
        let candidates = try buildCandidates(
            repository: repository,
            preferences: preferences,
            flags: flags,
            existingIntents: existingIntents,
            now: now
        )
        return try persistFirstApprovedIntent(
            from: candidates,
            repository: repository,
            preferences: preferences,
            flags: flags,
            existingIntents: existingIntents,
            now: now
        )
    }

    @discardableResult
    func prepareDailyQuestionIntentIfNeeded(
        repository: any NotificationPreparationRepositorying,
        now: Date = .now
    ) throws -> NotificationIntent? {
        let preferences = try repository.fetchIntelligencePreferences()
        let flags = try repository.fetchV6FeatureFlags()
        let existingIntents = try repository.fetchNotificationIntents(status: nil, limit: nil)
        let candidates = try dailyQuestionCandidate(
            repository: repository,
            preferences: preferences,
            flags: flags,
            existingIntents: existingIntents,
            now: now
        ).map { [$0] } ?? []

        return try persistFirstApprovedIntent(
            from: candidates,
            repository: repository,
            preferences: preferences,
            flags: flags,
            existingIntents: existingIntents,
            now: now
        )
    }

    private func buildCandidates(
        repository: any NotificationPreparationRepositorying,
        preferences: IntelligencePreferences,
        flags: V6FeatureFlags,
        existingIntents: [NotificationIntent],
        now: Date
    ) throws -> [PreparedNotificationCandidate] {
        var candidates: [PreparedNotificationCandidate] = []

        if let candidate = try dailyQuestionCandidate(
            repository: repository,
            preferences: preferences,
            flags: flags,
            existingIntents: existingIntents,
            now: now
        ) {
            candidates.append(candidate)
        }

        if let candidate = try backgroundDoneCandidate(
            repository: repository,
            existingIntents: existingIntents,
            now: now
        ) {
            candidates.append(candidate)
        }

        if let candidate = try stageFormingCandidate(
            repository: repository,
            existingIntents: existingIntents,
            now: now
        ) {
            candidates.append(candidate)
        }

        if let candidate = try repeatedThemeCandidate(
            repository: repository,
            existingIntents: existingIntents,
            now: now
        ) {
            candidates.append(candidate)
        }

        if let candidate = try revisitCandidate(
            repository: repository,
            existingIntents: existingIntents,
            now: now
        ) {
            candidates.append(candidate)
        }

        return candidates
    }

    private func persistFirstApprovedIntent(
        from candidates: [PreparedNotificationCandidate],
        repository: any NotificationPreparationRepositorying,
        preferences: IntelligencePreferences,
        flags: V6FeatureFlags,
        existingIntents: [NotificationIntent],
        now: Date
    ) throws -> NotificationIntent? {
        for candidate in candidates {
            let decision = policy.evaluate(
                intent: candidate.intent,
                existingIntents: existingIntents,
                preferences: preferences,
                flags: flags,
                questionSensitivity: candidate.questionSensitivity,
                now: now
            )

            guard let approvedIntent = decision.approvedIntent else {
                continue
            }

            try repository.upsertNotificationIntent(approvedIntent)
            return approvedIntent
        }

        return nil
    }

    private func dailyQuestionCandidate(
        repository: any NotificationPreparationRepositorying,
        preferences: IntelligencePreferences,
        flags: V6FeatureFlags,
        existingIntents: [NotificationIntent],
        now: Date
    ) throws -> PreparedNotificationCandidate? {
        guard preferences.dailyQuestionsEnabled, flags.dailyQuestions else {
            return nil
        }

        guard let question = nextDailyQuestion(
            from: try repository.fetchClarificationQuestions(status: .pending, limit: nil),
            now: now
        ) else {
            return nil
        }

        guard !hasActiveIntent(
            targetType: .question,
            targetID: question.id,
            existingIntents: existingIntents
        ) else {
            return nil
        }

        return PreparedNotificationCandidate(
            intent: NotificationIntent(
                kind: .dailyQuestion,
                title: "Mory",
                body: question.prompt,
                privacyLevel: .contextual,
                targetType: .question,
                targetID: question.id,
                scheduledAt: now,
                status: .pending,
                deliveryChannel: .local,
                createdAt: now
            ),
            questionSensitivity: question.sensitivity
        )
    }

    private func backgroundDoneCandidate(
        repository: any NotificationPreparationRepositorying,
        existingIntents: [NotificationIntent],
        now: Date
    ) throws -> PreparedNotificationCandidate? {
        let memoryIndex = try Dictionary(
            uniqueKeysWithValues: repository.fetchRecentMemories(limit: 24).map { ($0.id, $0) }
        )
        let statuses = try repository.fetchPipelineStatusSummaries(limit: 24)
            .filter { summary in
                summary.status.stage == .completed
                    && maxRelevantTimestamp(for: summary.status) >= now.addingTimeInterval(-recentCompletionWindow)
            }
            .sorted { lhs, rhs in
                maxRelevantTimestamp(for: lhs.status) > maxRelevantTimestamp(for: rhs.status)
            }

        for summary in statuses {
            let memory = memoryIndex[summary.recordID]
            let targetType: ClarificationTargetType = memory?.primaryArtifact == nil ? .record : .artifact
            let targetID = memory?.primaryArtifact?.id ?? summary.recordID

            guard !hasActiveIntent(targetType: targetType, targetID: targetID, existingIntents: existingIntents) else {
                continue
            }

            let title = memory?.title.trimmedOrNil ?? summary.title.trimmedOrNil ?? "Untitled Memory"
            return PreparedNotificationCandidate(
                intent: NotificationIntent(
                    kind: .backgroundDone,
                    title: "Mory",
                    body: "\"\(title)\" is ready to review.",
                    privacyLevel: .contextual,
                    targetType: targetType,
                    targetID: targetID,
                    scheduledAt: now,
                    status: .pending,
                    deliveryChannel: .local,
                    createdAt: now
                )
            )
        }

        return nil
    }

    private func stageFormingCandidate(
        repository: any NotificationPreparationRepositorying,
        existingIntents: [NotificationIntent],
        now: Date
    ) throws -> PreparedNotificationCandidate? {
        let arcCandidates = try repository.fetchTemporalArcSummaries(limit: 12)
            .filter { summary in
                summary.arc.status == .candidate
                    && summary.arc.updatedAt >= now.addingTimeInterval(-stageCandidateWindow)
            }
            .sorted { lhs, rhs in
                let lhsScore = lhs.arc.clusterStrength + lhs.arc.intensityScore
                let rhsScore = rhs.arc.clusterStrength + rhs.arc.intensityScore
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.arc.updatedAt > rhs.arc.updatedAt
            }

        for summary in arcCandidates {
            guard !hasActiveIntent(targetType: .chapter, targetID: summary.id, existingIntents: existingIntents) else {
                continue
            }

            let chapterLabel = summary.arc.title.trimmedOrNil
                ?? summary.arc.dominantTheme?.trimmedOrNil
                ?? "this chapter"
            return PreparedNotificationCandidate(
                intent: NotificationIntent(
                    kind: .stageForming,
                    title: "Mory",
                    body: "A chapter may be forming around \(chapterLabel).",
                    privacyLevel: .contextual,
                    targetType: .chapter,
                    targetID: summary.id,
                    scheduledAt: now,
                    status: .pending,
                    deliveryChannel: .local,
                    createdAt: now
                )
            )
        }

        let reflectionCandidates = try repository.fetchReflectionSummaries(limit: 12)
            .filter { summary in
                summary.reflection.status == .suggested
                    && summary.reflection.createdAt >= now.addingTimeInterval(-stageCandidateWindow)
                    && [.phase, .pattern].contains(summary.reflection.type)
            }
            .sorted { lhs, rhs in
                if lhs.reflection.confidence != rhs.reflection.confidence {
                    return lhs.reflection.confidence > rhs.reflection.confidence
                }
                return lhs.reflection.createdAt > rhs.reflection.createdAt
            }

        for summary in reflectionCandidates {
            guard !hasActiveIntent(targetType: .reflection, targetID: summary.id, existingIntents: existingIntents) else {
                continue
            }

            return PreparedNotificationCandidate(
                intent: NotificationIntent(
                    kind: .stageForming,
                    title: "Mory",
                    body: summary.reflection.title.trimmedOrNil ?? "A new reflection is ready to review.",
                    privacyLevel: .contextual,
                    targetType: .reflection,
                    targetID: summary.id,
                    scheduledAt: now,
                    status: .pending,
                    deliveryChannel: .local,
                    createdAt: now
                )
            )
        }

        return nil
    }

    private func repeatedThemeCandidate(
        repository: any NotificationPreparationRepositorying,
        existingIntents: [NotificationIntent],
        now: Date
    ) throws -> PreparedNotificationCandidate? {
        let kinds: [EntityKind] = [.person, .theme, .place, .decision]
        var candidates: [EntityDetailSnapshot] = []
        for kind in kinds {
            candidates.append(contentsOf: try repository.fetchEntityDetails(kind: kind, limit: 8))
        }

        let ranked = candidates
            .filter { detail in
                detail.relatedMemories.count >= 2
                    || detail.artifactCount >= 2
                    || !detail.relatedArcs.isEmpty
                    || !detail.relatedReflections.isEmpty
            }
            .sorted { lhs, rhs in
                let lhsScore = repeatedThemeScore(lhs)
                let rhsScore = repeatedThemeScore(rhs)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.entity.updatedAt > rhs.entity.updatedAt
            }

        for detail in ranked {
            let targetType = targetType(for: detail.entity.kind)
            guard !hasActiveIntent(targetType: targetType, targetID: detail.id, existingIntents: existingIntents) else {
                continue
            }

            return PreparedNotificationCandidate(
                intent: NotificationIntent(
                    kind: .repeatedTheme,
                    title: "Mory",
                    body: repeatedThemeBody(for: detail),
                    privacyLevel: .contextual,
                    targetType: targetType,
                    targetID: detail.id,
                    scheduledAt: now,
                    status: .pending,
                    deliveryChannel: .local,
                    createdAt: now
                )
            )
        }

        return nil
    }

    private func revisitCandidate(
        repository: any NotificationPreparationRepositorying,
        existingIntents: [NotificationIntent],
        now: Date
    ) throws -> PreparedNotificationCandidate? {
        let candidates = try repository.fetchRecentMemories(limit: 32)
            .filter { summary in
                summary.record.createdAt <= now.addingTimeInterval(-revisitMinimumAge)
            }
            .sorted { lhs, rhs in
                let lhsScore = revisitScore(lhs, now: now)
                let rhsScore = revisitScore(rhs, now: now)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.record.createdAt < rhs.record.createdAt
            }

        for memory in candidates {
            let targetType: ClarificationTargetType = memory.primaryArtifact == nil ? .record : .artifact
            let targetID = memory.primaryArtifact?.id ?? memory.id

            guard !hasActiveIntent(targetType: targetType, targetID: targetID, existingIntents: existingIntents) else {
                continue
            }

            return PreparedNotificationCandidate(
                intent: NotificationIntent(
                    kind: .revisit,
                    title: "Mory",
                    body: "It may be a good time to revisit \(memory.title).",
                    privacyLevel: .contextual,
                    targetType: targetType,
                    targetID: targetID,
                    scheduledAt: now,
                    status: .pending,
                    deliveryChannel: .local,
                    createdAt: now
                )
            )
        }

        return nil
    }

    private func nextDailyQuestion(
        from questions: [ClarificationQuestion],
        now: Date
    ) -> ClarificationQuestion? {
        questions
            .filter { question in
                question.kind == .dailyReflection
                    && question.status == .pending
                    && !isExpired(question, now: now)
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.createdAt > rhs.createdAt
            }
            .first
    }

    private func isExpired(_ question: ClarificationQuestion, now: Date) -> Bool {
        guard let expiresAt = question.expiresAt else {
            return false
        }
        return expiresAt <= now
    }

    private func hasActiveIntent(
        targetType: ClarificationTargetType,
        targetID: UUID,
        existingIntents: [NotificationIntent]
    ) -> Bool {
        existingIntents.contains { intent in
            intent.targetType == targetType
                && intent.targetID == targetID
                && intent.status != .dismissed
                && intent.status != .blocked
        }
    }

    private func targetType(for kind: EntityKind) -> ClarificationTargetType {
        switch kind {
        case .person, .activity, .object:
            return .entity
        case .place:
            return .place
        case .theme:
            return .theme
        case .decision:
            return .decision
        }
    }

    private func repeatedThemeBody(for detail: EntityDetailSnapshot) -> String {
        let name = detail.entity.displayName.trimmedOrNil ?? detail.entity.canonicalName
        switch detail.entity.kind {
        case .person:
            return "\(name) keeps showing up in your recent memories."
        case .place:
            return "\(name) has been appearing as a recurring place."
        case .theme:
            return "\(name) is starting to look like a recurring theme."
        case .decision:
            return "\(name) seems to be part of a repeated decision thread."
        case .activity, .object:
            return "\(name) keeps resurfacing in your memories."
        }
    }

    private func repeatedThemeScore(_ detail: EntityDetailSnapshot) -> Double {
        Double(detail.relatedMemories.count) * 2
            + Double(detail.artifactCount)
            + Double(detail.relatedArcs.count) * 1.5
            + Double(detail.relatedReflections.count) * 1.2
    }

    private func revisitScore(_ memory: MemorySummary, now: Date) -> Double {
        let ageDays = now.timeIntervalSince(memory.record.createdAt) / (24 * 60 * 60)
        let artifactBonus = Double(memory.artifactCount) * 0.4
        let pipelineBonus = memory.pipelineStatus?.stage == .completed ? 1.0 : 0
        return min(ageDays, 45) + artifactBonus + pipelineBonus
    }

    private func maxRelevantTimestamp(for status: MemoryPipelineStatusSnapshot) -> Date {
        status.completedAt
            ?? status.lastAttemptAt
            ?? status.updatedAt
    }
}

private struct PreparedNotificationCandidate {
    var intent: NotificationIntent
    var questionSensitivity: QuestionSensitivity? = nil
}
