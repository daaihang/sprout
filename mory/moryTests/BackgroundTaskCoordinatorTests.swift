import XCTest
@testable import mory

@MainActor
final class BackgroundTaskCoordinatorTests: XCTestCase {

    func testRepositoryIsNilBeforeConfiguration() {
        let coordinator = BackgroundTaskCoordinator()
        XCTAssertNil(coordinator.repository)
    }

    func testConfigureStoresRepository() {
        let coordinator = BackgroundTaskCoordinator()
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: BGCoordinatorTestAnalysisService()
        )
        coordinator.configure(repository: repository, backgroundOrchestrator: .noop)
        XCTAssertNotNil(coordinator.repository)
    }

    func testScheduleIfNeededDoesNotCrash() {
        // BGTaskScheduler.shared.submit() fails silently (try?) in simulator; no crash expected.
        let coordinator = BackgroundTaskCoordinator()
        coordinator.scheduleIfNeeded()
        // Reaching here = pass
    }

    func testConfigureWithCloudServiceStoresIt() {
        let coordinator = BackgroundTaskCoordinator()
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: BGCoordinatorTestAnalysisService()
        )
        coordinator.configure(repository: repository, backgroundOrchestrator: .noop)
        XCTAssertNotNil(coordinator.repository)

        // Reconfigure with the same orchestrator; repository reference should persist.
        coordinator.configure(repository: repository, backgroundOrchestrator: .noop)
        XCTAssertNotNil(coordinator.repository)
    }
}

// MARK: - Test Doubles

private enum BGCoordinatorTestError: Error { case unsupported }

private struct BGCoordinatorTestAnalysisService: ReflectionAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        await RecordAnalysisSnapshot(recordID: record.id, summary: record.rawText, createdAt: .now)
    }

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw BGCoordinatorTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw BGCoordinatorTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? { nil }
}
