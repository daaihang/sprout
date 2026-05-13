import Foundation

struct RecordAnalysisSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var recordID: UUID
    var summary: String
    var themes: [String]
    var emotionInterpretation: String
    var followUpCandidates: [String]
    var entityMentions: [EntityReference]
    var salienceScore: Double?
    var retrievalTerms: [String]
    var reflectionHint: String?
    var candidateEdges: [CandidateEdge]
    var createdAt: Date

    struct CandidateEdge: Codable, Hashable, Sendable {
        var fromName: String
        var fromKind: String
        var toName: String
        var toKind: String
        var relation: String

        init(
            fromName: String,
            fromKind: String,
            toName: String,
            toKind: String,
            relation: String
        ) {
            self.fromName = fromName
            self.fromKind = fromKind
            self.toName = toName
            self.toKind = toKind
            self.relation = relation
        }
    }

    init(
        id: UUID = UUID(),
        recordID: UUID,
        summary: String,
        themes: [String],
        emotionInterpretation: String,
        followUpCandidates: [String] = [],
        entityMentions: [EntityReference] = [],
        salienceScore: Double? = nil,
        retrievalTerms: [String] = [],
        reflectionHint: String? = nil,
        candidateEdges: [CandidateEdge] = [],
        createdAt: Date
    ) {
        self.id = id
        self.recordID = recordID
        self.summary = summary
        self.themes = themes
        self.emotionInterpretation = emotionInterpretation
        self.followUpCandidates = followUpCandidates
        self.entityMentions = entityMentions
        self.salienceScore = salienceScore
        self.retrievalTerms = retrievalTerms
        self.reflectionHint = reflectionHint
        self.candidateEdges = candidateEdges
        self.createdAt = createdAt
    }

    var tags: [String] {
        get { themes }
        set { themes = newValue }
    }

    var emotionLabel: String {
        get { emotionInterpretation }
        set { emotionInterpretation = newValue }
    }

    var insight: String {
        get { summary }
        set { summary = newValue }
    }

    var followUpQuestion: String? {
        get { followUpCandidates.first }
        set {
            if let newValue, !newValue.isEmpty {
                if followUpCandidates.isEmpty {
                    followUpCandidates = [newValue]
                } else {
                    followUpCandidates[0] = newValue
                }
            } else if !followUpCandidates.isEmpty {
                followUpCandidates.removeFirst()
            }
        }
    }

    var entities: [EntityReference] {
        get { entityMentions }
        set { entityMentions = newValue }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case recordID
        case summary
        case themes
        case emotionInterpretation
        case followUpCandidates
        case entityMentions
        case salienceScore
        case retrievalTerms
        case reflectionHint
        case candidateEdges
        case createdAt
        case tags
        case emotionLabel
        case insight
        case followUpQuestion
        case entities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        recordID = try container.decode(UUID.self, forKey: .recordID)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .insight)
            ?? ""
        themes = try container.decodeIfPresent([String].self, forKey: .themes)
            ?? container.decodeIfPresent([String].self, forKey: .tags)
            ?? []
        emotionInterpretation = try container.decodeIfPresent(String.self, forKey: .emotionInterpretation)
            ?? container.decodeIfPresent(String.self, forKey: .emotionLabel)
            ?? ""
        if let followUps = try container.decodeIfPresent([String].self, forKey: .followUpCandidates) {
            followUpCandidates = followUps
        } else if let followUp = try container.decodeIfPresent(String.self, forKey: .followUpQuestion), !followUp.isEmpty {
            followUpCandidates = [followUp]
        } else {
            followUpCandidates = []
        }
        entityMentions = try container.decodeIfPresent([EntityReference].self, forKey: .entityMentions)
            ?? container.decodeIfPresent([EntityReference].self, forKey: .entities)
            ?? []
        salienceScore = try container.decodeIfPresent(Double.self, forKey: .salienceScore)
        retrievalTerms = try container.decodeIfPresent([String].self, forKey: .retrievalTerms) ?? []
        reflectionHint = try container.decodeIfPresent(String.self, forKey: .reflectionHint)
        candidateEdges = try container.decodeIfPresent([CandidateEdge].self, forKey: .candidateEdges) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(recordID, forKey: .recordID)
        try container.encode(summary, forKey: .summary)
        try container.encode(themes, forKey: .themes)
        try container.encode(emotionInterpretation, forKey: .emotionInterpretation)
        try container.encode(followUpCandidates, forKey: .followUpCandidates)
        try container.encode(entityMentions, forKey: .entityMentions)
        try container.encodeIfPresent(salienceScore, forKey: .salienceScore)
        try container.encode(retrievalTerms, forKey: .retrievalTerms)
        try container.encodeIfPresent(reflectionHint, forKey: .reflectionHint)
        try container.encode(candidateEdges, forKey: .candidateEdges)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
