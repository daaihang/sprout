import Foundation

extension IntelligenceJobWorker {
    func executeEntityEnrichment(
        _ job: IntelligenceJob,
        repository: any IntelligenceJobRepositorying,
        now: Date
    ) throws {
        guard job.targetType == .entity else {
            throw IntelligenceJobWorkerError.unsupportedTargetType
        }
        guard let detail = try repository.fetchEntityDetail(entityID: job.targetID) else {
            return
        }

        let relatedRecords = detail.relatedMemories.map(\.record)
        let existingProfile = try repository.fetchEntityProfile(entityID: detail.entity.id)
        var profile = existingProfile ?? EntityProfile(
            entityID: detail.entity.id,
            kind: detail.entity.kind,
            displayName: detail.entity.displayName,
            canonicalName: detail.entity.canonicalName,
            aliases: detail.entity.aliases,
            mentionCount: relatedRecords.count,
            firstMentionedAt: relatedRecords.map(\.updatedAt).min(),
            lastMentionedAt: relatedRecords.map(\.updatedAt).max(),
            commonContextLabels: detail.relatedThemes,
            sourceRecordIDs: detail.relatedMemories.map(\.id),
            confirmationState: .inferred,
            confidence: detail.entity.confidence,
            createdAt: detail.entity.createdAt,
            updatedAt: now
        )

        profile.kind = detail.entity.kind
        profile.displayName = detail.entity.displayName
        profile.canonicalName = detail.entity.canonicalName
        profile.aliases = OrderedCollections.stableUnion(profile.aliases, detail.entity.aliases)
        profile.mentionCount = max(profile.mentionCount, relatedRecords.count)
        let earliestMention = relatedRecords.map(\.updatedAt).min()
        let latestMention = relatedRecords.map(\.updatedAt).max() ?? detail.entity.updatedAt
        profile.firstMentionedAt = minDate(profile.firstMentionedAt, earliestMention)
        profile.lastMentionedAt = maxDate(profile.lastMentionedAt, latestMention)
        profile.commonContextLabels = OrderedCollections.stableUnion(profile.commonContextLabels, detail.relatedThemes)
        profile.sourceRecordIDs = OrderedCollections.stableUnion(profile.sourceRecordIDs, detail.relatedMemories.map(\.id))
        profile.confidence = maxConfidence(profile.confidence, detail.entity.confidence)
        profile.updatedAt = now

        try repository.upsertEntityProfile(profile)
    }

    func executePersonProfileRefresh(
        _ job: IntelligenceJob,
        repository: any IntelligenceJobRepositorying,
        now: Date
    ) throws {
        guard job.targetType == .entity else {
            throw IntelligenceJobWorkerError.unsupportedTargetType
        }
        _ = try repository.refreshPersonProfile(entityID: job.targetID, now: now)
    }

    func executeClarificationQuestionGeneration(
        _ job: IntelligenceJob,
        repository: any IntelligenceJobRepositorying,
        now: Date
    ) throws {
        guard job.targetType == .entity else {
            throw IntelligenceJobWorkerError.unsupportedTargetType
        }
        guard let detail = try repository.fetchEntityDetail(entityID: job.targetID) else {
            return
        }

        let profile = try repository.fetchEntityProfile(entityID: detail.entity.id) ?? fallbackProfile(for: detail, now: now)
        let existingQuestions = try repository.fetchClarificationQuestions(status: nil, limit: nil)
        guard let latestMemory = detail.relatedMemories.max(by: { $0.record.updatedAt < $1.record.updatedAt }) else {
            return
        }

        let artifactIDs = try repository.fetchMemoryDetail(recordID: latestMemory.id)?.artifacts.map(\.id) ?? []
        let latestSummary = try repository.fetchRecordAnalysis(recordID: latestMemory.id)?.summary ?? latestMemory.summaryText
        guard let question = clarificationQuestionBuilder.buildQuestion(
            for: profile,
            record: latestMemory.record,
            artifactIDs: artifactIDs,
            existingQuestions: existingQuestions,
            latestSummary: latestSummary
        ) else {
            return
        }

        try repository.upsertClarificationQuestion(question)
    }

    func executeGraphDeltaApplication(
        _ job: IntelligenceJob,
        repository: any IntelligenceJobRepositorying,
        now: Date
    ) throws {
        guard job.targetType == .graphDelta else {
            throw IntelligenceJobWorkerError.unsupportedTargetType
        }
        guard let delta = try repository.fetchGraphDeltas(applied: false, limit: nil).first(where: { $0.id == job.targetID }) else {
            return
        }

        let targetEntityIDs = Array(
            Set(
                delta.operations
                    .filter { $0.targetType == .entity }
                    .map(\.targetID)
            )
        )
        guard let targetEntityID = targetEntityIDs.first else {
            try repository.markGraphDeltaApplied(delta.id, appliedAt: now)
            return
        }

        let profile = try repository.fetchEntityProfile(entityID: targetEntityID)
        let entityNode = try repository.fetchEntityDetail(entityID: targetEntityID)?.entity
        let result = graphDeltaApplier.apply(
            delta: delta,
            profile: profile,
            entityNode: entityNode,
            appliedAt: now
        )

        if let profile = result.profile {
            try repository.upsertEntityProfile(profile)
        }
        if let entityNode = result.entityNode {
            try repository.upsertEntityNode(entityNode)
        }

        try repository.markGraphDeltaApplied(delta.id, appliedAt: now)
    }

