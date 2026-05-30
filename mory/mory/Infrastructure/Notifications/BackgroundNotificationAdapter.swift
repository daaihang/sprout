import Foundation

@MainActor
struct BackgroundNotificationAdapter: BackgroundReminderRouting {
    private let notificationOrchestrator: NotificationOrchestrator

    init(notificationOrchestrator: NotificationOrchestrator) {
        self.notificationOrchestrator = notificationOrchestrator
    }

    func routeBackgroundReminder(
        for trigger: BackgroundTrigger,
        repository: any NotificationPreparationRepositorying,
        now: Date
    ) async throws -> BackgroundOperationOutcome {
        guard let notificationTrigger = makeNotificationTrigger(from: trigger) else {
            return .skipped(message: "No notification action for \(trigger.kind.rawValue).")
        }

        let report = try await notificationOrchestrator.orchestrate(
            trigger: notificationTrigger,
            repository: repository,
            now: now
        )
        let counts = [
            "generated": report.generatedIntentIDs.count,
            "scheduled": report.scheduledIntentIDs.count,
            "remote": report.remoteEnqueuedIntentIDs.count,
            "in_app": report.inAppOnlyIntentIDs.count,
            "blocked": report.blockedIntentIDs.count,
            "deduped": report.dedupedIntentIDs.count,
        ]
        guard report.errors.isEmpty else {
            return .failed(error: report.errors.joined(separator: "\n"), resultCounts: counts)
        }
        return .completed(resultCounts: counts)
    }

    private func makeNotificationTrigger(from trigger: BackgroundTrigger) -> NotificationTrigger? {
        switch trigger.kind {
        case .appLaunch:
            return .appLaunchRecovery
        case .bgAppRefreshTask:
            return .backgroundRefresh
        case .silentPush:
            return .silentPush
        case .homeForegroundRefresh, .sceneForeground:
            return .homeForegroundRefresh
        case .pipelineCompleted:
            if let recordID = trigger.targetID {
                return .pipelineCompleted(recordID: recordID)
            }
            return .homeForegroundRefresh
        case .notificationPreferencesChanged:
            return .settingsChanged
        case .bgProcessingTask, .apnsTokenUpdated, .backgroundURLSessionCompleted, .debugManual:
            return nil
        }
    }
}
