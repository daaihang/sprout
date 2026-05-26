import SwiftUI

struct CaptureAttachmentCarouselView: View {
    let items: [CaptureComposerAttachmentItem]
    let onRemoveStagedArtifact: (Int) -> Void
    let onRemoveContextCandidate: (UUID) -> Void
    let onRemoveAffectDraft: (Int) -> Void
    let onRemoveJournalingSuggestion: (UUID) -> Void

    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(items) { item in
                        CaptureCardView(
                            presentation: .composerAttachment(item),
                            onRemove: { remove(item) }
                        )
                        .scrollTransition(.animated, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.97)
                                .opacity(phase.isIdentity ? 1 : 0.86)
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
