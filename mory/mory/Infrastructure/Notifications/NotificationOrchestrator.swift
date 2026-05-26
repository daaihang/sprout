import Foundation

enum NotificationTrigger: Sendable {
    case appLaunchRecovery
    case homeForegroundRefresh
    case backgroundRefresh
    case silentPush
    case pipelineCompleted(recordID: UUID)
    case settingsChanged
    case debugManual(intent: NotificationIntent)

    var source: NotificationTriggerSource {
        switch self {
        case .appLaunchRecovery:
            return .appLaunchRecovery
        case .homeForegroundRefresh:
            return .homeForegroundRefresh
        case .backgroundRefresh:
            return .backgroundRefresh
        case .silentPush:
            return .silentPush
        case .pipelineCompleted:
            return .pipelineCompleted
        case .settingsChanged:
            return .settingsChanged
        case .debugManual:
            return .debugManual
        }
    }

    var deliversSystemNotification: Bool {
        switch self {
        case .backgroundRefresh, .silentPush, .debugManual:
            return true
        case .appLaunchRecovery, .homeForegroundRefresh, .pipelineCompleted, .settingsChanged:
            return false
        }
    }
}

struct NotificationOrchestrationReport: Hashable, Sendable {
    var generatedIntentIDs: [UUID] = []
    var dedupedIntentIDs: [UUID] = []
    var blockedIntentIDs: [UUID] = []
    var scheduledIntentIDs: [UUID] = []
    var remoteEnqueuedIntentIDs: [UUID] = []
    var inAppOnlyIntentIDs: [UUID] = []
    var errors: [String] = []

    static let empty = NotificationOrchestrationReport()
}

@MainActor
struct NotificationOrchestrator {
    private let policy: NotificationPolicy
    private let localScheduler: LocalNotificationScheduler
    private let deliveryRouter: NotificationDeliveryRouter?
    private let recentCompletionWindow: TimeInterval
    private let reflectionWindow: TimeInterval

    init(
        policy: NotificationPolicy = NotificationPolicy(),
        localScheduler: LocalNotificationScheduler? = nil,
        deliveryRouter: NotificationDeliveryRouter? = nil,
        recentCompletionWindow: TimeInterval = 36 * 60 * 60,
        reflectionWindow: TimeInterval = 14 * 24 * 60 * 60
    ) {
        self.policy = policy
        self.localScheduler = localScheduler ?? LocalNotificationScheduler()
        self.deliveryRouter = deliveryRouter
        self.recentCompletionWindow = recentCompletionWindow
        self.reflectionWindow = reflectionWindow
    }

    static var localDelivery: NotificationOrchestrator {
        NotificationOrchestrator(policy: NotificationPolicy())
    }

    static func live(remotePushSyncService: any RemotePushSyncing) -> NotificationOrchestrator {
        NotificationOrchestrator(
            deliveryRouter: NotificationDeliveryRouter(pushEnqueuer: remotePushSyncService)
        )
    }

