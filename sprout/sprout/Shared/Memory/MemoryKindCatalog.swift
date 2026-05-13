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
    var contentFirstCardKind: RecordCardKind? {
        let mediaCards = self.mediaCards ?? []

        if mediaCards.contains(where: { $0.type == MediaCardKind.photo.rawValue }) {
            return .photo
        }
        if mediaCards.contains(where: { $0.type == MediaCardKind.music.rawValue }) {
            return .music
        }
        if mediaCards.contains(where: { $0.type == MediaCardKind.audio.rawValue }) {
            return .audio
        }
        if mediaCards.contains(where: { $0.type == MediaCardKind.todo.rawValue }) {
            return .todo
        }
        if mediaCards.contains(where: { $0.type == MediaCardKind.link.rawValue }) {
            return .link
        }
        if latitude != nil && longitude != nil {
            return .map
        }
        if activity?.value != nil {
            return .activity
        }
        if let mood, !mood.isEmpty {
            return .emotion
        }
        if let weather, !weather.isEmpty {
            return .weather
        }
        if let mentionedPeople, !mentionedPeople.isEmpty {
            return .people
        }

        let body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty {
            return .text
        }

        return nil
    }

    var derivedCardKind: RecordCardKind {
        contentFirstCardKind ?? RecordCardKind(rawValue: cardType) ?? .text
    }

    var cardKind: RecordCardKind {
        derivedCardKind
    }
}

extension MediaCard {
    var mediaKind: MediaCardKind? {
        get { MediaCardKind(rawValue: type) }
        set { type = newValue?.rawValue ?? type }
    }
}
