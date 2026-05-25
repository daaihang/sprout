import XCTest
@testable import mory

@MainActor
final class NotificationDeliveryRouterTests: XCTestCase {
    private let apnsTokenKey = "mory.apnsTokenHex"

    override func setUp() {
        super.setUp()
        // Clear any APNS token left by other tests.
        PushDeviceRegistrationStore.resetForTests()
        UserDefaults.standard.removeObject(forKey: apnsTokenKey)
    }

    override func tearDown() {
        PushDeviceRegistrationStore.resetForTests()
        UserDefaults.standard.removeObject(forKey: apnsTokenKey)
        super.tearDown()
    }

    func testRouterSetsLocalChannelWhenNoAPNSToken() async throws {
        // No APNS token → should route to local.
        let fixture = makeRouterFixture()
        let intent = makeTestIntent()

        try await fixture.router.route(intent: intent, repository: fixture.repository)

        let stored = try XCTUnwrap(
            fixture.repository.fetchNotificationIntents(status: nil, limit: nil).first
        )
        XCTAssertEqual(stored.deliveryChannel, .local)
    }

    func testRouterSetsRemoteChannelWhenAPNSTokenPresent() async throws {
        // Seed a fake APNS hex token.
        UserDefaults.standard.set("deadbeefcafe1234", forKey: apnsTokenKey)
        let fixture = makeRouterFixture()
        let intent = makeTestIntent()

        // Remote service throws (test double) — we only care about the upserted channel.
        try? await fixture.router.route(intent: intent, repository: fixture.repository)

        let stored = try XCTUnwrap(
            fixture.repository.fetchNotificationIntents(status: nil, limit: nil).first
        )
        XCTAssertEqual(stored.deliveryChannel, .remote)
    }

    // MARK: - Helpers

    private struct RouterFixture {
        var router: NotificationDeliveryRouter
        var repository: RouterTestNotificationIntentRepository
    }

    private func makeRouterFixture() -> RouterFixture {
        let repository = RouterTestNotificationIntentRepository()
        let remotePushService = RouterTestRemotePushService()
        var router = NotificationDeliveryRouter(remotePushSyncService: remotePushService)
        // Inject a stub notification center so no real UNUserNotificationCenter calls happen.
        router.localScheduler = LocalNotificationScheduler(
            notificationCenter: RouterTestLocalNotificationCenter()
        )
        return RouterFixture(router: router, repository: repository)
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

private enum RouterTestError: Error { case unsupported }

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
    func prepareForLocalDataOwner(_ ownerID: String) {}
    func registerSystemRemoteNotificationsIfNeeded(repository: any MoryMemoryRepositorying) {}
    func syncRegistrationIfPossible(repository: any MoryMemoryRepositorying, force: Bool) async {}
    func enqueueRemoteNotificationIntent(_ intent: NotificationIntent) async throws -> MoryAPIClient.PushEnqueueResponse {
        throw RouterTestError.unsupported
    }
    func writeBackInteraction(_ event: NotificationInteractionEvent) async {}
    func fetchDebugSnapshot(repository: any MoryMemoryRepositorying) async -> RemotePushDebugSnapshot {
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
