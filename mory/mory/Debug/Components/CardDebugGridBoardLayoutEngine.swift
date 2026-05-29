import SwiftUI

enum CardDebugGridBoardLabModel {
    static func defaultItems() -> [CardDebugGridBoardLabItem] {
        orderedSparsePack(
            MemoryCardSizeToken.allCases.map { size in
                CardDebugGridBoardLabItem(
                    id: UUID(),
                    title: size.rawValue,
                    size: size,
                    recipe: recipe(for: size),
                    placement: nil
                )
            }
        )
    }

    static func autoPacked(_ items: [CardDebugGridBoardLabItem]) -> [CardDebugGridBoardLabItem] {
        let placements = MemoryCardGridPacking.placements(for: items.map(\.size))
        return items.enumerated().map { index, item in
            var item = item
            item.placement = placements[safe: index]
            return item
        }
    }

    static func orderedSparsePack(_ items: [CardDebugGridBoardLabItem]) -> [CardDebugGridBoardLabItem] {
        orderedSparsePack(items, prefixCount: 0, preferredAnchor: nil)
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
            .filter { _, slot in slot.hitFrame.contains(point) }
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
                renderFrame: slot.renderFrame,
                gridFrame: slot.gridFrame,
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
        return previewItems(
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
        itemsAfterDropping(dragging: id, targetPlacement: placement, in: items)
    }

    static func previewItemsWithoutCompaction(
        dragging id: UUID,
        to placement: MemoryCardGridPlacement,
        in items: [CardDebugGridBoardLabItem]
    ) -> CardDebugGridDragPreview {
        previewItems(dragging: id, to: placement, in: items)
    }

    static func itemsAfterDropping(
        dragging id: UUID,
        targetPlacement placement: MemoryCardGridPlacement,
        in items: [CardDebugGridBoardLabItem]
    ) -> CardDebugGridDragPreview {
        guard let sourceIndex = items.firstIndex(where: { $0.id == id }) else {
            return CardDebugGridDragPreview(
                itemID: id,
                targetPlacement: placement,
                insertionIndex: items.count,
                movedRange: nil,
                items: items
            )
        }

        let dragged = items[sourceIndex]
        let target = clampedPlacement(placement, for: dragged.size)
        var remaining = items
        remaining.remove(at: sourceIndex)
        let insertionIndex = targetInsertionIndex(for: target, draggedSize: dragged.size, in: remaining)
        var reordered = remaining
        reordered.insert(dragged, at: insertionIndex)

        let packed = orderedSparsePack(
            reordered,
            prefixCount: insertionIndex,
            preferredAnchor: (index: insertionIndex, placement: target)
        )
        return CardDebugGridDragPreview(
            itemID: id,
            targetPlacement: target,
            insertionIndex: insertionIndex,
            movedRange: changedRange(from: items, to: packed),
            items: packed
        )
    }

    static func commitPreview(_ items: [CardDebugGridBoardLabItem]) -> [CardDebugGridBoardLabItem] {
        items
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
        let next = CardDebugGridBoardLabItem(
            id: UUID(),
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
        let oldBox = MemoryCardRecipeLayoutPolicy.gridBox(for: items[index].size)
        let newBox = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
        var next = items
        next[index].size = size
        next[index].recipe = recipe(for: size)
        next[index].title = size.rawValue

        if newBox.columnSpan <= oldBox.columnSpan, newBox.rowSpan <= oldBox.rowSpan {
            return compactEmptyRows(next)
        }

        let anchor = next[index].placement ?? MemoryCardGridPlacement(column: 0, row: index)
        return orderedSparsePack(
            next,
            prefixCount: index,
            preferredAnchor: (index: index, placement: clampedPlacement(anchor, for: size))
        )
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
        let moved = next.remove(at: sourceIndex)
        next.insert(moved, at: targetIndex)
        return orderedSparsePack(next)
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
        lastInsertionIndex: Int? = nil,
        movedRange: ClosedRange<Int>? = nil
    ) -> CardDebugGridBoardLabReport {
        let currentSlots = slots(for: items, mode: mode, containerWidth: containerWidth, metrics: metrics)
        var occupied = Set<CardDebugGridCell>()
        var overlapCount = 0
        for slot in currentSlots {
            for cell in slot.cells {
                if occupied.contains(cell) {
                    overlapCount += 1
                } else {
                    occupied.insert(cell)
                }
            }
        }

        let rowCount = max(1, currentSlots.map { slot in
            guard let placement = slot.layout.gridPlacement else { return 0 }
            return placement.row + slot.gridBox.rowSpan
        }.max() ?? 0)
        let totalCells = rowCount * MemoryCardRecipeLayoutPolicy.columnCount
        let density = totalCells == 0 ? 0 : Double(occupied.count) / Double(totalCells)
        let currentHolesCount = max(0, totalCells - occupied.count)
        let autoPackHoles = mode == .storedPlacement
            ? holeCount(
                in: slots(
                    for: autoPacked(items),
                    mode: .storedPlacement,
                    containerWidth: containerWidth,
                    metrics: metrics
                )
            )
            : currentHolesCount
        return CardDebugGridBoardLabReport(
            projectionMode: mode,
            boardWidth: containerWidth,
            cellSize: metrics.cellWidth(for: containerWidth),
            activeDragTarget: activeDragTarget,
            lastInsertionIndex: lastInsertionIndex,
            movedRange: movedRange,
            rowCount: rowCount,
            occupiedCells: occupied.count,
            totalCells: totalCells,
            holesCount: currentHolesCount,
            autoPackRecoverableHoles: max(0, currentHolesCount - autoPackHoles),
            density: density,
            overlapCount: overlapCount,
            gridOverflowCount: currentSlots.filter(\.gridOverflow).count,
            slots: currentSlots
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

    private static func orderedSparsePack(
        _ items: [CardDebugGridBoardLabItem],
        prefixCount: Int,
        preferredAnchor: (index: Int, placement: MemoryCardGridPlacement)?
    ) -> [CardDebugGridBoardLabItem] {
        guard !items.isEmpty else { return [] }
        let prefixLimit = min(max(0, prefixCount), items.count)
        var occupied = [CardDebugGridOccupiedBox]()
        var next = items

        for index in 0..<prefixLimit {
            let placement = clampedPlacement(
                next[index].placement ?? MemoryCardGridPlacement(column: 0, row: index),
                for: next[index].size
            )
            next[index].placement = placement
            occupied.append(CardDebugGridOccupiedBox(placement: placement, box: MemoryCardRecipeLayoutPolicy.gridBox(for: next[index].size)))
        }

        var cursor = nextCursor(afterPrefix: occupied)
        var startIndex = prefixLimit
        if let preferredAnchor, next.indices.contains(preferredAnchor.index) {
            let size = next[preferredAnchor.index].size
            let placement = firstAvailablePlacement(
                for: size,
                from: preferredAnchor.placement,
                occupied: occupied
            )
            next[preferredAnchor.index].placement = placement
            occupied.append(CardDebugGridOccupiedBox(placement: placement, box: MemoryCardRecipeLayoutPolicy.gridBox(for: size)))
            cursor = nextCursor(after: placement, size: size)
            startIndex = preferredAnchor.index + 1
        }

        guard startIndex < next.count else { return next }
        for index in startIndex..<next.count {
            let placement = firstAvailablePlacement(for: next[index].size, from: cursor, occupied: occupied)
            next[index].placement = placement
            occupied.append(CardDebugGridOccupiedBox(placement: placement, box: MemoryCardRecipeLayoutPolicy.gridBox(for: next[index].size)))
            cursor = nextCursor(after: placement, size: next[index].size)
        }
        return next
    }

    private static func targetInsertionIndex(
        for target: MemoryCardGridPlacement,
        draggedSize: MemoryCardSizeToken,
        in items: [CardDebugGridBoardLabItem]
    ) -> Int {
        let targetBox = MemoryCardRecipeLayoutPolicy.gridBox(for: draggedSize)
        for (index, item) in items.enumerated() {
            guard let itemPlacement = item.placement else { continue }
            let placement = clampedPlacement(itemPlacement, for: item.size)
            let box = MemoryCardRecipeLayoutPolicy.gridBox(for: item.size)
            if gridRectsIntersect(lhsPlacement: target, lhsBox: targetBox, rhsPlacement: placement, rhsBox: box) {
                return index
            }
            if isRowMajor(placement, atOrAfter: target) {
                return index
            }
        }
        return items.count
    }

    private static func changedRange(
        from original: [CardDebugGridBoardLabItem],
        to next: [CardDebugGridBoardLabItem]
    ) -> ClosedRange<Int>? {
        let maxCount = max(original.count, next.count)
        let changed = (0..<maxCount).filter { index in
            original[safe: index] != next[safe: index]
        }
        guard let first = changed.first, let last = changed.last else { return nil }
        return first...last
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

    private static func holeCount(in slots: [CardDebugGridBoardLabSlot]) -> Int {
        var occupied = Set<CardDebugGridCell>()
        for slot in slots {
            for cell in slot.cells {
                occupied.insert(cell)
            }
        }
        let rowCount = max(1, slots.map { slot in
            guard let placement = slot.layout.gridPlacement else { return 0 }
            return placement.row + slot.gridBox.rowSpan
        }.max() ?? 0)
        return max(0, rowCount * MemoryCardRecipeLayoutPolicy.columnCount - occupied.count)
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

    private static func nextCursor(afterPrefix occupied: [CardDebugGridOccupiedBox]) -> MemoryCardGridPlacement {
        guard let last = occupied.max(by: { lhs, rhs in
            let lhsBottom = lhs.placement.row + lhs.box.rowSpan
            let rhsBottom = rhs.placement.row + rhs.box.rowSpan
            if lhsBottom != rhsBottom {
                return lhsBottom < rhsBottom
            }
            return lhs.placement.column < rhs.placement.column
        }) else {
            return MemoryCardGridPlacement(column: 0, row: 0)
        }
        return MemoryCardGridPlacement(column: 0, row: last.placement.row + last.box.rowSpan)
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

    private static func isRowMajor(
        _ placement: MemoryCardGridPlacement,
        atOrAfter target: MemoryCardGridPlacement
    ) -> Bool {
        placement.row > target.row || (placement.row == target.row && placement.column >= target.column)
    }
}

private struct CardDebugGridOccupiedBox {
    let placement: MemoryCardGridPlacement
    let box: MemoryCardGridBox
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
