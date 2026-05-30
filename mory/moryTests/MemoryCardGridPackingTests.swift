import XCTest
@testable import mory

final class MemoryCardGridPackingTests: XCTestCase {
    func testFirstFitPackingProducesNonOverlappingPlacements() {
        let sizes: [MemoryCardSizeToken] = [
            .banner, .tape, .square, .card, .strip, .stamp, .card, .tape, .strip
        ]
        let placements = MemoryCardGridPacking.placements(for: sizes)

        XCTAssertEqual(placements.count, sizes.count)
        XCTAssertTrue(placements.allSatisfy { placement in
            placement.column >= 0
                && placement.column < MemoryCardRecipeLayoutPolicy.columnCount
                && placement.row >= 0
        })

        var occupancy = Set<GridCell>()
        for (index, placement) in placements.enumerated() {
            let box = MemoryCardRecipeLayoutPolicy.gridBox(for: sizes[index])
            XCTAssertLessThanOrEqual(placement.column + box.columnSpan, MemoryCardRecipeLayoutPolicy.columnCount)
            for row in placement.row..<(placement.row + box.rowSpan) {
                for column in placement.column..<(placement.column + box.columnSpan) {
                    let cell = GridCell(column: column, row: row)
                    XCTAssertFalse(occupancy.contains(cell), "Unexpected overlap at \(cell)")
                    occupancy.insert(cell)
                }
            }
        }
    }

    func testRequiredRowCountMatchesBottomEdgeOfLayouts() {
        let layouts = [
            MemoryCardLayoutToken(order: 0, size: .banner, gridPlacement: MemoryCardGridPlacement(column: 0, row: 0)),
            MemoryCardLayoutToken(order: 1, size: .strip, gridPlacement: MemoryCardGridPlacement(column: 2, row: 3)),
            MemoryCardLayoutToken(order: 2, size: .square, gridPlacement: MemoryCardGridPlacement(column: 0, row: 4))
        ]

        let expected = 7 // square starts at row 4 and spans 3 rows.
        XCTAssertEqual(MemoryCardGridPacking.requiredRowCount(for: layouts), expected)
    }

    func testPackingExpandsWhenSizeBecomesLarger() {
        let baseSizes: [MemoryCardSizeToken] = [.card, .card, .card, .card, .card]
        let enlargedSizes: [MemoryCardSizeToken] = [.banner, .card, .card, .card, .card]

        let basePlacements = MemoryCardGridPacking.placements(for: baseSizes)
        let enlargedPlacements = MemoryCardGridPacking.placements(for: enlargedSizes)

        let baseLayouts = zip(basePlacements, baseSizes).enumerated().map { index, value in
            MemoryCardLayoutToken(order: index, size: value.1, gridPlacement: value.0)
        }
        let enlargedLayouts = zip(enlargedPlacements, enlargedSizes).enumerated().map { index, value in
            MemoryCardLayoutToken(order: index, size: value.1, gridPlacement: value.0)
        }

        XCTAssertGreaterThanOrEqual(
            MemoryCardGridPacking.requiredRowCount(for: enlargedLayouts),
            MemoryCardGridPacking.requiredRowCount(for: baseLayouts)
        )
    }
}

private struct GridCell: Hashable, CustomStringConvertible {
    let column: Int
    let row: Int

    var description: String {
        "(\(column), \(row))"
    }
}
