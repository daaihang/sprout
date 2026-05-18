import CoreGraphics

nonisolated struct HomeBoardGridMetrics: Hashable, Sendable {
    var columns: Int
    var spacing: CGFloat
    var minimumCellWidth: CGFloat

    init(columns: Int, spacing: CGFloat = 12, minimumCellWidth: CGFloat = 72) {
        self.columns = max(1, columns)
        self.spacing = spacing
        self.minimumCellWidth = minimumCellWidth
    }

    static func columns(for containerWidth: CGFloat) -> Int {
        containerWidth >= 600 ? 8 : 4
    }

    static func adaptive(for containerWidth: CGFloat) -> HomeBoardGridMetrics {
        HomeBoardGridMetrics(columns: columns(for: containerWidth))
    }

    func cellLength(for containerWidth: CGFloat) -> CGFloat {
        let available = max(containerWidth - spacing * CGFloat(columns - 1), minimumCellWidth)
        return max(minimumCellWidth, floor(available / CGFloat(columns)))
    }
}
