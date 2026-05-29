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
        displacedPreview(dragging: id, to: placement, in: items)
    }

    static func previewItemsWithoutCompaction(
        dragging id: UUID,
        to placement: MemoryCardGridPlacement,
        in items: [CardDebugGridBoardLabItem]
    ) -> CardDebugGridDragPreview {
        displacedPreview(dragging: id, to: placement, in: items)
    }

    static func commitPreview(_ items: [CardDebugGridBoardLabItem]) -> [CardDebugGridBoardLabItem] {
        compactEmptyRows(items)
    }

    static func appendPlacement(
        for size: MemoryCardSizeToken,
        in items: [CardDebugGridBoardLabItem]
    ) -> MemoryCardGridPlacement {
        let occupied = items.compactMap(occupiedBox(for:))
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
        let preview = displacedPreview(dragging: id, to: placement, in: next)
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
        affectedItemIDs: [UUID] = []
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

    private static func displacedPreview(
        dragging id: UUID,
        to placement: MemoryCardGridPlacement,
        in items: [CardDebugGridBoardLabItem]
    ) -> CardDebugGridDragPreview {
        guard let dragged = items.first(where: { $0.id == id }) else {
            return CardDebugGridDragPreview(itemID: id, targetPlacement: placement, items: items, affectedItemIDs: [])
        }

        let target = clampedPlacement(placement, for: dragged.size)
        let nonDragged = items.filter { $0.id != id }
        let targetBox = MemoryCardRecipeLayoutPolicy.gridBox(for: dragged.size)
        let ordered = visualOrder(nonDragged)
        let firstCollisionIndex = ordered.firstIndex { item in
            guard let itemPlacement = item.placement else { return false }
            return gridRectsIntersect(
                lhsPlacement: target,
                lhsBox: targetBox,
                rhsPlacement: clampedPlacement(itemPlacement, for: item.size),
                rhsBox: MemoryCardRecipeLayoutPolicy.gridBox(for: item.size)
            )
        }

        guard let firstCollisionIndex else {
            let next = items.map { item -> CardDebugGridBoardLabItem in
                guard item.id == id else { return item }
                var item = item
                item.placement = target
                return item
            }
            return CardDebugGridDragPreview(
                itemID: id,
                targetPlacement: target,
                items: next,
                affectedItemIDs: [id]
            )
        }

        let anchors = Array(ordered.prefix(firstCollisionIndex))
        let displaced = Array(ordered.suffix(from: firstCollisionIndex))
        var occupied = anchors.compactMap(occupiedBox(for:))
        var placementsByID: [UUID: MemoryCardGridPlacement] = [:]
        anchors.forEach { item in
            if let placement = item.placement {
                placementsByID[item.id] = clampedPlacement(placement, for: item.size)
            }
        }

        placementsByID[id] = target
        occupied.append(CardDebugGridOccupiedBox(placement: target, box: targetBox))
        var cursor = nextCursor(after: target, size: dragged.size)
        var affectedIDs: [UUID] = [id]

        for item in displaced {
            let placement = firstAvailablePlacement(for: item.size, from: cursor, occupied: occupied)
            placementsByID[item.id] = placement
            occupied.append(CardDebugGridOccupiedBox(placement: placement, box: MemoryCardRecipeLayoutPolicy.gridBox(for: item.size)))
            cursor = nextCursor(after: placement, size: item.size)
            affectedIDs.append(item.id)
        }

        let next = items.map { item -> CardDebugGridBoardLabItem in
            var item = item
            if let placement = placementsByID[item.id] {
                item.placement = placement
            }
            return item
        }
        return CardDebugGridDragPreview(
            itemID: id,
            targetPlacement: target,
            items: next,
            affectedItemIDs: affectedIDs
        )
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
