import SwiftUI

struct MemoryContextSection: View {
    let artifacts: [Artifact]
    var prominent = false

    var body: some View {
        if !artifacts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Context")
                    .font(prominent ? .headline : .caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                MemoryDetailAttachmentCarousel(artifacts: artifacts)
            }
        }
    }
}

struct MemoryArticleArtifactView: View {
    let artifact: Artifact

    var body: some View {
        switch artifact.kind {
        case .photo, .livePhoto:
            MemoryMediaStillView(artifact: artifact)
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .audio:
            MemoryAudioRow(artifact: artifact)
        case .link:
            MemoryLinkList(artifacts: [artifact])
                .padding(.horizontal, -20)
        default:
            MemoryDetailCaptureCard(artifact: artifact)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MemoryDetailInsightPanel: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let pipelineStatus = presentation.pipelineStatus {
                DisclosureGroup("Analysis status") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pipelineStatus.userLabel)
                        Text(pipelineStatus.explanation)
                            .foregroundStyle(.secondary)
                        if let lastError = pipelineStatus.lastError?.trimmedOrNil {
                            Text(lastError)
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.caption)
                    .padding(.top, 6)
                }
            }

            if let analysis = presentation.analysis {
                DisclosureGroup("AI analysis") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(analysis.summary)
                        if !analysis.themes.isEmpty {
                            Text(analysis.themes.joined(separator: " · "))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .padding(.top, 6)
                }
            }

            if hasRelatedInsights {
                DisclosureGroup("Related") {
                    VStack(alignment: .leading, spacing: 10) {
                        if !presentation.entities.isEmpty {
                            Text(presentation.entities.map(\.displayName).joined(separator: " · "))
                        }
                        if !presentation.arcs.isEmpty {
                            Text(presentation.arcs.map(\.title).joined(separator: " · "))
                        }
                        if !presentation.reflections.isEmpty {
                            Text(presentation.reflections.map(\.title).joined(separator: " · "))
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var hasRelatedInsights: Bool {
        !presentation.entities.isEmpty || !presentation.arcs.isEmpty || !presentation.reflections.isEmpty
    }
}
