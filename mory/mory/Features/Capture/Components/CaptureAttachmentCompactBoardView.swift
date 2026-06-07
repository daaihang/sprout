import SwiftUI

struct CaptureAttachmentCompactBoardView: View {
    let items: [CaptureComposerAttachmentItem]
    let onRemoveStagedArtifact: (Int) -> Void
    let onRemoveContextCandidate: (UUID) -> Void
    let onRemoveAffectDraft: (Int) -> Void
    let onRemoveJournalingSuggestion: (UUID) -> Void
    var onReorderItems: (CaptureComposerAttachmentItem, CaptureComposerAttachmentItem) -> Void = { _, _ in }
    var onStackWithPrevious: (CaptureComposerAttachmentItem) -> Void = { _ in }
    var onUnstack: (CaptureComposerAttachmentItem) -> Void = { _ in }
    var presentationForItem: (CaptureComposerAttachmentItem) -> CaptureCardPresentation = {
        .composerAttachment($0)
    }
    var layoutForItem: (CaptureComposerAttachmentItem) -> MemoryCardLayoutToken? = { _ in nil }

    @State private var measuredContainerWidth: CGFloat = 0
    private let boardMetrics = MemoryDeskBoardMetrics.compactComposer

    private var containerWidth: CGFloat {
        measuredContainerWidth > 0 ? measuredContainerWidth : 390
    }

    private var boardItems: [BoardItem] {
        items.enumerated().map { index, item in
            let presentation = presentationForItem(item)
            var layout = layoutForItem(item) ?? MemoryCardLayoutToken(
                order: index,
                rotationDegrees: item.isProcessing ? 0 : Double((index % 5) - 2),
                zIndex: index
            )
            layout.order = index
            layout.zIndex = index
            return BoardItem(item: item, presentation: presentation, layout: layout)
        }
    }

    private var layoutPlan: MemoryDeskBoardLayoutPlan<String> {
        let columnWidth = boardMetrics.columnSpec(for: containerWidth).columnWidth
        return MemoryDeskBoardLayoutPlan.make(
            nodes: boardItems.map {
                MemoryDeskBoardInputNode(
                    id: $0.id,
                    layout: $0.layout,
                    estimatedHeight: estimatedHeight(for: $0, columnWidth: columnWidth)
                )
            },
            containerWidth: containerWidth,
            metrics: boardMetrics
        )
    }

    private var resolvedSlots: [ResolvedBoardSlot] {
        let itemByID = Dictionary(uniqueKeysWithValues: boardItems.map { ($0.id, $0) })
        return layoutPlan.slots.compactMap { slot in
            guard let boardItem = itemByID[slot.id] else { return nil }
            return ResolvedBoardSlot(boardItem: boardItem, frame: slot.frame)
        }
    }

    var body: some View {
        if !items.isEmpty {
            ZStack(alignment: .topLeading) {
                ForEach(resolvedSlots) { slot in
                    CaptureCardView(
                        presentation: slot.boardItem.presentation,
                        objectAvailableSize: slot.frame.size,
                        onRemove: { remove(slot.boardItem.item) }
                    )
                    .frame(width: slot.frame.width, height: slot.frame.height, alignment: .center)
                    .position(
                        x: slot.frame.midX + slot.boardItem.layout.xNudge,
                        y: slot.frame.midY + slot.boardItem.layout.yNudge
                    )
                    .rotationEffect(.degrees(slot.boardItem.layout.rotationDegrees))
                    .zIndex(Double(slot.boardItem.layout.zIndex))
                    .draggable(slot.boardItem.id)
                    .dropDestination(for: String.self) { droppedIDs, _ in
                        guard let droppedID = droppedIDs.first,
                              let source = boardItems.first(where: { $0.id == droppedID }),
                              source.id != slot.boardItem.id else {
                            return false
                        }
                        onReorderItems(source.item, slot.boardItem.item)
                        return true
                    }
                    .contextMenu {
                        if slot.boardItem.item.supportsCompactBoardArrangementEditing {
                            Button("memory.arrangement.stackWithPrevious") {
                                onStackWithPrevious(slot.boardItem.item)
                            }
                            Button("memory.arrangement.unstack") {
                                onUnstack(slot.boardItem.item)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: layoutPlan.boardHeight, maxHeight: layoutPlan.boardHeight, alignment: .topLeading)
            .padding(.top, 4)
            .background(boardBackground)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            updateMeasuredWidth(proxy.size.width)
                        }
                        .onChange(of: proxy.size.width) { _, newWidth in
                            updateMeasuredWidth(newWidth)
                        }
                }
            }
        }
    }

    private var boardBackground: some View {
        LinearGradient(
            colors: [
                Color(.secondarySystemBackground).opacity(0.32),
                Color(.systemBackground).opacity(0.1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func updateMeasuredWidth(_ width: CGFloat) {
        guard width.isFinite, width > 0, abs(width - measuredContainerWidth) > 0.5 else { return }
        measuredContainerWidth = width
    }

    private func remove(_ item: CaptureComposerAttachmentItem) {
        switch item.source {
        case let .stagedArtifact(index):
            onRemoveStagedArtifact(index)
        case let .contextCandidate(id):
            onRemoveContextCandidate(id)
        case let .affect(index):
            onRemoveAffectDraft(index)
        case let .journalingSuggestion(importSessionID):
            onRemoveJournalingSuggestion(importSessionID)
        case .processing:
            return
        }
    }

    private func estimatedHeight(for item: BoardItem, columnWidth: CGFloat) -> CGFloat {
        MemoryCardObjectMetrics.estimatedHeight(
            for: item.presentation.contentKind,
            density: item.presentation.contentDensity,
            columnWidth: columnWidth,
            mediaAspectRatio: item.presentation.item.payload.mediaAspectRatio
        )
    }
}

private struct BoardItem: Identifiable {
    var id: String { item.id }
    var item: CaptureComposerAttachmentItem
    var presentation: CaptureCardPresentation
    var layout: MemoryCardLayoutToken
}

private struct ResolvedBoardSlot: Identifiable {
    let id: String
    let boardItem: BoardItem
    let frame: CGRect

    init(boardItem: BoardItem, frame: CGRect) {
        self.id = boardItem.id
        self.boardItem = boardItem
        self.frame = frame
    }
}

private extension CaptureComposerAttachmentItem {
    var supportsCompactBoardArrangementEditing: Bool {
        switch source {
        case .stagedArtifact, .contextCandidate, .journalingSuggestion:
            return true
        case .affect, .processing:
            return false
        }
    }
}
