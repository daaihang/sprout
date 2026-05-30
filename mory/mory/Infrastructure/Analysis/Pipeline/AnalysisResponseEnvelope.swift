import Foundation

struct AnalysisResponseEnvelope: Codable, Sendable {
    var analysis: AnalysisRecordResponse
    var affectProposals: [AffectProposal]
    var graphDeltaProposals: [GraphDeltaProposal]
    var profileUpdateProposals: [ProfileUpdateProposal]
    var mergeSplitCandidates: [MergeSplitCandidate]
    var arcCandidates: [ArcCandidate]
    var reflectionCandidates: [ReflectionCandidate]
    var questionCandidates: [QuestionCandidate]
    var quality: Quality
    var meta: MoryAPIClient.CloudIntelligenceMeta?

    enum CodingKeys: String, CodingKey {
        case analysis
        case affectProposals = "affect_proposals"
        case graphDeltaProposals = "graph_delta_proposals"
        case profileUpdateProposals = "profile_update_proposals"
        case mergeSplitCandidates = "merge_split_candidates"
        case arcCandidates = "arc_candidates"
        case reflectionCandidates = "reflection_candidates"
        case questionCandidates = "question_candidates"
        case quality
        case meta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        analysis = try container.decode(AnalysisRecordResponse.self, forKey: .analysis)
        affectProposals = try container.decodeIfPresent([AffectProposal].self, forKey: .affectProposals) ?? []
        graphDeltaProposals = try container.decodeIfPresent([GraphDeltaProposal].self, forKey: .graphDeltaProposals) ?? []
        profileUpdateProposals = try container.decodeIfPresent([ProfileUpdateProposal].self, forKey: .profileUpdateProposals) ?? []
        mergeSplitCandidates = try container.decodeIfPresent([MergeSplitCandidate].self, forKey: .mergeSplitCandidates) ?? []
        arcCandidates = try container.decodeIfPresent([ArcCandidate].self, forKey: .arcCandidates) ?? []
        reflectionCandidates = try container.decodeIfPresent([ReflectionCandidate].self, forKey: .reflectionCandidates) ?? []
        questionCandidates = try container.decodeIfPresent([QuestionCandidate].self, forKey: .questionCandidates) ?? []
        quality = try container.decodeIfPresent(Quality.self, forKey: .quality) ?? Quality()
        meta = try container.decodeIfPresent(MoryAPIClient.CloudIntelligenceMeta.self, forKey: .meta)
    }

    init(
        analysis: AnalysisRecordResponse,
        affectProposals: [AffectProposal] = [],
        graphDeltaProposals: [GraphDeltaProposal] = [],
        profileUpdateProposals: [ProfileUpdateProposal] = [],
        mergeSplitCandidates: [MergeSplitCandidate] = [],
        arcCandidates: [ArcCandidate] = [],
        reflectionCandidates: [ReflectionCandidate] = [],
        questionCandidates: [QuestionCandidate] = [],
        quality: Quality = Quality(),
        meta: MoryAPIClient.CloudIntelligenceMeta? = nil
    ) {
        self.analysis = analysis
        self.affectProposals = affectProposals
        self.graphDeltaProposals = graphDeltaProposals
        self.profileUpdateProposals = profileUpdateProposals
        self.mergeSplitCandidates = mergeSplitCandidates
        self.arcCandidates = arcCandidates
        self.reflectionCandidates = reflectionCandidates
        self.questionCandidates = questionCandidates
        self.quality = quality
        self.meta = meta
    }

    struct AffectProposal: Codable, Sendable {
        var proposalID: String?
        var valence: Double?
        var arousal: Double?
        var dominance: Double?
        var intensity: Double?
        var labels: [String]
        var toneHints: [String]
        var appraisal: AffectAppraisal?
        var confidence: Double?
        var evidence: [AnalysisRequestPayload.EvidencePayload]
        var requiresConfirmation: Bool
        var rawInput: String?

        enum CodingKeys: String, CodingKey {
            case proposalID = "proposal_id"
            case valence
            case arousal
            case dominance
            case intensity
            case labels
            case toneHints = "tone_hints"
            case appraisal
            case confidence
            case evidence
            case requiresConfirmation = "requires_confirmation"
            case rawInput = "raw_input"
        }
    }

    struct GraphDeltaProposal: Codable, Sendable {
        var proposalID: String?
        var operations: [Operation]
        var confidence: Double?
        var requiresConfirmation: Bool
        var evidence: [AnalysisRequestPayload.EvidencePayload]

