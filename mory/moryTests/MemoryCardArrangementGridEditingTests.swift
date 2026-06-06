import XCTest
@testable import mory

final class MemoryCardArrangementGridEditingTests: XCTestCase {
    func testUnsupportedSizeFallsBackThroughLayoutPolicy() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let placeID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let arrangement = MemoryCardArrangement(
            recordID: recordID,
            nodes: [
                MemoryCardNode(
                    contentRef: .artifact(placeID),
                    visualRecipe: .mapTicket,
                    layout: MemoryCardLayoutToken(order: 0, size: .stamp)
                )
            ],
            createdAt: now,
            updatedAt: now
        )

        let arranged = arrangement.autoArranged(updatedAt: now)

        XCTAssertEqual(arranged.nodes.first?.layout.size, .card)
        XCTAssertEqual(arranged.nodes.first?.layout.gridPlacement, MemoryCardGridPlacement(column: 0, row: 0))
    }

    func testAutoArrangePreservesRecipeSizeStackAndRepackedPlacement() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let photoID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let audioID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let todoID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let arrangement = MemoryCardArrangement(
            recordID: recordID,
            nodes: [
                MemoryCardNode(
                    contentRef: .artifact(photoID),
                    visualRecipe: .polaroid,
                    layout: MemoryCardLayoutToken(order: 2, size: .card, gridPlacement: MemoryCardGridPlacement(column: 3, row: 9), rotationDegrees: -2)
                ),
                MemoryCardNode(
                    contentRef: .artifactGroup([audioID, todoID], kind: .mediaStack),
                    visualRecipe: .bundlePacket,
                    layout: MemoryCardLayoutToken(order: 1, size: .card, gridPlacement: MemoryCardGridPlacement(column: 3, row: 4), rotationDegrees: 1)
                )
            ],
            createdAt: now,
            updatedAt: now
        )

        let arranged = arrangement.autoArranged(updatedAt: now)

        XCTAssertEqual(arranged.nodes.map(\.layout.order), [0, 1])
        XCTAssertEqual(arranged.nodes.map(\.visualRecipe), [.bundlePacket, .polaroid])
        XCTAssertEqual(arranged.nodes.map(\.layout.size), [.card, .card])
        XCTAssertTrue(arranged.nodes.allSatisfy { $0.layout.gridPlacement != nil })
        XCTAssertEqual(arranged.nodes[0].layout.rotationDegrees, 1)
        XCTAssertEqual(arranged.nodes[1].layout.rotationDegrees, -2)
        XCTAssertNoGridOverlap(arranged.nodes)
    }

    func testRowMoveChangesOrderAndRepackWithoutOverlaps() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let bannerID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let stripID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let cardID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let arrangement = MemoryCardArrangement(
            recordID: recordID,
            nodes: [
                MemoryCardNode(
                    contentRef: .artifact(bannerID),
                    visualRecipe: .notebook,
                    layout: MemoryCardLayoutToken(order: 0, size: .card)
                ),
                MemoryCardNode(
                    contentRef: .artifact(stripID),
                    visualRecipe: .taskNote,
                    layout: MemoryCardLayoutToken(order: 2, size: .strip)
                ),
                MemoryCardNode(
                    contentRef: .artifact(cardID),
                    visualRecipe: .linkNote,
                    layout: MemoryCardLayoutToken(order: 1, size: .card)
                )
            ],
            createdAt: now,
            updatedAt: now
        ).autoArranged(updatedAt: now)

        let moved = arrangement.movingArtifactToAdjacentBoardRow(
            artifactID: stripID,
            direction: .up,
            updatedAt: now
        )

        XCTAssertEqual(moved.nodes.first?.contentRef, .artifact(stripID))
        XCTAssertEqual(moved.nodes.map(\.layout.order), [0, 1, 2])
        XCTAssertTrue(moved.nodes.allSatisfy { $0.layout.gridPlacement != nil })
        XCTAssertNoGridOverlap(moved.nodes)
    }

    func testMoveEarlierLaterUsesExistingNodesInsteadOfDefaultArrangement() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let photoID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let audioID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let arrangement = MemoryCardArrangement(
            recordID: recordID,
            nodes: [
                MemoryCardNode(
                    contentRef: .artifact(photoID),
                    visualRecipe: .polaroid,
                    layout: MemoryCardLayoutToken(order: 0, size: .card)
                ),
                MemoryCardNode(
                    contentRef: .artifact(audioID),
                    visualRecipe: .cassette,
                    layout: MemoryCardLayoutToken(order: 1, size: .strip)
                )
            ],
            createdAt: now,
            updatedAt: now
        )

        let moved = arrangement.movingArtifact(artifactID: audioID, by: -1, updatedAt: now)

        XCTAssertEqual(moved.nodes.first?.contentRef, .artifact(audioID))
        XCTAssertEqual(moved.nodes.first?.visualRecipe, .cassette)
        XCTAssertEqual(moved.nodes.first?.layout.size, .strip)
        XCTAssertEqual(moved.nodes.last?.visualRecipe, .polaroid)
        XCTAssertEqual(moved.nodes.last?.layout.size, .card)
        XCTAssertNoGridOverlap(moved.nodes)
    }

    private func XCTAssertNoGridOverlap(
        _ nodes: [MemoryCardNode],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var occupied = Set<GridCell>()
        for node in nodes {
            guard let placement = node.layout.gridPlacement else {
                XCTFail("Missing grid placement", file: file, line: line)
                continue
            }
            let box = MemoryCardRecipeLayoutPolicy.gridBox(for: node.layout.size)
            for row in placement.row..<(placement.row + box.rowSpan) {
                for column in placement.column..<(placement.column + box.columnSpan) {
                    let cell = GridCell(column: column, row: row)
                    XCTAssertFalse(occupied.contains(cell), "Unexpected overlap at \(cell)", file: file, line: line)
                    occupied.insert(cell)
                }
            }
        }
    }
}

private struct GridCell: Hashable, CustomStringConvertible {
    let column: Int
    let row: Int

    var description: String {
        "(\(column), \(row))"
    }
}
