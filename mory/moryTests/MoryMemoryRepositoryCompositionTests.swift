import SwiftData
import XCTest
@testable import mory

@MainActor
final class MoryMemoryRepositoryCompositionTests: XCTestCase {
    func testFetchHomeBoardReturnsCompositionDrivenMemoryRenderValues() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Train insight",
                rawText: "Walked in the rain and the quarter plan clicked.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Train insight", body: "Walked in the rain and the quarter plan clicked.")]
            )
        )

        let board = try repository.fetchHomeBoard(for: Date(), limit: 8)

        XCTAssertFalse(board.items.isEmpty)
        XCTAssertTrue(board.items.allSatisfy {
            if case .memory = $0.renderValue { return true }
            return false
        })
    }

    func testFetchGraphOverviewReturnsPeopleThemesAndEdgesFromGraphLayer() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Dinner plan",
                rawText: "Met Linh after dinner and mapped the next quarter plan.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Dinner plan", body: "Met Linh after dinner and mapped the next quarter plan.")]
            )
        )
        let latestMemory = try XCTUnwrap(repository.fetchRecentMemories(limit: 1).first)
        try await repository.refreshMemoryPipeline(recordID: latestMemory.record.id)

        let themes = try repository.fetchThemeSummaries(limit: 10)
        let overview = try repository.fetchGraphOverview(limitPerKind: 10, edgeLimit: 10)

        XCTAssertFalse(themes.isEmpty)
        XCTAssertTrue(themes.contains(where: { $0.entity.kind == .theme && $0.entity.displayName == "planning" }))
        XCTAssertTrue(overview.entitySections.contains(where: { $0.kind == .person && $0.entities.contains(where: { $0.displayName == "Linh" }) }))
        XCTAssertTrue(overview.entitySections.contains(where: { $0.kind == .theme && $0.entities.contains(where: { $0.displayName == "planning" }) }))
        XCTAssertFalse(overview.topEdges.isEmpty)
    }

    func testDetailArcAndReflectionQueriesReturnLinkedSnapshots() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Late train insight",
                rawText: "Missed the express home after dinner with Linh and the quarter plan clicked into place.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Late train insight", body: "Missed the express home after dinner with Linh and the quarter plan clicked into place.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        let detail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: memory.record.id))
        let arcSummaries = try repository.fetchTemporalArcSummaries(limit: 10)
        let reflectionSummaries = try repository.fetchReflectionSummaries(limit: 10)

        XCTAssertNotNil(detail.analysis)
        XCTAssertFalse(detail.entities.isEmpty)
        XCTAssertFalse(detail.edges.isEmpty)
        XCTAssertFalse(detail.arcs.isEmpty)
        XCTAssertFalse(detail.reflections.isEmpty)

        let matchingArc = try XCTUnwrap(arcSummaries.first(where: { $0.arc.sourceRecordIDs.contains(memory.record.id) }))
        XCTAssertFalse(matchingArc.relatedMemories.isEmpty)
        XCTAssertEqual(matchingArc.relatedMemories.first?.record.id, memory.record.id)
        XCTAssertNotNil(matchingArc.linkedReflection)

        let matchingReflection = try XCTUnwrap(
            reflectionSummaries.first(where: {
                $0.reflection.sourceRecordIDs.contains(memory.record.id) ||
                $0.linkedArc?.sourceRecordIDs.contains(memory.record.id) == true
            })
        )
        XCTAssertFalse(matchingReflection.relatedMemories.isEmpty)
    }

    func testEntityDetailReturnsRelatedMemoriesThemesArcsAndReflections() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Quarter planning walk",
                rawText: "Walked home with Linh in the rain and clarified the quarter planning priorities.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Quarter planning walk", body: "Walked home with Linh in the rain and clarified the quarter planning priorities.")]
            )
        )
        let latestMemory = try XCTUnwrap(repository.fetchRecentMemories(limit: 1).first)
        try await repository.refreshMemoryPipeline(recordID: latestMemory.record.id)

        let people = try repository.fetchEntityDetails(kind: .person, limit: 10)
        let person = try XCTUnwrap(people.first(where: { $0.entity.displayName == "Linh" }))

        XCTAssertFalse(person.relatedMemories.isEmpty)
        XCTAssertTrue(person.relatedThemes.contains("planning"))
        XCTAssertFalse(person.relatedArcs.isEmpty)
        XCTAssertFalse(person.relatedReflections.isEmpty)
        XCTAssertFalse(person.edges.isEmpty)
    }

    func testSearchReturnsFormalObjectSnapshots() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService()
        )

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning dinner",
                rawText: "Dinner with Linh turned into a planning session for the next quarter.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Planning dinner", body: "Dinner with Linh turned into a planning session for the next quarter.")]
            )
        )
        let latestMemory = try XCTUnwrap(repository.fetchRecentMemories(limit: 1).first)
        try await repository.refreshMemoryPipeline(recordID: latestMemory.record.id)

        let result = try repository.search(query: "planning", limit: 10)

        XCTAssertFalse(result.memories.isEmpty)
        XCTAssertFalse(result.entities.isEmpty)
        XCTAssertFalse(result.arcs.isEmpty)
        XCTAssertFalse(result.reflections.isEmpty)
        XCTAssertTrue(result.entities.contains(where: { $0.entity.kind == .theme || $0.entity.kind == .person }))
        XCTAssertTrue(result.arcs.contains(where: { !$0.summary.relatedMemories.isEmpty }))
        XCTAssertTrue(result.reflections.contains(where: { !$0.summary.relatedMemories.isEmpty }))
    }

    func testCreateMemoryStillSucceedsWhenAnalysisHasNotRunYet() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: FailingRecordAnalysisService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Offline save",
                rawText: "This should save even if analysis is unavailable.",
                mood: "steady",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Offline save", body: "This should save even if analysis is unavailable.")]
            )
        )

        XCTAssertEqual(memory.record.rawText, "This should save even if analysis is unavailable.")
        XCTAssertEqual(memory.pipelineStatus?.stage, .pending)
        XCTAssertNil(try repository.fetchRecordAnalysis(recordID: memory.record.id))

        do {
            try await repository.refreshMemoryPipeline(recordID: memory.record.id)
            XCTFail("Expected refresh pipeline to fail when analysis service is unavailable")
        } catch {
            let status = try repository.fetchPipelineStatus(recordID: memory.record.id)
            XCTAssertEqual(status?.stage, .failed)
            XCTAssertNotNil(status?.lastError)
        }
    }

    func testUpdateMemoryPersistsCorrectionsAndAddsSupportingArtifact() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Draft note",
                rawText: "Initial wording that needs correction.",
                mood: "unclear",
                inputContext: "typed quickly",
                captureSource: .composer,
                artifacts: [.text(title: "Draft note", body: "Initial wording that needs correction.")]
            )
        )

        let updated = try await repository.updateMemory(
            recordID: memory.record.id,
            draft: MemoryEditDraft(
                rawText: "Corrected wording with clearer intent.",
                userMood: "focused",
                inputContext: "rewritten in detail",
                appendedArtifactText: "Follow-up note with one more concrete detail."
            )
        )

        let detail = try XCTUnwrap(updated)
        XCTAssertEqual(detail.record.rawText, "Corrected wording with clearer intent.")
        XCTAssertEqual(detail.record.userMood, "focused")
        XCTAssertEqual(detail.record.inputContext, "rewritten in detail")
        XCTAssertTrue(detail.artifacts.contains(where: { $0.summary == "Follow-up note with one more concrete detail." }))
        XCTAssertEqual(detail.pipelineStatus?.stage, .pending)
    }

    func testMergeTemporalArcReturnsMergedDetailAndArchivesCandidate() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService()
        )

        let first = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning walk one",
                rawText: "Walked with Linh and reviewed quarter planning priorities.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Planning walk one", body: "Walked with Linh and reviewed quarter planning priorities.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: first.record.id)

        let second = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning walk two",
                rawText: "Another rainy walk with Linh pushed the same planning theme further.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Planning walk two", body: "Another rainy walk with Linh pushed the same planning theme further.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: second.record.id)

        let arcsBefore = try repository.fetchTemporalArcSummaries(limit: 10)
        let sourceArc = try XCTUnwrap(arcsBefore.first(where: { $0.arc.sourceRecordIDs.contains(first.record.id) }))
        XCTAssertNotNil(try repository.fetchTemporalArcDetail(arcID: sourceArc.arc.id)?.mergeCandidate)

        let mergedDetail = try await repository.mergeTemporalArc(arcID: sourceArc.arc.id)
        let detail = try XCTUnwrap(mergedDetail)

        XCTAssertTrue(detail.summary.arc.sourceRecordIDs.contains(first.record.id))
        XCTAssertTrue(detail.summary.arc.sourceRecordIDs.contains(second.record.id))
        XCTAssertNil(detail.mergeCandidate)
        XCTAssertTrue(detail.reflections.count >= 1)
    }

    func testReflectionMutationsPersistStatusChanges() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService()
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Reflection note",
                rawText: "Dinner with Linh turned into a planning session with reflective value.",
                mood: "reflective",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Reflection note", body: "Dinner with Linh turned into a planning session with reflective value.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        let reflection = try XCTUnwrap(repository.fetchReflectionSummaries(limit: 10).first)

        try await repository.saveReflection(reflectionID: reflection.reflection.id)
        XCTAssertEqual(try repository.fetchReflectionDetail(reflectionID: reflection.reflection.id)?.summary.reflection.status, .saved)

        try await repository.dismissReflection(reflectionID: reflection.reflection.id)
        XCTAssertEqual(try repository.fetchReflectionDetail(reflectionID: reflection.reflection.id)?.summary.reflection.status, .dismissed)

        try await repository.archiveReflection(reflectionID: reflection.reflection.id)
        XCTAssertEqual(try repository.fetchReflectionDetail(reflectionID: reflection.reflection.id)?.summary.reflection.status, .archived)
    }
}

private struct StubRecordAnalysisService: RecordAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: "Stub summary",
            themes: ["planning"],
            emotionInterpretation: "reflective",
            salienceScore: 0.6,
            retrievalTerms: ["planning", "rain"],
            entityMentions: [
                EntityReference(kind: .person, name: "Linh", confidence: 0.9),
                EntityReference(kind: .theme, name: "planning", confidence: 0.8),
                EntityReference(kind: .place, name: "Rain Walk", confidence: 0.7),
            ],
            candidateEdges: [
                CandidateEntityEdge(
                    from: EntityReference(kind: .person, name: "Linh", confidence: 0.9),
                    to: EntityReference(kind: .theme, name: "planning", confidence: 0.8),
                    relationKind: .relatedTo,
                    confidence: 0.75
                )
            ],
            followUpCandidates: [],
            reflectionHint: "Watch for repeated planning moments.",
            createdAt: record.updatedAt
        )
    }
}

private struct FailingRecordAnalysisService: RecordAnalysisServing {
    struct StubError: LocalizedError {
        var errorDescription: String? { "Analysis service unavailable." }
    }

    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        throw StubError()
    }
}
