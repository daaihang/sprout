import SwiftUI

struct HomeBoardMasonryLayout: Layout {
    var metrics: MoryMasonryMetrics

    init(metrics: MoryMasonryMetrics = .default) {
        self.metrics = metrics
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? fallbackWidth
        let placements = measuredPlacements(in: CGRect(origin: .zero, size: CGSize(width: width, height: 0)), subviews: subviews)
        let height = placements.map(\.frame.maxY).max().map { $0 + metrics.verticalPadding } ?? 0
        return CGSize(width: width, height: max(metrics.verticalPadding * 2, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placements = measuredPlacements(in: bounds, subviews: subviews)
        for placement in placements {
            guard subviews.indices.contains(placement.index) else { continue }
            subviews[placement.index].place(
                at: CGPoint(x: placement.frame.minX, y: placement.frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: placement.frame.width, height: placement.frame.height)
            )
        }
    }

    private var fallbackWidth: CGFloat {
        metrics.horizontalPadding * 2 + metrics.minColumnWidth
    }

    private func measuredPlacements(in bounds: CGRect, subviews: Subviews) -> [Placement] {
        let spec = MoryMasonryLayoutPlan<String>.columnSpec(containerWidth: bounds.width, metrics: metrics)
        var columnHeights = Array(repeating: bounds.minY + metrics.verticalPadding, count: spec.columnCount)
        var placements: [Placement] = []

        for index in subviews.indices {
            let column = columnHeights.indices.min { lhs, rhs in
                if columnHeights[lhs] == columnHeights[rhs] {
                    return lhs < rhs
                }
                return columnHeights[lhs] < columnHeights[rhs]
            } ?? 0
            let size = subviews[index].sizeThatFits(
                ProposedViewSize(width: spec.columnWidth, height: nil)
            )
            let height = max(1, size.height)
            let x = bounds.minX + spec.leadingInset + CGFloat(column) * (spec.columnWidth + metrics.columnSpacing)
            let y = columnHeights[column]
            let frame = CGRect(x: x, y: y, width: spec.columnWidth, height: height)
            placements.append(Placement(index: index, frame: frame))
            columnHeights[column] = frame.maxY + metrics.rowSpacing
        }

        return placements
    }

    private struct Placement {
        var index: Int
        var frame: CGRect
    }
}
