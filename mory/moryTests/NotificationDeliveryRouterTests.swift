import XCTest
@testable import mory

@MainActor
final class NotificationDeliveryRouterTests: XCTestCase {
    private let apnsTokenKey = "mory.apnsTokenHex"

    override func setUp() {
        super.setUp()
        // Clear any APNS token left by other tests.
        UserDefaults.standard.removeObject(forKey: apnsTokenKey)
    }

    override func tearDown() {
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
        var repository: MoryMemoryRepository
    }

    private func makeRouterFixture() -> RouterFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: RouterTestAnalysisService()
        )
        let remotePushService = RouterTestRemotePushService()
        let router = NotificationDeliveryRouter(remotePushSyncService: remotePushService)
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

private struct RouterTestAnalysisService: RecordAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(recordID: record.id, summary: record.rawText, createdAt: .now)
    }

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw RouterTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw RouterTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? { nil }
}
