import XCTest
@testable import mory

final class CardDebugGridBoardLabTests: XCTestCase {
    func testDebugSquareMetricsCapWideBoardsAndUseSquareCells() {
        let boardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 1_200)
        let metrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 1_200)

        XCTAssertEqual(boardWidth, MemoryDeskBoardMetrics.debugMaxBoardWidth)
        XCTAssertEqual(metrics.cellWidth(for: boardWidth), metrics.rowHeight, accuracy: 0.1)
    }

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

    func testTargetPlacementClampsLargeCardsWithinSixColumns() {
        let boardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 390)
        let metrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 390)

        let tapeTarget = CardDebugGridBoardLabModel.targetPlacement(
            for: CGPoint(x: 10_000, y: metrics.verticalPadding),
            itemSize: .tape,
            boardWidth: boardWidth,
            metrics: metrics
        )
        let bannerTarget = CardDebugGridBoardLabModel.targetPlacement(
            for: CGPoint(x: 10_000, y: metrics.verticalPadding),
            itemSize: .banner,
            boardWidth: boardWidth,
            metrics: metrics
        )

        XCTAssertEqual(tapeTarget.column, 2)
        XCTAssertEqual(bannerTarget.column, 0)
    }

    func testPreviewDragToEmptyGridCellRepacksOtherCardsWithoutOverlap() throws {
        let items = CardDebugGridBoardLabModel.defaultItems()
        let draggingID = try XCTUnwrap(items.first(where: { $0.size == .banner })?.id)
        let target = MemoryCardGridPlacement(column: 0, row: 6)

        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: draggingID,
            to: target,
            in: items
        )
        let report = CardDebugGridBoardLabModel.report(for: preview, mode: .storedPlacement)

        XCTAssertEqual(preview.first(where: { $0.id == draggingID })?.placement, target)
        XCTAssertEqual(report.overlapCount, 0)
        XCTAssertTrue(report.slots.allSatisfy { $0.layout.gridPlacement != nil })
    }

    func testCommitPreviewPersistsPlacementsSortedByBoardPosition() throws {
        let items = CardDebugGridBoardLabModel.defaultItems()
        let draggingID = try XCTUnwrap(items.first(where: { $0.size == .square })?.id)
        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: draggingID,
            to: MemoryCardGridPlacement(column: 3, row: 4),
            in: items
        )

        let committed = CardDebugGridBoardLabModel.commitPreview(preview)
        let placements = committed.compactMap(\.placement)
        let sortedPlacements = placements.sorted { lhs, rhs in
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.column < rhs.column
        }

        XCTAssertEqual(placements, sortedPlacements)
        XCTAssertEqual(committed.count, preview.count)
        XCTAssertTrue(committed.allSatisfy { $0.placement != nil })
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
