import SwiftUI

enum CardDebugGridBoardPlacementMode: String, CaseIterable, Identifiable {
    case storedPlacement = "Stored"
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
        guard let pinnedIndex = items.firstIndex(where: { $0.id == id }) else { return items }
        let placements = MemoryCardGridPacking.placements(
            for: items.map(\.size),
            pinned: [pinnedIndex: placement]
        )
        return items.enumerated().map { index, item in
            var item = item
            item.placement = placements[safe: index]
            return item
        }
    }

    static func commitPreview(_ items: [CardDebugGridBoardLabItem]) -> [CardDebugGridBoardLabItem] {
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
}

struct CardDebugGridBoardLabView: View {
    @State private var items = CardDebugGridBoardLabModel.defaultItems()
    @State private var placementMode: CardDebugGridBoardPlacementMode = .storedPlacement
    @State private var measuredContainerWidth: CGFloat = 0
    @State private var activeDragItemID: UUID?
    @State private var previewItems: [CardDebugGridBoardLabItem]?
    @State private var dragTargetPlacement: MemoryCardGridPlacement?

    private let boardCoordinateSpace = "CardDebugGridBoardLab.board"

    private var availableBoardWidth: CGFloat {
        measuredContainerWidth > 0 ? measuredContainerWidth : 390
    }

    private var containerWidth: CGFloat {
        MemoryDeskBoardMetrics.debugBoardWidth(for: availableBoardWidth)
    }

    private var metrics: MemoryDeskBoardMetrics {
        MemoryDeskBoardMetrics.debugSquare(availableWidth: availableBoardWidth)
    }

    private var isStoredModeInteractive: Bool {
        placementMode == .storedPlacement
    }

    private var displayedItems: [CardDebugGridBoardLabItem] {
        isStoredModeInteractive ? (previewItems ?? items) : items
    }

    private var slots: [CardDebugGridBoardLabSlot] {
        CardDebugGridBoardLabModel.slots(
            for: displayedItems,
            mode: placementMode,
            containerWidth: containerWidth,
            metrics: metrics
        )
    }

    private var report: CardDebugGridBoardLabReport {
        CardDebugGridBoardLabModel.report(
            for: displayedItems,
            mode: placementMode,
            containerWidth: containerWidth,
            metrics: metrics,
            activeDragTarget: dragTargetPlacement
        )
    }

    private var boardHeight: CGFloat {
        let maxY = slots.map(\.frame.maxY).max() ?? metrics.verticalPadding + metrics.rowHeight
        return max(metrics.verticalPadding * 2 + metrics.rowHeight, maxY + metrics.verticalPadding)
    }

    private var dragTargetSize: MemoryCardSizeToken? {
        guard let activeDragItemID else { return nil }
        return displayedItems.first(where: { $0.id == activeDragItemID })?.size
    }

    var body: some View {
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
        }
        .navigationTitle("Grid Board Lab")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDisabled(activeDragItemID != nil)
        .onChange(of: placementMode) { _, _ in
            resetDragState()
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Placement mode", selection: $placementMode) {
                ForEach(CardDebugGridBoardPlacementMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

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
        ZStack(alignment: .topLeading) {
            CardDebugGridOverlay(
                boardHeight: boardHeight,
                metrics: metrics,
                targetPlacement: dragTargetPlacement,
                targetSize: dragTargetSize
            )

            ForEach(slots) { slot in
                CardDebugGridBoardPlaceholderCard(
                    slot: slot,
                    isProblematic: report.overlapCount > 0 && placementMode == .nilPlacementFallback,
                    isDragging: activeDragItemID == slot.item.id,
                    isInteractive: isStoredModeInteractive,
                    onDelete: { delete(slot.item.id) },
                    onMoveEarlier: { move(slot.item.id, by: -1) },
                    onMoveLater: { move(slot.item.id, by: 1) },
                    onSetSize: { size in setSize(size, for: slot.item.id) }
                )
                .frame(width: slot.frame.width, height: slot.frame.height)
                .position(x: slot.frame.midX, y: slot.frame.midY)
                .zIndex(activeDragItemID == slot.item.id ? 10_000 : Double(slot.layout.zIndex))
                .simultaneousGesture(layoutDragGesture(for: slot))
                .animation(.spring(response: 0.28, dampingFraction: 0.86), value: slots)
            }
        }
        .coordinateSpace(name: boardCoordinateSpace)
        .frame(width: containerWidth, height: boardHeight, alignment: .topLeading)
        .background(Color(.secondarySystemBackground).opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateMeasuredWidth(proxy.size.width - 32)
                    }
                    .onChange(of: proxy.size.width) { _, newWidth in
                        updateMeasuredWidth(newWidth - 32)
                    }
            }
        }
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

