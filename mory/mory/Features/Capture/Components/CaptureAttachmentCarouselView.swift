import SwiftUI

struct CaptureAttachmentCarouselView: View {
    let items: [CaptureComposerAttachmentItem]
    let onRemoveStagedArtifact: (Int) -> Void
    let onRemoveContextCandidate: (UUID) -> Void
    var onRemoveDraftGroup: ([UUID]) -> Void = { _ in }
    let onRemoveAffectDraft: (Int) -> Void
    let onRemoveJournalingSuggestion: (UUID) -> Void
    var onReorderStagedArtifact: (Int, Int) -> Void = { _, _ in }
    var onStackWithPrevious: (CaptureComposerAttachmentItem) -> Void = { _ in }
    var onUnstack: (CaptureComposerAttachmentItem) -> Void = { _ in }
    var onPreview: (CaptureComposerAttachmentItem) -> Void = { _ in }
    var presentationForItem: (CaptureComposerAttachmentItem) -> CaptureCardPresentation = {
        .composerAttachment($0)
    }

    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(items) { item in
                        CaptureCardView(
                            presentation: presentationForItem(item),
                            onTap: { onPreview(item) },
                            onRemove: { remove(item) }
                        )
                        .scrollTransition(.animated, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.97)
                                .opacity(phase.isIdentity ? 1 : 0.86)
                        }
                        .draggable(item.id)
                        .dropDestination(for: String.self) { droppedIDs, _ in
                            guard let droppedID = droppedIDs.first,
                                  let source = items.first(where: { $0.id == droppedID }),
                                  case let .stagedArtifact(sourceIndex) = source.source,
                                  case let .stagedArtifact(targetIndex) = item.source,
                                  sourceIndex != targetIndex else {
                                return false
                            }
                            onReorderStagedArtifact(sourceIndex, targetIndex)
                            return true
                        }
                        .contextMenu {
                            if canMergeWithPrevious(item) {
                                Button("memory.card.mergeMedia") {
                                    onStackWithPrevious(item)
                                }
                            }
                            if item.isDraftMediaGroup {
                                Button("memory.card.spreadMedia") {
                                    onUnstack(item)
                                }
                            }
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .frame(height: 148)
            .padding(.top, 4)
        }
    }

    private func remove(_ item: CaptureComposerAttachmentItem) {
        switch item.source {
        case let .stagedArtifact(index):
            onRemoveStagedArtifact(index)
        case let .contextCandidate(id):
            onRemoveContextCandidate(id)
        case let .draftGroup(_, draftIDs):
            onRemoveDraftGroup(draftIDs)
        case let .affect(index):
            onRemoveAffectDraft(index)
        case let .journalingSuggestion(importSessionID):
            onRemoveJournalingSuggestion(importSessionID)
        case .processing:
            return
        }
    }

    private func canMergeWithPrevious(_ item: CaptureComposerAttachmentItem) -> Bool {
        guard item.isSingleMergeableMedia,
              let index = items.firstIndex(where: { $0.id == item.id }),
              index > 0 else {
            return false
        }
        return items[index - 1].isMergeableMediaNode
    }
}

private extension CaptureComposerAttachmentItem {
    var isDraftMediaGroup: Bool {
        if case .draftGroup = source { return true }
        return false
    }

    var isSingleMergeableMedia: Bool {
        card.payload.isMemoryCardMergeableMedia && !isDraftMediaGroup
    }

    var isMergeableMediaNode: Bool {
        card.payload.isMemoryCardMergeableMedia
    }
}
