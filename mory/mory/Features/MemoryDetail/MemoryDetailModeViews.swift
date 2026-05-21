import AVFoundation
import SwiftUI
import UIKit

struct MemoryDetailAdaptiveView: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            MemoryDetailHeader(presentation: presentation)

            switch presentation.mode {
            case .story:
                MemoryStoryModeView(presentation: presentation)
            case .text:
                MemoryTextModeView(presentation: presentation)
            case .gallery:
                MemoryGalleryModeView(presentation: presentation)
            case .audio:
                MemoryAudioModeView(presentation: presentation)
            case .checkIn:
                MemoryCheckInModeView(presentation: presentation)
            case .link:
                MemoryLinkModeView(presentation: presentation)
            case .article:
                MemoryArticleModeView(presentation: presentation)
            }
        }
    }
}

private struct MemoryDetailHeader: View {
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

private struct MemoryStoryModeView: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MemoryDetailAttachmentCarousel(artifacts: presentation.contentArtifacts)
            MemoryDetailBodyText(text: presentation.bodyText)
            MemoryContextSection(artifacts: presentation.contextArtifacts)
        }
    }
}

private struct MemoryTextModeView: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MemoryDetailBodyText(text: presentation.bodyText)
            MemoryContextSection(artifacts: presentation.contextArtifacts)
        }
    }
}

private struct MemoryGalleryModeView: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MemoryPhotoGallery(artifacts: presentation.photoArtifacts)
            if presentation.bodyText.trimmedOrNil != nil {
                MemoryDetailBodyText(text: presentation.bodyText)
            }
            MemoryDetailAttachmentCarousel(artifacts: presentation.contentArtifacts.filter { $0.kind != .photo })
            MemoryContextSection(artifacts: presentation.contextArtifacts)
        }
    }
}

private struct MemoryAudioModeView: View {
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

private struct MemoryCheckInModeView: View {
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

private struct MemoryLinkModeView: View {
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

private struct MemoryArticleModeView: View {
    let presentation: MemoryDetailPresentationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            MemoryDetailBodyText(text: presentation.bodyText)
            ForEach(presentation.articleArtifacts) { artifact in
                MemoryArticleArtifactView(artifact: artifact)
                    .padding(.horizontal, 20)
            }
            MemoryContextSection(artifacts: presentation.contextArtifacts)
        }
    }
}

private struct MemoryDetailBodyText: View {
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

private struct MemoryDetailAttachmentCarousel: View {
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

private struct MemoryDetailCaptureCard: View {
    let artifact: Artifact

