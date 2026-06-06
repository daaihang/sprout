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

    private var nilLegacyReport: CardDebugGridBoardLabReport {
        CardDebugGridBoardLabModel.report(
            for: items,
            mode: .nilPlacementFallback,
            containerWidth: containerWidth,
            metrics: metrics
        )
    }

    private var firstFitReport: CardDebugGridBoardLabReport {
        CardDebugGridBoardLabModel.report(
            for: items,
            mode: .firstFitEffectivePlacement,
            containerWidth: containerWidth,
            metrics: metrics
        )
    }

    private var boardHeight: CGFloat {
        let maxY = slots.map(\.renderFrame.maxY).max() ?? metrics.verticalPadding + metrics.rowHeight
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

            Text("UIKit owns scrolling, hit testing, reuse, and long-press lifting. Dragging uses the shared 4-column board engine: the active card moves to a clamped grid target, collisions are resolved by side-shift or push-down, and release applies vertical compact.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Menu {
                    ForEach(MemoryCardSizeToken.allCases) { size in
                        Menu(size.rawValue) {
                            ForEach(CardDebugVisualStyle.allCases) { style in
                                Button(style.label) {
                                    items = CardDebugGridBoardLabModel.itemsAfterAdding(
                                        size: size,
                                        style: style,
                                        to: items
                                    )
                                    lastPreview = nil
                                }
                            }
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
            onSetSize: { id, size in
                items = CardDebugGridBoardLabModel.itemsAfterResizing(id: id, to: size, in: items)
                lastPreview = nil
            },
            onSetStyle: { id, style in
                items = CardDebugGridBoardLabModel.itemsAfterSettingStyle(id: id, to: style, in: items)
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
            DebugValueRow(title: "Target key", value: report.insertionIndexLabel)
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
    var onSetSize: (MemoryCardSizeToken) -> Void
    var onSetStyle: (CardDebugVisualStyle) -> Void
    var onTogglePinned: () -> Void
    var onToggleUserAdjusted: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: slot.item.visual.symbolName)
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

            Text(slot.item.visual.style.label)
                .font(.caption2.weight(.semibold))
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
        .background(cardBackground)
        .overlay(cardStroke)
        .scaleEffect(isDragging ? 1.025 : 1)
        .opacity(isDragging ? 0.82 : 1)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private var actionMenu: some View {
        Menu {
            Button(slot.item.isPinned ? "Unpin" : "Pin", action: onTogglePinned)
            Button(slot.item.isUserAdjusted ? "Clear User Adjusted" : "Mark User Adjusted", action: onToggleUserAdjusted)
            Menu("Size") {
                ForEach(MemoryCardSizeToken.allCases) { size in
                    Button(size.rawValue) {
                        onSetSize(size)
                    }
                }
            }
            Menu("Style") {
                ForEach(CardDebugVisualStyle.allCases) { style in
                    Button(style.label) {
                        onSetStyle(style)
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

    @ViewBuilder
    private var cardBackground: some View {
        switch slot.item.visual.style {
        case .circleBadge, .moodCircle:
            Circle()
                .fill(backgroundStyle)
        case .capsule:
            Capsule(style: .continuous)
                .fill(backgroundStyle)
        case .emojiSticker, .borderlessCutout:
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 10,
                bottomTrailingRadius: 20,
                topTrailingRadius: 12,
                style: .continuous
            )
            .fill(backgroundStyle)
        case .paperNote:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(backgroundStyle)
        case .photoTile:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundStyle)
        case .memoryCard:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundStyle)
        }
    }

    @ViewBuilder
    private var cardStroke: some View {
        let color = isProblematic ? Color.red.opacity(0.75) : Color.primary.opacity(0.16)
        let lineWidth: CGFloat = isProblematic ? 2 : 1
        switch slot.item.visual.style {
        case .circleBadge, .moodCircle:
            Circle().strokeBorder(color, lineWidth: lineWidth)
        case .capsule:
            Capsule(style: .continuous).strokeBorder(color, lineWidth: lineWidth)
        case .emojiSticker, .borderlessCutout:
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 10,
                bottomTrailingRadius: 20,
                topTrailingRadius: 12,
                style: .continuous
            )
            .strokeBorder(color, lineWidth: lineWidth)
        case .paperNote:
            RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(color, lineWidth: lineWidth)
        case .photoTile:
            RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(color, lineWidth: lineWidth)
        case .memoryCard:
            RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(color, lineWidth: lineWidth)
        }
    }

    private var backgroundStyle: LinearGradient {
        let hue = Double(abs(slot.item.visual.tintSeed % 360)) / 360
        let color = Color(hue: hue, saturation: 0.58, brightness: 0.92)
        return LinearGradient(
            colors: [
                color.opacity(slot.item.visual.style == .borderlessCutout ? 0.08 : 0.24),
                Color(.systemBackground).opacity(slot.item.visual.style == .photoTile ? 0.76 : 0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct CardDebugGridBoardRenderedCellHost: View {
    let slot: CardDebugGridBoardLabSlot
    let isProblematic: Bool
    let isDragging: Bool
    let isInteractive: Bool
    var onDelete: () -> Void
    var onSetSize: (MemoryCardSizeToken) -> Void
    var onSetStyle: (CardDebugVisualStyle) -> Void
    var onTogglePinned: () -> Void
    var onToggleUserAdjusted: () -> Void

    var body: some View {
        let insets = slot.contentInsetsInRenderFrame
        ZStack(alignment: .topLeading) {
            CardDebugGridBoardPlaceholderCard(
                slot: slot,
                isProblematic: isProblematic,
                isDragging: isDragging,
                isInteractive: isInteractive,
                onDelete: onDelete,
                onSetSize: onSetSize,
                onSetStyle: onSetStyle,
                onTogglePinned: onTogglePinned,
                onToggleUserAdjusted: onToggleUserAdjusted
            )
            .frame(width: slot.gridFrame.width, height: slot.gridFrame.height, alignment: .topLeading)
            .offset(x: insets.leading, y: insets.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
