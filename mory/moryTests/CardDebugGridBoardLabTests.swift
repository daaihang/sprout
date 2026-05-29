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
        XCTAssertEqual(CardDebugGridBoardLabModel.report(for: items, mode: .storedPlacement).overlapCount, 0)
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

    func testSlotRenderFrameExpandsGridFrameForOverflowAndSnapshotRoom() throws {
        let item = gridItem("banner", size: .banner, column: 0, row: 0)
        let boardWidth = MemoryDeskBoardMetrics.debugBoardWidth(for: 390)
        let metrics = MemoryDeskBoardMetrics.debugSquare(availableWidth: 390)
        let slot = try XCTUnwrap(
            CardDebugGridBoardLabModel.slots(
                for: [item],
                mode: .storedPlacement,
                containerWidth: boardWidth,
                metrics: metrics
            )
            .first
        )

        XCTAssertEqual(slot.frame, slot.gridFrame)
        XCTAssertTrue(slot.renderFrame.contains(slot.gridFrame))
        XCTAssertEqual(slot.hitFrame, slot.gridFrame)
        XCTAssertGreaterThan(slot.renderFrame.width, slot.gridFrame.width)
        XCTAssertGreaterThan(slot.renderFrame.height, slot.gridFrame.height)
        XCTAssertGreaterThan(slot.contentInsetsInRenderFrame.leading, 0)
        XCTAssertTrue(slot.debugLine.contains("grid="))
        XCTAssertTrue(slot.debugLine.contains("render="))
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

    func testHitTestingIgnoresRenderOverflowOutsideGridFrame() {
        let item = gridItem("overflow", size: .banner, column: 0, row: 0)
        let gridFrame = CGRect(x: 50, y: 30, width: 120, height: 80)
        let slot = CardDebugGridBoardLabSlot(
            id: item.id,
            item: item,
            layout: MemoryCardLayoutToken(
                order: 0,
                size: item.size,
                gridPlacement: item.placement,
                zIndex: 0
            ),
            gridFrame: gridFrame,
            renderFrame: gridFrame.insetBy(dx: -24, dy: -24),
            hitFrame: gridFrame
        )

        XCTAssertTrue(slot.renderFrame.contains(CGPoint(x: 32, y: 40)))
        XCTAssertFalse(slot.hitFrame.contains(CGPoint(x: 32, y: 40)))
        XCTAssertNil(CardDebugGridBoardLabModel.hitItemID(at: CGPoint(x: 32, y: 40), in: [slot]))
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
        XCTAssertEqual(session.geometry.originalFrame, slot.renderFrame)
        XCTAssertEqual(session.geometry.originalGridFrame, slot.gridFrame)
        XCTAssertEqual(
            session.geometry.grabOffset,
            CGPoint(
                x: touch.x - slot.renderFrame.minX,
                y: touch.y - slot.renderFrame.minY
            )
        )
        XCTAssertEqual(session.geometry.gridAnchorLocation(for: touch), slot.gridFrame.origin)
    }

    func testDragToEmptyCellMovesDraggedOrderAndKeepsOtherPlacements() {
        let dragged = gridItem("dragged", size: .strip, column: 0, row: 0)
        let right = gridItem("right", size: .strip, column: 2, row: 0)
        let farRight = gridItem("farRight", size: .strip, column: 4, row: 0)
        let target = MemoryCardGridPlacement(column: 0, row: 1)

        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: dragged.id,
            to: target,
            in: [dragged, right, farRight]
        )

        XCTAssertEqual(preview.insertionIndex, 2)
        XCTAssertEqual(preview.items.map(\.id), [right.id, farRight.id, dragged.id])
        XCTAssertEqual(placement(of: dragged.id, in: preview.items), target)
        XCTAssertEqual(placement(of: right.id, in: preview.items), right.placement)
        XCTAssertEqual(placement(of: farRight.id, in: preview.items), farRight.placement)
        XCTAssertEqual(preview.movedRange, 0...2)
        XCTAssertEqual(CardDebugGridBoardLabModel.report(for: preview.items, mode: .storedPlacement).overlapCount, 0)
    }

    func testDragToOccupiedCellInsertsBeforeBlockerAndFlowsLaterCards() {
        let dragged = gridItem("dragged", size: .strip, column: 0, row: 0)
        let blocker = gridItem("blocker", size: .strip, column: 2, row: 0)
        let follower = gridItem("follower", size: .strip, column: 4, row: 0)

        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: dragged.id,
            to: MemoryCardGridPlacement(column: 2, row: 0),
            in: [dragged, blocker, follower]
        )

        XCTAssertEqual(preview.insertionIndex, 0)
        XCTAssertEqual(preview.items.map(\.id), [dragged.id, blocker.id, follower.id])
        XCTAssertEqual(placement(of: dragged.id, in: preview.items), MemoryCardGridPlacement(column: 2, row: 0))
        XCTAssertEqual(placement(of: blocker.id, in: preview.items), MemoryCardGridPlacement(column: 4, row: 0))
        XCTAssertEqual(placement(of: follower.id, in: preview.items), MemoryCardGridPlacement(column: 0, row: 1))
        XCTAssertEqual(CardDebugGridBoardLabModel.report(for: preview.items, mode: .storedPlacement).overlapCount, 0)
    }

    func testOrderedSparsePackSupportsEverySizeWithoutOverlapOrOverflow() {
        let sizes: [MemoryCardSizeToken] = [.stamp, .strip, .card, .square, .tape, .banner, .stamp, .strip]
        let items = sizes.enumerated().map { index, size in
            CardDebugGridBoardLabItem(
                id: UUID(),
                title: "\(index)-\(size.rawValue)",
                size: size,
                recipe: CardDebugGridBoardLabModel.recipe(for: size),
                placement: nil
            )
        }

        let packed = CardDebugGridBoardLabModel.orderedSparsePack(items)
        let report = CardDebugGridBoardLabModel.report(for: packed, mode: .storedPlacement)

        XCTAssertEqual(Set(packed.map(\.size)), Set(sizes))
        XCTAssertEqual(report.overlapCount, 0)
        XCTAssertEqual(report.gridOverflowCount, 0)
    }

    func testSparseOperationsKeepPartialHolesUntilAutoPack() {
        let right = gridItem("right", size: .strip, column: 4, row: 0)
        let lowerWide = gridItem("lowerWide", size: .tape, column: 0, row: 1)

        let locallyCompacted = CardDebugGridBoardLabModel.compactEmptyRows([right, lowerWide])
        let sparseReport = CardDebugGridBoardLabModel.report(for: locallyCompacted, mode: .storedPlacement)
        let autoPacked = CardDebugGridBoardLabModel.autoPacked([right, lowerWide])
        let autoReport = CardDebugGridBoardLabModel.report(for: autoPacked, mode: .storedPlacement)

        XCTAssertEqual(placement(of: right.id, in: locallyCompacted), MemoryCardGridPlacement(column: 4, row: 0))
        XCTAssertEqual(placement(of: lowerWide.id, in: locallyCompacted), MemoryCardGridPlacement(column: 0, row: 1))
        XCTAssertEqual(placement(of: right.id, in: autoPacked), MemoryCardGridPlacement(column: 0, row: 0))
        XCTAssertGreaterThan(sparseReport.holesCount, autoReport.holesCount)
        XCTAssertGreaterThan(sparseReport.autoPackRecoverableHoles, 0)
    }

    func testCommitPreviewDoesNotCompactDropHoles() {
        let dragged = gridItem("dragged", size: .strip, column: 0, row: 0)
        let right = gridItem("right", size: .strip, column: 2, row: 0)
        let preview = CardDebugGridBoardLabModel.previewItems(
            dragging: dragged.id,
            to: MemoryCardGridPlacement(column: 0, row: 2),
            in: [dragged, right]
        )

        let committed = CardDebugGridBoardLabModel.commitPreview(preview.items)

        XCTAssertEqual(placement(of: dragged.id, in: committed), MemoryCardGridPlacement(column: 0, row: 2))
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

    func testResizeGrowingCardReflowsFromResizedIndexOnward() {
        let hero = gridItem("hero", size: .strip, column: 0, row: 0)
        let blocker = gridItem("blocker", size: .strip, column: 4, row: 0)
        let follower = gridItem("follower", size: .strip, column: 0, row: 3)

        let resized = CardDebugGridBoardLabModel.itemsAfterResizing(
            id: hero.id,
            to: .banner,
            in: [hero, blocker, follower]
        )

        XCTAssertEqual(placement(of: hero.id, in: resized), MemoryCardGridPlacement(column: 0, row: 0))
        XCTAssertEqual(placement(of: blocker.id, in: resized), MemoryCardGridPlacement(column: 0, row: 3))
        XCTAssertEqual(placement(of: follower.id, in: resized), MemoryCardGridPlacement(column: 2, row: 3))
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

    func testPreviewForLargeDebugSetDoesNotUseSearchSolver() {
        let sizes = MemoryCardSizeToken.allCases
        let items = CardDebugGridBoardLabModel.orderedSparsePack(
            (0..<100).map { index in
                let size = sizes[index % sizes.count]
                return CardDebugGridBoardLabItem(
                    id: UUID(),
                    title: "\(index)",
                    size: size,
                    recipe: CardDebugGridBoardLabModel.recipe(for: size),
                    placement: nil
                )
            }
        )
        let dragged = items[50]

        measure {
            for row in 0..<100 {
                _ = CardDebugGridBoardLabModel.previewItems(
                    dragging: dragged.id,
                    to: MemoryCardGridPlacement(column: 0, row: row),
                    in: items
                )
            }
        }
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
        let boardHeight = (slots.map(\.renderFrame.maxY).max() ?? 0) + metrics.verticalPadding
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
            XCTAssertEqual(attributes?.frame, slot.renderFrame)
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

    func testGridBoardImplementationDoesNotUseInteractiveMovementOrSearchSolver() throws {
        let uiKitSource = try source(named: "CardDebugGridBoardUIKitView.swift")
        let engineSource = try source(named: "CardDebugGridBoardLayoutEngine.swift")

        XCTAssertFalse(uiKitSource.contains("beginInteractiveMovementForItem"))
        XCTAssertFalse(uiKitSource.contains("updateInteractiveMovementTargetPosition"))
        XCTAssertFalse(uiKitSource.contains("endInteractiveMovement"))
        XCTAssertFalse(uiKitSource.contains("cancelInteractiveMovement"))
        XCTAssertFalse(uiKitSource.contains("onPreviewChanged"))
        XCTAssertFalse(uiKitSource.contains("+ collectionView.contentOffset"))
        XCTAssertTrue(uiKitSource.contains("snapshotView(afterScreenUpdates: false)"))
        XCTAssertTrue(uiKitSource.contains("collectionView.clipsToBounds = false"))
        XCTAssertTrue(uiKitSource.contains("cell.clipsToBounds = false"))
        XCTAssertTrue(uiKitSource.contains("UIView.animate"))
        XCTAssertTrue(uiKitSource.contains(".renderFrame"))
        XCTAssertFalse(engineSource.contains("minimumDisturbance"))
        XCTAssertFalse(engineSource.contains("displacedPreview"))
        XCTAssertFalse(engineSource.contains("maxIterations"))
        XCTAssertFalse(engineSource.contains("CardDebugGridLayoutCost"))
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
