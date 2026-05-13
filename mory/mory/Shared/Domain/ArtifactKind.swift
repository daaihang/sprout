import Foundation

enum ArtifactKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case photo
    case audio
    case music
    case link
    case location
    case weather
    case todo
    case personMention
    case decisionNote

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: "Text"
        case .photo: "Photo"
        case .audio: "Audio"
        case .music: "Music"
        case .link: "Link"
        case .location: "Location"
        case .weather: "Weather"
        case .todo: "Todo"
        case .personMention: "Person Mention"
        case .decisionNote: "Decision Note"
        }
    }
}
