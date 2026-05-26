import XCTest
@testable import mory

@MainActor
final class RuntimeOperationsCoordinatorTests: XCTestCase {
    func testRunBackgroundDelegatesThroughBackgroundOrchestratorAndRecordsRun() async throws {
        let fixture = makeFixture()
        let coordinator = RuntimeOperationsCoordinator(
            backgroundOperationOrchestrator: .noop,
            notificationOrchestrator: .localDelivery,
            remotePushSyncService: RuntimePushService()
        )

        let result = await coordinator.runBackground(
            kind: .debugManual,
            source: "RuntimeOperationsCoordinatorTests",
            repository: fixture.repository
        )

        XCTAssertTrue(result.message.contains("status=completed"))
        let runs = try fixture.repository.fetchBackgroundOperationRuns(status: nil, limit: nil)
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs.first?.triggerKind, .debugManual)
    }

    func testLoadSnapshotUsesReadOnlyRuntimeRepositories() async throws {
        let fixture = makeFixture()
        var intent = NotificationIntent(
            kind: .dailyQuestion,
            title: "Question",
            body: "Body",
            targetType: .question,
            targetID: UUID(),
            scheduledAt: .now
        )
        intent.status = .pending
        try fixture.repository.upsertNotificationIntent(intent)

        let coordinator = RuntimeOperationsCoordinator(
            backgroundOperationOrchestrator: .noop,
            notificationOrchestrator: .localDelivery,
            remotePushSyncService: RuntimePushService()
        )

        let snapshot = try await coordinator.loadSnapshot(repository: fixture.repository)

        XCTAssertEqual(snapshot.notifications.queueIntents.map(\.id), [intent.id])
        XCTAssertFalse(snapshot.push.hasAPNSToken)
    }

    private func makeFixture() -> RuntimeFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: RuntimeAnalysisService(),
            backgroundOperationStore: BackgroundOperationMemoryStore()
        )
        return RuntimeFixture(repository: repository)
    }
}

private struct RuntimeFixture {
    let repository: MoryMemoryRepository
}

private final class RuntimePushService: RemotePushSyncing {
    var hasAPNSToken: Bool { false }

    func prepareForLocalDataOwner(_ ownerID: String) {}
    func registerSystemRemoteNotificationsIfNeeded(repository: any MoryMemoryRepositorying) {}
    func syncRegistrationIfPossible(repository: any MoryMemoryRepositorying, force: Bool) async {}
    func enqueueRemoteNotificationIntent(_ intent: NotificationIntent) async throws -> MoryAPIClient.PushEnqueueResponse {
        MoryAPIClient.PushEnqueueResponse(
            accepted: true,
            userID: "runtime-test",
            queuedCount: 1,
            skippedCount: 0,
            sentCount: 0,
            failedCount: 0,
            retriedCount: 0,
            permanentFailedCount: 0
        )
    }
    func writeBackInteraction(_ event: NotificationInteractionEvent) async {}
    func fetchDebugSnapshot(repository: any MoryMemoryRepositorying) async -> RemotePushDebugSnapshot {
        RemotePushDebugSnapshot(
            ownerID: nil,
            deviceID: "runtime-test-device",
            timezone: "UTC",
            hasAPNSToken: false,
            apnsTokenPreview: nil,
            hasRegistrationDigest: false,
            pendingWritebackCount: 0,
            pendingIntentCount: 0,
            scheduledIntentCount: 0,
            remoteIntentCount: 0
        )
    }
    func fetchServerMetricsText() async throws -> String { "" }
}

private struct RuntimeAnalysisService: ReflectionAnalysisServing {
    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw RuntimeTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw RuntimeTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}

private enum RuntimeTestError: Error {
    case unsupported
}
