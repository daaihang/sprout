import XCTest
@testable import mory

@MainActor
final class NotificationDeliveryRouterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PushDeviceRegistrationStore.resetForTests()
    }

    override func tearDown() {
        PushDeviceRegistrationStore.resetForTests()
        super.tearDown()
    }

    func testRouterSetsLocalChannelWhenNoAPNSToken() async throws {
        // No APNS token → should route to local.
        let fixture = makeRouterFixture(hasAPNSToken: false)
        let intent = makeTestIntent()

        try await fixture.router.route(intent: intent, repository: fixture.repository)

        let stored = try XCTUnwrap(
            fixture.repository.fetchNotificationIntents(status: nil, limit: nil).first
        )
        XCTAssertEqual(stored.deliveryChannel, .local)
    }

    func testRouterSetsRemoteChannelWhenAPNSTokenPresent() async throws {
        let fixture = makeRouterFixture(hasAPNSToken: true)
        let intent = makeTestIntent()

        try await fixture.router.route(intent: intent, repository: fixture.repository)

        let stored = try XCTUnwrap(
            fixture.repository.fetchNotificationIntents(status: nil, limit: nil).first
        )
        XCTAssertEqual(stored.deliveryChannel, .remote)
        let payload = try XCTUnwrap(fixture.remotePushService.lastPayload)
        XCTAssertEqual(payload.intentID, intent.id)
        XCTAssertEqual(payload.kind, intent.kind.rawValue)
        XCTAssertEqual(payload.targetType, intent.targetType.rawValue)
        XCTAssertEqual(payload.targetID, intent.targetID)
        XCTAssertEqual(payload.deepLink, "mory://memories/record/\(intent.targetID.uuidString)")
    }

    // MARK: - Helpers

    private struct RouterFixture {
        var router: NotificationDeliveryRouter
        var repository: RouterTestNotificationIntentRepository
        var remotePushService: RouterTestRemotePushService
    }

    private func makeRouterFixture(hasAPNSToken: Bool) -> RouterFixture {
        let repository = RouterTestNotificationIntentRepository()
        let remotePushService = RouterTestRemotePushService(hasAPNSToken: hasAPNSToken)
        var router = NotificationDeliveryRouter(pushEnqueuer: remotePushService)
        // Inject a stub notification center so no real UNUserNotificationCenter calls happen.
        router.localScheduler = LocalNotificationScheduler(
            notificationCenter: RouterTestLocalNotificationCenter()
        )
        return RouterFixture(
            router: router,
            repository: repository,
            remotePushService: remotePushService
        )
    }

    private func makeTestIntent() -> NotificationIntent {
        NotificationIntent(
            id: UUID(),
            kind: .dailyQuestion,
            title: "Test",
            body: "Test body",
            targetType: .record,
            targetID: UUID(),
            scheduledAt: .now
        )
    }
}

// MARK: - Test Doubles

@MainActor
private final class RouterTestNotificationIntentRepository: NotificationIntentRepositorying {
    private var intents: [UUID: NotificationIntent] = [:]
    private var preferences: IntelligencePreferences
    private var flags: V6FeatureFlags

    init(now: Date = .now) {
        var preferences = IntelligencePreferences.defaults
        preferences.dailyQuestionsEnabled = true
        preferences.notificationPreferences = NotificationPreferences(
            enabled: true,
            dailyQuestionEnabled: true,
            maxPerDay: 4,
            quietHoursStartHour: nil,
            quietHoursEndHour: nil,
            richPreviewsEnabled: false
        )
        preferences.updatedAt = now
        self.preferences = preferences

        var flags = V6FeatureFlags.defaults
        flags.dailyQuestions = true
        flags.localNotifications = true
        flags.updatedAt = now
        self.flags = flags
    }

    func fetchNotificationIntents(status: NotificationIntentStatus?, limit: Int?) throws -> [NotificationIntent] {
        var results = intents.values
            .filter { intent in
                guard let status else { return true }
                return intent.status == status
            }
            .sorted { $0.createdAt > $1.createdAt }
        if let limit {
            results = Array(results.prefix(limit))
        }
        return results
    }

    func upsertNotificationIntent(_ intent: NotificationIntent) throws {
        intents[intent.id] = intent
    }

    func fetchIntelligencePreferences() throws -> IntelligencePreferences {
        preferences
    }

    func fetchV6FeatureFlags() throws -> V6FeatureFlags {
        flags
    }
}

private final class RouterTestRemotePushService: RemotePushSyncing {
    let hasAPNSToken: Bool
    private(set) var lastPayload: RemotePushDeliveryPayload?

    init(hasAPNSToken: Bool) {
        self.hasAPNSToken = hasAPNSToken
    }

    func prepareForLocalDataOwner(_ ownerID: String) {}
    func registerSystemRemoteNotificationsIfNeeded(repository: any MoryMemoryRepositorying) {}
    func syncRegistrationIfPossible(repository: any MoryMemoryRepositorying, force: Bool) async {}
    func enqueueRemotePush(_ payload: RemotePushDeliveryPayload) async throws -> MoryAPIClient.PushEnqueueResponse {
        lastPayload = payload
        return MoryAPIClient.PushEnqueueResponse(
            accepted: true,
            userID: "router-test",
            queuedCount: 1,
            skippedCount: 0
        )
    }
    func writeBackInteraction(_ event: NotificationInteractionEvent) async {}
    func fetchDebugSnapshot(intentCounts: RemotePushDebugIntentCounts) async -> RemotePushDebugSnapshot {
        RemotePushDebugSnapshot(
            ownerID: nil, deviceID: "test", timezone: "UTC",
            hasAPNSToken: false, apnsTokenPreview: nil,
            hasRegistrationDigest: false, pendingWritebackCount: 0,
            pendingIntentCount: 0, scheduledIntentCount: 0, remoteIntentCount: 0
        )
    }
    func fetchServerMetricsText() async throws -> String { "" }
}

@MainActor
private final class RouterTestLocalNotificationCenter: LocalNotificationSchedulingCenter {
    func authorizationState() async -> LocalNotificationAuthorizationState { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func add(_ request: LocalNotificationScheduleRequest) async throws {}
    func removePendingRequests(withIdentifiers identifiers: [String]) async {}
}
