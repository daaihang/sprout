import SwiftUI

enum CardDebugGridBoardLabModel {
    private static let engine = MoryBoardLayoutEngine<UUID>()

    static func defaultItems() -> [CardDebugGridBoardLabItem] {
        autoPacked(
            MemoryCardSizeToken.allCases.enumerated().map { index, size in
                item(
                    title: size.rawValue,
                    size: size,
                    style: CardDebugVisualStyle.defaultStyle(for: size),
                    zIndex: index
                )
            }
        )
    }

    static func autoPacked(_ items: [CardDebugGridBoardLabItem]) -> [CardDebugGridBoardLabItem] {
        applyingLayouts(engine.autoPack(items.map(\.layout)), to: items)
    }

    static func orderedSparsePack(_ items: [CardDebugGridBoardLabItem]) -> [CardDebugGridBoardLabItem] {
        autoPacked(items)
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
        let target = clampedPlacement(placement, for: items.first(where: { $0.id == id })?.size ?? .stamp)
        let movedLayouts = engine.moveItem(
            id: id,
            to: target.boardGridPoint,
            in: items.map(\.layout)
        )
        let movedItems = applyingLayouts(movedLayouts, to: items)
        return CardDebugGridDragPreview(
            itemID: id,
            targetPlacement: target,
            insertionIndex: target.row * MemoryCardRecipeLayoutPolicy.columnCount + target.column,
            movedRange: changedRange(from: items, to: movedItems),
            items: movedItems
        )
    }

    static func previewItemsWithoutCompaction(
        dragging id: UUID,
        to placement: MemoryCardGridPlacement,
        in items: [CardDebugGridBoardLabItem]
    ) -> CardDebugGridDragPreview {
        previewItems(dragging: id, to: placement, in: items)
    }

    static func commitPreview(_ items: [CardDebugGridBoardLabItem]) -> [CardDebugGridBoardLabItem] {
        applyingLayouts(engine.compactVertically(items.map(\.layout)), to: items)
    }

    static func itemsAfterAdding(
        size: MemoryCardSizeToken,
        style: CardDebugVisualStyle = .memoryCard,
        to items: [CardDebugGridBoardLabItem]
    ) -> [CardDebugGridBoardLabItem] {
        let next = item(
            title: "\(style.label) \(size.rawValue)",
            size: size,
            style: style,
            zIndex: (items.map(\.layout.zIndex).max() ?? -1) + 1
        )
        let layouts = engine.placeNewItem(next.layout, in: items.map(\.layout))
        return applyingLayouts(layouts, to: items + [next])
    }

    static func itemsAfterDeleting(
        id: UUID,
        from items: [CardDebugGridBoardLabItem]
    ) -> [CardDebugGridBoardLabItem] {
        let remaining = items.filter { $0.id != id }
        return applyingLayouts(engine.compactVertically(remaining.map(\.layout)), to: remaining)
    }

    static func itemsAfterResizing(
        id: UUID,
        to size: MemoryCardSizeToken,
        in items: [CardDebugGridBoardLabItem]
    ) -> [CardDebugGridBoardLabItem] {
        var next = items
        guard let index = next.firstIndex(where: { $0.id == id }) else { return items }
        next[index].size = size
        next[index].title = "\(next[index].visual.style.label) \(size.rawValue)"
        let layouts = engine.resizeItem(id: id, to: size.boardGridSize, in: next.map(\.layout))
        return applyingLayouts(layouts, to: next)
    }

    static func itemsAfterSettingStyle(
        id: UUID,
        to style: CardDebugVisualStyle,
        in items: [CardDebugGridBoardLabItem]
    ) -> [CardDebugGridBoardLabItem] {
        items.map { item in
            guard item.id == id else { return item }
            var item = item
            item.visual.style = style
            item.visual.symbolName = style.symbolName
            item.title = "\(style.label) \(item.size.rawValue)"
            return item
        }
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
        applyingLayouts(engine.compactVertically(items.map(\.layout)), to: items)
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
                    MemoryCardLayoutToken(
                        order: index,
                        size: item.size,
                        gridPlacement: item.placement,
                        zIndex: item.layout.zIndex
                    )
                },
                containerWidth: containerWidth,
                metrics: metrics
            )
        case .firstFitEffectivePlacement:
            return plannedSlots(
                for: items,
                layouts: items.enumerated().map { index, item in
                    MemoryCardLayoutToken(order: index, size: item.size, zIndex: item.layout.zIndex)
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
        }
    }

    private static func item(
        title: String,
        size: MemoryCardSizeToken,
        style: CardDebugVisualStyle,
        zIndex: Int
    ) -> CardDebugGridBoardLabItem {
        let id = UUID()
        return CardDebugGridBoardLabItem(
            layout: MoryBoardLayoutItem(
                id: id,
                point: MoryBoardGridPoint(x: 0, y: 0),
                size: size.boardGridSize,
                zIndex: zIndex
            ),
            visual: CardDebugVisualDescriptor(
                style: style,
                title: title,
                tintSeed: id.stableDebugTintSeed
            )
        )
    }

    private static func applyingLayouts(
        _ layouts: [MoryBoardLayoutItem<UUID>],
        to items: [CardDebugGridBoardLabItem]
    ) -> [CardDebugGridBoardLabItem] {
        let layoutByID = Dictionary(uniqueKeysWithValues: layouts.map { ($0.id, $0) })
        return items.map { item in
            guard let layout = layoutByID[item.id] else { return item }
            var item = item
            item.layout = layout
            return item
        }
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
            let layout = MemoryCardLayoutToken(
                order: index,
                size: item.size,
                gridPlacement: MemoryCardGridPlacement(
                    column: index % MemoryCardRecipeLayoutPolicy.columnCount,
                    row: index / MemoryCardRecipeLayoutPolicy.columnCount
                ),
                zIndex: item.layout.zIndex
            )
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

    private static func clampedPlacement(
        _ placement: MemoryCardGridPlacement,
        for size: MemoryCardSizeToken
    ) -> MemoryCardGridPlacement {
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
        let maxColumn = max(0, MemoryCardRecipeLayoutPolicy.columnCount - box.columnSpan)
        return MemoryCardGridPlacement(column: min(max(0, placement.column), maxColumn), row: max(0, placement.row))
    }
}

private extension MemoryCardGridPlacement {
    var boardGridPoint: MoryBoardGridPoint {
        MoryBoardGridPoint(x: column, y: row)
    }
}

private extension UUID {
    var stableDebugTintSeed: Int {
        uuidString.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31) &+ Int(scalar.value)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
