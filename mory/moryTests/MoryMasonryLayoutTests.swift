import CoreGraphics
import XCTest
@testable import mory

final class MoryMasonryLayoutTests: XCTestCase {
    func testColumnSpecClampsColumnWidth() {
        let metrics = MoryMasonryMetrics.default
        XCTAssertEqual(MoryMasonryLayoutPlan<String>.columnSpec(containerWidth: 180, metrics: metrics).columnCount, 1)

        let medium = MoryMasonryLayoutPlan<String>.columnSpec(containerWidth: 390, metrics: metrics)
        XCTAssertEqual(medium.columnCount, 2)
        XCTAssertGreaterThanOrEqual(medium.columnWidth, metrics.minColumnWidth)
        XCTAssertLessThanOrEqual(medium.columnWidth, metrics.maxColumnWidth)

        let wide = MoryMasonryLayoutPlan<String>.columnSpec(containerWidth: 900, metrics: metrics)
        XCTAssertGreaterThanOrEqual(wide.columnCount, 4)
        XCTAssertLessThanOrEqual(wide.columnWidth, metrics.maxColumnWidth)
    }

    func testShortestColumnPlacementIsStable() {
        let nodes = [
            MoryMasonryInputNode(id: "a", order: 0, estimatedHeight: 200),
            MoryMasonryInputNode(id: "b", order: 1, estimatedHeight: 100),
            MoryMasonryInputNode(id: "c", order: 2, estimatedHeight: 120),
            MoryMasonryInputNode(id: "d", order: 3, estimatedHeight: 80),
        ]
        let plan = MoryMasonryLayoutPlan.make(nodes: nodes, containerWidth: 390)

        XCTAssertEqual(plan.slots.map(\.id), ["a", "b", "c", "d"])
        XCTAssertEqual(plan.slots[0].column, 0)
        XCTAssertEqual(plan.slots[1].column, 1)
        XCTAssertEqual(plan.slots[2].column, 1)
        XCTAssertEqual(plan.slots[3].column, 0)
        XCTAssertFalse(hasOverlaps(plan.slots.map(\.frame)))
    }

    func testStickerOverflowExpandsRenderFrameOnly() {
        var metrics = MoryMasonryMetrics.default
        metrics.stickerOverflow = 20
        let plan = MoryMasonryLayoutPlan.make(
            nodes: [MoryMasonryInputNode(id: "a", order: 0, estimatedHeight: 120)],
            containerWidth: 390,
            metrics: metrics
        )
        let slot = try! XCTUnwrap(plan.slots.first)
        XCTAssertEqual(slot.renderFrame.width, slot.frame.width + 40)
        XCTAssertEqual(slot.renderFrame.height, slot.frame.height + 40)
    }

    func testOrderSortsBeforePlacement() {
        let nodes = [
            MoryMasonryInputNode(id: "late", order: 5, estimatedHeight: 120),
            MoryMasonryInputNode(id: "early", order: 0, estimatedHeight: 120),
        ]
        let plan = MoryMasonryLayoutPlan.make(nodes: nodes, containerWidth: 390)
        XCTAssertEqual(plan.slots.map(\.id), ["early", "late"])
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
