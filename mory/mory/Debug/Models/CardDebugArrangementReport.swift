import SwiftUI

struct CardDebugArrangementReport: Hashable {
    let columnCount: Int
    let columnWidth: CGFloat
    let boardHeight: CGFloat
    let stickerOverflow: CGFloat
    let slots: [CardDebugArrangementSlotReport]

    static func make(
        nodes: [MemoryCardNode],
        containerWidth: CGFloat = 390,
        metrics: MemoryDeskBoardMetrics = .default
    ) -> CardDebugArrangementReport {
        let columnWidth = metrics.columnSpec(for: containerWidth).columnWidth
        let inputNodes = nodes.map {
            MemoryDeskBoardInputNode(
                id: $0.id,
                layout: $0.layout,
                estimatedHeight: MemoryCardObjectMetrics.estimatedHeight(
                    for: $0.visualRecipe,
                    density: nil,
                    columnWidth: columnWidth
                )
            )
        }
        let plan = MemoryDeskBoardLayoutPlan.make(
            nodes: inputNodes,
            containerWidth: containerWidth,
            metrics: metrics
        )
        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let slots = plan.slots.compactMap { slot -> CardDebugArrangementSlotReport? in
            guard let node = nodeByID[slot.id] else { return nil }
            return CardDebugArrangementSlotReport(node: node, slot: slot)
        }
        return CardDebugArrangementReport(
            columnCount: plan.columnSpec.columnCount,
            columnWidth: plan.columnSpec.columnWidth,
            boardHeight: plan.boardHeight,
            stickerOverflow: metrics.masonry.stickerOverflow,
            slots: slots
        )
    }
}

struct CardDebugArrangementSlotReport: Identifiable, Hashable {
    let id: UUID
    let contentRef: MemoryCardContentRef
    let recipe: MemoryCardVisualRecipe
    let column: Int
    let order: Int
    let zIndex: Int
    let frame: CGRect
    let renderFrame: CGRect
    let objectMetrics: MemoryCardObjectMetrics

    init(node: MemoryCardNode, slot: MemoryDeskBoardLayoutSlot<UUID>) {
        self.id = node.id
        self.contentRef = node.contentRef
        self.recipe = node.visualRecipe
        self.column = slot.column
        self.order = node.layout.order
        self.zIndex = node.layout.zIndex
        self.frame = slot.frame
        self.renderFrame = slot.renderFrame
        self.objectMetrics = MemoryCardObjectMetrics.resolve(
            recipe: node.visualRecipe,
            availableSize: slot.frame.size
        )
    }

    var debugLine: String {
        "\(recipe.rawValue) order=\(order) z=\(zIndex) column=\(column) frame=(\(Int(frame.minX)),\(Int(frame.minY))) \(Int(frame.width))x\(Int(frame.height)) render=\(Int(renderFrame.width))x\(Int(renderFrame.height)) density=\(objectMetrics.density.rawValue)"
    }
}
