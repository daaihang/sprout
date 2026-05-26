import Foundation

struct RemotePushDebugSnapshot: Hashable, Sendable {
    var ownerID: String?
    var deviceID: String
    var timezone: String
    var hasAPNSToken: Bool
    var apnsTokenPreview: String?
    var hasRegistrationDigest: Bool
    var pendingWritebackCount: Int
    var pendingIntentCount: Int
    var scheduledIntentCount: Int
    var remoteIntentCount: Int
}

@MainActor
protocol PushNotificationEnqueuing: AnyObject {
    var hasAPNSToken: Bool { get }
    func enqueueRemoteNotificationIntent(_ intent: NotificationIntent) async throws -> MoryAPIClient.PushEnqueueResponse
}

@MainActor
protocol RemotePushSyncing: PushNotificationEnqueuing {
    func prepareForLocalDataOwner(_ ownerID: String)
    func registerSystemRemoteNotificationsIfNeeded(repository: any MoryMemoryRepositorying)
    func syncRegistrationIfPossible(repository: any MoryMemoryRepositorying, force: Bool) async
    func writeBackInteraction(_ event: NotificationInteractionEvent) async
    func fetchDebugSnapshot(repository: any NotificationIntentRepositorying) async -> RemotePushDebugSnapshot
    func fetchServerMetricsText() async throws -> String
}
