import XCTest
@testable import mory

final class CardDebugGridBoardLabTests: XCTestCase {
    func testDebugSquareMetricsCapWideBoardsAndUseSquareCells() {
        let boardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 1_200)
        let metrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 1_200)

        XCTAssertEqual(boardWidth, MemoryDeskBoardMetrics.debugMaxBoardWidth)
        XCTAssertEqual(metrics.cellWidth(for: boardWidth), metrics.rowHeight, accuracy: 0.1)
    }

    func testDebugSquareMetricsShrinkForNarrowRotations() {
        let narrowBoardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 360)
        let wideBoardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 900)
        let narrowMetrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 360)
        let wideMetrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 900)

        XCTAssertEqual(narrowBoardWidth, 360)
        XCTAssertEqual(wideBoardWidth, MemoryDeskBoardMetrics.debugMaxBoardWidth)
        XCTAssertLessThan(narrowMetrics.rowHeight, wideMetrics.rowHeight)
        XCTAssertEqual(narrowMetrics.cellWidth(for: narrowBoardWidth), narrowMetrics.rowHeight, accuracy: 0.1)
    }

    func testDefaultItemsCoverEverySizeToken() {
        let items = CardDebugGridBoardLabModel.defaultItems()

        XCTAssertEqual(Set(items.map(\.size)), Set(MemoryCardSizeToken.allCases))
        XCTAssertEqual(items.count, MemoryCardSizeToken.allCases.count)
        XCTAssertTrue(items.allSatisfy { $0.placement != nil })
    }

    func testNilDiagnosticsStillExposeLegacyOverlapAndFirstFitRepair() {
        let nilItems = CardDebugGridBoardLabModel.defaultItems().map { item in
            var item = item
            item.placement = nil
            return item
        }

        let legacyReport = CardDebugGridBoardLabModel.report(for: nilItems, mode: .nilPlacementFallback)
        let effectiveReport = CardDebugGridBoardLabModel.report(for: nilItems, mode: .firstFitEffectivePlacement)

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

    func testDragGeometryPreservesGrabOffsetInsteadOfCenteringCard() {
        let frame = CGRect(x: 48, y: 72, width: 180, height: 96)
        let initialTouch = CGPoint(x: 84, y: 100)
        let geometry = CardDebugGridDragGeometry(
            originalFrame: frame,
            touchLocation: initialTouch
        )

        let movedTouch = CGPoint(x: 210, y: 190)
        let liftedFrame = geometry.liftedFrame(for: movedTouch)
        let liftedCenter = CGPoint(x: liftedFrame.midX, y: liftedFrame.midY)

        XCTAssertEqual(geometry.grabOffset, CGPoint(x: 36, y: 28))
        XCTAssertEqual(liftedFrame.origin, CGPoint(x: 174, y: 162))
        XCTAssertNotEqual(liftedCenter, movedTouch)
        XCTAssertEqual(geometry.gridAnchorLocation(for: movedTouch), liftedFrame.origin)
    }

    func testHitTestingUsesTopmostFrameNotLastCard() {
        let lower = gridItem("lower", size: .strip, column: 0, row: 0)
        let top = gridItem("top", size: .strip, column: 0, row: 0)
        let lastButLower = gridItem("lastButLower", size: .strip, column: 0, row: 0)
        let slots = [
            slot(for: lower, frame: CGRect(x: 0, y: 0, width: 120, height: 80), zIndex: 1),
            slot(for: top, frame: CGRect(x: 0, y: 0, width: 120, height: 80), zIndex: 10),
            slot(for: lastButLower, frame: CGRect(x: 0, y: 0, width: 120, height: 80), zIndex: 2)
        ]

        let hitID = CardDebugGridBoardLabModel.hitItemID(at: CGPoint(x: 24, y: 24), in: slots)

        XCTAssertEqual(hitID, top.id)
        XCTAssertNotEqual(hitID, lastButLower.id)
    }

    func testBeginDragCapturesTheTouchedSlotAndGrabOffset() throws {
        let item = gridItem("strip", size: .strip, column: 2, row: 1)
        let boardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 390)
        let metrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 390)
        let slots = CardDebugGridBoardLabModel.slots(
            for: [item],
            mode: .storedPlacement,
            containerWidth: boardWidth,
            metrics: metrics
        )
        let slot = try XCTUnwrap(slots.first)
        let touch = CGPoint(x: slot.frame.minX + 21, y: slot.frame.minY + 15)

        let session = try XCTUnwrap(CardDebugGridBoardLabModel.beginDrag(at: touch, in: slots))

        XCTAssertEqual(session.itemID, item.id)
        XCTAssertEqual(session.geometry.grabOffset, CGPoint(x: 21, y: 15))
    }

    func testDragToEmptyCellMovesOnlyDraggedItem() {
        let dragged = gridItem("dragged", size: .strip, column: 0, row: 0)
        let right = gridItem("right", size: .strip, column: 2, row: 0)
        let farRight = gridItem("farRight", size: .strip, column: 4, row: 0)
        let target = MemoryCardGridPlacement(column: 0, row: 1)

        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: dragged.id,
            to: target,
            in: [dragged, right, farRight]
        )

        XCTAssertEqual(placement(of: dragged.id, in: preview.items), target)
        XCTAssertEqual(placement(of: right.id, in: preview.items), right.placement)
        XCTAssertEqual(placement(of: farRight.id, in: preview.items), farRight.placement)
        XCTAssertEqual(preview.affectedItemIDs, [dragged.id])
        XCTAssertEqual(CardDebugGridBoardLabModel.report(for: preview.items, mode: .storedPlacement).overlapCount, 0)
    }

    func testDragToOccupiedCellCanMoveBlockerLeftWithMinimumDisturbance() {
        let dragged = gridItem("dragged", size: .strip, column: 0, row: 0)
        let blocker = gridItem("blocker", size: .strip, column: 2, row: 0)
        let follower = gridItem("follower", size: .strip, column: 4, row: 0)
        let lowerBlocker = gridItem("lowerBlocker", size: .strip, column: 2, row: 1)

        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: dragged.id,
            to: MemoryCardGridPlacement(column: 2, row: 0),
            in: [dragged, blocker, follower, lowerBlocker]
        )

        XCTAssertEqual(placement(of: dragged.id, in: preview.items), MemoryCardGridPlacement(column: 2, row: 0))
        XCTAssertEqual(placement(of: blocker.id, in: preview.items), MemoryCardGridPlacement(column: 0, row: 0))
        XCTAssertEqual(placement(of: follower.id, in: preview.items), follower.placement)
        XCTAssertEqual(placement(of: lowerBlocker.id, in: preview.items), lowerBlocker.placement)
        XCTAssertEqual(preview.affectedItemIDs, [dragged.id, blocker.id])
        XCTAssertEqual(preview.solverCost?.movedItemCount, 1)
        XCTAssertEqual(CardDebugGridBoardLabModel.report(for: preview.items, mode: .storedPlacement).overlapCount, 0)
    }

    func testDragToOccupiedCellCanMoveBlockerUpWhenThatIsCheaper() {
        let dragged = gridItem("dragged", size: .strip, column: 4, row: 1)
        let blocker = gridItem("blocker", size: .strip, column: 0, row: 1)
        let follower = gridItem("follower", size: .strip, column: 2, row: 1)

        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: dragged.id,
            to: MemoryCardGridPlacement(column: 0, row: 1),
            in: [dragged, blocker, follower]
        )

        XCTAssertEqual(placement(of: dragged.id, in: preview.items), MemoryCardGridPlacement(column: 0, row: 1))
        XCTAssertEqual(placement(of: blocker.id, in: preview.items), MemoryCardGridPlacement(column: 0, row: 0))
        XCTAssertEqual(placement(of: follower.id, in: preview.items), follower.placement)
        XCTAssertEqual(preview.affectedItemIDs, [dragged.id, blocker.id])
        XCTAssertEqual(CardDebugGridBoardLabModel.report(for: preview.items, mode: .storedPlacement).overlapCount, 0)
    }

    func testLargeCardCrossRowOnlyMovesActuallyOverlappedCards() {
        let dragged = gridItem("banner", size: .banner, column: 0, row: 4)
        let first = gridItem("first", size: .stamp, column: 0, row: 0)
        let second = gridItem("second", size: .strip, column: 4, row: 1)
        let third = gridItem("third", size: .card, column: 0, row: 3)

        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: dragged.id,
            to: MemoryCardGridPlacement(column: 0, row: 0),
            in: [dragged, first, second, third]
        )
        let report = CardDebugGridBoardLabModel.report(for: preview.items, mode: .storedPlacement)

        XCTAssertEqual(placement(of: dragged.id, in: preview.items), MemoryCardGridPlacement(column: 0, row: 0))
        XCTAssertNotEqual(placement(of: first.id, in: preview.items), first.placement)
        XCTAssertNotEqual(placement(of: second.id, in: preview.items), second.placement)
        XCTAssertEqual(placement(of: third.id, in: preview.items), third.placement)
        XCTAssertEqual(Set(preview.affectedItemIDs), Set([dragged.id, first.id, second.id]))
        XCTAssertEqual(report.overlapCount, 0)
    }

    func testPinnedCardsArePreservedWhenEquivalentUnpinnedMoveExists() {
        let pinned = gridItem("pinned", size: .strip, column: 0, row: 0, isPinned: true)
        let blocker = gridItem("blocker", size: .strip, column: 2, row: 0)
        let dragged = gridItem("dragged", size: .strip, column: 4, row: 0)
        let lowerBlocker = gridItem("lowerBlocker", size: .strip, column: 2, row: 1)

        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: dragged.id,
            to: MemoryCardGridPlacement(column: 2, row: 0),
            in: [pinned, blocker, dragged, lowerBlocker]
        )

        XCTAssertEqual(placement(of: dragged.id, in: preview.items), MemoryCardGridPlacement(column: 2, row: 0))
        XCTAssertEqual(placement(of: pinned.id, in: preview.items), pinned.placement)
        XCTAssertEqual(placement(of: blocker.id, in: preview.items), MemoryCardGridPlacement(column: 4, row: 0))
        XCTAssertEqual(placement(of: lowerBlocker.id, in: preview.items), lowerBlocker.placement)
        XCTAssertEqual(preview.solverCost?.pinnedMovedCount, 0)
        XCTAssertEqual(CardDebugGridBoardLabModel.report(for: preview.items, mode: .storedPlacement).overlapCount, 0)
    }

    func testCommitCompactsOnlyCompleteEmptyRowsWithoutFillingPartialHoles() {
        let right = gridItem("right", size: .strip, column: 4, row: 0)
        let lower = gridItem("lower", size: .strip, column: 2, row: 2)

        let compacted = CardDebugGridBoardLabModel.compactEmptyRows([right, lower])

        XCTAssertEqual(placement(of: right.id, in: compacted), MemoryCardGridPlacement(column: 4, row: 0))
        XCTAssertEqual(placement(of: lower.id, in: compacted), MemoryCardGridPlacement(column: 2, row: 1))
    }

    func testDeleteOnlyCompactsCompleteEmptyRows() {
        let rowZero = gridItem("rowZero", size: .strip, column: 4, row: 0)
        let removed = gridItem("removed", size: .strip, column: 0, row: 1)
        let lower = gridItem("lower", size: .strip, column: 2, row: 3)

        let remaining = CardDebugGridBoardLabModel.itemsAfterDeleting(
            id: removed.id,
            from: [rowZero, removed, lower]
        )

        XCTAssertEqual(placement(of: rowZero.id, in: remaining), MemoryCardGridPlacement(column: 4, row: 0))
        XCTAssertEqual(placement(of: lower.id, in: remaining), MemoryCardGridPlacement(column: 2, row: 1))
    }

    func testResizeGrowingCardUsesMinimumDisturbanceSolver() {
        let hero = gridItem("hero", size: .strip, column: 0, row: 0)
        let blocker = gridItem("blocker", size: .strip, column: 4, row: 0)
        let follower = gridItem("follower", size: .strip, column: 0, row: 3)

        let resized = CardDebugGridBoardLabModel.itemsAfterResizing(
            id: hero.id,
            to: .banner,
            in: [hero, blocker, follower]
        )

        XCTAssertEqual(placement(of: hero.id, in: resized), MemoryCardGridPlacement(column: 0, row: 0))
        XCTAssertNotEqual(placement(of: blocker.id, in: resized), blocker.placement)
        XCTAssertEqual(placement(of: follower.id, in: resized), follower.placement)
        XCTAssertEqual(CardDebugGridBoardLabModel.report(for: resized, mode: .storedPlacement).overlapCount, 0)
    }

    func testResizeShrinkingCardOnlyCompactsCompleteEmptyRows() {
        let hero = gridItem("hero", size: .banner, column: 0, row: 0)
        let lower = gridItem("lower", size: .strip, column: 4, row: 4)

        let resized = CardDebugGridBoardLabModel.itemsAfterResizing(
            id: hero.id,
            to: .strip,
            in: [hero, lower]
        )

        XCTAssertEqual(placement(of: hero.id, in: resized), MemoryCardGridPlacement(column: 0, row: 0))
        XCTAssertEqual(placement(of: lower.id, in: resized), MemoryCardGridPlacement(column: 4, row: 1))
    }

    func testAddAppendsNearCurrentContentWithoutDisturbingExistingCards() {
        let existing = gridItem("existing", size: .strip, column: 4, row: 0)

        let next = CardDebugGridBoardLabModel.itemsAfterAdding(size: .strip, to: [existing])

        XCTAssertEqual(next.count, 2)
        XCTAssertEqual(placement(of: existing.id, in: next), existing.placement)
        XCTAssertEqual(next.last?.placement, MemoryCardGridPlacement(column: 0, row: 1))
    }

    func testAutoPackIsTheOnlyFullFirstFitTidyAction() {
        let item = gridItem("right", size: .strip, column: 4, row: 0)

        let locallyCompacted = CardDebugGridBoardLabModel.compactEmptyRows([item])
        let autoPacked = CardDebugGridBoardLabModel.autoPacked([item])

        XCTAssertEqual(placement(of: item.id, in: locallyCompacted), MemoryCardGridPlacement(column: 4, row: 0))
        XCTAssertEqual(placement(of: item.id, in: autoPacked), MemoryCardGridPlacement(column: 0, row: 0))
    }

    func testCollectionLayoutAttributesMatchBoardPlanFrames() {
        let items = CardDebugGridBoardLabModel.defaultItems()
        let boardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 390)
        let metrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 390)
        let slots = CardDebugGridBoardLabModel.slots(
            for: items,
            mode: .storedPlacement,
            containerWidth: boardWidth,
            metrics: metrics
        )
        let boardHeight = (slots.map(\.frame.maxY).max() ?? 0) + metrics.verticalPadding
        let layout = CardDebugGridBoardCollectionLayout()

        layout.configure(
            slots: slots,
            boardSize: CGSize(width: boardWidth, height: boardHeight),
            activeDragItemID: items.first?.id
        )
        layout.prepare()

        XCTAssertEqual(layout.collectionViewContentSize, CGSize(width: boardWidth, height: boardHeight))
        for (index, slot) in slots.enumerated() {
            let attributes = layout.layoutAttributesForItem(at: IndexPath(item: index, section: 0))
            XCTAssertEqual(attributes?.frame, slot.frame)
            if index == 0 {
                XCTAssertEqual(attributes?.zIndex, 10_000)
            }
        }
    }

    func testSwiftUILabNoLongerOwnsDragOrScrollGestureContract() throws {
        let source = try source(named: "CardDebugGridBoardLabView.swift")

        XCTAssertFalse(source.contains("LongPressGesture"))
        XCTAssertFalse(source.contains("DragGesture"))
        XCTAssertFalse(source.contains("scrollDisabled"))
        XCTAssertFalse(source.contains(".gesture("))
        XCTAssertFalse(source.contains(".simultaneousGesture("))
    }

    func testUIKitBoardUsesSnapshotDragInsteadOfInteractiveMovementOrStatePreview() throws {
        let source = try source(named: "CardDebugGridBoardUIKitView.swift")

        XCTAssertFalse(source.contains("beginInteractiveMovementForItem"))
        XCTAssertFalse(source.contains("updateInteractiveMovementTargetPosition"))
        XCTAssertFalse(source.contains("endInteractiveMovement"))
        XCTAssertFalse(source.contains("cancelInteractiveMovement"))
        XCTAssertFalse(source.contains("onPreviewChanged"))
        XCTAssertFalse(source.contains("+ collectionView.contentOffset"))
        XCTAssertTrue(source.contains("snapshotView(afterScreenUpdates: false)"))
    }

    private func gridItem(
        _ title: String,
        size: MemoryCardSizeToken,
        column: Int,
        row: Int,
        isPinned: Bool = false,
        isUserAdjusted: Bool = false
    ) -> CardDebugGridBoardLabItem {
        CardDebugGridBoardLabItem(
            id: UUID(),
            title: title,
            size: size,
            recipe: CardDebugGridBoardLabModel.recipe(for: size),
            placement: MemoryCardGridPlacement(column: column, row: row),
            isPinned: isPinned,
            isUserAdjusted: isUserAdjusted
        )
    }

    private func slot(
        for item: CardDebugGridBoardLabItem,
        frame: CGRect,
        zIndex: Int
    ) -> CardDebugGridBoardLabSlot {
        CardDebugGridBoardLabSlot(
            id: item.id,
            item: item,
            layout: MemoryCardLayoutToken(
                order: zIndex,
                size: item.size,
                gridPlacement: item.placement,
                zIndex: zIndex
            ),
            frame: frame
        )
    }

    private func placement(
        of id: UUID,
        in items: [CardDebugGridBoardLabItem]
    ) -> MemoryCardGridPlacement? {
        items.first(where: { $0.id == id })?.placement
    }

    private func source(named fileName: String) throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("mory")
            .appendingPathComponent("Debug")
            .appendingPathComponent("Components")
            .appendingPathComponent(fileName)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
