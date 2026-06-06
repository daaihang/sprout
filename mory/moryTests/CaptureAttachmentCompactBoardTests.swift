import CoreGraphics
import XCTest
@testable import mory

final class CaptureAttachmentCompactBoardTests: XCTestCase {
    func testCompactBoardLayoutAcceptsStringItemIDsAndMasonryFrames() {
        let nodes = (0..<5).map { index in
            MemoryDeskBoardInputNode(
                id: "item-\(index)",
                layout: MemoryCardLayoutToken(order: index),
                estimatedHeight: [168, 92, 120, 188, 104][index]
            )
        }

        let plan = MemoryDeskBoardLayoutPlan.make(
            nodes: nodes,
            containerWidth: 390,
            metrics: .compactComposer
        )

        XCTAssertEqual(plan.slots.map(\.id), ["item-0", "item-1", "item-2", "item-3", "item-4"])
        XCTAssertEqual(plan.slots.count, nodes.count)
        XCTAssertGreaterThan(plan.boardHeight, 0)
        XCTAssertFalse(hasOverlaps(plan.slots.map(\.frame)))
        for slot in plan.slots {
            XCTAssertGreaterThan(slot.frame.width, 0)
            XCTAssertGreaterThan(slot.frame.height, 0)
            XCTAssertGreaterThan(slot.renderFrame.width, slot.frame.width)
        }
    }

    private func hasOverlaps(_ frames: [CGRect]) -> Bool {
        for lhs in frames.indices {
            for rhs in frames.indices where rhs > lhs {
                if frames[lhs].intersects(frames[rhs]) {
                    return true
                }
            }
        }
        return false
    }
}
