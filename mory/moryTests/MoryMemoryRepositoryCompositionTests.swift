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
