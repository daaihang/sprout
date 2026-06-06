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
            sizeToken: .stamp
        )

        XCTAssertEqual(presentation.visualRecipe, .weatherStamp)
        XCTAssertEqual(presentation.sizeToken, .stamp)
        XCTAssertEqual(presentation.visualVariant, .weatherHumidity)
    }

    func testArrangementPlaygroundPreservesRecipeSizeOrderAndStack() {
        let snapshot = CardDebugCatalog.arrangementPlaygroundSnapshot()
        let nodes = MemoryDeskRenderPlan.nodes(for: snapshot)

        XCTAssertEqual(nodes.map(\.layout.order), Array(0..<nodes.count))
        XCTAssertTrue(nodes.contains { $0.visualRecipe == .weatherStamp && $0.layout.size == .stamp })
        XCTAssertTrue(nodes.contains { $0.visualRecipe == .mapTicket && $0.layout.size == .card })
        XCTAssertTrue(nodes.contains { node in
            guard case .artifactGroup = node.contentRef else { return false }
            return node.visualRecipe == .bundlePacket && node.layout.size == .card
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
                    layout: MemoryCardLayoutToken(order: 0, size: .stamp)
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

    func testBoardLayoutPlanUsesArrangementGridPlacementAndTokenSpan() throws {
        let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let nodes = [
            MemoryDeskBoardInputNode(
                id: firstID,
                layout: MemoryCardLayoutToken(
                    order: 0,
                    size: .card,
                    gridPlacement: MemoryCardGridPlacement(column: 0, row: 0)
                )
            ),
            MemoryDeskBoardInputNode(
                id: secondID,
                layout: MemoryCardLayoutToken(
                    order: 1,
                    size: .strip,
                    gridPlacement: MemoryCardGridPlacement(column: 2, row: 3)
                )
            )
        ]

        let metrics = MemoryDeskBoardMetrics.default
        let plan = MemoryDeskBoardLayoutPlan.make(nodes: nodes, containerWidth: 390, metrics: metrics)
        let cardSlot = try XCTUnwrap(plan.slots.first(where: { $0.id == firstID }))
        let stripSlot = try XCTUnwrap(plan.slots.first(where: { $0.id == secondID }))

        let cellWidth = metrics.cellWidth(for: 390)
        let expectedCardWidth = CGFloat(2) * cellWidth + metrics.columnSpacing
        let expectedStripWidth = CGFloat(2) * cellWidth + metrics.columnSpacing

        XCTAssertEqual(cardSlot.frame.origin.x, metrics.horizontalPadding, accuracy: 0.1)
        XCTAssertEqual(cardSlot.frame.width, expectedCardWidth, accuracy: 0.1)
        XCTAssertEqual(stripSlot.frame.origin.x, metrics.horizontalPadding + CGFloat(2) * (cellWidth + metrics.columnSpacing), accuracy: 0.1)
        XCTAssertEqual(stripSlot.frame.origin.y, metrics.verticalPadding + CGFloat(3) * (metrics.rowHeight + metrics.rowSpacing), accuracy: 0.1)
        XCTAssertEqual(stripSlot.frame.width, expectedStripWidth, accuracy: 0.1)
        XCTAssertGreaterThan(plan.boardHeight, stripSlot.frame.maxY)
    }

    func testBoardLayoutPlanFirstFitPacksMissingGridPlacementsWithoutOverlap() {
        let nodes = [
            MemoryDeskBoardInputNode(id: "card-a", layout: MemoryCardLayoutToken(order: 0, size: .card)),
            MemoryDeskBoardInputNode(id: "strip", layout: MemoryCardLayoutToken(order: 1, size: .strip)),
            MemoryDeskBoardInputNode(id: "stamp", layout: MemoryCardLayoutToken(order: 2, size: .stamp)),
            MemoryDeskBoardInputNode(id: "card-b", layout: MemoryCardLayoutToken(order: 3, size: .card))
        ]

        let plan = MemoryDeskBoardLayoutPlan.make(nodes: nodes, containerWidth: 390, metrics: .default)

        XCTAssertEqual(plan.slots.map(\.id), ["card-a", "strip", "stamp", "card-b"])
        XCTAssertTrue(plan.slots.allSatisfy { $0.layout.gridPlacement != nil })
        XCTAssertNoGridOverlap(plan.slots.map(\.layout))
    }
}

private func XCTAssertNoGridOverlap(
    _ layouts: [MemoryCardLayoutToken],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    var occupied = Set<MemoryDeskRendererTestGridCell>()
    for layout in layouts {
        guard let placement = layout.gridPlacement else {
            XCTFail("Missing grid placement", file: file, line: line)
            continue
        }
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: layout.size)
        for row in placement.row..<(placement.row + box.rowSpan) {
            for column in placement.column..<(placement.column + box.columnSpan) {
                let cell = MemoryDeskRendererTestGridCell(column: column, row: row)
                XCTAssertFalse(occupied.contains(cell), "Unexpected overlap at \(cell)", file: file, line: line)
                occupied.insert(cell)
            }
        }
    }
}

private struct MemoryDeskRendererTestGridCell: Hashable, CustomStringConvertible {
    let column: Int
    let row: Int

    var description: String {
        "(\(column), \(row))"
    }
}
