import SwiftUI

struct MemoryDeskBoardMetrics: Hashable, Sendable {
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
        let frames = ordered.map { entry in
            frame(for: entry.node.layout, containerWidth: containerWidth, metrics: metrics, fallbackOrder: entry.index)
        }
        let slots = zip(ordered, frames).map { entry, frame in
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
        metrics: MemoryDeskBoardMetrics,
        fallbackOrder: Int
    ) -> CGRect {
        let columns = max(1, min(metrics.columns, MemoryCardRecipeLayoutPolicy.columnCount))
        let cellWidth = metrics.cellWidth(for: containerWidth)
        let box = MemoryCardRecipeLayoutPolicy.gridBox(for: layout.size)
        let fallbackPlacement = MemoryCardGridPlacement(
            column: max(0, fallbackOrder % columns),
            row: max(0, fallbackOrder / columns)
        )
        let placement = layout.gridPlacement ?? fallbackPlacement

        let x = metrics.horizontalPadding + CGFloat(placement.column) * (cellWidth + metrics.columnSpacing)
        let y = metrics.verticalPadding + CGFloat(placement.row) * (metrics.rowHeight + metrics.rowSpacing)
        let width = CGFloat(box.columnSpan) * cellWidth + CGFloat(max(0, box.columnSpan - 1)) * metrics.columnSpacing
        let height = CGFloat(box.rowSpan) * metrics.rowHeight + CGFloat(max(0, box.rowSpan - 1)) * metrics.rowSpacing

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
