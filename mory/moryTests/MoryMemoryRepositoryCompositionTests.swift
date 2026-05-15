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
