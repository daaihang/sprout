import SwiftUI
import UIKit

/// Dedicated view for displaying music evidence in a record's detail page.
/// Extracted from RecordDetailView to improve maintainability and reusability.
@MainActor
struct MusicEvidenceSection: View {
    @Environment(AppLocalization.self) private var localization
    
    let artifact: Artifact?
    let record: Record
    let legacyMedia: MediaCard?
    
    var body: some View {
        if let artifact {
            renderMusicArtifact(artifact)
        } else if let m = legacyMedia {
            renderLegacyMusic(m)
        }
    }
    
    @ViewBuilder
    private func renderMusicArtifact(_ artifact: Artifact) -> some View {
        let artworkURL = artifact.metadata["artworkURLString"].flatMap(URL.init(string:))
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(icon: "music.note", title: localization.t("detail.section.music", "Music"))
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
                    Text(nonEmpty(artifact.title) ?? localization.t("detail.music.unknown_track", "Unknown Track"))
                        .font(.headline).lineLimit(2)
                    Text(artifact.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    if let albumName = artifact.metadata["albumName"] ?? nonEmpty(artifact.textContent), !albumName.isEmpty {
                        Text(albumName)
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                    if let urlStr = artifact.metadata["url"], let url = URL(string: urlStr) {
                        Link(localization.t("detail.music.open_apple_music", "Open in Apple Music"), destination: url)
                            .font(.caption)
                    }
                }
                Spacer()
            }
        }
        .detailCard()
    }
    
    @ViewBuilder
    private func renderLegacyMusic(_ m: MediaCard) -> some View {
        let artwork: UIImage? = m.thumbnailData.flatMap { UIImage(data: $0) }
        let artworkURL = m.artworkURLString.flatMap(URL.init(string:))
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(icon: "music.note", title: localization.t("detail.section.music", "Music"))
            HStack(spacing: 14) {
                Group {
                    if let img = artwork {
                        Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                    } else if let artworkURL {
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
                    Text(m.title ?? localization.t("detail.music.unknown_track", "Unknown Track"))
                        .font(.headline).lineLimit(2)
                    Text(m.caption ?? "").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    if let albumName = m.albumName, !albumName.isEmpty {
                        Text(albumName)
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                    if let urlStr = m.url, let url = URL(string: urlStr) {
                        Link(localization.t("detail.music.open_apple_music", "Open in Apple Music"), destination: url)
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