        enum CodingKeys: String, CodingKey {
            case proposalID = "proposal_id"
            case operations
            case confidence
            case requiresConfirmation = "requires_confirmation"
            case evidence
        }

        struct Operation: Codable, Sendable {
            var kind: String
            var targetType: String
            var targetID: String
            var relatedID: String?
            var stringValue: String?
            var numericValue: Double?
            var metadata: [String: String]

            enum CodingKeys: String, CodingKey {
                case kind
                case targetType = "target_type"
                case targetID = "target_id"
                case relatedID = "related_id"
                case stringValue = "string_value"
                case numericValue = "numeric_value"
                case metadata
            }
        }
    }

    struct ProfileUpdateProposal: Codable, Sendable {
        var proposalID: String?
        var targetEntityID: String
        var profileKind: String
        var field: String
        var proposedValue: String
        var confidence: Double?
        var evidence: [AnalysisRequestPayload.EvidencePayload]
        var requiresConfirmation: Bool

        enum CodingKeys: String, CodingKey {
            case proposalID = "proposal_id"
            case targetEntityID = "target_entity_id"
            case profileKind = "profile_kind"
            case field
            case proposedValue = "proposed_value"
            case confidence
            case evidence
            case requiresConfirmation = "requires_confirmation"
        }
    }

    struct MergeSplitCandidate: Codable, Sendable {
        var candidateID: String?
        var kind: String
        var sourceEntityIDs: [String]
        var targetEntityID: String?
        var confidence: Double?
        var positiveEvidence: [AnalysisRequestPayload.EvidencePayload]
        var negativeEvidence: [AnalysisRequestPayload.EvidencePayload]
        var question: String?

        enum CodingKeys: String, CodingKey {
            case candidateID = "candidate_id"
            case kind
            case sourceEntityIDs = "source_entity_ids"
            case targetEntityID = "target_entity_id"
            case confidence
            case positiveEvidence = "positive_evidence"
            case negativeEvidence = "negative_evidence"
            case question
        }
    }

    struct ArcCandidate: Codable, Sendable {
        var candidateID: String?
        var title: String
        var summary: String
        var sourceRecordIDs: [String]
        var confidence: Double?

        enum CodingKeys: String, CodingKey {
            case candidateID = "candidate_id"
            case title
            case summary
            case sourceRecordIDs = "source_record_ids"
            case confidence
        }
    }

    struct ReflectionCandidate: Codable, Sendable {
        var candidateID: String?
        var title: String
        var body: String
        var evidenceSummary: String
        var confidence: Double
        var sourceRecordIDs: [String]
        var sourceArtifactIDs: [String]
        var sourceEntityIDs: [String]

        enum CodingKeys: String, CodingKey {
            case candidateID = "candidate_id"
            case title
            case body
            case evidenceSummary = "evidence_summary"
            case confidence
            case sourceRecordIDs = "source_record_ids"
            case sourceArtifactIDs = "source_artifact_ids"
            case sourceEntityIDs = "source_entity_ids"
        }
    }

    struct QuestionCandidate: Codable, Sendable {
        var candidateID: String?
        var kind: String
        var prompt: String
        var reason: String
        var candidateAnswers: [String]
        var confidence: Double
        var sensitivity: String
        var targetType: String?
        var targetID: String?
        var sourceRecordIDs: [String]
        var sourceArtifactIDs: [String]

        enum CodingKeys: String, CodingKey {
            case candidateID = "candidate_id"
            case kind
            case prompt
            case reason
            case candidateAnswers = "candidate_answers"
            case confidence
            case sensitivity
            case targetType = "target_type"
            case targetID = "target_id"
            case sourceRecordIDs = "source_record_ids"
            case sourceArtifactIDs = "source_artifact_ids"
        }
    }

    struct Quality: Codable, Sendable, Equatable {
        var confidence: Double
        var uncertaintyReasons: [String]
        var needsUserCheck: [String]

        enum CodingKeys: String, CodingKey {
            case confidence
            case uncertaintyReasons = "uncertainty_reasons"
            case needsUserCheck = "needs_user_check"
        }

        init(confidence: Double = 0, uncertaintyReasons: [String] = [], needsUserCheck: [String] = []) {
            self.confidence = confidence
            self.uncertaintyReasons = uncertaintyReasons
            self.needsUserCheck = needsUserCheck
        }
    }
}
