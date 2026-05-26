import XCTest
@testable import mory

@MainActor
final class CaptureOrchestratorTests: XCTestCase {
    func testDefaultCapturePolicySavesWithoutRunningPipeline() async throws {
        let repository = CaptureOrchestratorRepositoryStub()
        let draft = MemoryCaptureDraft(rawText: "Local only memory")

        let memory = try await CaptureOrchestrator(memoryRepository: repository).capture(draft: draft)

        XCTAssertEqual(memory.record.rawText, "Local only memory")
        XCTAssertEqual(repository.createCallCount, 1)
        XCTAssertEqual(repository.refreshCallCount, 0)
    }

    func testRunAfterSavePolicyTriggersPipelineExplicitly() async throws {
        let repository = CaptureOrchestratorRepositoryStub()
        let draft = MemoryCaptureDraft(rawText: "Analyze after save")

        _ = try await CaptureOrchestrator(
            memoryRepository: repository,
            pipelinePolicy: .runAfterSave
        ).capture(draft: draft)

        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(repository.createCallCount, 1)
        XCTAssertEqual(repository.refreshCallCount, 1)
    }
}

@MainActor
private final class CaptureOrchestratorRepositoryStub: MemoryCaptureRepositorying {
    private(set) var createCallCount = 0
    private(set) var refreshCallCount = 0
    private var lastRecordID: UUID?

    func createMemory(from draft: MemoryCaptureDraft) async throws -> MemorySummary {
        createCallCount += 1
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let record = RecordShell(
            createdAt: now,
            updatedAt: now,
            captureSource: .composer,
            rawText: draft.rawText
        )
        lastRecordID = record.id
        return MemorySummary(
            record: record,
            primaryArtifact: nil,
            contextArtifacts: [],
            artifactCount: 0,
            pipelineStatus: nil
        )
    }

    func applyMemoryMutation(
        recordID: UUID,
        mutation: MemoryMutationDraft,
        refreshPolicy: MemoryMutationRefreshPolicy
    ) async throws -> MemoryMutationResult {
        XCTFail("Mutation is not part of capture orchestration tests")
        return MemoryMutationResult(
            mutationID: UUID(),
            detail: nil,
            addedArtifactIDs: [],
            updatedArtifactIDs: [],
            deletedArtifactIDs: [],
            reorderedArtifactIDs: [],
            invalidatedDerivedData: false,
            pipelineStatus: nil
        )
    }

    func appendArtifacts(recordID: UUID, drafts: [CaptureArtifactDraft]) async throws -> MemorySummary? {
        XCTFail("Append is not part of capture orchestration tests")
        return nil
    }

    func updateMemory(recordID: UUID, draft: MemoryEditDraft) async throws -> MemoryDetailSnapshot? {
        XCTFail("Update is not part of capture orchestration tests")
        return nil
    }

    func deleteMemory(recordID: UUID) throws {
        XCTFail("Delete is not part of capture orchestration tests")
    }

    func refreshMemoryPipeline(recordID: UUID) async throws {
        XCTAssertEqual(recordID, lastRecordID)
        refreshCallCount += 1
    }
}
