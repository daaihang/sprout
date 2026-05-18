import XCTest
@testable import mory

final class HomeBoardGridLayoutTests: XCTestCase {
    func testFourColumnCompactLayoutPacksVariableSpans() {
        let placements = HomeBoardGridPacking.pack(
            spans: [
                HomeBoardSpan(widthColumns: 2, heightUnits: 1),
                HomeBoardSpan(widthColumns: 2, heightUnits: 1),
                HomeBoardSpan(widthColumns: 1, heightUnits: 1),
                HomeBoardSpan(widthColumns: 3, heightUnits: 1),
            ],
            columns: 4
        )

        XCTAssertEqual(placements.map(\.column), [0, 2, 0, 1])
        XCTAssertEqual(placements.map(\.row), [0, 0, 1, 1])
        XCTAssertEqual(HomeBoardGridPacking.requiredRowCount(for: placements), 2)
    }

    func testEightColumnRegularLayoutKeepsMoreCardsInFirstRow() {
        let placements = HomeBoardGridPacking.pack(
            spans: [
                HomeBoardSpan(widthColumns: 2, heightUnits: 1),
                HomeBoardSpan(widthColumns: 2, heightUnits: 1),
                HomeBoardSpan(widthColumns: 2, heightUnits: 1),
                HomeBoardSpan(widthColumns: 2, heightUnits: 1),
                HomeBoardSpan(widthColumns: 4, heightUnits: 1),
            ],
            columns: 8
        )

        XCTAssertEqual(placements.prefix(4).map(\.row), [0, 0, 0, 0])
        XCTAssertEqual(placements[4].row, 1)
        XCTAssertEqual(placements[4].column, 0)
        XCTAssertEqual(HomeBoardGridPacking.requiredRowCount(for: placements), 2)
    }

    func testOversizedSpanClampsToAvailableColumns() {
        let placements = HomeBoardGridPacking.pack(
            spans: [HomeBoardSpan(widthColumns: 8, heightUnits: 1)],
            columns: 4
        )

        XCTAssertEqual(placements.first?.span, HomeBoardSpan(widthColumns: 4, heightUnits: 1))
    }
}
