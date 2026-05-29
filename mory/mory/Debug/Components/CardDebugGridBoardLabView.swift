import SwiftUI

struct CardDebugGridBoardLabView: View {
    @State private var items = CardDebugGridBoardLabModel.defaultItems()
    @State private var measuredContainerWidth: CGFloat = 0
    @State private var lastPreview: CardDebugGridDragPreview?

    private var availableBoardWidth: CGFloat {
        measuredContainerWidth > 0 ? measuredContainerWidth : 390
    }

    private var containerWidth: CGFloat {
        MemoryDeskBoardMetrics.debugBoardWidth(for: availableBoardWidth)
    }

    private var metrics: MemoryDeskBoardMetrics {
        MemoryDeskBoardMetrics.debugSquare(availableWidth: availableBoardWidth)
    }

    private var slots: [CardDebugGridBoardLabSlot] {
        CardDebugGridBoardLabModel.slots(
            for: items,
            mode: .storedPlacement,
            containerWidth: containerWidth,
            metrics: metrics
        )
    }

    private var report: CardDebugGridBoardLabReport {
        CardDebugGridBoardLabModel.report(
            for: items,
            mode: .storedPlacement,
            containerWidth: containerWidth,
            metrics: metrics,
            activeDragTarget: lastPreview?.targetPlacement,
            lastInsertionIndex: lastPreview?.insertionIndex,
            movedRange: lastPreview?.movedRange
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

            Text("UIKit owns scrolling, hit testing, reuse, and long-press lifting. Dragging uses an ordered sparse grid: the lifted card inserts into the visual sequence, later cards flow after it, and local holes are kept until Auto Pack.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Menu {
                    ForEach(MemoryCardSizeToken.allCases) { size in
                        Button(size.rawValue) {
                            items = CardDebugGridBoardLabModel.itemsAfterAdding(size: size, to: items)
                            lastPreview = nil
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Button {
                    items = CardDebugGridBoardLabModel.autoPacked(items)
                    lastPreview = nil
                } label: {
                    Label("Auto Pack", systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)

                Button {
                    items = CardDebugGridBoardLabModel.defaultItems()
                    lastPreview = nil
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    items = []
                    lastPreview = nil
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
            activeDragItemID: nil,
            activeDragTarget: lastPreview?.targetPlacement,
            overlapCount: report.overlapCount,
            onDragEnded: { preview in
                lastPreview = preview
                items = CardDebugGridBoardLabModel.commitPreview(preview.items)
            },
            onDelete: { id in
                items = CardDebugGridBoardLabModel.itemsAfterDeleting(id: id, from: items)
                lastPreview = nil
            },
            onMoveEarlier: { id in
                items = CardDebugGridBoardLabModel.itemsAfterMoving(id: id, by: -1, in: items)
                lastPreview = nil
            },
            onMoveLater: { id in
                items = CardDebugGridBoardLabModel.itemsAfterMoving(id: id, by: 1, in: items)
                lastPreview = nil
            },
            onSetSize: { id, size in
                items = CardDebugGridBoardLabModel.itemsAfterResizing(id: id, to: size, in: items)
                lastPreview = nil
            },
            onTogglePinned: { id in
                items = CardDebugGridBoardLabModel.itemsAfterTogglingPinned(id: id, in: items)
                lastPreview = nil
            },
            onToggleUserAdjusted: { id in
                items = CardDebugGridBoardLabModel.itemsAfterTogglingUserAdjusted(id: id, in: items)
                lastPreview = nil
            }
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
            DebugValueRow(title: "Insertion index", value: report.insertionIndexLabel)
            DebugValueRow(title: "Moved range", value: report.movedRangeLabel)
            DebugValueRow(title: "Rows", value: "\(report.rowCount)")
            DebugValueRow(title: "Cells", value: "\(report.occupiedCells)/\(report.totalCells)")
            DebugValueRow(title: "Holes", value: "\(report.holesCount)")
            DebugValueRow(title: "Auto Pack recoverable", value: "\(report.autoPackRecoverableHoles)")
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
                HStack(alignment: .firstTextBaseline) {
                    Text(slot.debugLine)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    if report.movedRange?.contains(report.slots.firstIndex(where: { $0.id == slot.id }) ?? -1) == true {
                        Text("moved")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
    }

    private func updateMeasuredWidth(_ width: CGFloat) {
        guard width.isFinite, width > 0, abs(width - measuredContainerWidth) > 0.5 else { return }
        measuredContainerWidth = width
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
    var onTogglePinned: () -> Void
    var onToggleUserAdjusted: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: slot.item.recipe.debugSymbolName)
                Text(slot.item.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text("\(slot.gridBox.columnSpan)x\(slot.gridBox.rowSpan)")
                    .font(.caption.monospaced())
                if slot.item.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.tint)
                }
                if slot.item.isUserAdjusted {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(.secondary)
                }
                if isInteractive {
                    actionMenu
                }
            }
            .font(.caption)

            Text(slot.layout.gridPlacement.map { "column \($0.column), row \($0.row)" } ?? "nil placement")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)

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
                .strokeBorder(
                    isProblematic ? Color.red.opacity(0.75) : Color.primary.opacity(0.16),
                    lineWidth: isProblematic ? 2 : 1
                )
        }
        .scaleEffect(isDragging ? 1.025 : 1)
        .opacity(isDragging ? 0.82 : 1)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private var actionMenu: some View {
        Menu {
            Button("Move Earlier", action: onMoveEarlier)
            Button("Move Later", action: onMoveLater)
            Button(slot.item.isPinned ? "Unpin" : "Pin", action: onTogglePinned)
            Button(slot.item.isUserAdjusted ? "Clear User Adjusted" : "Mark User Adjusted", action: onToggleUserAdjusted)
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
    var debugSymbolName: String {
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
