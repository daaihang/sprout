import SwiftData
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
        let repository = RuntimeSnapshotRepository()
        let coordinator = RuntimeOperationsCoordinator(
            backgroundOperationOrchestrator: .noop,
            notificationOrchestrator: .localDelivery,
            remotePushSyncService: RuntimePushService()
        )

        let snapshot = try await coordinator.loadSnapshot(repository: repository)

        XCTAssertTrue(snapshot.notifications.queueIntents.isEmpty)
        XCTAssertTrue(snapshot.backgroundRuns.isEmpty)
        XCTAssertTrue(snapshot.jobQueue.jobs.isEmpty)
        XCTAssertFalse(snapshot.push.hasAPNSToken)
    }

    func testHandleNotificationInteractionDelegatesToInteractionServiceAndPushWriteback() async throws {
        let fixture = makeFixture()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let pushService = RuntimePushService()
        let coordinator = RuntimeOperationsCoordinator(
            backgroundOperationOrchestrator: .noop,
            notificationOrchestrator: .localDelivery,
            remotePushSyncService: pushService
        )

        let targetID = UUID()
        let intent = NotificationIntent(
            kind: .debugTest,
            title: "Mory",
            body: "Runtime interaction test.",
            targetType: .record,
            targetID: targetID,
            scheduledAt: now,
            deliveryChannel: .local,
            deepLink: "mory://home",
            sourceTrigger: .debugManual,
            createdBy: .debug,
            createdAt: now
        )
        try fixture.repository.upsertNotificationIntent(intent)
        let event = NotificationInteractionEvent(
            action: .opened,
            payload: LocalNotificationPayload(
                intentID: intent.id,
                kind: intent.kind,
                targetType: intent.targetType,
                targetID: intent.targetID,
                deepLink: intent.deepLink
            ),
            receivedAt: now
        )

        let result = try await coordinator.handleNotificationInteraction(
            event,
            repository: fixture.repository,
            now: now
        )

        XCTAssertEqual(result.route?.destination, .home)
        XCTAssertEqual(pushService.writeBackEventIDs, [event.id])
        let stored = try XCTUnwrap(fixture.repository.fetchNotificationIntents(status: nil, limit: nil).first(where: { $0.id == intent.id }))
        XCTAssertEqual(stored.status, .delivered)
        XCTAssertEqual(stored.openedAt, now)
    }

    private func makeFixture() -> RuntimeFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: RuntimeAnalysisService(),
            backgroundOperationStore: BackgroundOperationMemoryStore()
        )
        return RuntimeFixture(container: container, repository: repository)
    }
}

private struct RuntimeFixture {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

private final class RuntimeSnapshotRepository: RuntimeOperationsRepositorying {
    var runs: [BackgroundOperationRun] = []
    var events: [BackgroundOperationEvent] = []
    var jobs: [IntelligenceJob] = []
    var graphDeltas: [GraphDelta] = []
    var pipelineStatuses: [PipelineStatusSummary] = []
    var notificationIntents: [NotificationIntent] = []
    var notificationEvents: [NotificationManagementEvent] = []

    func fetchBackgroundOperationRuns(status: BackgroundOperationStatus?, limit: Int?) throws -> [BackgroundOperationRun] {
        apply(limit: limit, to: runs.filter { status == nil || $0.status == status })
    }

    func fetchBackgroundOperationEvents(runID: UUID?, limit: Int?) throws -> [BackgroundOperationEvent] {
        apply(limit: limit, to: events.filter { runID == nil || $0.runID == runID })
    }

    func upsertBackgroundOperationRun(_ run: BackgroundOperationRun) throws {
        runs.removeAll { $0.id == run.id }
        runs.append(run)
    }

    func upsertBackgroundOperationEvent(_ event: BackgroundOperationEvent) throws {
        events.removeAll { $0.id == event.id }
        events.append(event)
    }

    func fetchNotificationIntents(status: NotificationIntentStatus?, limit: Int?) throws -> [NotificationIntent] {
        apply(limit: limit, to: notificationIntents.filter { status == nil || $0.status == status })
    }

    func upsertNotificationIntent(_ intent: NotificationIntent) throws {
        notificationIntents.removeAll { $0.id == intent.id }
        notificationIntents.append(intent)
    }

    func fetchNotificationManagementEvents(kind: NotificationManagementEventKind?, limit: Int?) throws -> [NotificationManagementEvent] {
        apply(limit: limit, to: notificationEvents.filter { kind == nil || $0.eventKind == kind })
    }

    func upsertNotificationManagementEvent(_ event: NotificationManagementEvent) throws {
        notificationEvents.removeAll { $0.id == event.id }
        notificationEvents.append(event)
    }

    func fetchIntelligenceJobs(status: IntelligenceJobStatus?, limit: Int?) throws -> [IntelligenceJob] {
        apply(limit: limit, to: jobs.filter { status == nil || $0.status == status })
    }

    func fetchGraphDeltas(applied: Bool?, limit: Int?) throws -> [GraphDelta] {
        apply(limit: limit, to: graphDeltas.filter { applied == nil || ($0.appliedAt != nil) == applied })
    }

    func fetchPipelineStatusSummaries(limit: Int?) throws -> [PipelineStatusSummary] {
        apply(limit: limit, to: pipelineStatuses)
    }

    private func apply<T>(limit: Int?, to values: [T]) -> [T] {
        guard let limit else { return values }
        return Array(values.prefix(limit))
    }
}

private final class RuntimePushService: RemotePushSyncing {
    var hasAPNSToken: Bool { false }
    private(set) var writeBackEventIDs: [UUID] = []

    func prepareForLocalDataOwner(_ ownerID: String) {}
    func registerSystemRemoteNotificationsIfNeeded(repository: any MoryMemoryRepositorying) {}
    func syncRegistrationIfPossible(repository: any MoryMemoryRepositorying, force: Bool) async {}
    func enqueueRemotePush(_ payload: RemotePushDeliveryPayload) async throws -> MoryAPIClient.PushEnqueueResponse {
        MoryAPIClient.PushEnqueueResponse(
            accepted: true,
            userID: "runtime-test",
            queuedCount: 1,
            skippedCount: 0
        )
    }
    func writeBackInteraction(_ event: NotificationInteractionEvent) async {
        writeBackEventIDs.append(event.id)
    }
    func fetchDebugSnapshot(intentCounts: RemotePushDebugIntentCounts) async -> RemotePushDebugSnapshot {
        RemotePushDebugSnapshot(
            ownerID: nil,
            deviceID: "runtime-test-device",
            timezone: "UTC",
            hasAPNSToken: false,
            apnsTokenPreview: nil,
            hasRegistrationDigest: false,
            pendingWritebackCount: 0,
            pendingIntentCount: intentCounts.pendingIntentCount,
            scheduledIntentCount: intentCounts.scheduledIntentCount,
            remoteIntentCount: intentCounts.remoteIntentCount
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
