import SwiftUI

struct MemoryDeskBoardMetrics: Hashable, Sendable {
    static let debugMaxBoardWidth: CGFloat = 620

    var columns: Int
    var horizontalPadding: CGFloat
    var verticalPadding: CGFloat
    var columnSpacing: CGFloat
    var rowSpacing: CGFloat
    var rowHeight: CGFloat
    var minimumCellWidth: CGFloat

    static let `default` = MemoryDeskBoardMetrics(
        columns: MemoryCardRecipeLayoutPolicy.columnCount,
        horizontalPadding: 16,
        verticalPadding: 18,
        columnSpacing: 10,
        rowSpacing: 12,
        rowHeight: 82,
        minimumCellWidth: 42
    )

    static let compactComposer = MemoryDeskBoardMetrics(
        columns: MemoryCardRecipeLayoutPolicy.columnCount,
        horizontalPadding: 16,
        verticalPadding: 12,
        columnSpacing: 8,
        rowSpacing: 10,
        rowHeight: 64,
        minimumCellWidth: 34
    )

    static func debugBoardWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth, 0), debugMaxBoardWidth)
    }

    static func debugSquare(availableWidth: CGFloat) -> MemoryDeskBoardMetrics {
        let horizontalPadding: CGFloat = 16
        let columnSpacing: CGFloat = 8
        let minimumCellWidth: CGFloat = 34
        let boardWidth = debugBoardWidth(for: availableWidth)
        let usableWidth = max(
            boardWidth - (horizontalPadding * 2),
            minimumCellWidth * CGFloat(MemoryCardRecipeLayoutPolicy.columnCount)
        )
        let totalSpacing = columnSpacing * CGFloat(MemoryCardRecipeLayoutPolicy.columnCount - 1)
        let cellSize = max(
            minimumCellWidth,
            floor((usableWidth - totalSpacing) / CGFloat(MemoryCardRecipeLayoutPolicy.columnCount))
        )
        return MemoryDeskBoardMetrics(
            columns: MemoryCardRecipeLayoutPolicy.columnCount,
            horizontalPadding: horizontalPadding,
            verticalPadding: 18,
            columnSpacing: columnSpacing,
            rowSpacing: columnSpacing,
            rowHeight: cellSize,
            minimumCellWidth: minimumCellWidth
        )
    }

    func cellWidth(for containerWidth: CGFloat) -> CGFloat {
        let clampedColumns = max(1, columns)
        let usableWidth = max(containerWidth - (horizontalPadding * 2), minimumCellWidth * CGFloat(clampedColumns))
        let totalSpacing = columnSpacing * CGFloat(clampedColumns - 1)
        return max(minimumCellWidth, floor((usableWidth - totalSpacing) / CGFloat(clampedColumns)))
    }
}

struct MemoryDeskBoardInputNode<ID: Hashable & Sendable>: Hashable, Sendable {
    let id: ID
    let layout: MemoryCardLayoutToken
}

struct MemoryDeskBoardLayoutSlot<ID: Hashable & Sendable>: Identifiable, Hashable, Sendable {
    let id: ID
    let layout: MemoryCardLayoutToken
    let frame: CGRect
}

struct MemoryDeskBoardLayoutPlan<ID: Hashable & Sendable>: Hashable, Sendable {
    let slots: [MemoryDeskBoardLayoutSlot<ID>]
    let boardHeight: CGFloat

    static func make(
        nodes: [MemoryDeskBoardInputNode<ID>],
        containerWidth: CGFloat,
        metrics: MemoryDeskBoardMetrics = .default
    ) -> MemoryDeskBoardLayoutPlan<ID> {
        let ordered = nodes.enumerated().map { index, node in
            (index: index, node: node)
        }
        let effectivePlacements = MemoryCardGridPacking.effectivePlacements(
            for: ordered.map(\.node.layout)
        )
        let effectiveEntries = ordered.enumerated().map { index, entry in
            var layout = entry.node.layout
            if layout.gridPlacement == nil {
                layout.gridPlacement = effectivePlacements[safe: index]
            }
            return (
                index: entry.index,
                node: MemoryDeskBoardInputNode(id: entry.node.id, layout: layout)
            )
        }
        let frames = effectiveEntries.map { entry in
            frame(for: entry.node.layout, containerWidth: containerWidth, metrics: metrics)
        }
        let slots = zip(effectiveEntries, frames).map { entry, frame in
            MemoryDeskBoardLayoutSlot(id: entry.node.id, layout: entry.node.layout, frame: frame)
        }
        let maxY = frames.map(\.maxY).max() ?? 0
        let minHeight = metrics.verticalPadding * 2 + metrics.rowHeight
        return MemoryDeskBoardLayoutPlan(
            slots: slots,
            boardHeight: max(minHeight, maxY + metrics.verticalPadding)
        )
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
