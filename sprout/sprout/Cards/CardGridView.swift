import SwiftUI

struct CardGridView: View {
    let items: [GridItem]

    @State private var containerWidth: CGFloat = 393

    private var layoutSignature: [String] {
        items.map {
            "\($0.recordID.uuidString)-\($0.projectionTargetType ?? "record")-\($0.projectionTargetID?.uuidString ?? "none")-\($0.columns)x\($0.units)-r\($0.rotationDegrees)-s\($0.scale)"
        }
    }

    var body: some View {
        let gridCols = GridConfig.adaptiveColumnCount(screenWidth: containerWidth)
        let gridWidth = GridConfig.gridWidth(screenWidth: containerWidth)

        StickerGridLayout(columns: gridCols) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                editableCard(item: item, index: index)
            }
        }
        .frame(width: gridWidth)
        .padding(.horizontal, GridConfig.horizontalPadding)
        .padding(.vertical, 20)
        .animation(.spring(duration: 0.38, bounce: 0.2), value: layoutSignature)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { containerWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in containerWidth = w }
            }
        )
    }

    @ViewBuilder
    private func editableCard(item: GridItem, index: Int) -> some View {
        let span = item.span
        CardContainerView(
            container: CardContainer(
                id: item.id,
                span: span,
                rotationDegrees: item.rotationDegrees,
                scale: item.scale,
                zIndex: item.zIndex,
                content: item.card
            )
        )
        .layoutValue(key: StickerGridSpanKey.self, value: span)
        .contentShape(RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius, style: .continuous))
        .contextMenu {
            ForEach(item.availableSpans, id: \.self) { span in
                Button {
                    item.onResize(span)
                } label: {
                    Label(
                        "\(span.widthColumns)×\(span.heightUnits)",
                        systemImage: item.span == span ? "checkmark.circle.fill" : "rectangle.expand.vertical"
                    )
                }
            }

            Divider()

            Button(role: .destructive) {
                item.onDelete()
            } label: {
                Label(localizedString("common.delete", default: "Delete"), systemImage: "trash")
            }
        }
    }
}

struct GridItem: Identifiable {
    let projectionTargetType: String?
    let projectionTargetID: UUID?
    let id: String
    let recordID: UUID
    let card: AnyView
    let columns: Int   // 2, 4, 6, 8
    let units: Int     // 1, 2, 4
    let zIndex: Int
    let rotationDegrees: Double
    let scale: Double
    let availableSpans: [ContainerSpan]
    let onResize: (ContainerSpan) -> Void
    let onDelete: () -> Void

    init(
        id: String = UUID().uuidString,
        projectionTargetType: String? = nil,
        projectionTargetID: UUID? = nil,
        recordID: UUID = UUID(),
        card: AnyView,
        columns: Int,
        units: Int,
        zIndex: Int = 0,
        rotationDegrees: Double? = nil,
        scale: Double? = nil,
        availableSpans: [ContainerSpan] = [],
        onResize: @escaping (ContainerSpan) -> Void = { _ in },
        onDelete: @escaping () -> Void = {}
    ) {
        self.id = id
        self.projectionTargetType = projectionTargetType
        self.projectionTargetID = projectionTargetID
        self.recordID = recordID
        self.card = card
        self.columns = columns
        self.units = units
        self.zIndex = zIndex
        self.rotationDegrees = rotationDegrees ?? stickerRotation(for: id)
        self.scale = scale ?? stickerScale(for: id)
        self.availableSpans = availableSpans.isEmpty
            ? [ContainerSpan(widthColumns: columns, heightUnits: units)]
            : availableSpans
        self.onResize = onResize
        self.onDelete = onDelete
    }

    var span: ContainerSpan {
        ContainerSpan(widthColumns: columns, heightUnits: units)
    }
}

#Preview {
    ScrollView(showsIndicators: false) {
        CardGridView(items: [
            GridItem(card: AnyView(QuoteCard()), columns: 4, units: 2, availableSpans: availableSpans(for: "quote"), onResize: { _ in }, onDelete: {}),
            GridItem(card: AnyView(WeatherCard()), columns: 4, units: 1, availableSpans: availableSpans(for: "weather"), onResize: { _ in }, onDelete: {}),
            GridItem(card: AnyView(ActivityCard()), columns: 4, units: 2, availableSpans: availableSpans(for: "activity"), onResize: { _ in }, onDelete: {}),
            GridItem(card: AnyView(MusicCard()), columns: 4, units: 1, availableSpans: availableSpans(for: "music"), onResize: { _ in }, onDelete: {}),
            GridItem(card: AnyView(EmotionCard()), columns: 4, units: 1, availableSpans: availableSpans(for: "emotion"), onResize: { _ in }, onDelete: {}),
            GridItem(card: AnyView(TodoCard()), columns: 4, units: 4, availableSpans: availableSpans(for: "todo"), onResize: { _ in }, onDelete: {}),
            GridItem(card: AnyView(PhotoCard()), columns: 4, units: 4, availableSpans: availableSpans(for: "photo"), onResize: { _ in }, onDelete: {}),
        ])
        .padding(.vertical, 20)
    }
}
