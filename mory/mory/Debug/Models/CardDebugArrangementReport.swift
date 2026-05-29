import SwiftUI

struct CardDebugArrangementReport: Hashable {
    let rowCount: Int
    let occupiedCells: Int
    let totalCells: Int
    let density: Double
    let overlapCount: Int
    let slots: [CardDebugArrangementSlotReport]

    var densityLabel: String {
        "\(Int((density * 100).rounded()))%"
    }

    static func make(
        nodes: [MemoryCardNode],
        containerWidth: CGFloat = 390,
        metrics: MemoryDeskBoardMetrics = .default
    ) -> CardDebugArrangementReport {
        let inputNodes = nodes.map { MemoryDeskBoardInputNode(id: $0.id, layout: $0.layout) }
        let plan = MemoryDeskBoardLayoutPlan.make(
            nodes: inputNodes,
            containerWidth: containerWidth,
            metrics: metrics
        )
        let effectiveLayouts = plan.slots.map(\.layout)
        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let slots = plan.slots.compactMap { slot -> CardDebugArrangementSlotReport? in
            guard let node = nodeByID[slot.id] else { return nil }
            var effectiveNode = node
            effectiveNode.layout = slot.layout
            return CardDebugArrangementSlotReport(node: effectiveNode, frame: slot.frame)
        }

        var occupied = Set<CardDebugGridCell>()
        var overlapCount = 0
        for slot in slots {
            for cell in slot.cells {
                if occupied.contains(cell) {
                    overlapCount += 1
                } else {
                    occupied.insert(cell)
                }
            }
        }

        let rowCount = max(1, MemoryCardGridPacking.requiredRowCount(for: effectiveLayouts))
        let totalCells = rowCount * MemoryCardRecipeLayoutPolicy.columnCount
        let density = totalCells == 0 ? 0 : Double(occupied.count) / Double(totalCells)
        return CardDebugArrangementReport(
            rowCount: rowCount,
            occupiedCells: occupied.count,
            totalCells: totalCells,
            density: density,
            overlapCount: overlapCount,
            slots: slots
        )
    }
}

struct CardDebugArrangementSlotReport: Identifiable, Hashable {
    let id: UUID
    let contentRef: MemoryCardContentRef
    let recipe: MemoryCardVisualRecipe
    let size: MemoryCardSizeToken
    let gridBox: MemoryCardGridBox
    let placement: MemoryCardGridPlacement?
    let frame: CGRect
    let objectMetrics: MemoryCardObjectMetrics

    init(node: MemoryCardNode, frame: CGRect) {
        self.id = node.id
        self.contentRef = node.contentRef
        self.recipe = node.visualRecipe
        self.size = node.layout.size
        self.gridBox = MemoryCardRecipeLayoutPolicy.gridBox(for: node.layout.size)
        self.placement = node.layout.gridPlacement
        self.frame = frame
        self.objectMetrics = MemoryCardObjectMetrics.resolve(recipe: node.visualRecipe, sizeToken: node.layout.size)
    }

    var occupiedCellCount: Int {
        gridBox.columnSpan * gridBox.rowSpan
    }

    var hasOverflow: Bool {
        objectMetrics.preferredSize.width > frame.width + 0.5
            || objectMetrics.preferredSize.height > frame.height + 0.5
    }

    var overflowLabel: String {
        hasOverflow ? "overflow" : "within box"
    }

    var debugLine: String {
        let placementLabel = placement.map { "c\($0.column)r\($0.row)" } ?? "nil"
        return "\(recipe.rawValue).\(size.rawValue) grid=\(placementLabel) box=\(gridBox.columnSpan)x\(gridBox.rowSpan) frame=\(Int(frame.width))x\(Int(frame.height)) object=\(Int(objectMetrics.preferredSize.width))x\(Int(objectMetrics.preferredSize.height)) \(overflowLabel)"
    }

    var cells: [CardDebugGridCell] {
        guard let placement else { return [] }
        var cells: [CardDebugGridCell] = []
        for row in placement.row..<(placement.row + gridBox.rowSpan) {
            for column in placement.column..<(placement.column + gridBox.columnSpan) {
                cells.append(CardDebugGridCell(column: column, row: row))
            }
        }
        return cells
    }
}

struct CardDebugGridCell: Hashable {
    let column: Int
    let row: Int
}
