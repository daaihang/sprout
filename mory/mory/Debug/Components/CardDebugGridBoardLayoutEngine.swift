import SwiftUI

enum CardDebugGridBoardLabModel {
    static func defaultItems() -> [CardDebugGridBoardLabItem] {
        let sizes = MemoryCardSizeToken.allCases
        let placements = MemoryCardGridPacking.placements(for: sizes)
        return sizes.enumerated().map { index, size in
            CardDebugGridBoardLabItem(
                id: UUID(),
                title: size.rawValue,
                size: size,
                recipe: recipe(for: size),
                placement: placements[safe: index]
            )
        }
    }

    static func autoPacked(_ items: [CardDebugGridBoardLabItem]) -> [CardDebugGridBoardLabItem] {
        let placements = MemoryCardGridPacking.placements(for: items.map(\.size))
        return items.enumerated().map { index, item in
            var item = item
            item.placement = placements[safe: index]
            return item
        }
    }

    static func targetPlacement(
        for location: CGPoint,
        itemSize: MemoryCardSizeToken,
        boardWidth: CGFloat,
        metrics: MemoryDeskBoardMetrics
    ) -> MemoryCardGridPlacement {
        let cellSize = metrics.cellWidth(for: boardWidth)
        let columnStep = cellSize + metrics.columnSpacing
        let rowStep = metrics.rowHeight + metrics.rowSpacing
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: itemSize)
        let maxColumn = max(0, MemoryCardRecipeLayoutPolicy.columnCount - box.columnSpan)
        let rawColumn = Int(round((location.x - metrics.horizontalPadding) / max(CGFloat(1), columnStep)))
        let rawRow = Int(round((location.y - metrics.verticalPadding) / max(CGFloat(1), rowStep)))
        return MemoryCardGridPlacement(
            column: min(max(0, rawColumn), maxColumn),
            row: max(0, rawRow)
        )
    }

    static func hitItemID(
        at point: CGPoint,
        in slots: [CardDebugGridBoardLabSlot]
    ) -> UUID? {
        slots.enumerated()
            .filter { _, slot in slot.frame.contains(point) }
            .sorted { lhs, rhs in
                let lhsZIndex = lhs.element.layout.zIndex
                let rhsZIndex = rhs.element.layout.zIndex
                if lhsZIndex != rhsZIndex {
                    return lhsZIndex > rhsZIndex
                }
                return lhs.offset > rhs.offset
            }
            .first?
            .element
            .item
            .id
    }

    static func beginDrag(
        at point: CGPoint,
        in slots: [CardDebugGridBoardLabSlot]
    ) -> CardDebugGridUIKitDragSession? {
        guard
            let itemID = hitItemID(at: point, in: slots),
            let slot = slots.first(where: { $0.item.id == itemID })
        else {
            return nil
        }
        return CardDebugGridUIKitDragSession(
            itemID: itemID,
            itemSize: slot.item.size,
            geometry: CardDebugGridDragGeometry(
                originalFrame: slot.frame,
                touchLocation: point
            )
        )
    }

    static func dragPreview(
        for session: CardDebugGridUIKitDragSession,
        at location: CGPoint,
        boardWidth: CGFloat,
        metrics: MemoryDeskBoardMetrics,
        in items: [CardDebugGridBoardLabItem]
    ) -> CardDebugGridDragPreview {
        let target = targetPlacement(
            for: session.geometry.gridAnchorLocation(for: location),
            itemSize: session.itemSize,
            boardWidth: boardWidth,
            metrics: metrics
        )
        return previewItemsWithoutCompaction(
            dragging: session.itemID,
            to: target,
            in: items
        )
    }

    static func previewItems(
        dragging id: UUID,
        to placement: MemoryCardGridPlacement,
        in items: [CardDebugGridBoardLabItem]
    ) -> CardDebugGridDragPreview {
        minimumDisturbancePreview(dragging: id, to: placement, in: items)
    }

    static func previewItemsWithoutCompaction(
        dragging id: UUID,
        to placement: MemoryCardGridPlacement,
        in items: [CardDebugGridBoardLabItem]
    ) -> CardDebugGridDragPreview {
        minimumDisturbancePreview(dragging: id, to: placement, in: items)
    }

    static func commitPreview(_ items: [CardDebugGridBoardLabItem]) -> [CardDebugGridBoardLabItem] {
        compactEmptyRows(items)
    }

    static func appendPlacement(
        for size: MemoryCardSizeToken,
        in items: [CardDebugGridBoardLabItem]
    ) -> MemoryCardGridPlacement {
        let occupied = items.compactMap { occupiedBox(for: $0) }
        let bottomRow = occupied.map { $0.placement.row + $0.box.rowSpan }.max() ?? 0
        return firstAvailablePlacement(
            for: size,
            from: MemoryCardGridPlacement(column: 0, row: bottomRow),
            occupied: occupied
        )
    }

    static func itemsAfterAdding(
        size: MemoryCardSizeToken,
        to items: [CardDebugGridBoardLabItem]
    ) -> [CardDebugGridBoardLabItem] {
        let id = UUID()
        let next = CardDebugGridBoardLabItem(
            id: id,
            title: size.rawValue,
            size: size,
            recipe: recipe(for: size),
            placement: appendPlacement(for: size, in: items)
        )
        return items + [next]
    }

    static func itemsAfterDeleting(
        id: UUID,
        from items: [CardDebugGridBoardLabItem]
    ) -> [CardDebugGridBoardLabItem] {
        compactEmptyRows(items.filter { $0.id != id })
    }

    static func itemsAfterResizing(
        id: UUID,
        to size: MemoryCardSizeToken,
        in items: [CardDebugGridBoardLabItem]
    ) -> [CardDebugGridBoardLabItem] {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return items }
        var next = items
        next[index].size = size
        next[index].recipe = recipe(for: size)
        next[index].title = size.rawValue
        let placement = next[index].placement ?? MemoryCardGridPlacement(column: 0, row: index)
        let preview = minimumDisturbancePreview(dragging: id, to: placement, in: next)
        return commitPreview(preview.items)
    }

    static func itemsAfterMoving(
        id: UUID,
        by offset: Int,
        in items: [CardDebugGridBoardLabItem]
    ) -> [CardDebugGridBoardLabItem] {
        guard let sourceIndex = items.firstIndex(where: { $0.id == id }) else { return items }
        let targetIndex = sourceIndex + offset
        guard items.indices.contains(targetIndex) else { return items }
        var next = items
        next.swapAt(sourceIndex, targetIndex)
        return next
    }

    static func itemsAfterTogglingPinned(
        id: UUID,
        in items: [CardDebugGridBoardLabItem]
    ) -> [CardDebugGridBoardLabItem] {
        items.map { item in
            guard item.id == id else { return item }
            var item = item
            item.isPinned.toggle()
            return item
        }
    }

    static func itemsAfterTogglingUserAdjusted(
        id: UUID,
        in items: [CardDebugGridBoardLabItem]
    ) -> [CardDebugGridBoardLabItem] {
        items.map { item in
            guard item.id == id else { return item }
            var item = item
            item.isUserAdjusted.toggle()
            return item
        }
    }

    static func compactEmptyRows(_ items: [CardDebugGridBoardLabItem]) -> [CardDebugGridBoardLabItem] {
        items.compactingEmptyRows()
    }

    static func slots(
        for items: [CardDebugGridBoardLabItem],
        mode: CardDebugGridBoardPlacementMode,
        containerWidth: CGFloat,
        metrics: MemoryDeskBoardMetrics = .default
    ) -> [CardDebugGridBoardLabSlot] {
        switch mode {
        case .storedPlacement:
            return plannedSlots(
                for: items,
                layouts: items.enumerated().map { index, item in
                    MemoryCardLayoutToken(order: index, size: item.size, gridPlacement: item.placement, zIndex: index)
                },
                containerWidth: containerWidth,
                metrics: metrics
            )
        case .firstFitEffectivePlacement:
            return plannedSlots(
                for: items,
                layouts: items.enumerated().map { index, item in
                    MemoryCardLayoutToken(order: index, size: item.size, zIndex: index)
                },
                containerWidth: containerWidth,
                metrics: metrics
            )
        case .nilPlacementFallback:
            return legacyFallbackSlots(for: items, containerWidth: containerWidth, metrics: metrics)
        }
    }

    static func report(
        for items: [CardDebugGridBoardLabItem],
        mode: CardDebugGridBoardPlacementMode,
        containerWidth: CGFloat = 390,
        metrics: MemoryDeskBoardMetrics = .default,
        activeDragTarget: MemoryCardGridPlacement? = nil,
        affectedItemIDs: [UUID] = [],
        solverCost: CardDebugGridLayoutCost? = nil,
        solverUsedFallback: Bool = false
    ) -> CardDebugGridBoardLabReport {
        let slots = slots(for: items, mode: mode, containerWidth: containerWidth, metrics: metrics)
        var occupied = Set<CardDebugGridCell>()
        var overlapCount = 0
        for slot in slots {
            for cell in slot.cells {
                if occupied.contains(cell) {
                    overlapCount += 1
                } else {
                    occupied.insert(cell)
                }
            }
        }

        let rowCount = max(1, slots.map { slot in
            guard let placement = slot.layout.gridPlacement else { return 0 }
            return placement.row + slot.gridBox.rowSpan
        }.max() ?? 0)
        let totalCells = rowCount * MemoryCardRecipeLayoutPolicy.columnCount
        let density = totalCells == 0 ? 0 : Double(occupied.count) / Double(totalCells)
        return CardDebugGridBoardLabReport(
            projectionMode: mode,
            boardWidth: containerWidth,
            cellSize: metrics.cellWidth(for: containerWidth),
            activeDragTarget: activeDragTarget,
            affectedItemIDs: affectedItemIDs,
            rowCount: rowCount,
            occupiedCells: occupied.count,
            totalCells: totalCells,
            density: density,
            overlapCount: overlapCount,
            gridOverflowCount: slots.filter(\.gridOverflow).count,
            solverCost: solverCost,
            solverUsedFallback: solverUsedFallback,
            slots: slots
        )
    }

    static func recipe(for size: MemoryCardSizeToken) -> MemoryCardVisualRecipe {
        switch size {
        case .stamp:
            return .weatherStamp
        case .strip:
            return .taskNote
        case .card:
            return .linkNote
        case .square:
            return .polaroid
        case .tape:
            return .cassette
        case .banner:
            return .notebook
        }
    }

    private static func minimumDisturbancePreview(
        dragging id: UUID,
        to placement: MemoryCardGridPlacement,
        in items: [CardDebugGridBoardLabItem]
    ) -> CardDebugGridDragPreview {
        guard let dragged = items.first(where: { $0.id == id }) else {
            return CardDebugGridDragPreview(itemID: id, targetPlacement: placement, items: items, affectedItemIDs: [])
        }

        let target = clampedPlacement(placement, for: dragged.size)
        let originalPlacements = normalizedPlacements(for: items)
        var initialPlacements = originalPlacements
        initialPlacements[id] = target

        let result = solveMinimumDisturbance(
            dragging: id,
            items: items,
            originalPlacements: originalPlacements,
            initialState: CardDebugGridLayoutState(placementsByID: initialPlacements)
        )

        let next = items.map { item -> CardDebugGridBoardLabItem in
            var item = item
            if let placement = result.state.placementsByID[item.id] {
                item.placement = placement
            }
            return item
        }
        let movedIDs = items.compactMap { item -> UUID? in
            guard item.id != id,
                  result.state.placementsByID[item.id] != originalPlacements[item.id]
            else {
                return nil
            }
            return item.id
        }
        return CardDebugGridDragPreview(
            itemID: id,
            targetPlacement: target,
            items: next,
            affectedItemIDs: [id] + movedIDs,
            solverCost: result.cost,
            usedFallback: result.usedFallback
        )
    }

    private static func solveMinimumDisturbance(
        dragging id: UUID,
        items: [CardDebugGridBoardLabItem],
        originalPlacements: [UUID: MemoryCardGridPlacement],
        initialState: CardDebugGridLayoutState
    ) -> CardDebugGridLayoutSolverResult {
        let maxIterations = 3_500
        var frontier = [initialState]
        var visited = Set([stateSignature(initialState, items: items)])

        for _ in 0..<maxIterations where !frontier.isEmpty {
            frontier.sort { lhs, rhs in
                let lhsCost = cost(
                    for: lhs,
                    dragging: id,
                    items: items,
                    originalPlacements: originalPlacements
                )
                let rhsCost = cost(
                    for: rhs,
                    dragging: id,
                    items: items,
                    originalPlacements: originalPlacements
                )
                if lhsCost != rhsCost {
                    return lhsCost < rhsCost
                }
                return collisionCount(in: lhs, items: items) < collisionCount(in: rhs, items: items)
            }

            let state = frontier.removeFirst()
            let collisions = collisions(in: state, items: items)
            if collisions.isEmpty {
                return CardDebugGridLayoutSolverResult(
                    state: state,
                    cost: cost(
                        for: state,
                        dragging: id,
                        items: items,
                        originalPlacements: originalPlacements
                    ),
                    usedFallback: false
                )
            }

            let collision = collisions[0]
            for itemID in movableItemIDs(for: collision, dragging: id, items: items) {
                guard let item = items.first(where: { $0.id == itemID }) else { continue }
                let candidates = candidatePlacements(
                    for: item,
                    in: state,
                    items: items,
                    originalPlacements: originalPlacements,
                    dragging: id
                )
                for candidate in candidates {
                    guard candidate != state.placementsByID[itemID] else { continue }
                    var nextState = state
                    nextState.placementsByID[itemID] = candidate
                    let signature = stateSignature(nextState, items: items)
                    guard !visited.contains(signature) else { continue }
                    visited.insert(signature)
                    frontier.append(nextState)
                }
            }
        }

        return fallbackResult(
            dragging: id,
            items: items,
            originalPlacements: originalPlacements,
            initialState: initialState
        )
    }

    private static func candidatePlacements(
        for item: CardDebugGridBoardLabItem,
        in state: CardDebugGridLayoutState,
        items: [CardDebugGridBoardLabItem],
        originalPlacements: [UUID: MemoryCardGridPlacement],
        dragging id: UUID
    ) -> [MemoryCardGridPlacement] {
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: item.size)
        let maxColumn = max(0, MemoryCardRecipeLayoutPolicy.columnCount - box.columnSpan)
        let original = originalPlacements[item.id] ?? MemoryCardGridPlacement(column: 0, row: 0)
        let currentBottom = boardBottomRow(state: state, items: items)
        let originalBottom = boardBottomRow(placements: originalPlacements, items: items)
        let maxRow = max(currentBottom, originalBottom) + 4
        let draggedPlacement = state.placementsByID[id]
        let draggedBox = items.first(where: { $0.id == id }).map { MemoryCardRecipeLayoutPolicy.gridBox(for: $0.size) }

        let candidates = (0...maxRow).flatMap { row in
            (0...maxColumn).map { column in
                MemoryCardGridPlacement(column: column, row: row)
            }
        }
        .filter { placement in
            guard let draggedPlacement, let draggedBox else { return true }
            return !gridRectsIntersect(
                lhsPlacement: placement,
                lhsBox: box,
                rhsPlacement: draggedPlacement,
                rhsBox: draggedBox
            )
        }
        .sorted { lhs, rhs in
            let lhsScore = candidateScore(lhs, original: original)
            let rhsScore = candidateScore(rhs, original: original)
            if lhsScore != rhsScore {
                return lhsScore < rhsScore
            }
            if lhs.row != rhs.row {
                return lhs.row < rhs.row
            }
            return lhs.column < rhs.column
        }

        return Array(candidates.prefix(24))
    }

    private static func candidateScore(
        _ placement: MemoryCardGridPlacement,
        original: MemoryCardGridPlacement
    ) -> Int {
        let rowDelta = abs(placement.row - original.row)
        let columnDelta = abs(placement.column - original.column)
        let sameRowBonus = placement.row == original.row ? 0 : 1
        let sameColumnBonus = placement.column == original.column ? 0 : 1
        return (rowDelta + columnDelta) * 100 + rowDelta * 10 + columnDelta * 4 + sameRowBonus * 2 + sameColumnBonus
    }

    private static func fallbackResult(
        dragging id: UUID,
        items: [CardDebugGridBoardLabItem],
        originalPlacements: [UUID: MemoryCardGridPlacement],
        initialState: CardDebugGridLayoutState
    ) -> CardDebugGridLayoutSolverResult {
        var state = initialState
        var guardCount = 0
        while let collision = collisions(in: state, items: items).first, guardCount < 80 {
            guardCount += 1
            guard let itemID = movableItemIDs(for: collision, dragging: id, items: items).first,
                  let item = items.first(where: { $0.id == itemID })
            else {
                break
            }
            let occupied = items.compactMap { other -> CardDebugGridOccupiedBox? in
                guard other.id != itemID,
                      let placement = state.placementsByID[other.id]
                else {
                    return nil
                }
                return CardDebugGridOccupiedBox(
                    placement: placement,
                    box: MemoryCardRecipeLayoutPolicy.gridBox(for: other.size)
                )
            }
            let bottomRow = occupied.map { $0.placement.row + $0.box.rowSpan }.max() ?? 0
            state.placementsByID[itemID] = firstAvailablePlacement(
                for: item.size,
                from: MemoryCardGridPlacement(column: 0, row: bottomRow),
                occupied: occupied
            )
        }
        return CardDebugGridLayoutSolverResult(
            state: state,
            cost: cost(
                for: state,
                dragging: id,
                items: items,
                originalPlacements: originalPlacements
            ),
            usedFallback: true
        )
    }

    private static func normalizedPlacements(for items: [CardDebugGridBoardLabItem]) -> [UUID: MemoryCardGridPlacement] {
        Dictionary(
            uniqueKeysWithValues: items.enumerated().map { index, item in
                (
                    item.id,
                    clampedPlacement(
                        item.placement ?? MemoryCardGridPlacement(column: 0, row: index),
                        for: item.size
                    )
                )
            }
        )
    }

    private static func collisions(
        in state: CardDebugGridLayoutState,
        items: [CardDebugGridBoardLabItem]
    ) -> [CardDebugGridCollision] {
        let placed = items.compactMap { item -> (item: CardDebugGridBoardLabItem, placement: MemoryCardGridPlacement)? in
            guard let placement = state.placementsByID[item.id] else { return nil }
            return (item, clampedPlacement(placement, for: item.size))
        }
        var collisions: [CardDebugGridCollision] = []
        for lhsIndex in placed.indices {
            for rhsIndex in placed.indices where rhsIndex > lhsIndex {
                let lhs = placed[lhsIndex]
                let rhs = placed[rhsIndex]
                if gridRectsIntersect(
                    lhsPlacement: lhs.placement,
                    lhsBox: MemoryCardRecipeLayoutPolicy.gridBox(for: lhs.item.size),
                    rhsPlacement: rhs.placement,
                    rhsBox: MemoryCardRecipeLayoutPolicy.gridBox(for: rhs.item.size)
                ) {
                    collisions.append(CardDebugGridCollision(lhsID: lhs.item.id, rhsID: rhs.item.id))
                }
            }
        }
        return collisions
    }

    private static func collisionCount(
        in state: CardDebugGridLayoutState,
        items: [CardDebugGridBoardLabItem]
    ) -> Int {
        collisions(in: state, items: items).count
    }

    private static func movableItemIDs(
        for collision: CardDebugGridCollision,
        dragging id: UUID,
        items: [CardDebugGridBoardLabItem]
    ) -> [UUID] {
        if collision.lhsID == id {
            return [collision.rhsID]
        }
        if collision.rhsID == id {
            return [collision.lhsID]
        }
        return [collision.lhsID, collision.rhsID].sorted { lhs, rhs in
            let lhsItem = items.first { $0.id == lhs }
            let rhsItem = items.first { $0.id == rhs }
            let lhsProtection = movementProtectionScore(lhsItem)
            let rhsProtection = movementProtectionScore(rhsItem)
            if lhsProtection != rhsProtection {
                return lhsProtection < rhsProtection
            }
            return lhs.uuidString < rhs.uuidString
        }
    }

    private static func movementProtectionScore(_ item: CardDebugGridBoardLabItem?) -> Int {
        guard let item else { return 0 }
        return (item.isPinned ? 2 : 0) + (item.isUserAdjusted ? 1 : 0)
    }

    private static func cost(
        for state: CardDebugGridLayoutState,
        dragging id: UUID,
        items: [CardDebugGridBoardLabItem],
        originalPlacements: [UUID: MemoryCardGridPlacement]
    ) -> CardDebugGridLayoutCost {
        var movedItemCount = 0
        var pinnedMovedCount = 0
        var userAdjustedMovedCount = 0
        var totalManhattanDistance = 0
        var totalRowDelta = 0
        var totalColumnDelta = 0

        for item in items where item.id != id {
            guard
                let original = originalPlacements[item.id],
                let placement = state.placementsByID[item.id]
            else {
                continue
            }
            let rowDelta = abs(placement.row - original.row)
            let columnDelta = abs(placement.column - original.column)
            guard rowDelta > 0 || columnDelta > 0 else { continue }
            movedItemCount += 1
            pinnedMovedCount += item.isPinned ? 1 : 0
            userAdjustedMovedCount += item.isUserAdjusted ? 1 : 0
            totalManhattanDistance += rowDelta + columnDelta
            totalRowDelta += rowDelta
            totalColumnDelta += columnDelta
        }

        let boardHeightGrowth = max(
            0,
            boardBottomRow(state: state, items: items)
                - boardBottomRow(placements: originalPlacements, items: items)
        )
        let visualOrderInversionCount = visualOrderInversionCount(
            state: state,
            dragging: id,
            items: items,
            originalPlacements: originalPlacements
        )
        let tieBreakSignature = items.map { item in
            let placement = state.placementsByID[item.id] ?? MemoryCardGridPlacement(column: 0, row: 0)
            return "\(placement.row):\(placement.column):\(item.id.uuidString)"
        }
        .joined(separator: "|")

        return CardDebugGridLayoutCost(
            movedItemCount: movedItemCount,
            pinnedMovedCount: pinnedMovedCount,
            userAdjustedMovedCount: userAdjustedMovedCount,
            totalManhattanDistance: totalManhattanDistance,
            totalRowDelta: totalRowDelta,
            totalColumnDelta: totalColumnDelta,
            visualOrderInversionCount: visualOrderInversionCount,
            boardHeightGrowth: boardHeightGrowth,
            tieBreakSignature: tieBreakSignature
        )
    }

    private static func visualOrderInversionCount(
        state: CardDebugGridLayoutState,
        dragging id: UUID,
        items: [CardDebugGridBoardLabItem],
        originalPlacements: [UUID: MemoryCardGridPlacement]
    ) -> Int {
        let nonDraggedItems = items.filter { $0.id != id }
        let originalOrder = nonDraggedItems.sorted { lhs, rhs in
            visualOrderSort(
                lhsID: lhs.id,
                lhsPlacement: originalPlacements[lhs.id],
                rhsID: rhs.id,
                rhsPlacement: originalPlacements[rhs.id]
            )
        }
        let finalOrder = nonDraggedItems.sorted { lhs, rhs in
            visualOrderSort(
                lhsID: lhs.id,
                lhsPlacement: state.placementsByID[lhs.id],
                rhsID: rhs.id,
                rhsPlacement: state.placementsByID[rhs.id]
            )
        }
        let originalIndex = Dictionary(uniqueKeysWithValues: originalOrder.enumerated().map { ($0.element.id, $0.offset) })
        var inversions = 0
        for lhsIndex in finalOrder.indices {
            for rhsIndex in finalOrder.indices where rhsIndex > lhsIndex {
                let lhsID = finalOrder[lhsIndex].id
                let rhsID = finalOrder[rhsIndex].id
                if (originalIndex[lhsID] ?? 0) > (originalIndex[rhsID] ?? 0) {
                    inversions += 1
                }
            }
        }
        return inversions
    }

    private static func visualOrderSort(
        lhsID: UUID,
        lhsPlacement: MemoryCardGridPlacement?,
        rhsID: UUID,
        rhsPlacement: MemoryCardGridPlacement?
    ) -> Bool {
        let lhsPlacement = lhsPlacement ?? MemoryCardGridPlacement(column: 0, row: 0)
        let rhsPlacement = rhsPlacement ?? MemoryCardGridPlacement(column: 0, row: 0)
        if lhsPlacement.row != rhsPlacement.row {
            return lhsPlacement.row < rhsPlacement.row
        }
        if lhsPlacement.column != rhsPlacement.column {
            return lhsPlacement.column < rhsPlacement.column
        }
        return lhsID.uuidString < rhsID.uuidString
    }

    private static func boardBottomRow(
        state: CardDebugGridLayoutState,
        items: [CardDebugGridBoardLabItem]
    ) -> Int {
        boardBottomRow(placements: state.placementsByID, items: items)
    }

    private static func boardBottomRow(
        placements: [UUID: MemoryCardGridPlacement],
        items: [CardDebugGridBoardLabItem]
    ) -> Int {
        items.compactMap { item in
            placements[item.id].map { placement in
                placement.row + MemoryCardRecipeLayoutPolicy.gridBox(for: item.size).rowSpan
            }
        }
        .max() ?? 0
    }

    private static func stateSignature(
        _ state: CardDebugGridLayoutState,
        items: [CardDebugGridBoardLabItem]
    ) -> String {
        items.map { item in
            let placement = state.placementsByID[item.id] ?? MemoryCardGridPlacement(column: 0, row: 0)
            return "\(item.id.uuidString):\(placement.column),\(placement.row)"
        }
        .joined(separator: "|")
    }

    private static func plannedSlots(
        for items: [CardDebugGridBoardLabItem],
        layouts: [MemoryCardLayoutToken],
        containerWidth: CGFloat,
        metrics: MemoryDeskBoardMetrics
    ) -> [CardDebugGridBoardLabSlot] {
        let inputNodes = zip(items, layouts).map { item, layout in
            MemoryDeskBoardInputNode(id: item.id, layout: layout)
        }
        let plan = MemoryDeskBoardLayoutPlan.make(
            nodes: inputNodes,
            containerWidth: containerWidth,
            metrics: metrics
        )
        let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return plan.slots.compactMap { slot in
            guard let item = itemByID[slot.id] else { return nil }
            return CardDebugGridBoardLabSlot(id: item.id, item: item, layout: slot.layout, frame: slot.frame)
        }
    }

    private static func legacyFallbackSlots(
        for items: [CardDebugGridBoardLabItem],
        containerWidth: CGFloat,
        metrics: MemoryDeskBoardMetrics
    ) -> [CardDebugGridBoardLabSlot] {
        items.enumerated().map { index, item in
            var layout = MemoryCardLayoutToken(
                order: index,
                size: item.size,
                gridPlacement: MemoryCardGridPlacement(
                    column: index % MemoryCardRecipeLayoutPolicy.columnCount,
                    row: index / MemoryCardRecipeLayoutPolicy.columnCount
                ),
                zIndex: index
            )
            layout.size = MemoryCardRecipeLayoutPolicy.normalizedSize(layout.size, for: item.recipe)
            return CardDebugGridBoardLabSlot(
                id: item.id,
                item: item,
                layout: layout,
                frame: frame(for: layout, containerWidth: containerWidth, metrics: metrics)
            )
        }
    }

    private static func frame(
        for layout: MemoryCardLayoutToken,
        containerWidth: CGFloat,
        metrics: MemoryDeskBoardMetrics
    ) -> CGRect {
        let cellWidth = metrics.cellWidth(for: containerWidth)
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: layout.size)
        let placement = layout.gridPlacement ?? MemoryCardGridPlacement(column: 0, row: layout.order)
        let x = metrics.horizontalPadding + CGFloat(placement.column) * (cellWidth + metrics.columnSpacing)
        let y = metrics.verticalPadding + CGFloat(placement.row) * (metrics.rowHeight + metrics.rowSpacing)
        let width = CGFloat(box.columnSpan) * cellWidth + CGFloat(max(0, box.columnSpan - 1)) * metrics.columnSpacing
        let height = CGFloat(box.rowSpan) * metrics.rowHeight + CGFloat(max(0, box.rowSpan - 1)) * metrics.rowSpacing
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func visualOrder(_ items: [CardDebugGridBoardLabItem]) -> [CardDebugGridBoardLabItem] {
        items.enumerated()
            .sorted { lhs, rhs in
                let lhsPlacement = lhs.element.placement ?? MemoryCardGridPlacement(column: 0, row: lhs.offset)
                let rhsPlacement = rhs.element.placement ?? MemoryCardGridPlacement(column: 0, row: rhs.offset)
                if lhsPlacement.row != rhsPlacement.row {
                    return lhsPlacement.row < rhsPlacement.row
                }
                if lhsPlacement.column != rhsPlacement.column {
                    return lhsPlacement.column < rhsPlacement.column
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func firstAvailablePlacement(
        for size: MemoryCardSizeToken,
        from start: MemoryCardGridPlacement,
        occupied: [CardDebugGridOccupiedBox]
    ) -> MemoryCardGridPlacement {
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
        let maxColumn = max(0, MemoryCardRecipeLayoutPolicy.columnCount - box.columnSpan)
        var row = max(0, start.row)
        var startColumn = min(max(0, start.column), maxColumn)

        while true {
            for column in startColumn...maxColumn {
                let placement = MemoryCardGridPlacement(column: column, row: row)
                if !intersectsAny(box: box, placement: placement, occupied: occupied) {
                    return placement
                }
            }
            row += 1
            startColumn = 0
        }
    }

    private static func nextCursor(
        after placement: MemoryCardGridPlacement,
        size: MemoryCardSizeToken
    ) -> MemoryCardGridPlacement {
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
        let nextColumn = placement.column + box.columnSpan
        if nextColumn < MemoryCardRecipeLayoutPolicy.columnCount {
            return MemoryCardGridPlacement(column: nextColumn, row: placement.row)
        }
        return MemoryCardGridPlacement(column: 0, row: placement.row + 1)
    }

    private static func clampedPlacement(
        _ placement: MemoryCardGridPlacement,
        for size: MemoryCardSizeToken
    ) -> MemoryCardGridPlacement {
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
        let maxColumn = max(0, MemoryCardRecipeLayoutPolicy.columnCount - box.columnSpan)
        return MemoryCardGridPlacement(column: min(max(0, placement.column), maxColumn), row: max(0, placement.row))
    }

    private static func occupiedBox(for item: CardDebugGridBoardLabItem) -> CardDebugGridOccupiedBox? {
        guard let placement = item.placement else { return nil }
        return CardDebugGridOccupiedBox(
            placement: clampedPlacement(placement, for: item.size),
            box: MemoryCardRecipeLayoutPolicy.gridBox(for: item.size)
        )
    }

    private static func intersectsAny(
        box: MemoryCardGridBox,
        placement: MemoryCardGridPlacement,
        occupied: [CardDebugGridOccupiedBox]
    ) -> Bool {
        occupied.contains { occupiedBox in
            gridRectsIntersect(
                lhsPlacement: placement,
                lhsBox: box,
                rhsPlacement: occupiedBox.placement,
                rhsBox: occupiedBox.box
            )
        }
    }

    private static func gridRectsIntersect(
        lhsPlacement: MemoryCardGridPlacement,
        lhsBox: MemoryCardGridBox,
        rhsPlacement: MemoryCardGridPlacement,
        rhsBox: MemoryCardGridBox
    ) -> Bool {
        let lhsMaxColumn = lhsPlacement.column + lhsBox.columnSpan
        let lhsMaxRow = lhsPlacement.row + lhsBox.rowSpan
        let rhsMaxColumn = rhsPlacement.column + rhsBox.columnSpan
        let rhsMaxRow = rhsPlacement.row + rhsBox.rowSpan
        return lhsPlacement.column < rhsMaxColumn
            && lhsMaxColumn > rhsPlacement.column
            && lhsPlacement.row < rhsMaxRow
            && lhsMaxRow > rhsPlacement.row
    }
}

private struct CardDebugGridOccupiedBox {
    let placement: MemoryCardGridPlacement
    let box: MemoryCardGridBox
}

private struct CardDebugGridCollision: Hashable {
    let lhsID: UUID
    let rhsID: UUID
}

private extension Array where Element == CardDebugGridBoardLabItem {
    func compactingEmptyRows() -> [CardDebugGridBoardLabItem] {
        let occupiedRows = Set(
            flatMap { item -> [Int] in
                guard let placement = item.placement else { return [] }
                let rowSpan = MemoryCardRecipeLayoutPolicy.gridBox(for: item.size).rowSpan
                return (placement.row..<(placement.row + rowSpan)).map { $0 }
            }
        )
        guard let maxRow = occupiedRows.max() else { return self }

        var emptyRowsBefore: [Int: Int] = [:]
        var emptyRowCount = 0
        for row in 0...maxRow {
            emptyRowsBefore[row] = emptyRowCount
            if !occupiedRows.contains(row) {
                emptyRowCount += 1
            }
        }

        return map { item in
            guard let placement = item.placement else { return item }
            var item = item
            item.placement = MemoryCardGridPlacement(
                column: placement.column,
                row: Swift.max(0, placement.row - (emptyRowsBefore[placement.row] ?? emptyRowCount))
            )
            return item
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
