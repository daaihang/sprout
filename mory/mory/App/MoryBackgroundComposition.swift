import Foundation

@MainActor
extension BackgroundOperationOrchestrator {
    static func live(
        cloudIntelligenceService: (any CloudIntelligenceServing)?,
        notificationOrchestrator: NotificationOrchestrator,
        remotePushSyncService: (any RemotePushSyncing)?
    ) -> BackgroundOperationOrchestrator {
        BackgroundOperationOrchestrator(
            jobRecoverer: IntelligenceJobRecoveryService(),
            jobProcessor: IntelligenceJobWorker(
                cloudIntelligenceService: cloudIntelligenceService,
                notificationRouting: notificationOrchestrator
            ),
            questionPreparer: IntelligenceBackgroundQuestionPreparer(
                cloudIntelligenceService: cloudIntelligenceService
            ),
            reminderRouting: BackgroundNotificationAdapter(
                notificationOrchestrator: notificationOrchestrator
            ),
            pushSyncing: BackgroundPushSyncAdapter(remotePushSyncService: remotePushSyncService)
        )
    }
}
