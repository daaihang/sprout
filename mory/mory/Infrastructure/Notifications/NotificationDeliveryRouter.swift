import Foundation

@MainActor
struct NotificationDeliveryRouter {
    var localScheduler: LocalNotificationScheduler = .init()
    var remotePushSyncService: any RemotePushSyncing

    func route(
        intent: NotificationIntent,
        repository: any MoryMemoryRepositorying,
        now: Date = .now
    ) async throws {
        var routed = intent
        let hasToken = PushDeviceRegistrationStore.currentAPNSToken() != nil
        routed.deliveryChannel = hasToken ? .remote : .local
        try repository.upsertNotificationIntent(routed)
        if routed.deliveryChannel == .remote {
            _ = try await remotePushSyncService.enqueueRemoteNotificationIntent(routed)
        } else {
            _ = try await localScheduler.schedulePendingIntents(
                repository: repository,
                now: now,
                requestAuthorizationIfNeeded: false
            )
        }
    }
}