    func orchestrate(
        trigger: NotificationTrigger,
        repository: any NotificationPreparationRepositorying,
        now: Date = .now
    ) async throws -> NotificationOrchestrationReport {
        var report = NotificationOrchestrationReport()
        let existingIntents = try repository.fetchNotificationIntents(status: nil, limit: nil)
        let preferences = try repository.fetchIntelligencePreferences()
        let flags = try repository.fetchV6FeatureFlags()

        let candidates = try buildCandidates(
            trigger: trigger,
            repository: repository,
            now: now
        )

        for candidate in candidates {
            let existingBlocked = existingIntents.first {
                $0.dedupeKey == candidate.intent.dedupeKey && $0.status == .blocked
            }
            if let activeIntent = existingIntents.first(where: {
                $0.dedupeKey == candidate.intent.dedupeKey && $0.status != .blocked
            }) {
                try repository.upsertNotificationManagementEvent(event(
                    .deduped,
                    intent: activeIntent,
                    trigger: trigger.source,
                    message: "Skipped duplicate candidate for \(candidate.intent.dedupeKey).",
                    now: now
                ))
                report.dedupedIntentIDs.append(activeIntent.id)
                continue
            }

            var intent = candidate.intent
            if let existingBlocked {
                intent.id = existingBlocked.id
            }
            intent.sourceTrigger = trigger.source
            intent.lastEvaluatedAt = now
            report.generatedIntentIDs.append(intent.id)
            try repository.upsertNotificationManagementEvent(event(
                .generated,
                intent: intent,
                trigger: trigger.source,
                message: "Generated \(intent.kind.rawValue) candidate.",
                now: now
            ))

            guard hasResolvableRoute(intent) else {
                intent.status = .blocked
                intent.blockedReasons = [NotificationPolicyBlockReason.noResolvableRoute.rawValue]
                try repository.upsertNotificationIntent(intent)
                try repository.upsertNotificationManagementEvent(event(
                    .routeError,
                    intent: intent,
                    trigger: trigger.source,
                    message: "Blocked notification because deepLink is missing or cannot be parsed.",
                    now: now
                ))
                report.blockedIntentIDs.append(intent.id)
                continue
            }

            if !trigger.deliversSystemNotification {
                intent.status = .inAppOnly
                intent.blockedReasons = []
                try repository.upsertNotificationIntent(intent)
                try repository.upsertNotificationManagementEvent(event(
                    .inAppOnly,
                    intent: intent,
                    trigger: trigger.source,
                    message: "Stored as in-app only for \(trigger.source.rawValue).",
                    now: now
                ))
                report.inAppOnlyIntentIDs.append(intent.id)
                continue
            }

            let policyExistingIntents = existingIntents.filter { $0.id != intent.id && $0.status != .blocked }
            let decision = policy.evaluate(
                intent: intent,
                existingIntents: policyExistingIntents,
                preferences: preferences,
                flags: flags,
                questionSensitivity: candidate.questionSensitivity,
                now: now
            )

            guard var approvedIntent = decision.approvedIntent else {
                intent.status = .blocked
                intent.blockedReasons = decision.blockReasons.map(\.rawValue)
                try repository.upsertNotificationIntent(intent)
                try repository.upsertNotificationManagementEvent(event(
                    .policyBlocked,
                    intent: intent,
                    trigger: trigger.source,
                    message: "Policy blocked notification: \(intent.blockedReasons.joined(separator: ", ")).",
                    now: now
                ))
                report.blockedIntentIDs.append(intent.id)
                continue
            }

            approvedIntent.dedupeKey = intent.dedupeKey
            approvedIntent.deepLink = intent.deepLink
            approvedIntent.reason = intent.reason
            approvedIntent.sourceTrigger = intent.sourceTrigger
            approvedIntent.createdBy = intent.createdBy
            approvedIntent.lastEvaluatedAt = now
            approvedIntent.blockedReasons = []

            do {
                let deliveredIntent = try await route(
                    intent: approvedIntent,
                    repository: repository,
                    now: now
                )
                if deliveredIntent.status == .scheduled {
                    report.scheduledIntentIDs.append(deliveredIntent.id)
                    if deliveredIntent.deliveryChannel == .remote {
                        report.remoteEnqueuedIntentIDs.append(deliveredIntent.id)
                    }
                    try repository.upsertNotificationManagementEvent(event(
                        .scheduled,
                        intent: deliveredIntent,
                        trigger: trigger.source,
                        message: "Scheduled through \(deliveredIntent.deliveryChannel.rawValue) delivery.",
                        now: now
                    ))
                } else {
                    try repository.upsertNotificationManagementEvent(event(
                        .deliveryError,
                        intent: deliveredIntent,
                        trigger: trigger.source,
                        message: "Delivery did not schedule: \(deliveredIntent.blockedReasons.joined(separator: ", ")).",
                        now: now
                    ))
                    report.blockedIntentIDs.append(deliveredIntent.id)
                }
            } catch {
                report.errors.append(error.localizedDescription)
                var failedIntent = approvedIntent
                failedIntent.status = .blocked
                failedIntent.blockedReasons = ["delivery_error"]
                try repository.upsertNotificationIntent(failedIntent)
                try repository.upsertNotificationManagementEvent(event(
                    .deliveryError,
                    intent: failedIntent,
                    trigger: trigger.source,
                    message: error.localizedDescription,
                    now: now
                ))
                report.blockedIntentIDs.append(failedIntent.id)
            }

        }

        return report
    }

