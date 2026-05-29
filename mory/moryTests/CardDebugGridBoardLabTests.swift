import XCTest
@testable import mory

final class CardDebugGridBoardLabTests: XCTestCase {
    func testDefaultItemsCoverEverySizeToken() {
        let items = CardDebugGridBoardLabModel.defaultItems()

        XCTAssertEqual(Set(items.map(\.size)), Set(MemoryCardSizeToken.allCases))
        XCTAssertEqual(items.count, MemoryCardSizeToken.allCases.count)
        XCTAssertTrue(items.allSatisfy { $0.placement != nil })
    }

    func testLegacyNilPlacementModeReproducesOverlapAndEffectiveModeAvoidsIt() {
        let items = CardDebugGridBoardLabModel.defaultItems().map { item in
            var item = item
            item.placement = nil
            return item
        }

        let legacyReport = CardDebugGridBoardLabModel.report(
            for: items,
            mode: .nilPlacementFallback
        )
        let effectiveReport = CardDebugGridBoardLabModel.report(
            for: items,
            mode: .firstFitEffectivePlacement
        )

        XCTAssertGreaterThan(legacyReport.overlapCount, 0)
        XCTAssertEqual(effectiveReport.overlapCount, 0)
        XCTAssertTrue(effectiveReport.slots.allSatisfy { $0.layout.gridPlacement != nil })
    }

    func testAddDeleteSizeChangeAndAutoPackKeepGridNonOverlapping() {
        var items = CardDebugGridBoardLabModel.defaultItems()
        items.append(
            CardDebugGridBoardLabItem(
                id: UUID(),
                title: "extra banner",
                size: .banner,
                recipe: CardDebugGridBoardLabModel.recipe(for: .banner)
            )
        )
        items.removeFirst()
        items[0].size = .banner
        items[0].recipe = CardDebugGridBoardLabModel.recipe(for: .banner)

        let packed = CardDebugGridBoardLabModel.autoPacked(items)
        let report = CardDebugGridBoardLabModel.report(for: packed, mode: .storedPlacement)

        XCTAssertEqual(report.overlapCount, 0)
        XCTAssertTrue(report.slots.allSatisfy { $0.layout.gridPlacement != nil })
        XCTAssertGreaterThan(report.rowCount, 0)
    }
}
