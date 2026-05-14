import SwiftUI

/// Dedicated view for displaying music evidence in a record's detail page.
/// Extracted from RecordDetailView to improve maintainability and reusability.
@MainActor
struct MusicEvidenceSection: View {
    @Environment(AppLocalization.self) private var localization
    
    let artifact: Artifact?
    
    var body: some View {
        if let artifact {
            renderMusicArtifact(artifact)
        }
    }
    
    @ViewBuilder
    private func renderMusicArtifact(_ artifact: Artifact) -> some View {
        let artworkURL = artifact.metadata["artworkURLString"].flatMap(URL.init(string:))
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(icon: "music.note", title: localization.string("detail.section.music", default: "Music"))
            HStack(spacing: 14) {
                Group {
                    if let artworkURL {
                        CachedRemoteImage(url: artworkURL, contentMode: .fill) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.15))
                                .overlay(ProgressView())
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.15))
                            .overlay(
                                Image(systemName: "music.note").font(.title2)
                                    .foregroundStyle(.secondary.opacity(0.5))
                            )
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(nonEmpty(artifact.title) ?? localization.string("detail.music.unknown_track", default: "Unknown Track"))
                        .font(.headline).lineLimit(2)
                    Text(artifact.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    if let albumName = artifact.metadata["albumName"] ?? nonEmpty(artifact.textContent), !albumName.isEmpty {
                        Text(albumName)
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                    if let urlStr = artifact.metadata["url"], let url = URL(string: urlStr) {
                        Link(localization.string("detail.music.open_apple_music", default: "Open in Apple Music"), destination: url)
                            .font(.caption)
                    }
                }
                Spacer()
            }
        }
        .detailCard()
    }
}

// MARK: - Helper

private func nonEmpty(_ str: String?) -> String? {
    guard let str = str, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return str
}
