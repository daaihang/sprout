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

    func testDragPreviewDerivesTargetPlacementFromBoardCoordinates() throws {
        let dragged = gridItem("dragged", size: .strip, column: 4, row: 0)
        let anchor = gridItem("anchor", size: .strip, column: 0, row: 0)
        let rowFiller = gridItem("rowFiller", size: .strip, column: 0, row: 1)
        let items = [dragged, anchor, rowFiller]
        let boardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 390)
        let metrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 390)
        let cellSize = metrics.cellWidth(for: boardWidth)
        let location = CGPoint(
            x: metrics.horizontalPadding + CGFloat(4) * (cellSize + metrics.columnSpacing),
            y: metrics.verticalPadding + CGFloat(2) * (metrics.rowHeight + metrics.rowSpacing)
        )

        let preview = CardDebugGridBoardLabModel.dragPreview(
            dragging: dragged.id,
            at: location,
            itemSize: dragged.size,
            boardWidth: boardWidth,
            metrics: metrics,
            in: items
        )

        XCTAssertEqual(preview.itemID, dragged.id)
        XCTAssertEqual(preview.targetPlacement, MemoryCardGridPlacement(column: 4, row: 2))
        XCTAssertEqual(preview.items.first(where: { $0.id == dragged.id })?.placement, preview.targetPlacement)
    }

    func testUIKitDragSessionUsesGrabOffsetForGridTarget() throws {
        let dragged = gridItem("dragged", size: .strip, column: 0, row: 0)
        let items = [dragged]
        let boardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 390)
        let metrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 390)
        let slots = CardDebugGridBoardLabModel.slots(
            for: items,
            mode: .storedPlacement,
            containerWidth: boardWidth,
            metrics: metrics
        )
        let slot = try XCTUnwrap(slots.first)
        let touchAtPickup = CGPoint(x: slot.frame.minX + 24, y: slot.frame.minY + 18)
        let session = try XCTUnwrap(CardDebugGridBoardLabModel.beginDrag(at: touchAtPickup, in: slots))
        let targetOrigin = CGPoint(
            x: metrics.horizontalPadding + 2 * (metrics.cellWidth(for: boardWidth) + metrics.columnSpacing),
            y: metrics.verticalPadding + 3 * (metrics.rowHeight + metrics.rowSpacing)
        )
        let draggedTouch = CGPoint(
            x: targetOrigin.x + session.geometry.grabOffset.x,
            y: targetOrigin.y + session.geometry.grabOffset.y
        )

        let preview = CardDebugGridBoardLabModel.dragPreview(
            for: session,
            at: draggedTouch,
            boardWidth: boardWidth,
            metrics: metrics,
            in: items
        )

        XCTAssertEqual(preview.targetPlacement, MemoryCardGridPlacement(column: 2, row: 3))
    }

    func testDragPreviewDoesNotMutateStoredItems() {
        let dragged = gridItem("dragged", size: .strip, column: 0, row: 0)
        let blocker = gridItem("blocker", size: .strip, column: 2, row: 0)
        let items = [dragged, blocker]
        let boardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 390)
        let metrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 390)
        let originalItems = items

        _ = CardDebugGridBoardLabModel.dragPreview(
            dragging: dragged.id,
            at: CGPoint(x: metrics.horizontalPadding + 200, y: metrics.verticalPadding),
            itemSize: dragged.size,
            boardWidth: boardWidth,
            metrics: metrics,
            in: items
        )

        XCTAssertEqual(items, originalItems)
    }

    func testDragPreviewCommitPersistsPlacementsWithoutOverlap() {
        let dragged = gridItem("dragged", size: .tape, column: 0, row: 0)
        let blocker = gridItem("blocker", size: .strip, column: 2, row: 0)
        let bystander = gridItem("bystander", size: .square, column: 0, row: 2)
        let items = [dragged, blocker, bystander]
        let boardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 390)
        let metrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 390)
        let location = CGPoint(
            x: metrics.horizontalPadding + CGFloat(2) * (metrics.cellWidth(for: boardWidth) + metrics.columnSpacing),
            y: metrics.verticalPadding
        )

        let preview = CardDebugGridBoardLabModel.dragPreview(
            dragging: dragged.id,
            at: location,
            itemSize: dragged.size,
            boardWidth: boardWidth,
            metrics: metrics,
            in: items
        )
        let committed = CardDebugGridBoardLabModel.commitPreview(preview.items)
        let report = CardDebugGridBoardLabModel.report(for: committed, mode: .storedPlacement)

        XCTAssertTrue(committed.allSatisfy { $0.placement != nil })
        XCTAssertEqual(report.overlapCount, 0)
    }

    func testActiveDragPreviewDoesNotCompactRowsUntilDropCommit() {
        let dragged = gridItem("dragged", size: .strip, column: 0, row: 2)

        let preview = CardDebugGridBoardLabModel.previewItemsWithoutCompaction(
            dragging: dragged.id,
            to: MemoryCardGridPlacement(column: 0, row: 4),
            in: [dragged]
        )
        let committed = CardDebugGridBoardLabModel.commitPreview(preview)

        XCTAssertEqual(preview.first?.placement, MemoryCardGridPlacement(column: 0, row: 4))
        XCTAssertEqual(committed.first?.placement, MemoryCardGridPlacement(column: 0, row: 0))
    }

    func testDragPreviewClampsLargeCardsWithinSixColumns() {
        let banner = gridItem("banner", size: .banner, column: 0, row: 0)
        let boardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 390)
        let metrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 390)

        let preview = CardDebugGridBoardLabModel.dragPreview(
            dragging: banner.id,
            at: CGPoint(x: 10_000, y: metrics.verticalPadding),
            itemSize: banner.size,
            boardWidth: boardWidth,
            metrics: metrics,
            in: [banner]
        )

        XCTAssertEqual(preview.targetPlacement.column, 0)
    }

    func testPreviewDragToEmptyGridCellPreservesOtherStoredPlacements() throws {
        let dragged = gridItem("dragged", size: .strip, column: 0, row: 0)
        let right = gridItem("right", size: .strip, column: 2, row: 0)
        let farRight = gridItem("farRight", size: .strip, column: 4, row: 0)
        let items = [dragged, right, farRight]
        let target = MemoryCardGridPlacement(column: 0, row: 1)

        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: dragged.id,
            to: target,
            in: items
        )
        let report = CardDebugGridBoardLabModel.report(for: preview, mode: .storedPlacement)

        XCTAssertEqual(preview.first(where: { $0.id == dragged.id })?.placement, target)
        for item in preview where item.id != dragged.id {
            XCTAssertEqual(item.placement, items.first(where: { $0.id == item.id })?.placement)
        }
        XCTAssertEqual(report.overlapCount, 0)
        XCTAssertTrue(report.slots.allSatisfy { $0.layout.gridPlacement != nil })
    }

    func testPreviewDragOnlyMovesCollidingCards() throws {
        let pinned = gridItem("pinned", size: .strip, column: 0, row: 0)
        let blocker = gridItem("blocker", size: .strip, column: 2, row: 0)
        let bystander = gridItem("bystander", size: .strip, column: 4, row: 0)
        let items = [pinned, blocker, bystander]

        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: pinned.id,
            to: MemoryCardGridPlacement(column: 2, row: 0),
            in: items
        )
        let report = CardDebugGridBoardLabModel.report(for: preview, mode: .storedPlacement)

        XCTAssertEqual(preview.first(where: { $0.id == pinned.id })?.placement, MemoryCardGridPlacement(column: 2, row: 0))
        XCTAssertEqual(preview.first(where: { $0.id == blocker.id })?.placement, MemoryCardGridPlacement(column: 2, row: 1))
        XCTAssertEqual(preview.first(where: { $0.id == bystander.id })?.placement, bystander.placement)
        XCTAssertEqual(report.overlapCount, 0)
    }

    func testCollisionResolutionChoosesNearestAvailableCandidateIncludingUpwardMoves() {
        let anchor = gridItem("anchor", size: .strip, column: 0, row: 0)
        let dragged = gridItem("dragged", size: .strip, column: 4, row: 0)
        let blocker = gridItem("blocker", size: .strip, column: 2, row: 2)
        let items = [anchor, dragged, blocker]

        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: dragged.id,
            to: MemoryCardGridPlacement(column: 2, row: 2),
            in: items
        )
        let report = CardDebugGridBoardLabModel.report(for: preview, mode: .storedPlacement)

        XCTAssertEqual(preview.first(where: { $0.id == dragged.id })?.placement, MemoryCardGridPlacement(column: 2, row: 2))
        XCTAssertEqual(preview.first(where: { $0.id == blocker.id })?.placement, MemoryCardGridPlacement(column: 2, row: 1))
        XCTAssertEqual(preview.first(where: { $0.id == anchor.id })?.placement, anchor.placement)
        XCTAssertEqual(report.overlapCount, 0)
    }

    func testCommitPreviewPersistsPlacementsWithoutResortingItems() throws {
        let items = CardDebugGridBoardLabModel.defaultItems()
        let draggingID = try XCTUnwrap(items.first(where: { $0.size == .square })?.id)
        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: draggingID,
            to: MemoryCardGridPlacement(column: 3, row: 4),
            in: items
        )

        let committed = CardDebugGridBoardLabModel.commitPreview(preview)

        XCTAssertEqual(committed.map(\.id), preview.map(\.id))
        XCTAssertEqual(committed.count, preview.count)
        XCTAssertTrue(committed.allSatisfy { $0.placement != nil })
    }

    func testCompactEmptyRowsMovesLowerContentUpButDoesNotFillPartialHoles() {
        let right = gridItem("right", size: .strip, column: 4, row: 0)
        let lower = gridItem("lower", size: .strip, column: 2, row: 2)

        let compacted = CardDebugGridBoardLabModel.compactEmptyRows([right, lower])

        XCTAssertEqual(compacted.first(where: { $0.id == right.id })?.placement, MemoryCardGridPlacement(column: 4, row: 0))
        XCTAssertEqual(compacted.first(where: { $0.id == lower.id })?.placement, MemoryCardGridPlacement(column: 2, row: 1))
    }

    func testResizeGrowsAtSameAnchorAndOnlyPushesCollidingCards() {
        var hero = gridItem("hero", size: .strip, column: 0, row: 0)
        hero.size = .banner
        hero.recipe = CardDebugGridBoardLabModel.recipe(for: .banner)
        let blocker = gridItem("blocker", size: .strip, column: 4, row: 0)
        let bystander = gridItem("bystander", size: .strip, column: 0, row: 3)
        let items = [hero, blocker, bystander]

        let resolved = CardDebugGridBoardLabModel.collisionResolvedItems(
            items,
            pinnedID: hero.id,
            pinnedPlacement: hero.placement
        )
        let report = CardDebugGridBoardLabModel.report(for: resolved, mode: .storedPlacement)

        XCTAssertEqual(resolved.first(where: { $0.id == hero.id })?.placement, MemoryCardGridPlacement(column: 0, row: 0))
        XCTAssertEqual(resolved.first(where: { $0.id == blocker.id })?.placement, MemoryCardGridPlacement(column: 4, row: 3))
        XCTAssertEqual(resolved.first(where: { $0.id == bystander.id })?.placement, bystander.placement)
        XCTAssertEqual(report.overlapCount, 0)
    }

    func testAutoPackIsTheOnlyFullFirstFitTidyAction() {
        let item = gridItem("right", size: .strip, column: 4, row: 0)

        let locallyCompacted = CardDebugGridBoardLabModel.compactEmptyRows([item])
        let autoPacked = CardDebugGridBoardLabModel.autoPacked([item])

        XCTAssertEqual(locallyCompacted.first?.placement, MemoryCardGridPlacement(column: 4, row: 0))
        XCTAssertEqual(autoPacked.first?.placement, MemoryCardGridPlacement(column: 0, row: 0))
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

    func testBoardHitTestingUsesFrameAndZIndexInsteadOfLastSlot() {
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

    func testUIKitDragSessionPreviewCommitSemantics() throws {
        let dragged = gridItem("dragged", size: .strip, column: 0, row: 0)
        let blocker = gridItem("blocker", size: .strip, column: 2, row: 0)
        let items = [dragged, blocker]
        let boardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 390)
        let metrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 390)
        let slots = CardDebugGridBoardLabModel.slots(
            for: items,
            mode: .storedPlacement,
            containerWidth: boardWidth,
            metrics: metrics
        )
        let session = try XCTUnwrap(
            CardDebugGridBoardLabModel.beginDrag(at: CGPoint(x: 24, y: 24), in: slots)
        )

        let preview = CardDebugGridBoardLabModel.dragPreview(
            for: session,
            at: CGPoint(
                x: metrics.horizontalPadding + 2 * (metrics.cellWidth(for: boardWidth) + metrics.columnSpacing),
                y: metrics.verticalPadding
            ),
            boardWidth: boardWidth,
            metrics: metrics,
            in: items
        )
        let committed = CardDebugGridBoardLabModel.commitPreview(preview.items)
        let report = CardDebugGridBoardLabModel.report(for: committed, mode: .storedPlacement)

        XCTAssertEqual(session.itemID, dragged.id)
        XCTAssertEqual(committed.first(where: { $0.id == dragged.id })?.placement, preview.targetPlacement)
        XCTAssertEqual(report.overlapCount, 0)
        XCTAssertEqual(items.first(where: { $0.id == dragged.id })?.placement, dragged.placement)
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
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("mory")
            .appendingPathComponent("Debug")
            .appendingPathComponent("Components")
            .appendingPathComponent("CardDebugGridBoardLabView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("LongPressGesture"))
        XCTAssertFalse(source.contains("DragGesture"))
        XCTAssertFalse(source.contains("scrollDisabled"))
        XCTAssertFalse(source.contains(".gesture("))
        XCTAssertFalse(source.contains(".simultaneousGesture("))
    }

    func testUIKitBoardUsesSnapshotDragInsteadOfInteractiveMovementOrStatePreview() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("mory")
            .appendingPathComponent("Debug")
            .appendingPathComponent("Components")
            .appendingPathComponent("CardDebugGridBoardUIKitView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

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
        row: Int
    ) -> CardDebugGridBoardLabItem {
        CardDebugGridBoardLabItem(
            id: UUID(),
            title: title,
            size: size,
            recipe: CardDebugGridBoardLabModel.recipe(for: size),
            placement: MemoryCardGridPlacement(column: column, row: row)
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
}
