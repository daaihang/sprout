import SwiftUI

struct CardDebugArrangementReport: Hashable {
    let columnCount: Int
    let columnWidth: CGFloat
    let boardHeight: CGFloat
    let stickerOverflow: CGFloat
    let slots: [CardDebugArrangementSlotReport]

    static func make(
        nodes: [MemoryCardNode],
        artifacts: [Artifact],
        containerWidth: CGFloat = 390,
        metrics: MemoryDeskBoardMetrics = .default
    ) -> CardDebugArrangementReport {
        let columnWidth = metrics.columnSpec(for: containerWidth).columnWidth
        let contentKindByNodeID = Dictionary(uniqueKeysWithValues: nodes.map { node in
            (node.id, contentKind(for: node.contentRef, artifacts: artifacts))
        })
        let mediaAspectRatioByNodeID = Dictionary(uniqueKeysWithValues: nodes.map { node in
            (node.id, mediaAspectRatio(for: node.contentRef, artifacts: artifacts))
        })
        let inputNodes = nodes.map {
            MemoryDeskBoardInputNode(
                id: $0.id,
                layout: $0.layout,
                estimatedHeight: MemoryCardObjectMetrics.estimatedHeight(
                    for: contentKindByNodeID[$0.id] ?? .status,
                    density: $0.contentDensity,
                    columnWidth: columnWidth,
                    mediaAspectRatio: mediaAspectRatioByNodeID[$0.id] ?? nil
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
            return CardDebugArrangementSlotReport(
                node: node,
                contentKind: contentKindByNodeID[node.id] ?? .status,
                mediaAspectRatio: mediaAspectRatioByNodeID[node.id] ?? nil,
                slot: slot
            )
        }
        return CardDebugArrangementReport(
            columnCount: plan.columnSpec.columnCount,
            columnWidth: plan.columnSpec.columnWidth,
            boardHeight: plan.boardHeight,
            stickerOverflow: metrics.masonry.stickerOverflow,
            slots: slots
        )
    }

    private static func contentKind(for contentRef: MemoryCardContentRef, artifacts: [Artifact]) -> MemoryCardContentKind {
        switch contentRef {
        case .recordBody:
            return .recordBody
        case let .artifact(id):
            guard let artifact = artifacts.first(where: { $0.id == id }) else { return .status }
            return CaptureCardItem(artifact: artifact).memoryContentKind
        case .artifactGroup:
            return .bundle
        case .affect:
            return .affect
        case .journalingSuggestion:
            return .journalingSuggestion
        }
    }

    private static func mediaAspectRatio(for contentRef: MemoryCardContentRef, artifacts: [Artifact]) -> CGFloat? {
        guard case let .artifact(id) = contentRef,
              let artifact = artifacts.first(where: { $0.id == id })
        else { return nil }
        return CaptureCardItem(artifact: artifact).payload.mediaAspectRatio
    }
}

struct CardDebugArrangementSlotReport: Identifiable, Hashable {
    let id: UUID
    let contentRef: MemoryCardContentRef
    let contentKind: MemoryCardContentKind
    let density: MemoryCardContentDensity
    let column: Int
    let order: Int
    let zIndex: Int
    let frame: CGRect
    let renderFrame: CGRect
    let objectMetrics: MemoryCardObjectMetrics

    init(
        node: MemoryCardNode,
        contentKind: MemoryCardContentKind,
        mediaAspectRatio: CGFloat?,
        slot: MemoryDeskBoardLayoutSlot<UUID>
    ) {
        self.id = node.id
        self.contentRef = node.contentRef
        self.contentKind = contentKind
        self.density = node.contentDensity
        self.column = slot.column
        self.order = node.layout.order
        self.zIndex = node.layout.zIndex
        self.frame = slot.frame
        self.renderFrame = slot.renderFrame
        self.objectMetrics = MemoryCardObjectMetrics.resolve(
            contentKind: contentKind,
            density: node.contentDensity,
            availableSize: slot.frame.size,
            mediaAspectRatio: mediaAspectRatio
        )
    }

    var debugLine: String {
        "\(contentKind.rawValue) order=\(order) z=\(zIndex) column=\(column) frame=(\(Int(frame.minX)),\(Int(frame.minY))) \(Int(frame.width))x\(Int(frame.height)) render=\(Int(renderFrame.width))x\(Int(renderFrame.height)) density=\(density.rawValue)"
    }
}
