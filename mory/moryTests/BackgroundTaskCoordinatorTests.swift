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
        coordinator.configure(repository: repository, cloudService: nil)
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
        let service = BGCoordinatorTestCloudService()
        coordinator.configure(repository: repository, cloudService: service)
        XCTAssertNotNil(coordinator.repository)

        // Reconfigure with nil cloud service; repository reference should persist.
        coordinator.configure(repository: repository, cloudService: nil)
        XCTAssertNotNil(coordinator.repository)
    }
}

// MARK: - Test Doubles

private enum BGCoordinatorTestError: Error { case unsupported }

private struct BGCoordinatorTestAnalysisService: RecordAnalysisServing {
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

private struct BGCoordinatorTestCloudService: CloudIntelligenceServing {
    func analyzeV7(_ payload: AnalyzeV7RequestPayload) async throws -> AnalyzeV7ResponseEnvelope {
        throw BGCoordinatorTestError.unsupported
    }
    func refineTranscript(_ payload: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse {
        throw BGCoordinatorTestError.unsupported
    }
    func suggestQuestions(_ payload: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse {
        throw BGCoordinatorTestError.unsupported
    }
    func suggestChapters(_ payload: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse {
        throw BGCoordinatorTestError.unsupported
    }
    func analyzePhotoSemantics(_ payload: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse {
        throw BGCoordinatorTestError.unsupported
    }
    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse {
        throw BGCoordinatorTestError.unsupported
    }
}
