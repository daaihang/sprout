import Foundation

enum ReflectionType: String, Codable, CaseIterable, Sendable {
    case pattern
    case relationship
    case phase
    case record
}

struct ReflectionSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var type: ReflectionType
    var title: String
    var body: String
    var linkedTemporalArcID: UUID?
    var sourceRecordIDs: [UUID]
    var sourceArtifactIDs: [UUID]
    var sourceEntityIDs: [UUID]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        type: ReflectionType,
        title: String,
        body: String,
        linkedTemporalArcID: UUID? = nil,
        sourceRecordIDs: [UUID],
        sourceArtifactIDs: [UUID],
        sourceEntityIDs: [UUID] = [],
        createdAt: Date
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.linkedTemporalArcID = linkedTemporalArcID
        self.sourceRecordIDs = sourceRecordIDs
        self.sourceArtifactIDs = sourceArtifactIDs
        self.sourceEntityIDs = sourceEntityIDs
        self.createdAt = createdAt
    }
}
