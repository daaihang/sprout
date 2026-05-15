import Foundation

// MARK: - Record Analysis Snapshot

struct RecordAnalysisSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var recordID: UUID
    var summary: String
    var themes: [String]
    var emotionInterpretation: String
    var salienceScore: Double?
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
        themes: [String] = [],
        emotionInterpretation: String = "",
        salienceScore: Double? = nil,
        retrievalTerms: [String] = [],
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

// MARK: - Candidate Entity Edge

struct CandidateEntityEdge: Codable, Hashable, Sendable {
    var from: EntityReference
    var to: EntityReference
    var relationKind: EntityRelationKind
    var confidence: Double?
}

// MARK: - Follow-Up Candidate

struct FollowUpCandidate: Codable, Hashable, Sendable {
    var prompt: String
    var reason: String?
}
