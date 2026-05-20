import Foundation

struct CaptureComposerAttachmentItem: Identifiable {
    enum Source: Equatable {
        case stagedArtifact(index: Int)
        case contextCandidate(id: UUID)
        case processing(id: String)
    }

    enum Kind {
        case photo
        case audio
        case location
        case link
        case todo
        case weather
        case music
        case status

        var iconName: String {
            switch self {
            case .photo: return "photo"
            case .audio: return "waveform"
            case .location: return "mappin.and.ellipse"
            case .link: return "link"
            case .todo: return "checklist"
            case .weather: return "cloud.sun"
            case .music: return "music.note"
            case .status: return "hourglass"
            }
        }

        var label: String {
            switch self {
            case .photo: return String(localized: "capture.card.kind.photo")
            case .audio: return String(localized: "capture.card.kind.audio")
            case .location: return String(localized: "capture.card.kind.location")
            case .link: return String(localized: "capture.card.kind.link")
            case .todo: return String(localized: "capture.card.kind.todo")
            case .weather: return String(localized: "capture.card.kind.weather")
            case .music: return String(localized: "capture.card.kind.music")
            case .status: return String(localized: "capture.card.kind.working")
            }
        }
    }

    let id: String
    let source: Source
    let kind: Kind
    let detail: String
    let secondaryText: String?
    let origin: CaptureArtifactOrigin?
    let thumbnailData: Data?
    let artworkURL: String?
    let artworkPalette: MusicArtworkPalette?
    let weatherStyle: CaptureWeatherVisualStyle?
    let weatherConditionCode: String?
    let weatherSymbolName: String?
    let weatherIsDaylight: Bool?
    let latitude: Double?
    let longitude: Double?
    let isSelected: Bool
    let isProcessing: Bool
    let isRemovable: Bool
    let isSelectable: Bool

    nonisolated static func staged(index: Int, draft: CaptureArtifactDraft) -> CaptureComposerAttachmentItem {
        CaptureComposerAttachmentItem(
            id: "staged-\(index)-\(draft.id)",
            source: .stagedArtifact(index: index),
            kind: draft.captureComposerKind,
            detail: draft.captureComposerDetail,
            secondaryText: nil,
            origin: draft.origin,
            thumbnailData: draft.captureComposerThumbnailData,
            artworkURL: draft.captureComposerArtworkURL,
            artworkPalette: draft.captureComposerArtworkPalette,
            weatherStyle: draft.captureComposerWeatherStyle,
            weatherConditionCode: draft.captureComposerWeatherConditionCode,
            weatherSymbolName: draft.captureComposerWeatherSymbolName,
            weatherIsDaylight: draft.captureComposerWeatherIsDaylight,
            latitude: draft.captureComposerLatitude,
            longitude: draft.captureComposerLongitude,
            isSelected: false,
            isProcessing: false,
            isRemovable: true,
            isSelectable: false
        )
    }

    nonisolated static func context(_ candidate: ContextCandidate) -> CaptureComposerAttachmentItem {
        CaptureComposerAttachmentItem(
            id: "context-\(candidate.id.uuidString)",
            source: .contextCandidate(id: candidate.id),
            kind: candidate.draft.captureComposerKind,
            detail: candidate.draft.captureComposerDetail,
            secondaryText: candidate.capturedAt.formatted(date: .omitted, time: .shortened),
            origin: candidate.draft.origin,
            thumbnailData: candidate.draft.captureComposerThumbnailData,
            artworkURL: candidate.draft.captureComposerArtworkURL,
            artworkPalette: candidate.draft.captureComposerArtworkPalette,
            weatherStyle: candidate.draft.captureComposerWeatherStyle,
            weatherConditionCode: candidate.draft.captureComposerWeatherConditionCode,
            weatherSymbolName: candidate.draft.captureComposerWeatherSymbolName,
            weatherIsDaylight: candidate.draft.captureComposerWeatherIsDaylight,
            latitude: candidate.draft.captureComposerLatitude,
            longitude: candidate.draft.captureComposerLongitude,
            isSelected: false,
            isProcessing: false,
            isRemovable: true,
            isSelectable: false
        )
    }

    nonisolated static func processing(id: String, detail: String) -> CaptureComposerAttachmentItem {
        CaptureComposerAttachmentItem(
            id: "processing-\(id)",
            source: .processing(id: id),
            kind: .status,
            detail: detail,
            secondaryText: nil,
            origin: nil,
            thumbnailData: nil,
            artworkURL: nil,
            artworkPalette: nil,
            weatherStyle: nil,
            weatherConditionCode: nil,
            weatherSymbolName: nil,
            weatherIsDaylight: nil,
            latitude: nil,
            longitude: nil,
            isSelected: false,
            isProcessing: true,
            isRemovable: false,
            isSelectable: false
        )
    }
}

extension CaptureArtifactDraft {
    nonisolated var captureComposerKind: CaptureComposerAttachmentItem.Kind {
        switch self {
        case .text: return .status
        case .photo: return .photo
        case .audio: return .audio
        case .location: return .location
        case .link: return .link
        case .todo: return .todo
        case .weather: return .weather
        case .music: return .music
        }
    }

