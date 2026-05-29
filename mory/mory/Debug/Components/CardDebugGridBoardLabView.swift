import SwiftUI

enum CardDebugGridBoardPlacementMode: String, CaseIterable, Identifiable {
    case storedPlacement = "Stored Interactive"
    case nilPlacementFallback = "Nil Legacy"
    case firstFitEffectivePlacement = "First Fit"

    var id: String { rawValue }
}

struct CardDebugGridBoardLabItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var size: MemoryCardSizeToken
    var recipe: MemoryCardVisualRecipe
    var placement: MemoryCardGridPlacement?
}

struct CardDebugGridBoardLabSlot: Identifiable, Hashable {
    let id: UUID
    let item: CardDebugGridBoardLabItem
    let layout: MemoryCardLayoutToken
    let frame: CGRect

    var gridBox: MemoryCardGridBox {
        MemoryCardRecipeLayoutPolicy.gridBox(for: layout.size)
    }

    var cells: [CardDebugGridCell] {
        guard let placement = layout.gridPlacement else { return [] }
        var cells: [CardDebugGridCell] = []
        for row in placement.row..<(placement.row + gridBox.rowSpan) {
            for column in placement.column..<(placement.column + gridBox.columnSpan) {
                cells.append(CardDebugGridCell(column: column, row: row))
            }
        }
        return cells
    }

    var gridOverflow: Bool {
        guard let placement = layout.gridPlacement else { return false }
        return placement.column + gridBox.columnSpan > MemoryCardRecipeLayoutPolicy.columnCount
    }

    var debugLine: String {
        let placement = layout.gridPlacement.map { "c\($0.column)r\($0.row)" } ?? "nil"
        return "\(item.title) \(layout.size.rawValue) \(placement) \(gridBox.columnSpan)x\(gridBox.rowSpan) frame=\(Int(frame.width))x\(Int(frame.height))"
    }
}

struct CardDebugGridBoardLabReport: Hashable {
    let projectionMode: CardDebugGridBoardPlacementMode
    let boardWidth: CGFloat
    let cellSize: CGFloat
    let activeDragTarget: MemoryCardGridPlacement?
    let rowCount: Int
    let occupiedCells: Int
    let totalCells: Int
    let density: Double
    let overlapCount: Int
    let gridOverflowCount: Int
    let slots: [CardDebugGridBoardLabSlot]

    var densityLabel: String {
        "\(Int((density * 100).rounded()))%"
    }

    var activeDragTargetLabel: String {
        activeDragTarget.map { "c\($0.column) r\($0.row)" } ?? "none"
    }
}

struct CardDebugGridDragPreview: Hashable {
    let itemID: UUID
    let targetPlacement: MemoryCardGridPlacement
    let items: [CardDebugGridBoardLabItem]
}

