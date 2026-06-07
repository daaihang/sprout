import Foundation

enum MemoryCardContentDensity: String, Codable, CaseIterable, Identifiable, Sendable {
    case simple
    case standard
    case detailed

    var id: String { rawValue }
}

enum MemoryCardPresentationPolicy {
    static func defaultDensity(for content: CaptureArtifactContent) -> MemoryCardContentDensity {
        switch content {
        case .text, .promptAnswer:
            return .detailed
        case .photo, .video, .livePhoto, .location, .link, .personContext:
            return .standard
        case .audio, .music, .weather, .todo:
            return .simple
        }
    }

    nonisolated static func defaultDensity(for artifact: Artifact) -> MemoryCardContentDensity {
        switch artifact.kind {
        case .text:
            return .detailed
        case .photo, .video, .livePhoto, .location, .link:
            return .standard
        case .audio, .music, .weather, .todo:
            return .simple
        case .document:
            if artifact.metadata["documentType"] == "personContext" {
                return .standard
            }
            return .detailed
        }
    }

    static func defaultDensity(for contentRef: MemoryCardContentRef) -> MemoryCardContentDensity {
        switch contentRef {
        case .recordBody:
            return .detailed
        case .artifact:
            return .standard
        case .artifactGroup, .journalingSuggestion:
            return .standard
        case .affect:
            return .simple
        }
    }

    static func defaultDensity(for contentRef: MemoryCardDraftContentRef) -> MemoryCardContentDensity {
        switch contentRef {
        case .recordBody:
            return .detailed
        case .artifactDraft:
            return .standard
        case .artifactDraftGroup, .journalingSuggestion:
            return .standard
        case .affectDraft:
            return .simple
        }
    }

    static func supportedDensities(for contentKind: MemoryCardContentKind) -> [MemoryCardContentDensity] {
        switch contentKind {
        case .recordBody, .audio, .music, .place, .todo, .journalingSuggestion, .bundle:
            return MemoryCardContentDensity.allCases
        case .weather, .status, .person, .link:
            return [.simple, .standard]
        case .prompt:
            return [.standard, .detailed]
        case .photo, .video, .livePhoto:
            return [.standard]
        case .affect:
            return [.simple]
        }
    }

    static func normalizedDensity(
        _ density: MemoryCardContentDensity?,
        for contentKind: MemoryCardContentKind
    ) -> MemoryCardContentDensity {
        let supported = supportedDensities(for: contentKind)
        let fallback = defaultDensity(for: contentKind)
        guard let density else { return fallback }
        return supported.contains(density) ? density : fallback
    }

    static func defaultDensity(for contentKind: MemoryCardContentKind) -> MemoryCardContentDensity {
        switch contentKind {
        case .recordBody, .prompt:
            return .detailed
        case .photo, .video, .livePhoto, .place, .link, .person, .bundle, .journalingSuggestion:
            return .standard
        case .audio, .weather, .music, .todo, .affect, .status:
            return .simple
        }
    }
}

enum MemoryCardContentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case recordBody
    case photo
    case video
    case livePhoto
    case audio
    case place
    case weather
    case music
    case link
    case todo
    case prompt
    case person
    case affect
    case journalingSuggestion
    case bundle
    case status

    var id: String { rawValue }
}