    nonisolated var captureComposerDetail: String {
        switch self {
        case let .text(_, body, _):
            return body.captureCardSnippet ?? String(localized: "capture.card.kind.text")
        case let .photo(_, summary, filename, _, _, ocrText, _, _):
            return [summary.captureCardSnippet, ocrText.captureCardSnippet, filename.trimmedOrNil]
                .compactMap { $0 }
                .first ?? String(localized: "capture.card.photo.attached")
        case let .audio(_, summary, _, _, transcriptionText, _):
            if transcriptionText.trimmedOrNil != nil {
                return String(localized: "capture.card.audio.transcriptAdded")
            }
            return summary.captureCardSnippet ?? String(localized: "capture.card.audio.attached")
        case let .location(_, summary, _, _, _):
            if let summary = summary.captureCardSnippet {
                return summary
            }
            return String(localized: "capture.card.place.attached")
        case let .link(_, url, note, summary, _, _, _):
            return summary?.captureCardSnippet
                ?? note?.captureCardSnippet
                ?? url.captureCardSnippet
                ?? String(localized: "capture.card.link.attached")
        case let .todo(title, note, _):
            return note?.captureCardSnippet
                ?? title.captureCardSnippet
                ?? String(localized: "capture.card.todo.attached")
        case let .weather(condition, temp, humidity, _, _, _, _, _, _, _, _):
            return String(
                format: String(localized: "capture.card.weather.shortDetail.format"),
                condition,
                temp,
                humidity * 100
            )
        case let .music(trackName, artistName, albumName, _, _, _, _, _):
            return [trackName.trimmedOrNil, artistName.trimmedOrNil, albumName.trimmedOrNil]
                .compactMap { $0 }
                .joined(separator: " · ")
                .trimmedOrNil ?? String(localized: "capture.card.music.attached")
        }
    }

    nonisolated var captureComposerThumbnailData: Data? {
        switch self {
        case let .photo(_, _, _, _, thumbnailData, _, _, _):
            return thumbnailData
        case let .link(_, _, _, _, _, thumbnailData, _):
            return thumbnailData
        case let .music(_, _, _, _, _, artworkData, _, _):
            return artworkData
        default:
            return nil
        }
    }

    nonisolated var captureComposerArtworkURL: String? {
        switch self {
        case let .music(_, _, _, _, artworkURL, _, _, _):
            return artworkURL
        default:
            return nil
        }
    }

    nonisolated var captureComposerArtworkPalette: MusicArtworkPalette? {
        switch self {
        case let .music(_, _, _, _, _, _, artworkPalette, _):
            return artworkPalette
        default:
            return nil
        }
    }

    nonisolated var captureComposerWeatherStyle: CaptureWeatherVisualStyle? {
        switch self {
        case let .weather(condition, temperatureCelsius, _, windSpeedKmh, _, _, _, conditionCode, _, isDaylight, _):
            return .resolve(
                conditionCode: conditionCode,
                condition: condition,
                temperatureCelsius: temperatureCelsius,
                windSpeedKmh: windSpeedKmh,
                isDaylight: isDaylight
            )
        default:
            return nil
        }
    }

    nonisolated var captureComposerWeatherConditionCode: String? {
        switch self {
        case let .weather(_, _, _, _, _, _, _, conditionCode, _, _, _):
            return conditionCode
        default:
            return nil
        }
    }

    nonisolated var captureComposerWeatherSymbolName: String? {
        switch self {
        case let .weather(_, _, _, _, _, _, _, _, symbolName, _, _):
            return symbolName
        default:
            return nil
        }
    }

    nonisolated var captureComposerWeatherIsDaylight: Bool? {
        switch self {
        case let .weather(_, _, _, _, _, _, _, _, _, isDaylight, _):
            return isDaylight
        default:
            return nil
        }
    }

    nonisolated var captureComposerLatitude: Double? {
        switch self {
        case let .location(_, _, latitude, _, _):
            return latitude
        case let .weather(_, _, _, _, _, latitude, _, _, _, _, _):
            return latitude
        default:
            return nil
        }
    }

    nonisolated var captureComposerLongitude: Double? {
        switch self {
        case let .location(_, _, _, longitude, _):
            return longitude
        case let .weather(_, _, _, _, _, _, longitude, _, _, _, _):
            return longitude
        default:
            return nil
        }
    }
}

extension CaptureArtifactOrigin {
    var captureBadgeLabel: String {
        switch self {
        case .manual:
            return String(localized: "capture.origin.manual")
        case .context:
            return String(localized: "capture.origin.context")
        case .imported:
            return String(localized: "capture.origin.imported")
        case .inferred:
            return String(localized: "capture.origin.inferred")
        }
    }
}

private extension String {
    nonisolated var captureCardSnippet: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let collapsed = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard collapsed.count > 96 else { return collapsed }
        return String(collapsed.prefix(93)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
