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
}
