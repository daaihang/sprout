import CoreGraphics
import Foundation

struct MoryMasonryMetrics: Hashable, Sendable {
    var minColumnWidth: CGFloat
    var maxColumnWidth: CGFloat
    var columnSpacing: CGFloat
    var rowSpacing: CGFloat
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    var stickerOverflow: CGFloat

    init(
        minColumnWidth: CGFloat = 164,
        maxColumnWidth: CGFloat = 228,
        columnSpacing: CGFloat = 12,
        rowSpacing: CGFloat = 12,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 16,
        stickerOverflow: CGFloat = 16
    ) {
        self.minColumnWidth = max(1, minColumnWidth)
        self.maxColumnWidth = max(self.minColumnWidth, maxColumnWidth)
        self.columnSpacing = max(0, columnSpacing)
        self.rowSpacing = max(0, rowSpacing)
        self.horizontalPadding = max(0, horizontalPadding)
        self.verticalPadding = max(0, verticalPadding)
        self.stickerOverflow = max(0, stickerOverflow)
    }

    static let `default` = MoryMasonryMetrics()

    static let homeBoard = MoryMasonryMetrics(
        minColumnWidth: 164,
        maxColumnWidth: 228,
        columnSpacing: 12,
        rowSpacing: 12,
        horizontalPadding: 0,
        verticalPadding: 0,
        stickerOverflow: 16
    )

    static let compactComposer = MoryMasonryMetrics(
        minColumnWidth: 132,
        maxColumnWidth: 188,
        columnSpacing: 10,
        rowSpacing: 10,
        horizontalPadding: 16,
        verticalPadding: 12,
        stickerOverflow: 14
    )
}

struct MoryMasonryColumnSpec: Hashable, Sendable {
    var columnCount: Int
    var columnWidth: CGFloat
    var leadingInset: CGFloat
    var contentWidth: CGFloat
}

struct MoryMasonryInputNode<ID: Hashable & Sendable>: Hashable, Sendable {
    let id: ID
    var order: Int
    var zIndex: Int
    var columnHint: Int?
    var estimatedHeight: CGFloat

    init(
        id: ID,
        order: Int,
        zIndex: Int = 0,
        columnHint: Int? = nil,
        estimatedHeight: CGFloat
    ) {
        self.id = id
        self.order = order
        self.zIndex = zIndex
        self.columnHint = columnHint
        self.estimatedHeight = max(1, estimatedHeight)
    }
}

struct MoryMasonryLayoutSlot<ID: Hashable & Sendable>: Identifiable, Hashable, Sendable {
    let id: ID
    var order: Int
    var zIndex: Int
    var column: Int
    var frame: CGRect
    var renderFrame: CGRect
}

struct MoryMasonryLayoutPlan<ID: Hashable & Sendable>: Hashable, Sendable {
    let slots: [MoryMasonryLayoutSlot<ID>]
    let columnSpec: MoryMasonryColumnSpec
    let boardHeight: CGFloat

    static func make(
        nodes: [MoryMasonryInputNode<ID>],
        containerWidth: CGFloat,
        metrics: MoryMasonryMetrics = .default
    ) -> MoryMasonryLayoutPlan<ID> {
        let columnSpec = Self.columnSpec(containerWidth: containerWidth, metrics: metrics)
        var columnHeights = Array(repeating: metrics.verticalPadding, count: columnSpec.columnCount)
        let ordered = nodes.sorted {
            if $0.order == $1.order {
                return String(describing: $0.id) < String(describing: $1.id)
            }
            return $0.order < $1.order
        }
        var slots: [MoryMasonryLayoutSlot<ID>] = []

        for node in ordered {
            let column = resolvedColumn(for: node, columnHeights: columnHeights)
            let x = columnSpec.leadingInset + CGFloat(column) * (columnSpec.columnWidth + metrics.columnSpacing)
            let y = columnHeights[column]
            let height = max(1, node.estimatedHeight)
            let frame = CGRect(x: x, y: y, width: columnSpec.columnWidth, height: height)
            let renderFrame = frame.insetBy(dx: -metrics.stickerOverflow, dy: -metrics.stickerOverflow)
            slots.append(
                MoryMasonryLayoutSlot(
                    id: node.id,
                    order: node.order,
                    zIndex: node.zIndex,
                    column: column,
                    frame: frame,
                    renderFrame: renderFrame
                )
            )
            columnHeights[column] = frame.maxY + metrics.rowSpacing
        }

        let tallestColumn = columnHeights.max() ?? metrics.verticalPadding
        let minHeight = metrics.verticalPadding * 2 + 1
        let boardHeight = max(minHeight, tallestColumn - metrics.rowSpacing + metrics.verticalPadding)
        return MoryMasonryLayoutPlan(slots: slots, columnSpec: columnSpec, boardHeight: boardHeight)
    }

    static func columnSpec(
        containerWidth: CGFloat,
        metrics: MoryMasonryMetrics = .default
    ) -> MoryMasonryColumnSpec {
        let safeWidth = max(1, containerWidth)
        let available = max(1, safeWidth - metrics.horizontalPadding * 2)
        let rawCount = Int(floor((available + metrics.columnSpacing) / (metrics.minColumnWidth + metrics.columnSpacing)))
        let columnCount = min(max(1, rawCount), adaptiveColumnLimit(for: safeWidth))
        let totalSpacing = metrics.columnSpacing * CGFloat(max(0, columnCount - 1))
        let unclampedWidth = floor((available - totalSpacing) / CGFloat(columnCount))
        let columnWidth = min(metrics.maxColumnWidth, max(1, unclampedWidth))
        let contentWidth = columnWidth * CGFloat(columnCount) + totalSpacing
        let leadingInset = max(metrics.horizontalPadding, (safeWidth - contentWidth) / 2)
        return MoryMasonryColumnSpec(
            columnCount: columnCount,
            columnWidth: columnWidth,
            leadingInset: leadingInset,
            contentWidth: contentWidth
        )
    }

    private static func adaptiveColumnLimit(for width: CGFloat) -> Int {
        switch width {
        case ..<360:
            return 1
        case ..<600:
            return 2
        case ..<900:
            return 3
        case ..<1_200:
            return 4
        case ..<1_500:
            return 5
        default:
            return 6
        }
    }

    private static func resolvedColumn(
        for node: MoryMasonryInputNode<ID>,
        columnHeights: [CGFloat]
    ) -> Int {
        if let hint = node.columnHint {
            return min(max(0, hint), max(0, columnHeights.count - 1))
        }

        return columnHeights.indices.min { lhs, rhs in
            if columnHeights[lhs] == columnHeights[rhs] {
                return lhs < rhs
            }
            return columnHeights[lhs] < columnHeights[rhs]
        } ?? 0
    }
}
