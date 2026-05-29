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
        metrics: MemoryDeskBoardMetrics = .default
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

    private let metrics = MemoryDeskBoardMetrics.default

    private var containerWidth: CGFloat {
        measuredContainerWidth > 0 ? measuredContainerWidth : 390
    }

    private var slots: [CardDebugGridBoardLabSlot] {
        CardDebugGridBoardLabModel.slots(
            for: items,
            mode: placementMode,
            containerWidth: containerWidth,
            metrics: metrics
        )
    }

    private var report: CardDebugGridBoardLabReport {
        CardDebugGridBoardLabModel.report(
            for: items,
            mode: placementMode,
            containerWidth: containerWidth,
            metrics: metrics
        )
    }

    private var boardHeight: CGFloat {
        let maxY = slots.map(\.frame.maxY).max() ?? metrics.verticalPadding + metrics.rowHeight
        return max(metrics.verticalPadding * 2 + metrics.rowHeight, maxY + metrics.verticalPadding)
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
            CardDebugGridOverlay(boardHeight: boardHeight, metrics: metrics)

            ForEach(slots) { slot in
                CardDebugGridBoardPlaceholderCard(
                    slot: slot,
                    isProblematic: report.overlapCount > 0 && placementMode == .nilPlacementFallback,
                    onDelete: { delete(slot.item.id) },
                    onMoveEarlier: { move(slot.item.id, by: -1) },
                    onMoveLater: { move(slot.item.id, by: 1) },
                    onSetSize: { size in setSize(size, for: slot.item.id) }
                )
                .frame(width: slot.frame.width, height: slot.frame.height)
                .position(x: slot.frame.midX, y: slot.frame.midY)
                .zIndex(Double(slot.layout.zIndex))
                .draggable(slot.item.id.uuidString)
                .dropDestination(for: String.self) { droppedIDs, _ in
                    guard let rawID = droppedIDs.first,
                          let sourceID = UUID(uuidString: rawID),
                          sourceID != slot.item.id else {
                        return false
                    }
                    reorder(sourceID, before: slot.item.id)
                    return true
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: boardHeight, maxHeight: boardHeight, alignment: .topLeading)
        .background(Color(.secondarySystemBackground).opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            DebugValueRow(title: "Mode", value: placementMode.rawValue)
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

    private func add(_ size: MemoryCardSizeToken) {
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
        items.removeAll { $0.id == id }
        items = CardDebugGridBoardLabModel.autoPacked(items)
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let sourceIndex = items.firstIndex(where: { $0.id == id }) else { return }
        let targetIndex = sourceIndex + offset
        guard items.indices.contains(targetIndex) else { return }
        items.swapAt(sourceIndex, targetIndex)
        items = CardDebugGridBoardLabModel.autoPacked(items)
    }

    private func reorder(_ sourceID: UUID, before targetID: UUID) {
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
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].size = size
        items[index].recipe = CardDebugGridBoardLabModel.recipe(for: size)
        items[index].title = size.rawValue
        items = CardDebugGridBoardLabModel.autoPacked(items)
    }

    private func autoPack() {
        items = CardDebugGridBoardLabModel.autoPacked(items)
    }
}

private struct CardDebugGridOverlay: View {
    let boardHeight: CGFloat
    let metrics: MemoryDeskBoardMetrics

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
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CardDebugGridBoardPlaceholderCard: View {
    let slot: CardDebugGridBoardLabSlot
    let isProblematic: Bool
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

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isProblematic ? Color.red.opacity(0.75) : Color.primary.opacity(0.16), lineWidth: isProblematic ? 2 : 1)
        }
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