    private func buildCandidates(
        trigger: NotificationTrigger,
        repository: any NotificationPreparationRepositorying,
        now: Date
    ) throws -> [PreparedNotificationCandidate] {
        switch trigger {
        case .debugManual(var intent):
            if intent.kind == .debugTest, intent.deepLink?.trimmedOrNil == nil {
                intent.deepLink = "mory://home"
            }
            return [PreparedNotificationCandidate(intent: intent)]
        case let .pipelineCompleted(recordID):
            if let reflectionCandidate = try reflectionReadyCandidate(
                repository: repository,
                recordID: recordID,
                now: now
            ) {
                return [reflectionCandidate]
            }
            if let analysisCandidate = try analysisReadyCandidate(
                repository: repository,
                recordID: recordID,
                now: now
            ) {
                return [analysisCandidate]
            }
            return []
        case .backgroundRefresh, .silentPush:
            var candidates: [PreparedNotificationCandidate] = []
            if let reflection = try reflectionReadyCandidate(repository: repository, recordID: nil, now: now) {
                candidates.append(reflection)
            }
            if let analysis = try analysisReadyCandidate(repository: repository, recordID: nil, now: now) {
                candidates.append(analysis)
            }
            if let question = try dailyQuestionCandidate(repository: repository, now: now) {
                candidates.append(question)
            }
            return candidates
        case .appLaunchRecovery, .homeForegroundRefresh, .settingsChanged:
            var candidates: [PreparedNotificationCandidate] = []
            if let question = try dailyQuestionCandidate(repository: repository, now: now) {
                candidates.append(question)
            }
            if let reflection = try reflectionReadyCandidate(repository: repository, recordID: nil, now: now) {
                candidates.append(reflection)
            }
            if let analysis = try analysisReadyCandidate(repository: repository, recordID: nil, now: now) {
                candidates.append(analysis)
            }
            return candidates
        }
    }

    private func dailyQuestionCandidate(
        repository: any NotificationPreparationRepositorying,
        now: Date
    ) throws -> PreparedNotificationCandidate? {
        let preferences = try repository.fetchIntelligencePreferences()
        let flags = try repository.fetchV6FeatureFlags()
        guard preferences.dailyQuestionsEnabled,
              preferences.notificationPreferences.dailyQuestionEnabled,
              flags.dailyQuestions else {
            return nil
        }

        guard let question = try repository.fetchClarificationQuestions(status: .pending, limit: nil)
            .filter({ $0.kind == .dailyReflection })
            .filter({ question in
                guard let expiresAt = question.expiresAt else { return true }
                return expiresAt > now
            })
            .sorted(by: { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.createdAt > rhs.createdAt
            })
            .first else {
            return nil
        }

        let deepLink = "mory://home/question/\(question.id.uuidString)"
        return PreparedNotificationCandidate(
            intent: NotificationIntent(
                kind: .dailyQuestion,
                title: "Mory",
                body: question.prompt,
                privacyLevel: .contextual,
                targetType: .question,
                targetID: question.id,
                scheduledAt: now,
                deliveryChannel: .local,
                deepLink: deepLink,
                reason: "Daily question is ready to answer.",
                sourceTrigger: .appLaunchRecovery,
                createdBy: .orchestrator,
                createdAt: now
            ),
            questionSensitivity: question.sensitivity
        )
    }

    private func reflectionReadyCandidate(
        repository: any NotificationPreparationRepositorying,
        recordID: UUID?,
        now: Date
    ) throws -> PreparedNotificationCandidate? {
        let candidates = try repository.fetchReflectionSummaries(limit: 12)
            .filter { summary in
                summary.reflection.status == .suggested
                    && summary.reflection.createdAt >= now.addingTimeInterval(-reflectionWindow)
            }
            .filter { summary in
                guard let recordID else { return true }
                return summary.reflection.sourceRecordIDs.contains(recordID)
            }
            .sorted { lhs, rhs in
                if lhs.reflection.confidence != rhs.reflection.confidence {
                    return lhs.reflection.confidence > rhs.reflection.confidence
                }
                return lhs.reflection.createdAt > rhs.reflection.createdAt
            }

        guard let summary = candidates.first else {
            return nil
        }

        let deepLink = "mory://insights/reflection/\(summary.id.uuidString)"
        return PreparedNotificationCandidate(
            intent: NotificationIntent(
                kind: .reflectionReady,
                title: "Mory",
                body: summary.reflection.title.trimmedOrNil ?? "A reflection is ready to review.",
                privacyLevel: .contextual,
                targetType: .reflection,
                targetID: summary.id,
                scheduledAt: now,
                deliveryChannel: .local,
                deepLink: deepLink,
                reason: "A suggested reflection is ready to review.",
                sourceTrigger: .appLaunchRecovery,
                createdBy: .orchestrator,
                createdAt: now
            )
        )
    }

