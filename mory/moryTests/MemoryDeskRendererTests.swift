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
        let visualRecipes = MemoryDeskRenderPlan.nodes(for: snapshot).map(\.visualRecipe)

        XCTAssertEqual(contentRefs, [.recordBody, .artifact(audioID)])
        XCTAssertEqual(visualRecipes, [.notebook, .cassette])
        XCTAssertFalse(contentRefs.contains(.artifact(photoID)))
    }

    func testDetailPresentationCarriesArrangementVisualRecipe() {
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
            surfaceMode: .skeuomorphic,
            visualRecipe: .cassette
        )

        XCTAssertEqual(presentation.surfaceMode, .skeuomorphic)
        XCTAssertEqual(presentation.visualRecipe, .cassette)
    }

    func testDetailPresentationCarriesArrangementVariant() {
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
            surfaceMode: .skeuomorphic,
            visualRecipe: .weatherStamp,
            visualVariant: .weatherHumidity,
            contentDensity: .compact
        )

        XCTAssertEqual(presentation.visualRecipe, .weatherStamp)
        XCTAssertEqual(presentation.visualVariant, .weatherHumidity)
        XCTAssertEqual(presentation.contentDensity, .compact)
    }

    func testArrangementPlaygroundPreservesRecipeOrderAndStack() {
        let snapshot = CardDebugCatalog.arrangementPlaygroundSnapshot()
        let nodes = MemoryDeskRenderPlan.nodes(for: snapshot)

        XCTAssertEqual(nodes.map(\.layout.order), Array(0..<nodes.count))
        XCTAssertTrue(nodes.contains { $0.visualRecipe == .weatherStamp })
        XCTAssertTrue(nodes.contains { $0.visualRecipe == .mapTicket })
        XCTAssertTrue(nodes.contains { node in
            guard case .artifactGroup = node.contentRef else { return false }
            return node.visualRecipe == .bundlePacket
        })
    }

    func testRenderPlanPreservesVisualVariantFromArrangement() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID(uuidString: "ABABABAB-ABAB-ABAB-ABAB-ABABABABABAB")!
        let weatherID = UUID(uuidString: "CDCDCDCD-CDCD-CDCD-CDCD-CDCDCDCDCDCD")!
        let record = RecordShell(
            id: recordID,
            createdAt: now,
            updatedAt: now,
            captureSource: .composer,
            rawText: "Weather variant check.",
            artifactIDs: [weatherID]
        )
        let weather = Artifact(
            id: weatherID,
            recordID: recordID,
            kind: .weather,
            title: "22°C",
            summary: "Cloudy",
            metadata: ["condition": "Cloudy", "temperatureCelsius": "22"],
            createdAt: now,
            updatedAt: now
        )
        let arrangement = MemoryCardArrangement(
            recordID: recordID,
            nodes: [
                MemoryCardNode(
                    contentRef: .artifact(weatherID),
                    visualRecipe: .weatherStamp,
                    visualVariant: .weatherHumidity,
                    layout: MemoryCardLayoutToken(order: 0)
                ),
            ],
            createdAt: now,
            updatedAt: now
        )
        let snapshot = MemoryDetailSnapshot(
            record: record,
            artifacts: [weather],
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
        XCTAssertEqual(nodes.first?.visualVariant, .weatherHumidity)
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
            MemoryDeskBoardInputNode(id: "card-a", layout: MemoryCardLayoutToken(order: 0), estimatedHeight: 220),
            MemoryDeskBoardInputNode(id: "strip", layout: MemoryCardLayoutToken(order: 1), estimatedHeight: 90),
            MemoryDeskBoardInputNode(id: "stamp", layout: MemoryCardLayoutToken(order: 2), estimatedHeight: 120),
            MemoryDeskBoardInputNode(id: "card-b", layout: MemoryCardLayoutToken(order: 3), estimatedHeight: 160)
        ]

        let plan = MemoryDeskBoardLayoutPlan.make(nodes: nodes, containerWidth: 390, metrics: .default)

        XCTAssertEqual(plan.slots.map(\.id), ["card-a", "strip", "stamp", "card-b"])
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
