import Foundation

struct EntityNode: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: EntityKind
    var displayName: String
    var canonicalName: String
    var summary: String
    var createdAt: Date
    var updatedAt: Date
    var confidence: Double?

    init(
        id: UUID = UUID(),
        kind: EntityKind,
        displayName: String,
        canonicalName: String? = nil,
        summary: String = "",
        createdAt: Date,
        updatedAt: Date,
        confidence: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.canonicalName = canonicalName ?? displayName
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.confidence = confidence
    }
}
