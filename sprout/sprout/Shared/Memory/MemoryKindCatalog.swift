import Foundation

enum MemoryPresentationKind: String, CaseIterable, Codable, Sendable {
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

    var symbolName: String {
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
