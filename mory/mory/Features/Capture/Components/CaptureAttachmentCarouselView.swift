import SwiftUI

struct CaptureAttachmentCarouselView: View {
    let items: [CaptureComposerAttachmentItem]
    let onRemoveStagedArtifact: (Int) -> Void
    let onToggleContextCandidate: (UUID) -> Void

    var body: some View {
        if !items.isEmpty {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(items) { item in
                        CaptureAttachmentCard(
                            item: item,
                            onRemove: { remove(item) },
                            onToggleSelection: { toggle(item) }
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
            .frame(height: 128)
            .padding(.top, 4)
        }
    }

    private func remove(_ item: CaptureComposerAttachmentItem) {
        guard case let .stagedArtifact(index) = item.source else { return }
        onRemoveStagedArtifact(index)
    }

    private func toggle(_ item: CaptureComposerAttachmentItem) {
        guard case let .contextCandidate(id) = item.source else { return }
        onToggleContextCandidate(id)
    }
}