    func executeChapterCandidate(
        _ job: IntelligenceJob,
        repository: any IntelligenceJobRepositorying,
        cloudIntelligenceService: any CloudIntelligenceServing,
        now: Date
    ) async throws {
        guard job.targetType == .record || job.targetType == .board else {
            throw IntelligenceJobWorkerError.unsupportedTargetType
        }

        let recentMemories = try repository.fetchRecentMemories(limit: 12)
            .sorted { $0.record.updatedAt < $1.record.updatedAt }
        guard recentMemories.count >= 2 else {
            return
        }

        let existingQuestions = try repository.fetchClarificationQuestions(status: nil, limit: nil)
        guard let question = try await buildChapterCandidateQuestion(
            anchorJob: job,
            repository: repository,
            cloudIntelligenceService: cloudIntelligenceService,
            existingQuestions: existingQuestions,
            recentMemories: recentMemories,
            now: now
        ) else {
            return
        }

        let hasEquivalentQuestion = existingQuestions.contains { existing in
            guard existing.kind == .chapterCandidate else { return false }
            guard existing.status != .dismissed, existing.status != .expired, existing.status != .stale else {
                return false
            }
            return existing.prompt == question.prompt || existing.sourceRecordIDs == question.sourceRecordIDs
        }
        guard !hasEquivalentQuestion else {
            return
        }

        try repository.upsertClarificationQuestion(question)
    }

    private func buildChapterCandidateQuestion(
        anchorJob: IntelligenceJob,
        repository: any IntelligenceJobRepositorying,
        cloudIntelligenceService: any CloudIntelligenceServing,
        existingQuestions: [ClarificationQuestion],
        recentMemories: [MemorySummary],
        now: Date
    ) async throws -> ClarificationQuestion? {
        let preferences = try repository.fetchIntelligencePreferences()
        let flags = try repository.fetchV6FeatureFlags()

        if preferences.cloudIntelligenceEnabled, flags.cloudChapterSuggestions,
           let question = try await buildCloudChapterCandidateQuestion(
                anchorJob: anchorJob,
                repository: repository,
                cloudIntelligenceService: cloudIntelligenceService,
                recentMemories: recentMemories,
                now: now
           ) {
            return question
        }

        return try buildLocalChapterCandidateQuestion(
            anchorJob: anchorJob,
            repository: repository,
            existingQuestions: existingQuestions,
            recentMemories: recentMemories,
            now: now
        )
    }

    private func buildCloudChapterCandidateQuestion(
        anchorJob: IntelligenceJob,
        repository: any IntelligenceJobRepositorying,
        cloudIntelligenceService: any CloudIntelligenceServing,
        recentMemories: [MemorySummary],
        now: Date
    ) async throws -> ClarificationQuestion? {
        var analyses: [(MemorySummary, RecordAnalysisSnapshot)] = []
        for memory in recentMemories {
            if let analysis = try repository.fetchRecordAnalysis(recordID: memory.id) {
                analyses.append((memory, analysis))
            }
        }
        guard analyses.count >= 2 else {
            return nil
        }

        var themeCounts: [String: Int] = [:]
        var themeSalience: [String: Double] = [:]
        for (_, analysis) in analyses {
            for theme in analysis.themes.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
                themeCounts[theme, default: 0] += 1
                themeSalience[theme, default: 0] += analysis.salienceScore ?? 0.5
            }
        }