    private func layoutDragGesture(for slot: CardDebugGridBoardLabSlot) -> some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(boardCoordinateSpace)))
            .onChanged { value in
                guard isStoredModeInteractive else { return }
                switch value {
                case .first(true):
                    beginDrag(slot)
                case .second(true, let drag?):
                    updateDrag(slot, at: drag.location)
                default:
                    break
                }
            }
            .onEnded { _ in
                guard isStoredModeInteractive else { return }
                commitDrag()
            }
    }

    private func beginDrag(_ slot: CardDebugGridBoardLabSlot) {
        guard activeDragItemID != slot.item.id else { return }
        activeDragItemID = slot.item.id
        let placement = slot.layout.gridPlacement ?? slot.item.placement ?? MemoryCardGridPlacement(column: 0, row: slot.layout.order)
        dragTargetPlacement = placement
        previewItems = CardDebugGridBoardLabModel.previewItems(
            dragging: slot.item.id,
            to: placement,
            in: items
        )
    }

    private func updateDrag(_ slot: CardDebugGridBoardLabSlot, at location: CGPoint) {
        guard activeDragItemID == slot.item.id else { return }
        let placement = CardDebugGridBoardLabModel.targetPlacement(
            for: location,
            itemSize: slot.item.size,
            boardWidth: containerWidth,
            metrics: metrics
        )
        guard placement != dragTargetPlacement else { return }
        dragTargetPlacement = placement
        previewItems = CardDebugGridBoardLabModel.previewItems(
            dragging: slot.item.id,
            to: placement,
            in: items
        )
    }

    private func commitDrag() {
        if let previewItems {
            items = CardDebugGridBoardLabModel.commitPreview(previewItems)
        }
        resetDragState()
    }

    private func resetDragState() {
        activeDragItemID = nil
        previewItems = nil
        dragTargetPlacement = nil
    }

    private func add(_ size: MemoryCardSizeToken) {
        resetDragState()
        var next = CardDebugGridBoardLabItem(
            id: UUID(),
            title: size.rawValue,
            size: size,
            recipe: CardDebugGridBoardLabModel.recipe(for: size)
        )
        items.append(next)
        items = CardDebugGridBoardLabModel.autoPacked(items)
        if let updated = items.last {
            next = updated
        }
        _ = next
    }

    private func delete(_ id: UUID) {
        resetDragState()
        items.removeAll { $0.id == id }
        items = CardDebugGridBoardLabModel.autoPacked(items)
    }

    private func move(_ id: UUID, by offset: Int) {
        resetDragState()
        guard let sourceIndex = items.firstIndex(where: { $0.id == id }) else { return }
        let targetIndex = sourceIndex + offset
        guard items.indices.contains(targetIndex) else { return }
        items.swapAt(sourceIndex, targetIndex)
        items = CardDebugGridBoardLabModel.autoPacked(items)
    }

    private func reorder(_ sourceID: UUID, before targetID: UUID) {
        resetDragState()
        guard let sourceIndex = items.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = items.firstIndex(where: { $0.id == targetID }) else {
            return
        }
        let moved = items.remove(at: sourceIndex)
        let adjustedTargetIndex = sourceIndex < targetIndex ? max(0, targetIndex - 1) : targetIndex
        items.insert(moved, at: adjustedTargetIndex)
        items = CardDebugGridBoardLabModel.autoPacked(items)
    }

    private func setSize(_ size: MemoryCardSizeToken, for id: UUID) {
        resetDragState()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].size = size
        items[index].recipe = CardDebugGridBoardLabModel.recipe(for: size)
        items[index].title = size.rawValue
        items = CardDebugGridBoardLabModel.autoPacked(items)
    }

    private func autoPack() {
        resetDragState()
        items = CardDebugGridBoardLabModel.autoPacked(items)
    }
}

private struct CardDebugGridOverlay: View {
    let boardHeight: CGFloat
    let metrics: MemoryDeskBoardMetrics
    let targetPlacement: MemoryCardGridPlacement?
    let targetSize: MemoryCardSizeToken?

    private var rowCount: Int {
        max(1, Int(ceil((boardHeight - metrics.verticalPadding * 2) / (metrics.rowHeight + metrics.rowSpacing))))
    }

    var body: some View {
        GeometryReader { proxy in
            let cellWidth = metrics.cellWidth(for: proxy.size.width)
            ZStack(alignment: .topLeading) {
                ForEach(0..<rowCount, id: \.self) { row in
                    ForEach(0..<MemoryCardRecipeLayoutPolicy.columnCount, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.7)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(.systemBackground).opacity(0.22))
                            )
                            .frame(width: cellWidth, height: metrics.rowHeight)
                            .position(
                                x: metrics.horizontalPadding + CGFloat(column) * (cellWidth + metrics.columnSpacing) + cellWidth / 2,
                                y: metrics.verticalPadding + CGFloat(row) * (metrics.rowHeight + metrics.rowSpacing) + metrics.rowHeight / 2
                            )
                    }
                }

                if let targetFrame = targetFrame(cellWidth: cellWidth) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.72), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        }
                        .frame(width: targetFrame.width, height: targetFrame.height)
                        .position(x: targetFrame.midX, y: targetFrame.midY)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func targetFrame(cellWidth: CGFloat) -> CGRect? {
        guard let targetPlacement, let targetSize else { return nil }
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: targetSize)
        let x = metrics.horizontalPadding + CGFloat(targetPlacement.column) * (cellWidth + metrics.columnSpacing)
        let y = metrics.verticalPadding + CGFloat(targetPlacement.row) * (metrics.rowHeight + metrics.rowSpacing)
        let width = CGFloat(box.columnSpan) * cellWidth + CGFloat(max(0, box.columnSpan - 1)) * metrics.columnSpacing
        let height = CGFloat(box.rowSpan) * metrics.rowHeight + CGFloat(max(0, box.rowSpan - 1)) * metrics.rowSpacing
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

private struct CardDebugGridBoardPlaceholderCard: View {
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
        .contextMenu {
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
        }
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
