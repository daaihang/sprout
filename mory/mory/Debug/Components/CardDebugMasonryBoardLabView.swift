import SwiftUI

struct CardDebugMasonryBoardLabView: View {
    @State private var items = CardDebugMasonryBoardItem.defaultItems()
    @State private var measuredWidth: CGFloat = 0

    private let horizontalChromePadding: CGFloat = 20

    private var containerWidth: CGFloat {
        let measured = measuredWidth > 0 ? measuredWidth : 390
        return MemoryDeskBoardMetrics.debugBoardWidth(for: max(1, measured - horizontalChromePadding * 2))
    }

    private var effectiveMetrics: MemoryDeskBoardMetrics {
        MemoryDeskBoardMetrics.debugBoard(availableWidth: containerWidth)
    }

    private var plan: MoryMasonryLayoutPlan<UUID> {
        MoryMasonryLayoutPlan.make(
            nodes: items.map {
                MoryMasonryInputNode(
                    id: $0.id,
                    order: $0.order,
                    zIndex: $0.zIndex,
                    estimatedHeight: $0.height
                )
            },
            containerWidth: containerWidth,
            metrics: effectiveMetrics.masonry
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controls
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                board
                    .frame(maxWidth: .infinity)
                    .background(widthReader)

                report
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .navigationTitle("Masonry Board Lab")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                addItem()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            Button {
                items = CardDebugMasonryBoardItem.defaultItems()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .font(.caption.weight(.semibold))
    }

    private var board: some View {
        ZStack(alignment: .topLeading) {
            ForEach(plan.slots) { slot in
                if let item = items.first(where: { $0.id == slot.id }) {
                    CardDebugMasonryTile(item: item, slot: slot)
                        .frame(width: slot.frame.width, height: slot.frame.height)
                        .position(x: slot.frame.midX, y: slot.frame.midY)
                        .zIndex(Double(slot.zIndex))
                }
            }
        }
        .frame(width: containerWidth, height: plan.boardHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.45))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.secondary.opacity(0.18))
        }
        .padding(.horizontal, horizontalChromePadding)
    }

    private var report: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Report")
                .font(.headline)
            DebugValueRow(title: "Columns", value: "\(plan.columnSpec.columnCount)")
            DebugValueRow(title: "Column width", value: "\(Int(plan.columnSpec.columnWidth))")
            DebugValueRow(title: "Board height", value: "\(Int(plan.boardHeight))")
            DebugValueRow(title: "Sticker overflow", value: "\(Int(effectiveMetrics.masonry.stickerOverflow))")

            ForEach(plan.slots) { slot in
                if let item = items.first(where: { $0.id == slot.id }) {
                    Text("\(item.title) order=\(slot.order) column=\(slot.column) frame=(\(Int(slot.frame.minX)),\(Int(slot.frame.minY))) \(Int(slot.frame.width))x\(Int(slot.frame.height)) render=\(Int(slot.renderFrame.width))x\(Int(slot.renderFrame.height))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { updateWidth(proxy.size.width) }
                .onChange(of: proxy.size.width) { _, newWidth in updateWidth(newWidth) }
        }
    }

    private func updateWidth(_ width: CGFloat) {
        guard width.isFinite, width > 0, abs(width - measuredWidth) > 0.5 else { return }
        measuredWidth = width
    }

    private func addItem() {
        let order = items.count
        items.append(
            CardDebugMasonryBoardItem(
                title: "New \(order + 1)",
                subtitle: "ad hoc card",
                height: [96, 128, 168, 216][order % 4],
                order: order,
                zIndex: order,
                tint: [.orange, .blue, .purple, .green][order % 4]
            )
        )
    }
}

private struct CardDebugMasonryBoardItem: Identifiable {
    let id: UUID
    var title: String
    var subtitle: String
    var height: CGFloat
    var order: Int
    var zIndex: Int
    var tint: Color

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        height: CGFloat,
        order: Int,
        zIndex: Int,
        tint: Color
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.height = height
        self.order = order
        self.zIndex = zIndex
        self.tint = tint
    }

    static func defaultItems() -> [CardDebugMasonryBoardItem] {
        [
            CardDebugMasonryBoardItem(title: "Notebook", subtitle: "expanded body", height: 226, order: 0, zIndex: 0, tint: .brown),
            CardDebugMasonryBoardItem(title: "Photo", subtitle: "media evidence", height: 246, order: 1, zIndex: 1, tint: .pink),
            CardDebugMasonryBoardItem(title: "Music", subtitle: "compact context", height: 112, order: 2, zIndex: 2, tint: .indigo),
            CardDebugMasonryBoardItem(title: "Weather", subtitle: "context", height: 92, order: 3, zIndex: 3, tint: .cyan),
            CardDebugMasonryBoardItem(title: "Link", subtitle: "reference card", height: 156, order: 4, zIndex: 4, tint: .teal),
            CardDebugMasonryBoardItem(title: "Bundle", subtitle: "packet", height: 158, order: 5, zIndex: 5, tint: .orange),
        ]
    }
}

private struct CardDebugMasonryTile: View {
    let item: CardDebugMasonryBoardItem
    let slot: MoryMasonryLayoutSlot<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(item.tint)
                    .frame(width: 20, height: 20)
                Spacer()
                Text("#\(slot.order)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "sparkle")
                .font(.caption)
                .foregroundStyle(item.tint)
                .padding(6)
                .offset(x: 8, y: -8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(item.tint.opacity(0.22))
        }
    }
}
