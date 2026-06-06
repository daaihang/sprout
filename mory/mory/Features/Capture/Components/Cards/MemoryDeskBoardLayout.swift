import SwiftUI

struct MemoryDeskBoardMetrics: Hashable, Sendable {
    static let debugMaxBoardWidth: CGFloat = 620

    var masonry: MoryMasonryMetrics

    static let `default` = MemoryDeskBoardMetrics(masonry: .default)
    static let compactComposer = MemoryDeskBoardMetrics(masonry: .compactComposer)

    static func debugBoardWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth, 0), debugMaxBoardWidth)
    }

    static func debugBoard(availableWidth: CGFloat) -> MemoryDeskBoardMetrics {
        let boardWidth = debugBoardWidth(for: availableWidth)
        var metrics = MoryMasonryMetrics.default
        metrics.minColumnWidth = 132
        metrics.maxColumnWidth = 188
        metrics.columnSpacing = 10
        metrics.rowSpacing = 10
        metrics.horizontalPadding = boardWidth < 340 ? 12 : 16
        metrics.verticalPadding = 16
        metrics.stickerOverflow = 16
        return MemoryDeskBoardMetrics(masonry: metrics)
    }

    func columnSpec(for containerWidth: CGFloat) -> MoryMasonryColumnSpec {
        MoryMasonryLayoutPlan<String>.columnSpec(containerWidth: containerWidth, metrics: masonry)
    }
}

struct MemoryDeskBoardInputNode<ID: Hashable & Sendable>: Hashable, Sendable {
    let id: ID
    let layout: MemoryCardLayoutToken
    let estimatedHeight: CGFloat

    init(
        id: ID,
        layout: MemoryCardLayoutToken,
        estimatedHeight: CGFloat
    ) {
        self.id = id
        self.layout = layout
        self.estimatedHeight = max(1, estimatedHeight)
    }
}

struct MemoryDeskBoardLayoutSlot<ID: Hashable & Sendable>: Identifiable, Hashable, Sendable {
    let id: ID
    let layout: MemoryCardLayoutToken
    let column: Int
    let frame: CGRect
    let renderFrame: CGRect
}

struct MemoryDeskBoardLayoutPlan<ID: Hashable & Sendable>: Hashable, Sendable {
    let slots: [MemoryDeskBoardLayoutSlot<ID>]
    let columnSpec: MoryMasonryColumnSpec
    let boardHeight: CGFloat

    static func make(
        nodes: [MemoryDeskBoardInputNode<ID>],
        containerWidth: CGFloat,
        metrics: MemoryDeskBoardMetrics = .default
    ) -> MemoryDeskBoardLayoutPlan<ID> {
        let masonryPlan = MoryMasonryLayoutPlan.make(
            nodes: nodes.map {
                MoryMasonryInputNode(
                    id: $0.id,
                    order: $0.layout.order,
                    zIndex: $0.layout.zIndex,
                    estimatedHeight: $0.estimatedHeight
                )
            },
            containerWidth: containerWidth,
            metrics: metrics.masonry
        )
        let layoutByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.layout) })
        let slots = masonryPlan.slots.compactMap { slot -> MemoryDeskBoardLayoutSlot<ID>? in
            guard let layout = layoutByID[slot.id] else { return nil }
            return MemoryDeskBoardLayoutSlot(
                id: slot.id,
                layout: layout,
                column: slot.column,
                frame: slot.frame,
                renderFrame: slot.renderFrame
            )
        }
        return MemoryDeskBoardLayoutPlan(
            slots: slots,
            columnSpec: masonryPlan.columnSpec,
            boardHeight: masonryPlan.boardHeight
        )
    }
}
