import Foundation

struct ArtifactEntityLink: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var artifactID: UUID
    var entityID: UUID
    var confidence: Double?
    var source: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        artifactID: UUID,
        entityID: UUID,
        confidence: Double? = nil,
        source: String,
        createdAt: Date
    ) {
        self.id = id
        self.artifactID = artifactID
        self.entityID = entityID
        self.confidence = confidence
        self.source = source
        self.createdAt = createdAt
    }
}