struct CardDebugGridUIKitDragSession: Hashable {
    let itemID: UUID
    let itemSize: MemoryCardSizeToken
}

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

    static func previewItems(
        dragging id: UUID,
        to placement: MemoryCardGridPlacement,
        in items: [CardDebugGridBoardLabItem]
    ) -> [CardDebugGridBoardLabItem] {
        collisionResolvedItems(items, pinnedID: id, pinnedPlacement: placement)
    }

    static func dragPreview(
        dragging id: UUID,
        at location: CGPoint,
        itemSize: MemoryCardSizeToken,
        boardWidth: CGFloat,
        metrics: MemoryDeskBoardMetrics,
        in items: [CardDebugGridBoardLabItem]
    ) -> CardDebugGridDragPreview {
        let target = targetPlacement(
            for: location,
            itemSize: itemSize,
            boardWidth: boardWidth,
            metrics: metrics
        )
        let preview = previewItems(
            dragging: id,
            to: target,
            in: items
        )
        let effectiveTarget = preview.first(where: { $0.id == id })?.placement ?? target
        return CardDebugGridDragPreview(
            itemID: id,
            targetPlacement: effectiveTarget,
            items: preview
        )
    }

    static func commitPreview(_ items: [CardDebugGridBoardLabItem]) -> [CardDebugGridBoardLabItem] {
        items
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
            itemSize: slot.item.size
        )
    }

    static func dragPreview(
        for session: CardDebugGridUIKitDragSession,
        at location: CGPoint,
        boardWidth: CGFloat,
        metrics: MemoryDeskBoardMetrics,
        in items: [CardDebugGridBoardLabItem]
    ) -> CardDebugGridDragPreview {
        dragPreview(
            dragging: session.itemID,
            at: location,
            itemSize: session.itemSize,
            boardWidth: boardWidth,
            metrics: metrics,
            in: items
        )
    }

    static func appendPlacement(
        for size: MemoryCardSizeToken,
        in items: [CardDebugGridBoardLabItem]
    ) -> MemoryCardGridPlacement {
        let bottomRow = items.compactMap { item -> Int? in
            guard let placement = item.placement else { return nil }
            return placement.row + MemoryCardRecipeLayoutPolicy.gridBox(for: item.size).rowSpan
        }
        .max() ?? 0
        let occupied = items.compactMap { item -> CardDebugGridOccupiedBox? in
            guard let placement = item.placement else { return nil }
            return CardDebugGridOccupiedBox(
                placement: clampedPlacement(placement, for: item.size),
                box: MemoryCardRecipeLayoutPolicy.gridBox(for: item.size)
            )
        }
        return nearestAvailablePlacement(
            for: size,
            from: MemoryCardGridPlacement(column: 0, row: bottomRow),
            occupied: occupied
        )
    }

    static func collisionResolvedItems(
        _ items: [CardDebugGridBoardLabItem],
        pinnedID: UUID? = nil,
        pinnedPlacement: MemoryCardGridPlacement? = nil
    ) -> [CardDebugGridBoardLabItem] {
        guard !items.isEmpty else { return [] }
        let pinnedIndex = pinnedID.flatMap { id in items.firstIndex(where: { $0.id == id }) }
        let next = items
        var resolvedPlacements = Array<MemoryCardGridPlacement?>(repeating: nil, count: items.count)
        var occupied: [CardDebugGridOccupiedBox] = []

        if let pinnedIndex {
            let pinnedItem = next[pinnedIndex]
            let pinnedDesired = desiredPlacement(
                for: pinnedItem,
                index: pinnedIndex,
                pinnedIndex: pinnedIndex,
                pinnedPlacement: pinnedPlacement
            )
            resolvedPlacements[pinnedIndex] = pinnedDesired
            occupied.append(CardDebugGridOccupiedBox(placement: pinnedDesired, box: MemoryCardRecipeLayoutPolicy.gridBox(for: pinnedItem.size)))

            var deferredIndices: [Int] = []
            for index in 0..<items.count where index != pinnedIndex {
                let item = next[index]
                let desired = desiredPlacement(
                    for: item,
                    index: index,
                    pinnedIndex: pinnedIndex,
                    pinnedPlacement: pinnedPlacement
                )
                let box = MemoryCardRecipeLayoutPolicy.gridBox(for: item.size)
                if intersectsAny(box: box, placement: desired, occupied: occupied) {
                    deferredIndices.append(index)
                } else {
                    resolvedPlacements[index] = desired
                    occupied.append(CardDebugGridOccupiedBox(placement: desired, box: box))
                }
            }

            for index in deferredIndices {
                let item = next[index]
                let desired = desiredPlacement(
                    for: item,
                    index: index,
                    pinnedIndex: pinnedIndex,
                    pinnedPlacement: pinnedPlacement
                )
                let placement = nearestAvailablePlacement(
                    for: item.size,
                    from: desired,
                    occupied: occupied
                )
                resolvedPlacements[index] = placement
                occupied.append(CardDebugGridOccupiedBox(placement: placement, box: MemoryCardRecipeLayoutPolicy.gridBox(for: item.size)))
            }

            return next.enumerated().map { index, item in
                var item = item
                item.placement = resolvedPlacements[index]
                return item
            }
            .compactingEmptyRows()
        }

        let orderedIndices = collisionResolutionOrder(itemCount: items.count, pinnedIndex: pinnedIndex)

        for index in orderedIndices {
            let item = next[index]
            let desired = desiredPlacement(
                for: item,
                index: index,
                pinnedIndex: pinnedIndex,
                pinnedPlacement: pinnedPlacement
            )
            let placement = nearestAvailablePlacement(
                for: item.size,
                from: desired,
                occupied: occupied
            )
            resolvedPlacements[index] = placement
            occupied.append(CardDebugGridOccupiedBox(placement: placement, box: MemoryCardRecipeLayoutPolicy.gridBox(for: item.size)))
        }

        return next.enumerated().map { index, item in
            var item = item
            item.placement = resolvedPlacements[index]
            return item
        }
        .compactingEmptyRows()
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
        activeDragTarget: MemoryCardGridPlacement? = nil
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

    private static func collisionResolutionOrder(itemCount: Int, pinnedIndex: Int?) -> [Int] {
        guard let pinnedIndex, pinnedIndex >= 0, pinnedIndex < itemCount else {
            return Array(0..<itemCount)
        }
        return [pinnedIndex] + Array(0..<itemCount).filter { $0 != pinnedIndex }
    }

    private static func desiredPlacement(
        for item: CardDebugGridBoardLabItem,
        index: Int,
        pinnedIndex: Int?,
        pinnedPlacement: MemoryCardGridPlacement?
    ) -> MemoryCardGridPlacement {
        if index == pinnedIndex, let pinnedPlacement {
            return clampedPlacement(pinnedPlacement, for: item.size)
        }
        if let placement = item.placement {
            return clampedPlacement(placement, for: item.size)
        }
        return MemoryCardGridPlacement(column: 0, row: max(0, index))
    }

    private static func nearestAvailablePlacement(
        for size: MemoryCardSizeToken,
        from desired: MemoryCardGridPlacement,
        occupied: [CardDebugGridOccupiedBox]
    ) -> MemoryCardGridPlacement {
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
        let maxColumn = max(0, MemoryCardRecipeLayoutPolicy.columnCount - box.columnSpan)
        let preferredColumn = min(max(0, desired.column), maxColumn)
        let preferredRow = max(0, desired.row)
        var radius = 0

        while true {
            let minRow = max(0, preferredRow - radius)
            let maxRow = preferredRow + radius
            let candidates = (minRow...maxRow).flatMap { row in
                (0...maxColumn).compactMap { column -> MemoryCardGridCandidate? in
                    let distance = abs(row - preferredRow) + abs(column - preferredColumn)
                    guard distance == radius else { return nil }
                    return MemoryCardGridCandidate(
                        placement: MemoryCardGridPlacement(column: column, row: row),
                        preferredColumn: preferredColumn,
                        preferredRow: preferredRow
                    )
                }
            }
            .sorted()

            for candidate in candidates {
                guard !intersectsAny(box: box, placement: candidate.placement, occupied: occupied) else {
                    continue
                }
                return candidate.placement
            }

            radius += 1
        }
    }

    private static func clampedPlacement(
        _ placement: MemoryCardGridPlacement,
        for size: MemoryCardSizeToken
    ) -> MemoryCardGridPlacement {
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
        let maxColumn = max(0, MemoryCardRecipeLayoutPolicy.columnCount - box.columnSpan)
        return MemoryCardGridPlacement(column: min(max(0, placement.column), maxColumn), row: max(0, placement.row))
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

private struct MemoryCardGridCandidate: Comparable {
    let placement: MemoryCardGridPlacement
    private let preferredColumn: Int
    private let preferredRow: Int

    init(placement: MemoryCardGridPlacement, preferredColumn: Int, preferredRow: Int) {
        self.placement = placement
        self.preferredColumn = preferredColumn
        self.preferredRow = preferredRow
    }

    static func < (lhs: MemoryCardGridCandidate, rhs: MemoryCardGridCandidate) -> Bool {
        lhs.sortKey.lexicographicallyPrecedes(rhs.sortKey)
    }

    static func == (lhs: MemoryCardGridCandidate, rhs: MemoryCardGridCandidate) -> Bool {
        lhs.sortKey == rhs.sortKey
    }

    private var sortKey: [Int] {
        let verticalDistance = abs(placement.row - preferredRow)
        let horizontalDistance = abs(placement.column - preferredColumn)
        return [
            verticalDistance + horizontalDistance,
            placement.row == preferredRow ? 0 : 1,
            placement.column == preferredColumn ? 0 : 1,
            verticalDistance,
            horizontalDistance,
            placement.row,
            placement.column
        ]
    }
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

struct CardDebugGridBoardLabView: View {
    @State private var items = CardDebugGridBoardLabModel.defaultItems()
    @State private var measuredContainerWidth: CGFloat = 0
    @State private var activeDragPreview: CardDebugGridDragPreview?

    private var availableBoardWidth: CGFloat {
        measuredContainerWidth > 0 ? measuredContainerWidth : 390
    }

    private var containerWidth: CGFloat {
        MemoryDeskBoardMetrics.debugBoardWidth(for: availableBoardWidth)
    }

    private var metrics: MemoryDeskBoardMetrics {
        MemoryDeskBoardMetrics.debugSquare(availableWidth: availableBoardWidth)
    }

    private var displayedItems: [CardDebugGridBoardLabItem] {
        activeDragPreview?.items ?? items
    }

    private var activeDragItemID: UUID? {
        activeDragPreview?.itemID
    }

    private var dragTargetPlacement: MemoryCardGridPlacement? {
        activeDragPreview?.targetPlacement
    }

    private var slots: [CardDebugGridBoardLabSlot] {
        CardDebugGridBoardLabModel.slots(
            for: displayedItems,
            mode: .storedPlacement,
            containerWidth: containerWidth,
            metrics: metrics
        )
    }

    private var report: CardDebugGridBoardLabReport {
        CardDebugGridBoardLabModel.report(
            for: displayedItems,
            mode: .storedPlacement,
            containerWidth: containerWidth,
            metrics: metrics,
            activeDragTarget: dragTargetPlacement
        )
    }

    private var nilProjectionItems: [CardDebugGridBoardLabItem] {
        items.map { item in
            var item = item
            item.placement = nil
            return item
        }
    }

    private var nilLegacyReport: CardDebugGridBoardLabReport {
        CardDebugGridBoardLabModel.report(
            for: nilProjectionItems,
            mode: .nilPlacementFallback,
            containerWidth: containerWidth,
            metrics: metrics
        )
    }

    private var firstFitReport: CardDebugGridBoardLabReport {
        CardDebugGridBoardLabModel.report(
            for: nilProjectionItems,
            mode: .firstFitEffectivePlacement,
            containerWidth: containerWidth,
            metrics: metrics
        )
    }

    private var boardHeight: CGFloat {
        let maxY = slots.map(\.frame.maxY).max() ?? metrics.verticalPadding + metrics.rowHeight
        return max(metrics.verticalPadding * 2 + metrics.rowHeight, maxY + metrics.verticalPadding)
    }

    private var boardViewportHeight: CGFloat {
        min(max(boardHeight, 360), 560)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    controls
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    board

                    reportSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear {
                updateMeasuredWidth(proxy.size.width - 32)
            }
            .onChange(of: proxy.size.width) { _, newWidth in
                updateMeasuredWidth(newWidth - 32)
            }
        }
        .navigationTitle("Grid Board Lab")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Stored Interactive", systemImage: "hand.draw")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("UIKit owns scrolling, hit testing, and long-press dragging. Long press a card to lift it, then drag to a grid cell; other cards keep their positions unless they collide. Auto Pack is the explicit full tidy action.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Menu {
                    ForEach(MemoryCardSizeToken.allCases) { size in
                        Button(size.rawValue) {
                            add(size)
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Button {
                    autoPack()
                } label: {
                    Label("Auto Pack", systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)

                Button {
                    items = CardDebugGridBoardLabModel.defaultItems()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    items = []
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .font(.caption.weight(.semibold))
        }
    }

    private var board: some View {
        CardDebugGridBoardUIKitView(
            slots: slots,
            storedItems: items,
            containerWidth: containerWidth,
            boardHeight: boardHeight,
            metrics: metrics,
            activeDragItemID: activeDragItemID,
            activeDragTarget: dragTargetPlacement,
            overlapCount: report.overlapCount,
            onPreviewChanged: { preview in
                activeDragPreview = preview
            },
            onDragEnded: { preview in
                items = CardDebugGridBoardLabModel.commitPreview(preview.items)
                activeDragPreview = nil
            },
            onDragCancelled: {
                activeDragPreview = nil
            },
            onDelete: { id in delete(id) },
            onMoveEarlier: { id in move(id, by: -1) },
            onMoveLater: { id in move(id, by: 1) },
            onSetSize: { id, size in setSize(size, for: id) }
        )
        .frame(width: containerWidth, height: boardViewportHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
    }

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Occupancy")
                .font(.headline)
            DebugValueRow(title: "Mode", value: report.projectionMode.rawValue)
            DebugValueRow(title: "Board width", value: "\(Int(report.boardWidth.rounded()))")
            DebugValueRow(title: "Cell size", value: "\(Int(report.cellSize.rounded()))")
            DebugValueRow(title: "Drag target", value: report.activeDragTargetLabel)
            DebugValueRow(title: "Rows", value: "\(report.rowCount)")
            DebugValueRow(title: "Cells", value: "\(report.occupiedCells)/\(report.totalCells)")
            DebugValueRow(title: "Density", value: report.densityLabel)
            DebugValueRow(title: "Overlaps", value: "\(report.overlapCount)")
            DebugValueRow(title: "Grid overflows", value: "\(report.gridOverflowCount)")

            DisclosureGroup("Projection Diagnostics") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Read-only reports for nil placements. They are not interaction modes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DebugValueRow(title: "Nil Legacy overlaps", value: "\(nilLegacyReport.overlapCount)")
                    DebugValueRow(title: "First Fit overlaps", value: "\(firstFitReport.overlapCount)")
                    DebugValueRow(title: "First Fit rows", value: "\(firstFitReport.rowCount)")
                }
                .padding(.top, 6)
            }
            .font(.caption.weight(.semibold))

            Divider()

            ForEach(report.slots) { slot in
                Text(slot.debugLine)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func updateMeasuredWidth(_ width: CGFloat) {
        guard width.isFinite, width > 0, abs(width - measuredContainerWidth) > 0.5 else { return }
        measuredContainerWidth = width
    }

    private func add(_ size: MemoryCardSizeToken) {
        activeDragPreview = nil
        let id = UUID()
        let next = CardDebugGridBoardLabItem(
            id: id,
            title: size.rawValue,
            size: size,
            recipe: CardDebugGridBoardLabModel.recipe(for: size),
            placement: CardDebugGridBoardLabModel.appendPlacement(for: size, in: items)
        )
        items.append(next)
        items = CardDebugGridBoardLabModel.collisionResolvedItems(
            items,
            pinnedID: id,
            pinnedPlacement: next.placement
        )
    }

    private func delete(_ id: UUID) {
        activeDragPreview = nil
        items.removeAll { $0.id == id }
        items = CardDebugGridBoardLabModel.compactEmptyRows(items)
    }

    private func move(_ id: UUID, by offset: Int) {
        activeDragPreview = nil
        guard let sourceIndex = items.firstIndex(where: { $0.id == id }) else { return }
        let targetIndex = sourceIndex + offset
        guard items.indices.contains(targetIndex) else { return }
        items.swapAt(sourceIndex, targetIndex)
    }

    private func setSize(_ size: MemoryCardSizeToken, for id: UUID) {
        activeDragPreview = nil
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].size = size
        items[index].recipe = CardDebugGridBoardLabModel.recipe(for: size)
        items[index].title = size.rawValue
        let placement = items[index].placement ?? MemoryCardGridPlacement(column: 0, row: index)
        items = CardDebugGridBoardLabModel.collisionResolvedItems(
            items,
            pinnedID: id,
            pinnedPlacement: placement
        )
    }

    private func autoPack() {
        activeDragPreview = nil
        items = CardDebugGridBoardLabModel.autoPacked(items)
    }
}

struct CardDebugGridBoardPlaceholderCard: View {
    let slot: CardDebugGridBoardLabSlot
    let isProblematic: Bool
    let isDragging: Bool
    let isInteractive: Bool
    var onDelete: () -> Void
    var onMoveEarlier: () -> Void
    var onMoveLater: () -> Void
    var onSetSize: (MemoryCardSizeToken) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: slot.item.recipe.symbolName)
                Text(slot.item.title)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(slot.gridBox.columnSpan)x\(slot.gridBox.rowSpan)")
                    .font(.caption.monospaced())
                if isInteractive {
                    actionMenu
                }
            }
            .font(.caption)

            Text(slot.layout.gridPlacement.map { "column \($0.column), row \($0.row)" } ?? "nil placement")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

            if !isInteractive {
                Text("read-only projection")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isProblematic ? Color.red.opacity(0.75) : Color.primary.opacity(0.16), lineWidth: isProblematic ? 2 : 1)
        }
        .scaleEffect(isDragging ? 1.025 : 1)
        .opacity(isDragging ? 0.82 : 1)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private var actionMenu: some View {
        Menu {
            Button("Move Earlier", action: onMoveEarlier)
            Button("Move Later", action: onMoveLater)
            Menu("Size") {
                ForEach(MemoryCardSizeToken.allCases) { size in
                    Button(size.rawValue) {
                        onSetSize(size)
                    }
                }
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Card actions")
    }

    private var cardBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.18),
                Color(.systemBackground).opacity(0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension MemoryCardVisualRecipe {
    var symbolName: String {
        switch self {
        case .notebook:
            return "note.text"
        case .polaroid:
            return "photo"
        case .filmFrame:
            return "film"
        case .livePhotoPrint:
            return "livephoto"
        case .cassette:
            return "waveform"
        case .vinyl:
            return "music.note"
        case .mapTicket:
            return "map"
        case .weatherStamp:
            return "cloud.sun"
        case .linkNote:
            return "link"
        case .taskNote:
            return "checklist"
        case .personCard:
            return "person.crop.rectangle"
        case .affectCard:
            return "heart.text.square"
        case .bundlePacket:
            return "shippingbox"
        case .statusNote:
            return "info.circle"
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
