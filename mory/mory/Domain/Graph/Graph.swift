import Foundation

enum EntityKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case person
    case place
    case theme
    case decision
    case activity
    case object

    var id: String { rawValue }
}

struct EntityReference: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: EntityKind
    var name: String
    var aliases: [String]
    var confidence: Double?

    init(
        id: UUID = UUID(),
        kind: EntityKind,
        name: String,
        aliases: [String] = [],
        confidence: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.aliases = aliases
        self.confidence = confidence
    }
}

enum EntityRelationKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case mentionedWith
    case repeatedIn
    case decidedAt
    case relatedTo

    var id: String { rawValue }
}

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
