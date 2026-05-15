import Foundation

struct CandidateEntityEdge: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var from: EntityReference
    var to: EntityReference
    var relationKind: EntityRelationKind
    var confidence: Double?

    init(
        id: UUID = UUID(),
        from: EntityReference,
        to: EntityReference,
        relationKind: EntityRelationKind,
        confidence: Double? = nil
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.relationKind = relationKind
        self.confidence = confidence
    }
}

struct FollowUpCandidate: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var prompt: String
    var reason: String?

    init(
        id: UUID = UUID(),
        prompt: String,
        reason: String? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.reason = reason
    }
}

struct RecordAnalysisSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var recordID: UUID
    var summary: String
    var themes: [String]
    var emotionInterpretation: String
    var salienceScore: Double
    var retrievalTerms: [String]
    var entityMentions: [EntityReference]
    var candidateEdges: [CandidateEntityEdge]
    var followUpCandidates: [FollowUpCandidate]
    var reflectionHint: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        recordID: UUID,
        summary: String,
        themes: [String],
        emotionInterpretation: String,
        salienceScore: Double,
        retrievalTerms: [String],
        entityMentions: [EntityReference] = [],
        candidateEdges: [CandidateEntityEdge] = [],
        followUpCandidates: [FollowUpCandidate] = [],
        reflectionHint: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.recordID = recordID
        self.summary = summary
        self.themes = themes
        self.emotionInterpretation = emotionInterpretation
        self.salienceScore = salienceScore
        self.retrievalTerms = retrievalTerms
        self.entityMentions = entityMentions
        self.candidateEdges = candidateEdges
        self.followUpCandidates = followUpCandidates
        self.reflectionHint = reflectionHint
        self.createdAt = createdAt
    }
}

enum ReflectionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case pattern
    case relationship
    case phase
    case record

    var id: String { rawValue }
}

enum ReflectionStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case suggested
    case saved
    case archived
    case dismissed

    var id: String { rawValue }
}

extension ReflectionStatus {
    var label: String {
        switch self {
        case .suggested:
            return "Suggested"
        case .saved:
            return "Saved"
        case .archived:
            return "Archived"
        case .dismissed:
            return "Dismissed"
        }
    }
}

extension ReflectionSnapshot {
    var statusLabel: String { status.label }
}

struct ReflectionSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var type: ReflectionType
    var title: String
    var body: String
    var evidenceSummary: String
    var confidence: Double
    var status: ReflectionStatus
    var linkedTemporalArcID: UUID?
    var sourceRecordIDs: [UUID]
    var sourceArtifactIDs: [UUID]
    var sourceEntityIDs: [UUID]
    var createdAt: Date
    var savedAt: Date?
    var dismissedAt: Date?

    init(
        id: UUID = UUID(),
        type: ReflectionType,
        title: String,
        body: String,
        evidenceSummary: String,
        confidence: Double,
        status: ReflectionStatus,
        linkedTemporalArcID: UUID? = nil,
        sourceRecordIDs: [UUID],
        sourceArtifactIDs: [UUID],
        sourceEntityIDs: [UUID] = [],
        createdAt: Date,
        savedAt: Date? = nil,
        dismissedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.evidenceSummary = evidenceSummary
        self.confidence = confidence
        self.status = status
        self.linkedTemporalArcID = linkedTemporalArcID
        self.sourceRecordIDs = sourceRecordIDs
        self.sourceArtifactIDs = sourceArtifactIDs
        self.sourceEntityIDs = sourceEntityIDs
        self.createdAt = createdAt
        self.savedAt = savedAt
        self.dismissedAt = dismissedAt
    }
}

enum TemporalArcStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case candidate
    case accepted
    case archived

    var id: String { rawValue }
}

struct TemporalArc: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var summary: String
    var status: TemporalArcStatus
    var dominantTheme: String?
    var dominantEntityName: String?
    var themeLabels: [String]
    var entityNames: [String]
    var linkedReflectionID: UUID?
    var mergedFromArcIDs: [UUID]
    var mergedIntoArcID: UUID?
    var lastMergedAt: Date?
    var sourceRecordIDs: [UUID]
    var sourceArtifactIDs: [UUID]
    var sourceEntityIDs: [UUID]
    var startDate: Date
    var endDate: Date
    var intensityScore: Double
    var clusterStrength: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        status: TemporalArcStatus,
        dominantTheme: String? = nil,
        dominantEntityName: String? = nil,
        themeLabels: [String],
        entityNames: [String],
        linkedReflectionID: UUID? = nil,
        mergedFromArcIDs: [UUID] = [],
        mergedIntoArcID: UUID? = nil,
        lastMergedAt: Date? = nil,
        sourceRecordIDs: [UUID],
        sourceArtifactIDs: [UUID],
        sourceEntityIDs: [UUID],
        startDate: Date,
        endDate: Date,
        intensityScore: Double,
        clusterStrength: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.status = status
        self.dominantTheme = dominantTheme
        self.dominantEntityName = dominantEntityName
        self.themeLabels = themeLabels
        self.entityNames = entityNames
        self.linkedReflectionID = linkedReflectionID
        self.mergedFromArcIDs = mergedFromArcIDs
        self.mergedIntoArcID = mergedIntoArcID
        self.lastMergedAt = lastMergedAt
        self.sourceRecordIDs = sourceRecordIDs
        self.sourceArtifactIDs = sourceArtifactIDs
        self.sourceEntityIDs = sourceEntityIDs
        self.startDate = startDate
        self.endDate = endDate
        self.intensityScore = intensityScore
        self.clusterStrength = clusterStrength
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
