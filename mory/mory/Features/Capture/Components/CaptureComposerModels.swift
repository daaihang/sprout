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
            case .photo: return "Photo"
            case .audio: return "Voice"
            case .location: return "Location"
            case .link: return "Link"
            case .todo: return "Task"
            case .weather: return "Weather"
            case .music: return "Music"
            case .status: return "Working"
            }
        }
    }

    let id: String
    let source: Source
    let kind: Kind
    let detail: String
    let secondaryText: String?
    let origin: CaptureArtifactOrigin?
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
            isSelected: true,
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
            isSelected: candidate.isSelected,
            isProcessing: false,
            isRemovable: false,
            isSelectable: true
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
            isSelected: true,
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
            return body.captureCardSnippet ?? "Text"
        case let .photo(_, summary, filename, _, _, ocrText, _, _):
            return [summary.captureCardSnippet, ocrText.captureCardSnippet, filename.trimmedOrNil]
                .compactMap { $0 }
                .first ?? "Photo attached"
        case let .audio(_, summary, _, _, transcriptionText, _):
            if transcriptionText.trimmedOrNil != nil {
                return "Transcript added to note"
            }
            return summary.captureCardSnippet ?? "Voice attached"
        case let .location(_, summary, latitude, longitude, _):
            if let summary = summary.captureCardSnippet {
                return summary
            }
            if let latitude, let longitude {
                return "\(latitude), \(longitude)"
            }
            return "Location attached"
        case let .link(_, url, note, summary, _, _, _):
            return summary?.captureCardSnippet
                ?? note?.captureCardSnippet
                ?? url.captureCardSnippet
                ?? "Link attached"
        case let .todo(title, note, _):
            return note?.captureCardSnippet
                ?? title.captureCardSnippet
                ?? "Task attached"
        case let .weather(condition, temp, humidity, _, _, _, _, _):
            return "\(condition) \(String(format: "%.0f", temp))°C · \(String(format: "%.0f", humidity * 100))% humidity"
        case let .music(trackName, artistName, albumName, _, _, _):
            return [trackName.trimmedOrNil, artistName.trimmedOrNil, albumName.trimmedOrNil]
                .compactMap { $0 }
                .joined(separator: " · ")
                .trimmedOrNil ?? "Music attached"
        }
    }
}

extension CaptureArtifactOrigin {
    var captureBadgeLabel: String {
        switch self {
        case .manual:
            return "Manual"
        case .context:
            return "Context"
        case .imported:
            return "Imported"
        case .inferred:
            return "Inferred"
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