    var body: some View {
        CaptureCardView(
            item: CaptureCardItem(artifact: artifact),
            provenanceDisplayMode: .production,
            musicCardStyle: .compactRow,
            placeCardStyle: .standard
        )
    }
}

private struct MemoryPhotoGallery: View {
    let artifacts: [Artifact]

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        if artifacts.count == 1, let artifact = artifacts.first {
            MemoryPhotoView(artifact: artifact)
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)
        } else if !artifacts.isEmpty {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(artifacts) { artifact in
                    MemoryPhotoView(artifact: artifact)
                        .aspectRatio(artifact.id.uuidString.hashValue.isMultiple(of: 2) ? 0.82 : 1.18, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct MemoryPhotoView: View {
    let artifact: Artifact

    var body: some View {
        Group {
            if let data = artifact.binaryPayload, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let data = artifact.previewPayload, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
        .accessibilityLabel(Text(artifact.memoryDetailSummary))
    }
}

private struct MemoryAudioList: View {
    let artifacts: [Artifact]

    var body: some View {
        if !artifacts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(artifacts) { artifact in
                    MemoryAudioRow(artifact: artifact)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct MemoryAudioRow: View {
    let artifact: Artifact
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(artifact.binaryPayload == nil)

            VStack(alignment: .leading, spacing: 3) {
                Text(artifact.memoryDetailSummary)
                    .font(.subheadline)
                    .lineLimit(2)
                if let filename = artifact.mediaRef?.filename {
                    Text(filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func togglePlayback() {
        guard let data = artifact.binaryPayload else { return }
        do {
            if player == nil {
                player = try AVAudioPlayer(data: data)
            }
            if player?.isPlaying == true {
                player?.pause()
                isPlaying = false
            } else {
                player?.play()
                isPlaying = true
            }
        } catch {
            isPlaying = false
        }
    }
}

private struct MemoryLinkList: View {
    let artifacts: [Artifact]

    var body: some View {
        if !artifacts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(artifacts) { artifact in
                    Link(destination: URL(string: artifact.metadata["url"] ?? "") ?? URL(string: "https://example.com")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "link")
                                .frame(width: 32, height: 32)
                                .background(Color.secondary.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(artifact.memoryDetailSummary)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                if let url = artifact.metadata["url"] {
                                    Text(url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct MemoryContextSection: View {
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

private struct MemoryArticleArtifactView: View {
    let artifact: Artifact

    var body: some View {
        switch artifact.kind {
        case .photo:
            MemoryPhotoView(artifact: artifact)
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

extension MemoryDetailPresentationMode {
    var title: String {
        switch self {
        case .story: return "Story"
        case .text: return "Text"
        case .gallery: return "Gallery"
        case .audio: return "Audio"
        case .checkIn: return "Check-in"
        case .link: return "Link"
        case .article: return "Article"
        }
    }

    var systemImage: String {
        switch self {
        case .story: return "sparkles"
        case .text: return "text.alignleft"
        case .gallery: return "photo.on.rectangle"
        case .audio: return "waveform"
        case .checkIn: return "mappin.and.ellipse"
        case .link: return "link"
        case .article: return "doc.richtext"
        }
    }
}

extension MemoryDetailPresentationStrategy {
    var title: String {
        switch self {
        case .ruleBased: return "Automatic"
        case .fixed: return "Fixed layout"
        case .aiAutomatic: return "AI automatic"
        }
    }
}

private extension Artifact {
    var memoryDetailSummary: String {
        switch kind {
        case .music:
            return [metadata["trackName"], metadata["artistName"], metadata["albumName"]]
                .compactMap { $0?.trimmedOrNil }
                .joined(separator: " · ")
                .trimmedOrNil ?? summaryOrTitle
        case .weather:
            if let condition = metadata["condition"], let temp = metadata["temperatureCelsius"] {
                return "\(condition) · \(temp)°C"
            }
            return summaryOrTitle
        case .location:
            if let summary = summary.trimmedOrNil {
                return summary
            }
            if let lat = metadata["latitude"], let lon = metadata["longitude"] {
                return "\(lat), \(lon)"
            }
            return summaryOrTitle
        case .audio:
            return metadata["transcriptionText"]?.trimmedOrNil
                ?? summary.trimmedOrNil
                ?? mediaRef?.filename
                ?? "Audio"
        case .link:
            return summary.trimmedOrNil
                ?? metadata["url"]?.trimmedOrNil
                ?? "Link"
        default:
            return summaryOrTitle
        }
    }

    var captureOriginLabel: String? {
        guard let raw = metadata["captureOrigin"],
              let origin = CaptureArtifactOrigin(rawValue: raw) else {
            return nil
        }
        return origin.captureBadgeLabel
    }

    private var summaryOrTitle: String {
        summary.trimmedOrNil
            ?? textContent.trimmedOrNil
            ?? title.trimmedOrNil
            ?? kind.displayName
    }
}

private extension ArtifactKind {
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .photo: return "Photo"
        case .audio: return "Audio"
        case .music: return "Music"
        case .link: return "Link"
        case .location: return "Place"
        case .weather: return "Weather"
        case .todo: return "Task"
        case .document: return "Document"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .photo: return "photo"
        case .audio: return "waveform"
        case .music: return "music.note"
        case .link: return "link"
        case .location: return "mappin.and.ellipse"
        case .weather: return "cloud.sun"
        case .todo: return "checklist"
        case .document: return "doc.text"
        }
    }
}

private extension String {
    var isPlaceholderMemoryBody: Bool {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "context check-in"
            || normalized == "audio capture"
            || normalized == "photo capture"
            || normalized == "untitled memory"
    }
}
