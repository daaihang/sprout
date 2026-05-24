import Foundation
import SwiftData

@Model
final class CorrectionEventStore {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var actorRawValue: String
    var targetEntityIDs: [UUID]
    var targetRecordIDs: [UUID]
    var sourceRecordIDs: [UUID]
    var note: String?
    var metadataData: Data?
    var isReversible: Bool
    var createdAt: Date
    var reversedAt: Date?

    init(
        id: UUID,
        kindRawValue: String,
        actorRawValue: String,
        targetEntityIDs: [UUID],
        targetRecordIDs: [UUID],
        sourceRecordIDs: [UUID],
        note: String?,
        metadataData: Data?,
        isReversible: Bool,
        createdAt: Date,
        reversedAt: Date?
    ) {
        self.id = id
        self.kindRawValue = kindRawValue
        self.actorRawValue = actorRawValue
        self.targetEntityIDs = targetEntityIDs
        self.targetRecordIDs = targetRecordIDs
        self.sourceRecordIDs = sourceRecordIDs
        self.note = note
        self.metadataData = metadataData
        self.isReversible = isReversible
        self.createdAt = createdAt
        self.reversedAt = reversedAt
    }
}

@Model
final class EntityTombstoneStore {
    @Attribute(.unique) var oldEntityID: UUID
    var id: UUID
    var replacementEntityID: UUID?
    var kindRawValue: String
    var reasonRawValue: String
    var note: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        oldEntityID: UUID,
        replacementEntityID: UUID?,
        kindRawValue: String,
        reasonRawValue: String,
        note: String?,
        createdAt: Date
    ) {
        self.id = id
        self.oldEntityID = oldEntityID
        self.replacementEntityID = replacementEntityID
        self.kindRawValue = kindRawValue
        self.reasonRawValue = reasonRawValue
        self.note = note
        self.createdAt = createdAt
    }
}

@Model
final class EntityProfileStore {
    @Attribute(.unique) var id: UUID
    var entityID: UUID
    var kindRawValue: String
    var displayName: String
    var canonicalName: String
    var aliases: [String]
    var relationshipToUserRawValue: String?
    var userDescription: String?
    var mentionCount: Int
    var firstMentionedAt: Date?
    var lastMentionedAt: Date?
    var commonContextLabels: [String]
    var sourceRecordIDs: [UUID]
    var confirmationStateRawValue: String
    var confidence: Double?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        entityID: UUID,
        kindRawValue: String,
        displayName: String,
        canonicalName: String,
        aliases: [String] = [],
        relationshipToUserRawValue: String? = nil,
        userDescription: String? = nil,
        mentionCount: Int,
        firstMentionedAt: Date? = nil,
        lastMentionedAt: Date? = nil,
        commonContextLabels: [String] = [],
        sourceRecordIDs: [UUID] = [],
        confirmationStateRawValue: String,
        confidence: Double? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.entityID = entityID
        self.kindRawValue = kindRawValue
        self.displayName = displayName
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.relationshipToUserRawValue = relationshipToUserRawValue
        self.userDescription = userDescription
        self.mentionCount = mentionCount
        self.firstMentionedAt = firstMentionedAt
        self.lastMentionedAt = lastMentionedAt
        self.commonContextLabels = commonContextLabels
        self.sourceRecordIDs = sourceRecordIDs
        self.confirmationStateRawValue = confirmationStateRawValue
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class EntityNodeStore {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var displayName: String
    var canonicalName: String
    var aliases: [String]
    var summary: String
    var provenanceRecordIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date
    var confidence: Double?

    init(
        id: UUID,
        kindRawValue: String,
        displayName: String,
        canonicalName: String,
        aliases: [String] = [],
        summary: String,
        provenanceRecordIDs: [UUID] = [],
        createdAt: Date,
        updatedAt: Date,
        confidence: Double? = nil
    ) {
        self.id = id
        self.kindRawValue = kindRawValue
        self.displayName = displayName
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.summary = summary
        self.provenanceRecordIDs = provenanceRecordIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.confidence = confidence
    }
}

@Model
final class EntityEdgeStore {
    @Attribute(.unique) var id: UUID
    var fromEntityID: UUID
    var toEntityID: UUID
    var relationKindRawValue: String
    var weight: Double
    var firstSeenAt: Date
    var lastSeenAt: Date
    var evidenceCount: Int
    var sourceArtifactIDs: [UUID]
    var sourceRecordIDs: [UUID]

    init(
        id: UUID,
        fromEntityID: UUID,
        toEntityID: UUID,
        relationKindRawValue: String,
        weight: Double,
        firstSeenAt: Date,
        lastSeenAt: Date,
        evidenceCount: Int,
        sourceArtifactIDs: [UUID] = [],
        sourceRecordIDs: [UUID] = []
    ) {
        self.id = id
        self.fromEntityID = fromEntityID
        self.toEntityID = toEntityID
        self.relationKindRawValue = relationKindRawValue
        self.weight = weight
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.evidenceCount = evidenceCount
        self.sourceArtifactIDs = sourceArtifactIDs
        self.sourceRecordIDs = sourceRecordIDs
    }
}

@Model
final class ArtifactEntityLinkStore {
    @Attribute(.unique) var id: UUID
    var artifactID: UUID
    var entityID: UUID
    var confidence: Double?
    var source: String
    var sourceRecordID: UUID?
    var sourceAnalysisRecordID: UUID?
    var evidenceSummary: String
    var createdAt: Date

    init(
        id: UUID,
        artifactID: UUID,
        entityID: UUID,
        confidence: Double? = nil,
        source: String,
        sourceRecordID: UUID? = nil,
        sourceAnalysisRecordID: UUID? = nil,
        evidenceSummary: String = "",
        createdAt: Date
    ) {
        self.id = id
        self.artifactID = artifactID
        self.entityID = entityID
        self.confidence = confidence
        self.source = source
        self.sourceRecordID = sourceRecordID
        self.sourceAnalysisRecordID = sourceAnalysisRecordID
        self.evidenceSummary = evidenceSummary
        self.createdAt = createdAt
    }
}
