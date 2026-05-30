import XCTest
@testable import mory

final class CaptureAttachmentCompactBoardTests: XCTestCase {
    func testCompactBoardLayoutAcceptsStringItemIDsAndPackedGridPlacements() throws {
        let sizes: [MemoryCardSizeToken] = [.square, .tape, .card, .stamp, .strip]
        let placements = MemoryCardGridPacking.placements(for: sizes)
        let nodes = sizes.enumerated().map { index, size in
            MemoryDeskBoardInputNode(
                id: "item-\(index)",
                layout: MemoryCardLayoutToken(
                    order: index,
                    size: size,
                    gridPlacement: placements[index]
                )
            )
        }

        let plan = MemoryDeskBoardLayoutPlan.make(
            nodes: nodes,
            containerWidth: 390,
            metrics: .compactComposer
        )

        XCTAssertEqual(plan.slots.map(\.id), ["item-0", "item-1", "item-2", "item-3", "item-4"])
        XCTAssertEqual(plan.slots.count, sizes.count)
        XCTAssertGreaterThan(plan.boardHeight, 0)
        for slot in plan.slots {
            XCTAssertGreaterThan(slot.frame.width, 0)
            XCTAssertGreaterThan(slot.frame.height, 0)
        }
    }
}
