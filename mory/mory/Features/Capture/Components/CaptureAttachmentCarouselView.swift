import SwiftUI

struct CaptureAttachmentCarouselView: View {
    let items: [CaptureComposerAttachmentItem]
    let onRemoveStagedArtifact: (Int) -> Void
    let onRemoveContextCandidate: (UUID) -> Void
    let onRemoveAffectDraft: (Int) -> Void
    let onRemoveJournalingSuggestion: (UUID) -> Void
    var onReorderStagedArtifact: (Int, Int) -> Void = { _, _ in }
    var onSetSize: (CaptureComposerAttachmentItem, MemoryCardSizeToken) -> Void = { _, _ in }
    var onStackWithPrevious: (CaptureComposerAttachmentItem) -> Void = { _ in }
    var onUnstack: (CaptureComposerAttachmentItem) -> Void = { _ in }
    var presentationForItem: (CaptureComposerAttachmentItem) -> CaptureCardPresentation = {
        .composerAttachment($0)
    }
    var supportedSizesForItem: (CaptureComposerAttachmentItem) -> [MemoryCardSizeToken] = { _ in
        MemoryCardSizeToken.allCases
    }

    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(items) { item in
                        CaptureCardView(
                            presentation: presentationForItem(item),
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
                            if item.supportsArrangementEditing {
                                Menu("memory.arrangement.size") {
                                    ForEach(supportedSizesForItem(item)) { size in
                                        Button(size.rawValue) {
                                            onSetSize(item, size)
                                        }
                                    }
                                }
                                Button("memory.arrangement.stackWithPrevious") {
                                    onStackWithPrevious(item)
                                }
                                Button("memory.arrangement.unstack") {
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
        case let .affect(index):
            onRemoveAffectDraft(index)
        case let .journalingSuggestion(importSessionID):
            onRemoveJournalingSuggestion(importSessionID)
        case .processing:
            return
        }
    }
}

private extension CaptureComposerAttachmentItem {
    var supportsArrangementEditing: Bool {
        switch source {
        case .stagedArtifact, .contextCandidate, .journalingSuggestion:
            return true
        case .affect, .processing:
            return false
        }
    }
}
