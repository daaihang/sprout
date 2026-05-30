import SwiftUI

struct MemoryDetailHeader: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(presentation.mode.title, systemImage: presentation.mode.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(presentation.subtitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
    }
}

struct MemoryStoryModeView: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MemoryDetailAttachmentCarousel(artifacts: presentation.contentArtifacts)
            MemoryDetailBodyText(text: presentation.bodyText)
            MemoryContextSection(artifacts: presentation.contextArtifacts)
        }
    }
}

struct MemoryTextModeView: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MemoryDetailBodyText(text: presentation.bodyText)
            MemoryContextSection(artifacts: presentation.contextArtifacts)
        }
    }
}

struct MemoryGalleryModeView: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MemoryPhotoGallery(artifacts: presentation.photoArtifacts)
            if presentation.bodyText.trimmedOrNil != nil {
                MemoryDetailBodyText(text: presentation.bodyText)
            }
            MemoryDetailAttachmentCarousel(artifacts: presentation.contentArtifacts.filter { $0.kind != .photo && $0.kind != .livePhoto })
            MemoryContextSection(artifacts: presentation.contextArtifacts)
        }
    }
}

struct MemoryAudioModeView: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MemoryAudioList(artifacts: presentation.audioArtifacts)
            MemoryDetailBodyText(text: presentation.bodyText)
            MemoryDetailAttachmentCarousel(artifacts: presentation.contentArtifacts.filter { $0.kind != .audio })
            MemoryContextSection(artifacts: presentation.contextArtifacts)
        }
    }
}

struct MemoryCheckInModeView: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MemoryContextSection(artifacts: presentation.contextArtifacts, prominent: true)
            if presentation.bodyText.trimmedOrNil != nil && !presentation.bodyText.isPlaceholderMemoryBody {
                MemoryDetailBodyText(text: presentation.bodyText)
            }
        }
    }
}

struct MemoryLinkModeView: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MemoryLinkList(artifacts: presentation.linkArtifacts)
            if presentation.bodyText.trimmedOrNil != nil {
                MemoryDetailBodyText(text: presentation.bodyText)
            }
            MemoryDetailAttachmentCarousel(artifacts: presentation.contentArtifacts.filter { $0.kind != .link })
            MemoryContextSection(artifacts: presentation.contextArtifacts)
        }
    }
}

struct MemoryArticleModeView: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            MemoryDetailBodyText(text: presentation.bodyText)
            if presentation.articleArtifacts.isEmpty {
                MemoryDetailEmptyBlock(
                    titleKey: "memory.detail.empty.article.title",
                    messageKey: "memory.detail.empty.article.message",
                    systemImage: "doc.richtext"
                )
                .padding(.horizontal, 20)
            } else {
                ForEach(presentation.articleArtifacts) { artifact in
                    MemoryArticleArtifactView(artifact: artifact)
                        .padding(.horizontal, 20)
                }
            }
            MemoryContextSection(artifacts: presentation.contextArtifacts)
        }
    }
}
