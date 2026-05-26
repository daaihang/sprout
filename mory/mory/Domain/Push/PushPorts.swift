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

struct RemotePushDebugIntentCounts: Hashable, Sendable {
    var pendingIntentCount: Int
    var scheduledIntentCount: Int
    var remoteIntentCount: Int

    static let empty = RemotePushDebugIntentCounts(
        pendingIntentCount: 0,
        scheduledIntentCount: 0,
        remoteIntentCount: 0
    )
}

@MainActor
protocol PushNotificationEnqueuing: AnyObject {
    var hasAPNSToken: Bool { get }
    func enqueueRemotePush(_ payload: RemotePushDeliveryPayload) async throws -> MoryAPIClient.PushEnqueueResponse
}

@MainActor
protocol RemotePushSyncing: PushNotificationEnqueuing {
    func prepareForLocalDataOwner(_ ownerID: String)
    func registerSystemRemoteNotificationsIfNeeded(repository: any MoryMemoryRepositorying)
    func syncRegistrationIfPossible(repository: any MoryMemoryRepositorying, force: Bool) async
    func writeBackInteraction(_ event: NotificationInteractionEvent) async
    func fetchDebugSnapshot(intentCounts: RemotePushDebugIntentCounts) async -> RemotePushDebugSnapshot
    func fetchServerMetricsText() async throws -> String
}
