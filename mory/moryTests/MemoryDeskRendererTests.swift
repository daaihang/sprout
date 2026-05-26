import XCTest
@testable import mory

@MainActor
final class MemoryDeskRendererTests: XCTestCase {
    func testRenderPlanUsesArrangementInsteadOfInferringArtifactMode() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let photoID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let audioID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let record = RecordShell(
            id: recordID,
            createdAt: now,
            updatedAt: now,
            captureSource: .composer,
            rawText: "Renderer should follow arrangement.",
            artifactIDs: [photoID, audioID]
        )
        let photo = Artifact(
            id: photoID,
            recordID: recordID,
            kind: .photo,
            title: "Photo",
            summary: "Photo summary",
            textContent: "Photo summary",
            createdAt: now,
            updatedAt: now
        )
        let audio = Artifact(
            id: audioID,
            recordID: recordID,
            kind: .audio,
            title: "Audio",
            summary: "Audio summary",
            textContent: "Audio transcript",
            createdAt: now,
            updatedAt: now
        )
        let arrangement = MemoryCardArrangement(
            recordID: recordID,
            nodes: [
                MemoryCardNode(
                    contentRef: .recordBody,
                    visualRecipe: .notebook,
                    layout: MemoryCardLayoutToken(order: 0)
                ),
                MemoryCardNode(
                    contentRef: .artifact(audioID),
                    visualRecipe: .cassette,
                    layout: MemoryCardLayoutToken(order: 1)
                )
            ],
            createdAt: now,
            updatedAt: now
        )
        let snapshot = MemoryDetailSnapshot(
            record: record,
            artifacts: [photo, audio],
            artifactSemanticDigests: [],
            cardArrangement: arrangement,
            analysis: nil,
            pipelineStatus: nil,
            entities: [],
            edges: [],
            arcs: [],
            reflections: []
        )

        let contentRefs = MemoryDeskRenderPlan.nodes(for: snapshot).map(\.contentRef)

        XCTAssertEqual(contentRefs, [.recordBody, .artifact(audioID)])
        XCTAssertFalse(contentRefs.contains(.artifact(photoID)))
    }
}
