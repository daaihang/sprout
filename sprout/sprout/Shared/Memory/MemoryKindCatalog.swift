import Foundation

enum RecordCardKind: String, CaseIterable, Codable, Sendable {
    case text
    case quote
    case emotion
    case weather
    case activity
    case todo
    case photo
    case music
    case link
    case map
    case audio
    case people
    case todayInHistory = "today_in_history"
    case book
    case film
    case game
    case ticket
    case health

    var timelineSymbolName: String {
        switch self {
        case .text, .quote:
            return "text.alignleft"
        case .emotion:
            return "face.smiling"
        case .weather:
            return "cloud.sun.fill"
        case .activity:
            return "figure.walk"
        case .todo:
            return "checklist"
        case .photo:
            return "photo"
        case .music:
            return "music.note"
        case .link:
            return "link"
        case .map:
            return "mappin.and.ellipse"
        case .audio:
            return "waveform"
        case .people:
            return "person.2.fill"
        case .todayInHistory:
            return "clock.arrow.circlepath"
        case .book:
            return "book"
        case .film:
            return "film"
        case .game:
            return "gamecontroller"
        case .ticket:
            return "ticket"
        case .health:
            return "heart.text.square"
        }
    }

    static func primaryCaptureKind(
        draft: CaptureDraft,
        parsed: ParsedContent
    ) -> RecordCardKind {
        let attachments = draft.attachments
        if !attachments.photos.isEmpty { return .photo }
        if attachments.music != nil { return .music }
        if attachments.todos != nil { return .todo }
        if attachments.locationData != nil { return .map }
        if attachments.mood != nil { return .emotion }
        if attachments.audioData != nil { return .audio }
        if !attachments.people.isEmpty { return .people }
        if !parsed.appleMusicURLs.isEmpty { return .music }
        if !parsed.regularURLs.isEmpty { return .link }
        return .text
    }
}

enum MediaCardKind: String, CaseIterable, Codable, Sendable {
    case photo
    case audio
    case music
    case link
    case todo
    case book
    case film
    case game
    case ticket
    case health

    var artifactKind: ArtifactKind {
        switch self {
        case .photo:
            return .photo
        case .audio:
            return .audio
        case .music:
            return .music
        case .link:
            return .link
        case .todo:
            return .todo
        case .book:
            return .book
        case .film:
            return .film
        case .game:
            return .game
        case .ticket:
            return .ticket
        case .health:
            return .healthMetric
        }
    }
}

extension Record {
    var cardKind: RecordCardKind {
        get { RecordCardKind(rawValue: cardType) ?? .text }
        set { cardType = newValue.rawValue }
    }
}

extension MediaCard {
    var mediaKind: MediaCardKind? {
        get { MediaCardKind(rawValue: type) }
        set { type = newValue?.rawValue ?? type }
    }
}