        let signals = themeCounts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key < rhs.key
            }
            .prefix(4)
            .map { theme, count in
                MoryAPIClient.ChapterSignalPayload(
                    kind: "theme",
                    label: theme,
                    recordCount: count,
                    salience: max(0.1, min(1, (themeSalience[theme] ?? Double(count) * 0.5) / Double(count)))
                )
            }

        let payload = MoryAPIClient.ChapterSuggestionPayload(
            locale: Locale.autoupdatingCurrent.identifier,
            timeWindow: .init(
                start: isoDateString(from: recentMemories.first?.record.updatedAt ?? now),
                end: isoDateString(from: recentMemories.last?.record.updatedAt ?? now)
            ),
            signals: signals,
            evidenceSnippets: recentMemories.prefix(8).map { memory in
                MoryAPIClient.EvidenceSnippetPayload(
                    recordID: memory.id.uuidString,
                    artifactID: memory.primaryArtifact?.id.uuidString,
                    snippet: memory.summaryText,
                    createdAt: isoDateString(from: memory.record.updatedAt)
                )
            }
        )

        let response = try await cloudIntelligenceService.suggestChapters(payload)
        guard let candidate = response.chapterCandidates.first else {
            return nil
        }

        let sourceRecordIDs = candidate.evidenceRecordIDs.compactMap(UUID.init(uuidString:))
        return ClarificationQuestion(
            kind: .chapterCandidate,
            prompt: "Does \"\(candidate.title)\" feel like a new chapter?",
            targetType: .record,
            targetID: anchorJob.targetID,
            sourceRecordIDs: sourceRecordIDs,
            sourceArtifactIDs: [],
            candidateAnswers: [
                ClarificationAnswerOption(label: "Yes", value: "confirm"),
                ClarificationAnswerOption(label: "Not yet", value: "not_yet"),
            ],
            priority: min(0.55 + candidate.confidence * 0.35, 0.95),
            reason: candidate.summary,
            sensitivity: .normal,
            createdAt: now
        )
    }

    private func buildLocalChapterCandidateQuestion(
        anchorJob: IntelligenceJob,
        repository: any IntelligenceJobRepositorying,
        existingQuestions: [ClarificationQuestion],
        recentMemories: [MemorySummary],
        now: Date
    ) throws -> ClarificationQuestion? {
        var analyses: [(MemorySummary, RecordAnalysisSnapshot)] = []
        for memory in recentMemories {
            if let analysis = try repository.fetchRecordAnalysis(recordID: memory.id) {
                analyses.append((memory, analysis))
            }
        }
        guard analyses.count >= 3 else {
            return nil
        }

        var themeCounts: [String: Int] = [:]
        var themeSources: [String: [UUID]] = [:]
        for (memory, analysis) in analyses {
            for theme in analysis.themes.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
                themeCounts[theme, default: 0] += 1
                themeSources[theme, default: []].append(memory.id)
            }
        }

        guard let topTheme = themeCounts.max(by: { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value < rhs.value
            }
            return lhs.key > rhs.key
        }), topTheme.value >= 2 else {
            return nil
        }

        let sourceRecordIDs = Array(NSOrderedSet(array: themeSources[topTheme.key] ?? [])) as? [UUID] ?? []
        let hasActiveQuestion = existingQuestions.contains { question in
            question.kind == .chapterCandidate
                && question.status != .dismissed
                && question.status != .expired
                && question.status != .stale
                && question.sourceRecordIDs == sourceRecordIDs
        }
        guard !hasActiveQuestion else {
            return nil
        }

        return ClarificationQuestion(
            kind: .chapterCandidate,
            prompt: "Does \"\(topTheme.key)\" feel like a new chapter?",
            targetType: .record,
            targetID: anchorJob.targetID,
            sourceRecordIDs: sourceRecordIDs,
            sourceArtifactIDs: [],
            candidateAnswers: [
                ClarificationAnswerOption(label: "Yes", value: "confirm"),
                ClarificationAnswerOption(label: "Not yet", value: "not_yet"),
            ],
            priority: min(0.48 + Double(topTheme.value) * 0.08, 0.86),
            reason: "\"\(topTheme.key)\" has surfaced repeatedly in recent memories.",
            sensitivity: .normal,
            createdAt: now
        )
    }

    private func fallbackProfile(
        for detail: EntityDetailSnapshot,
        now: Date
    ) -> EntityProfile {
        EntityProfile(
            entityID: detail.entity.id,
            kind: detail.entity.kind,
            displayName: detail.entity.displayName,
            canonicalName: detail.entity.canonicalName,
            aliases: detail.entity.aliases,
            mentionCount: detail.relatedMemories.count,
            firstMentionedAt: detail.relatedMemories.map(\.record.updatedAt).min(),
            lastMentionedAt: detail.relatedMemories.map(\.record.updatedAt).max(),
            commonContextLabels: detail.relatedThemes,
            sourceRecordIDs: detail.relatedMemories.map(\.id),
            confirmationState: .inferred,
            confidence: detail.entity.confidence,
            createdAt: detail.entity.createdAt,
            updatedAt: now
        )
    }

    private func minDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return min(lhs, rhs)
        case (nil, let rhs?):
            return rhs
        case (let lhs?, nil):
            return lhs
        case (nil, nil):
            return nil
        }
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return max(lhs, rhs)
        case (nil, let rhs?):
            return rhs
        case (let lhs?, nil):
            return lhs
        case (nil, nil):
            return nil
        }
    }

    private func maxConfidence(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return max(lhs, rhs)
        case (nil, let rhs?):
            return rhs
        case (let lhs?, nil):
            return lhs
        case (nil, nil):
            return nil
        }
    }

    private func isoDateString(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
