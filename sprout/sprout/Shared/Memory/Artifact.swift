import Foundation

struct Artifact: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: ArtifactKind
    var title: String
    var summary: String
    var textContent: String
    var createdAt: Date
    var updatedAt: Date
    var metadata: [String: String]
    var entities: [EntityReference]
    var binaryPayload: Data?
    var previewPayload: Data?

    init(
        id: UUID = UUID(),
        kind: ArtifactKind,
        title: String,
        summary: String,
        textContent: String = "",
        createdAt: Date,
        updatedAt: Date,
        metadata: [String: String] = [:],
        entities: [EntityReference] = [],
        binaryPayload: Data? = nil,
        previewPayload: Data? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.textContent = textContent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.entities = entities
        self.binaryPayload = binaryPayload
        self.previewPayload = previewPayload
    }
}
