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
                    contentDensity: .detailed,
                    layout: MemoryCardLayoutToken(order: 0)
                ),
                MemoryCardNode(
                    contentRef: .artifact(audioID),
                    contentDensity: .simple,
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

        let nodes = MemoryDeskRenderPlan.nodes(for: snapshot)

        XCTAssertEqual(nodes.map(\.contentRef), [.recordBody, .artifact(audioID)])
        XCTAssertEqual(nodes.map(\.contentDensity), [.detailed, .simple])
        XCTAssertFalse(nodes.map(\.contentRef).contains(.artifact(photoID)))
    }

    func testDetailPresentationCarriesArrangementDensity() {
        let item = CaptureCardItem(
            id: "audio",
            payload: .audio(CaptureAudioCardPayload()),
            origin: .manual,
            title: "Audio",
            detail: "Transcript"
        )

        let presentation = CaptureCardPresentation(
            item: item,
            role: .detailViewing,
            provenanceDisplayMode: .production,
            contentDensity: .detailed
        )

        XCTAssertEqual(presentation.contentDensity, .detailed)
    }

    func testPresentationNormalizesUnsupportedDensityByContentKind() {
        let item = CaptureCardItem(
            id: "weather",
            payload: .weather(CaptureWeatherCardPayload()),
            origin: .context,
            title: "22°C",
            detail: "Cloudy"
        )

        let presentation = CaptureCardPresentation(
            item: item,
            role: .detailViewing,
            provenanceDisplayMode: .production,
            contentDensity: .detailed
        )

        XCTAssertEqual(presentation.contentDensity, .simple)
    }

    func testArrangementPlaygroundPreservesDensityOrderAndStack() {
        let snapshot = CardDebugCatalog.arrangementPlaygroundSnapshot()
        let nodes = MemoryDeskRenderPlan.nodes(for: snapshot)

        XCTAssertEqual(nodes.map(\.layout.order), Array(0..<nodes.count))
        XCTAssertTrue(nodes.contains { $0.contentDensity == .simple })
        XCTAssertTrue(nodes.contains { $0.contentDensity == .standard })
        XCTAssertTrue(nodes.contains { node in
            guard case .artifactGroup = node.contentRef else { return false }
            return node.contentDensity == .standard
        })
    }

    func testBoardLayoutPlanUsesMasonryColumnsAndEstimatedHeights() throws {
        let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let nodes = [
            MemoryDeskBoardInputNode(
                id: firstID,
                layout: MemoryCardLayoutToken(order: 0),
                estimatedHeight: 220
            ),
            MemoryDeskBoardInputNode(
                id: secondID,
                layout: MemoryCardLayoutToken(order: 1),
                estimatedHeight: 100
            )
        ]

        let metrics = MemoryDeskBoardMetrics.default
        let plan = MemoryDeskBoardLayoutPlan.make(nodes: nodes, containerWidth: 390, metrics: metrics)
        let firstSlot = try XCTUnwrap(plan.slots.first(where: { $0.id == firstID }))
        let secondSlot = try XCTUnwrap(plan.slots.first(where: { $0.id == secondID }))

        XCTAssertEqual(firstSlot.column, 0)
        XCTAssertEqual(secondSlot.column, 1)
        XCTAssertEqual(firstSlot.frame.height, 220)
        XCTAssertEqual(secondSlot.frame.height, 100)
        XCTAssertEqual(firstSlot.frame.width, plan.columnSpec.columnWidth, accuracy: 0.1)
        XCTAssertGreaterThan(plan.boardHeight, firstSlot.frame.maxY)
    }

    func testBoardLayoutPlanPlacesItemsWithoutOverlap() {
        let nodes = [
            MemoryDeskBoardInputNode(id: "first", layout: MemoryCardLayoutToken(order: 0), estimatedHeight: 220),
            MemoryDeskBoardInputNode(id: "second", layout: MemoryCardLayoutToken(order: 1), estimatedHeight: 90),
            MemoryDeskBoardInputNode(id: "third", layout: MemoryCardLayoutToken(order: 2), estimatedHeight: 120),
            MemoryDeskBoardInputNode(id: "fourth", layout: MemoryCardLayoutToken(order: 3), estimatedHeight: 160)
        ]

        let plan = MemoryDeskBoardLayoutPlan.make(nodes: nodes, containerWidth: 390, metrics: .default)

        XCTAssertEqual(plan.slots.map(\.id), ["first", "second", "third", "fourth"])
        XCTAssertNoFrameOverlap(plan.slots.map(\.frame))
    }
}

private func XCTAssertNoFrameOverlap(
    _ frames: [CGRect],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    for lhs in frames.indices {
        for rhs in frames.indices where rhs > lhs {
            XCTAssertFalse(frames[lhs].intersects(frames[rhs]), "Unexpected overlap", file: file, line: line)
        }
    }
}
