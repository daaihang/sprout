import Foundation

enum EntityRelationKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case mentionedWith
    case repeatedIn
    case decidedAt
    case relatedTo

    var id: String { rawValue }
}

struct EntityEdge: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var fromEntityID: UUID
    var toEntityID: UUID
    var relationKind: EntityRelationKind
    var weight: Double
    var firstSeenAt: Date
    var lastSeenAt: Date
    var evidenceCount: Int
    var sourceArtifactIDs: [UUID]
    var sourceRecordIDs: [UUID]

    init(
        id: UUID = UUID(),
        fromEntityID: UUID,
        toEntityID: UUID,
        relationKind: EntityRelationKind,
        weight: Double = 1,
        firstSeenAt: Date,
        lastSeenAt: Date,
        evidenceCount: Int = 1,
        sourceArtifactIDs: [UUID] = [],
        sourceRecordIDs: [UUID] = []
    ) {
        self.id = id
        self.fromEntityID = fromEntityID
        self.toEntityID = toEntityID
        self.relationKind = relationKind
        self.weight = weight
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.evidenceCount = evidenceCount
        self.sourceArtifactIDs = sourceArtifactIDs
        self.sourceRecordIDs = sourceRecordIDs
    }
}
