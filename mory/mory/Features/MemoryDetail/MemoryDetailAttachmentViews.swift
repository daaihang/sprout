import SwiftUI

struct MemoryDetailBodyText: View {
    let text: String

    var body: some View {
        if let body = text.trimmedOrNil {
            Text(body)
                .font(.body)
                .lineSpacing(5)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
        }
    }
}

struct MemoryDetailAttachmentCarousel: View {
    let artifacts: [Artifact]

    var body: some View {
        if !artifacts.isEmpty {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(artifacts) { artifact in
                        MemoryDetailCaptureCard(artifact: artifact)
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
        }
    }
}

struct MemoryDetailCaptureCard: View {
    let artifact: Artifact

    var body: some View {
        CaptureCardView(
            presentation: .detailArtifact(artifact)
        )
    }
}
