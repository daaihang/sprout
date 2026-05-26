import Foundation

extension MemoryDetailPresentationMode {
    var title: String {
        switch self {
        case .story: return String(localized: "memory.detail.mode.story")
        case .text: return String(localized: "memory.detail.mode.text")
        case .gallery: return String(localized: "memory.detail.mode.gallery")
        case .audio: return String(localized: "memory.detail.mode.audio")
        case .checkIn: return String(localized: "memory.detail.mode.checkIn")
        case .link: return String(localized: "memory.detail.mode.link")
        case .article: return String(localized: "memory.detail.mode.article")
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
        case .ruleBased: return String(localized: "memory.detail.strategy.automatic")
        case .fixed: return String(localized: "memory.detail.strategy.fixed")
        case .aiAutomatic: return String(localized: "memory.detail.strategy.aiAutomatic")
        }
    }
}

extension Artifact {
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
                ?? String(localized: "memory.detail.artifact.audio")
        case .link:
            return summary.trimmedOrNil
                ?? metadata["url"]?.trimmedOrNil
                ?? String(localized: "memory.detail.artifact.link")
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

extension ArtifactKind {
    var displayName: String {
        switch self {
        case .text: return String(localized: "artifact.kind.text")
        case .photo: return String(localized: "artifact.kind.photo")
        case .audio: return String(localized: "artifact.kind.audio")
        case .video: return String(localized: "artifact.kind.video")
        case .livePhoto: return String(localized: "artifact.kind.livePhoto")
        case .music: return String(localized: "artifact.kind.music")
        case .link: return String(localized: "artifact.kind.link")
        case .location: return String(localized: "artifact.kind.location")
        case .weather: return String(localized: "artifact.kind.weather")
        case .todo: return String(localized: "artifact.kind.todo")
        case .document: return String(localized: "artifact.kind.document")
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .photo: return "photo"
        case .audio: return "waveform"
        case .video: return "video"
        case .livePhoto: return "livephoto"
        case .music: return "music.note"
        case .link: return "link"
        case .location: return "mappin.and.ellipse"
        case .weather: return "cloud.sun"
        case .todo: return "checklist"
        case .document: return "doc.text"
        }
    }
}

extension String {
    var isPlaceholderMemoryBody: Bool {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "context check-in"
            || normalized == "audio capture"
            || normalized == "photo capture"
            || normalized == "untitled memory"
    }
}