    private func analysisReadyCandidate(
        repository: any NotificationPreparationRepositorying,
        recordID: UUID?,
        now: Date
    ) throws -> PreparedNotificationCandidate? {
        let memories = try repository.fetchRecentMemories(limit: 24)
        let memoryIndex = Dictionary(uniqueKeysWithValues: memories.map { ($0.id, $0) })
        let statuses = try repository.fetchPipelineStatusSummaries(limit: 24)
            .filter { summary in
                summary.status.stage == .completed
                    && relevantPipelineTimestamp(summary.status) >= now.addingTimeInterval(-recentCompletionWindow)
            }
            .filter { summary in
                guard let recordID else { return true }
                return summary.recordID == recordID
            }
            .sorted { lhs, rhs in
                relevantPipelineTimestamp(lhs.status) > relevantPipelineTimestamp(rhs.status)
            }

        guard let summary = statuses.first,
              let memory = memoryIndex[summary.recordID] else {
            return nil
        }

        let deepLink = "mory://memories/record/\(summary.recordID.uuidString)"
        let title = memory.title.trimmedOrNil ?? summary.title.trimmedOrNil ?? "Untitled Memory"
        return PreparedNotificationCandidate(
            intent: NotificationIntent(
                kind: .analysisReady,
                title: "Mory",
                body: "\"\(title)\" is ready to review.",
                privacyLevel: .contextual,
                targetType: .record,
                targetID: summary.recordID,
                scheduledAt: now,
                deliveryChannel: .local,
                deepLink: deepLink,
                reason: "Memory analysis finished successfully.",
                sourceTrigger: .appLaunchRecovery,
                createdBy: .orchestrator,
                createdAt: now
            )
        )
    }

    private func route(
        intent: NotificationIntent,
        repository: any NotificationPreparationRepositorying,
        now: Date
    ) async throws -> NotificationIntent {
        if let deliveryRouter {
            return try await deliveryRouter.route(intent: intent, repository: repository, now: now)
        }

        try repository.upsertNotificationIntent(intent)
        let report = try await localScheduler.schedulePendingIntents(
            repository: repository,
            now: now,
            requestAuthorizationIfNeeded: false
        )
        if let result = report.results.first(where: { $0.intentID == intent.id }), !result.scheduled {
            var blockedIntent = intent
            blockedIntent.status = .blocked
            blockedIntent.blockedReasons = [result.skipReason?.rawValue].compactMap { $0 }
            try repository.upsertNotificationIntent(blockedIntent)
        }
        return try repository.fetchNotificationIntents(status: nil, limit: nil)
            .first(where: { $0.id == intent.id }) ?? intent
    }

    private func hasResolvableRoute(_ intent: NotificationIntent) -> Bool {
        guard let deepLink = intent.deepLink?.trimmedOrNil else {
            return false
        }
        return MoryDeepLinkRoute.parse(deepLink) != nil
    }

    private func relevantPipelineTimestamp(_ status: MemoryPipelineStatusSnapshot) -> Date {
        status.completedAt ?? status.lastAttemptAt ?? status.updatedAt
    }

    private func event(
        _ kind: NotificationManagementEventKind,
        intent: NotificationIntent,
        trigger: NotificationTriggerSource,
        message: String,
        now: Date = .now
    ) -> NotificationManagementEvent {
        NotificationManagementEvent(
            eventKind: kind,
            intentID: intent.id,
            dedupeKey: intent.dedupeKey,
            trigger: trigger,
            kind: intent.kind,
            targetType: intent.targetType,
            targetID: intent.targetID,
            message: message,
            createdAt: now
        )
    }
}

private struct PreparedNotificationCandidate {
    var intent: NotificationIntent
    var questionSensitivity: QuestionSensitivity? = nil
}
