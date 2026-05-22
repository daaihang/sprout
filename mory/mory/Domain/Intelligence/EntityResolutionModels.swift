import Foundation

enum CorrectionActor: String, Codable, CaseIterable, Identifiable, Sendable {
    case user
    case localPolicy
    case aiAccepted

    var id: String { rawValue }
}

enum CorrectionEventKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case markAsMe
    case notMe
    case sameEntity
    case notSameEntity
    case splitEntity
    case roleLabel
    case roleLabelMapsToPerson
    case relationshipChanged
    case profileFieldIncorrect
    case doNotTrackTopic
    case affectCorrection

    var id: String { rawValue }
}

struct CorrectionEvent: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: CorrectionEventKind
    var actor: CorrectionActor
    var targetEntityIDs: [UUID]
    var targetRecordIDs: [UUID]
    var sourceRecordIDs: [UUID]
    var note: String?
    var metadata: [String: String]
    var isReversible: Bool
    var createdAt: Date
    var reversedAt: Date?

    init(
        id: UUID = UUID(),
        kind: CorrectionEventKind,
        actor: CorrectionActor,
        targetEntityIDs: [UUID] = [],
        targetRecordIDs: [UUID] = [],
        sourceRecordIDs: [UUID] = [],
        note: String? = nil,
        metadata: [String: String] = [:],
        isReversible: Bool = true,
        createdAt: Date = .now,
        reversedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.actor = actor
        self.targetEntityIDs = targetEntityIDs
        self.targetRecordIDs = targetRecordIDs
        self.sourceRecordIDs = sourceRecordIDs
        self.note = note
        self.metadata = metadata
        self.isReversible = isReversible
        self.createdAt = createdAt
        self.reversedAt = reversedAt
    }
}

enum EntityTombstoneReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case merged
    case split
    case deleted

    var id: String { rawValue }
}

struct EntityTombstone: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var oldEntityID: UUID
    var replacementEntityID: UUID?
    var kind: EntityKind
    var reason: EntityTombstoneReason
    var note: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        oldEntityID: UUID,
        replacementEntityID: UUID?,
        kind: EntityKind,
        reason: EntityTombstoneReason,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.oldEntityID = oldEntityID
        self.replacementEntityID = replacementEntityID
        self.kind = kind
        self.reason = reason
        self.note = note
        self.createdAt = createdAt
    }
}

struct EntityMention: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: EntityKind
    var value: String
    var sourceRecordID: UUID?
    var hintedEntityID: UUID?

    init(
        id: UUID = UUID(),
        kind: EntityKind,
        value: String,
        sourceRecordID: UUID? = nil,
        hintedEntityID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.value = value
        self.sourceRecordID = sourceRecordID
        self.hintedEntityID = hintedEntityID
    }
}

enum EntityResolutionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case resolvedEntity
    case samePersonCandidate
    case notSameDecision
    case roleLabel
    case ambiguousEntityBucket
    case mergeCandidate
    case splitCandidate

    var id: String { rawValue }
}

struct EntityResolutionLink: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var mentionID: UUID
    var mentionValue: String
    var resolvedEntityID: UUID?
    var kind: EntityResolutionKind
    var confidence: Double
    var reason: String

    init(
        id: UUID = UUID(),
        mentionID: UUID,
        mentionValue: String,
        resolvedEntityID: UUID?,
        kind: EntityResolutionKind,
        confidence: Double,
        reason: String
    ) {
        self.id = id
        self.mentionID = mentionID
        self.mentionValue = mentionValue
        self.resolvedEntityID = resolvedEntityID
        self.kind = kind
        self.confidence = confidence
        self.reason = reason
    }
}

struct AmbiguousEntityBucket: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var label: String
    var candidateEntityIDs: [UUID]
    var reason: String

    init(id: UUID = UUID(), label: String, candidateEntityIDs: [UUID], reason: String) {
        self.id = id
        self.label = label
        self.candidateEntityIDs = candidateEntityIDs
        self.reason = reason
    }
}

struct EntityMergeProposal: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var primaryEntityID: UUID
    var mergingEntityID: UUID
    var confidence: Double
    var reason: String

    init(
        id: UUID = UUID(),
        primaryEntityID: UUID,
        mergingEntityID: UUID,
        confidence: Double,
        reason: String
    ) {
        self.id = id
        self.primaryEntityID = primaryEntityID
        self.mergingEntityID = mergingEntityID
        self.confidence = confidence
        self.reason = reason
    }
}

struct EntitySplitProposal: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var entityID: UUID
    var confidence: Double
    var reason: String

    init(id: UUID = UUID(), entityID: UUID, confidence: Double, reason: String) {
        self.id = id
        self.entityID = entityID
        self.confidence = confidence
        self.reason = reason
    }
}

struct EntityResolutionContext: Codable, Hashable, Sendable {
    var selfProfile: SelfProfile
    var existingProfiles: [EntityProfile]
    var correctionEvents: [CorrectionEvent]
    var now: Date

    init(
        selfProfile: SelfProfile,
        existingProfiles: [EntityProfile],
        correctionEvents: [CorrectionEvent] = [],
        now: Date = .now
    ) {
        self.selfProfile = selfProfile
        self.existingProfiles = existingProfiles
        self.correctionEvents = correctionEvents
        self.now = now
    }
}

struct EntityResolutionResult: Codable, Hashable, Sendable {
    var links: [EntityResolutionLink]
    var ambiguousBuckets: [AmbiguousEntityBucket]
    var mergeProposals: [EntityMergeProposal]
    var splitProposals: [EntitySplitProposal]

    init(
        links: [EntityResolutionLink] = [],
        ambiguousBuckets: [AmbiguousEntityBucket] = [],
        mergeProposals: [EntityMergeProposal] = [],
        splitProposals: [EntitySplitProposal] = []
    ) {
        self.links = links
        self.ambiguousBuckets = ambiguousBuckets
        self.mergeProposals = mergeProposals
        self.splitProposals = splitProposals
    }
}
