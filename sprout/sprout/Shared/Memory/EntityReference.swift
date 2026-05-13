import Foundation

enum EntityKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case person
    case place
    case theme
    case decision

    var id: String { rawValue }
}

struct EntityReference: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: EntityKind
    var name: String
    var confidence: Double?

    init(
        id: UUID = UUID(),
        kind: EntityKind,
        name: String,
        confidence: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.confidence = confidence
    }
}
