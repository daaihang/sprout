import Foundation

@MainActor
struct BackgroundPushSyncAdapter: BackgroundPushRegistrationSyncing {
    private let remotePushSyncService: (any RemotePushSyncing)?

    init(remotePushSyncService: (any RemotePushSyncing)?) {
        self.remotePushSyncService = remotePushSyncService
    }

    func syncBackgroundPushRegistration(
        repository: any MoryMemoryRepositorying,
        force: Bool
    ) async -> BackgroundOperationOutcome {
        guard let remotePushSyncService else {
            return .skipped(message: "Remote push sync service unavailable.")
        }

        remotePushSyncService.registerSystemRemoteNotificationsIfNeeded(repository: repository)
        await remotePushSyncService.syncRegistrationIfPossible(repository: repository, force: force)
        return .completed(resultCounts: ["attempted": 1])
    }
}
