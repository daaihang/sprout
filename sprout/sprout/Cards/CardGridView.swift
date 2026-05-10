import SwiftUI

struct CardGridView: View {
    let items: [GridItem]

    @State private var containerWidth: CGFloat = CardSize.defaultScreenWidth

    var body: some View {
        let unitW         = GridConfig.unitWidth(screenWidth: containerWidth)
        let spacing       = GridConfig.columnSpacing
        let gridCols      = GridConfig.adaptiveColumnCount(screenWidth: containerWidth)
        let waterfallCols = max(1, gridCols / 4)
        let colWidth      = unitW * 4 + spacing * 3

        WaterfallLayout(
            items: items,
            columnCount: waterfallCols,
            columnWidth: colWidth,
            unitWidth: unitW,
            spacing: spacing
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { containerWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in containerWidth = w }
            }
        )
    }
}

struct WaterfallLayout: View {
    let items: [GridItem]
    let columnCount: Int
    let columnWidth: CGFloat
    let unitWidth: CGFloat
    let spacing: CGFloat

    var body: some View {
        let positions = computePositions()

        ZStack(alignment: .topLeading) {
            ForEach(items.indices, id: \.self) { index in
                let pos = positions[index]
                items[index].card
                    .frame(width: columnWidth, height: pos.height)
                    .offset(x: pos.x, y: pos.y)
            }
        }
        .frame(width: totalWidth, height: computeTotalHeight(), alignment: .topLeading)
    }

    private var totalWidth: CGFloat {
        columnWidth * CGFloat(columnCount) + spacing * CGFloat(columnCount - 1)
    }

    private struct Position {
        var x: CGFloat
        var y: CGFloat
        var height: CGFloat
    }

    private func cardHeight(for item: GridItem) -> CGFloat {
        // 包含行间距：N 单位高度 = N×unitWidth + (N-1)×spacing
        // 使 N 张 4×1 叠放高度 = 一张 4×N 高度
        unitWidth * CGFloat(item.units) + spacing * CGFloat(item.units - 1)
    }

    private func computePositions() -> [Position] {
        var positions: [Position] = []
        var colHeights = Array(repeating: CGFloat(0), count: columnCount)

        for item in items {
            let col = colHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let h   = cardHeight(for: item)
            positions.append(Position(
                x: CGFloat(col) * (columnWidth + spacing),
                y: colHeights[col],
                height: h
            ))
            colHeights[col] += h + spacing
        }

        return positions
    }

    private func computeTotalHeight() -> CGFloat {
        var colHeights = Array(repeating: CGFloat(0), count: columnCount)

        for item in items {
            let col = colHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            colHeights[col] += cardHeight(for: item) + spacing
        }

        return (colHeights.max() ?? 0) - spacing
    }
}

struct GridItem: Identifiable {
    let id = UUID()
    let card: AnyView
    let columns: Int
    let units: Int
}

#Preview {
    ScrollView(showsIndicators: false) {
        CardGridView(items: [
            GridItem(card: AnyView(QuoteCard_4x2()),    columns: 4, units: 2),
            GridItem(card: AnyView(WeatherCard_4x1()),  columns: 4, units: 1),
            GridItem(card: AnyView(ActivityCard_4x2()), columns: 4, units: 2),
            GridItem(card: AnyView(MusicCard_4x1()),    columns: 4, units: 1),
            GridItem(card: AnyView(EmotionCard_4x1()),  columns: 4, units: 1),
            GridItem(card: AnyView(TodoCard_4x4()),     columns: 4, units: 4),
            GridItem(card: AnyView(PhotoCard_4x4()),    columns: 4, units: 4),
        ])
        .padding(.vertical, 20)
    }
}
