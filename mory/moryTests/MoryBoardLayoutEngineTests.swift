import XCTest
@testable import mory

final class MoryBoardLayoutEngineTests: XCTestCase {
    private let engine = MoryBoardLayoutEngine<String>()

    func testAllowedSizesClampWithinFourColumns() {
        let item = layoutItem("a", x: 99, y: -4, size: .card)

        let moved = engine.moveItem(id: "a", to: MoryBoardGridPoint(x: 99, y: 0), in: [item])

        XCTAssertEqual(moved.first?.x, 2)
        XCTAssertEqual(moved.first?.y, 0)
        XCTAssertEqual(moved.first?.w, 2)
        XCTAssertEqual(moved.first?.h, 2)
        XCTAssertFalse(engine.hasOverlaps(moved))
    }

    func testMoveItemRecursivelyPushesOrdinaryCollisions() {
        let active = layoutItem("active", x: 2, y: 0, size: .strip)
        let blocker = layoutItem("blocker", x: 0, y: 0, size: .strip)
        let follower = layoutItem("follower", x: 0, y: 1, size: .strip)

        let moved = engine.moveItem(
            id: "active",
            to: MoryBoardGridPoint(x: 0, y: 0),
            in: [active, blocker, follower]
        )

        XCTAssertEqual(item("active", in: moved)?.point, MoryBoardGridPoint(x: 0, y: 0))
        XCTAssertFalse(engine.hasOverlaps(moved))
        XCTAssertGreaterThanOrEqual(item("blocker", in: moved)?.y ?? 0, 1)
    }

    func testSideShiftHappensBeforeDownPush() {
        let active = layoutItem("active", x: 2, y: 0, size: .strip)
        let blocker = layoutItem("blocker", x: 0, y: 0, size: .strip)

        let moved = engine.moveItem(
            id: "active",
            to: MoryBoardGridPoint(x: 0, y: 0),
            in: [active, blocker]
        )

        XCTAssertEqual(item("blocker", in: moved)?.point, MoryBoardGridPoint(x: 2, y: 0))
        XCTAssertFalse(engine.hasOverlaps(moved))
    }

    func testPinnedItemIsNotPushedAndActiveFindsLegalPlacement() {
        let active = layoutItem("active", x: 2, y: 0, size: .strip)
        let pinned = layoutItem("pinned", x: 0, y: 0, size: .strip, isPinned: true)

        let moved = engine.moveItem(
            id: "active",
            to: MoryBoardGridPoint(x: 0, y: 0),
            in: [active, pinned]
        )

        XCTAssertEqual(item("pinned", in: moved)?.point, MoryBoardGridPoint(x: 0, y: 0))
        XCTAssertEqual(item("active", in: moved)?.point, MoryBoardGridPoint(x: 2, y: 0))
        XCTAssertFalse(engine.hasOverlaps(moved))
    }

    func testVerticalCompactOnlyChangesYAndPreservesX() {
        let left = layoutItem("left", x: 0, y: 3, size: .strip)
        let right = layoutItem("right", x: 2, y: 2, size: .strip)

        let compacted = engine.compactVertically([left, right])

        XCTAssertEqual(item("left", in: compacted)?.x, 0)
        XCTAssertEqual(item("right", in: compacted)?.x, 2)
        XCTAssertEqual(item("left", in: compacted)?.y, 0)
        XCTAssertEqual(item("right", in: compacted)?.y, 0)
        XCTAssertFalse(engine.hasOverlaps(compacted))
    }

    func testResizeGrowingResolvesCollisionAndShrinkingCompacts() {
        let hero = layoutItem("hero", x: 0, y: 0, size: .strip)
        let blocker = layoutItem("blocker", x: 2, y: 0, size: .strip)
        let lower = layoutItem("lower", x: 0, y: 4, size: .strip)

        let grown = engine.resizeItem(id: "hero", to: .card, in: [hero, blocker, lower])
        XCTAssertFalse(engine.hasOverlaps(grown))
        XCTAssertEqual(item("hero", in: grown)?.size, .card)

        let shrunk = engine.resizeItem(id: "hero", to: .strip, in: grown)
        XCTAssertFalse(engine.hasOverlaps(shrunk))
        XCTAssertEqual(item("lower", in: shrunk)?.x, 0)
        XCTAssertLessThan(item("lower", in: shrunk)?.y ?? 99, item("lower", in: grown)?.y ?? 99)
    }

    func testAutoPackKeepsThreeSizesInsideFourColumns() {
        let items = [
            layoutItem("a", x: 0, y: 9, size: .stamp),
            layoutItem("b", x: 0, y: 9, size: .strip),
            layoutItem("c", x: 0, y: 9, size: .card),
            layoutItem("d", x: 0, y: 9, size: .card),
        ]

        let packed = engine.autoPack(items)

        XCTAssertFalse(engine.hasOverlaps(packed))
        XCTAssertTrue(packed.allSatisfy { $0.x + $0.w <= 4 })
        XCTAssertEqual(Set(packed.map(\.size)), Set([.stamp, .strip, .card]))
    }

    private func layoutItem(
        _ id: String,
        x: Int,
        y: Int,
        size: MoryBoardGridSize,
        isPinned: Bool = false
    ) -> MoryBoardLayoutItem<String> {
        MoryBoardLayoutItem(
            id: id,
            point: MoryBoardGridPoint(x: x, y: y),
            size: size,
            isPinned: isPinned
        )
    }

    private func item(
        _ id: String,
        in items: [MoryBoardLayoutItem<String>]
    ) -> MoryBoardLayoutItem<String>? {
        items.first { $0.id == id }
    }
}
