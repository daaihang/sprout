import Foundation

struct AnalysisRequestPayload: Codable, Sendable {
    var clientRequestID: String
    var recordShell: AnalysisRecordPayload.RecordShellPayload
    var artifacts: [AnalysisRecordPayload.ArtifactPayload]
    var semanticDigests: [SemanticDigestPayload]
    var arrangementExclusion: ArrangementExclusionPayload?
    var knownEntities: [AnalysisRecordPayload.KnownEntityPayload]
    var moodEvidence: [MoodEvidencePayload]
    var contextPack: ContextPackPayload
    var clientCapabilities: ClientCapabilitiesPayload
    var debugOptions: AnalysisRecordPayload.DebugOptionsPayload?

    enum CodingKeys: String, CodingKey {
        case clientRequestID = "client_request_id"
        case recordShell = "record_shell"
        case artifacts
        case semanticDigests = "semantic_digests"
        case arrangementExclusion = "arrangement_exclusion"
        case knownEntities = "known_entities"
        case moodEvidence = "mood_evidence"
        case contextPack = "context_pack"
        case clientCapabilities = "client_capabilities"
        case debugOptions = "debug_options"
    }

    struct SemanticDigestPayload: Codable, Sendable, Equatable {
        var id: String
        var recordID: String
        var artifactID: String
        var artifactKind: String
        var source: String
        var summary: String?
        var caption: String?
        var ocrText: String?
        var visualLabels: [String]
        var transcript: String?
        var languageCode: String?
        var durationSeconds: Double?
        var width: Int?
        var height: Int?
        var captureDate: String?
        var localIdentifier: String?
        var technicalNotes: [String]

        enum CodingKeys: String, CodingKey {
            case id
            case recordID = "record_id"
            case artifactID = "artifact_id"
            case artifactKind = "artifact_kind"
            case source
            case summary
            case caption
            case ocrText = "ocr_text"
            case visualLabels = "visual_labels"
            case transcript
            case languageCode = "language_code"
            case durationSeconds = "duration_seconds"
            case width
            case height
            case captureDate = "capture_date"
            case localIdentifier = "local_identifier"
            case technicalNotes = "technical_notes"
        }
    }

    struct ArrangementExclusionPayload: Codable, Sendable, Equatable {
        var excludedCardArrangementID: String?
        var reason: String

        enum CodingKeys: String, CodingKey {
            case excludedCardArrangementID = "excluded_card_arrangement_id"
            case reason
        }
    }

    struct MoodEvidencePayload: Codable, Sendable {
        var id: String
        var recordID: String
        var valence: Double?
        var arousal: Double?
        var dominance: Double?
        var intensity: Double?
        var labels: [String]
        var toneHints: [String]
        var sources: [String]
        var confidence: Double?
        var userConfirmed: Bool
        var evidence: [EvidencePayload]

        enum CodingKeys: String, CodingKey {
            case id
            case recordID = "record_id"
            case valence
            case arousal
            case dominance
            case intensity
            case labels
            case toneHints = "tone_hints"
            case sources
            case confidence
            case userConfirmed = "user_confirmed"
            case evidence
        }
    }

    struct EvidencePayload: Codable, Sendable, Equatable {
        var recordID: String?
        var artifactID: String?
        var snippet: String
        var createdAt: String?

        enum CodingKeys: String, CodingKey {
            case recordID = "record_id"
            case artifactID = "artifact_id"
            case snippet
            case createdAt = "created_at"
        }
    }

    struct ContextPackPayload: Codable, Sendable {
        var packID: String
        var targetRecordID: String
        var selfBrief: SelfBriefPayload?
        var knownProfiles: [KnownProfilePayload]
        var relatedMemories: [RelatedMemoryPayload]
        var relatedArcs: [RelatedArcPayload]
        var priorReflections: [PriorReflectionPayload]
        var correctionSignals: [CorrectionSignalPayload]
        var affectHistory: [AffectHistoryPayload]
        var privacyDecisions: [PrivacyDecisionPayload]
        var budgetReport: BudgetReportPayload
        var retrievalReport: RetrievalReportPayload
        var builtAt: String

        enum CodingKeys: String, CodingKey {
            case packID = "pack_id"
            case targetRecordID = "target_record_id"
            case selfBrief = "self_brief"
            case knownProfiles = "known_profiles"
            case relatedMemories = "related_memories"
            case relatedArcs = "related_arcs"
            case priorReflections = "prior_reflections"
            case correctionSignals = "correction_signals"
            case affectHistory = "affect_history"
            case privacyDecisions = "privacy_decisions"
            case budgetReport = "budget_report"
            case retrievalReport = "retrieval_report"
            case builtAt = "built_at"
        }
    }

    struct SelfBriefPayload: Codable, Sendable {
        var selfEntityID: String
        var displayName: String?
        var aliases: [String]
        var roleLabels: [String]
        var goalTitles: [String]
        var expressionHints: [String]
        var privacyMode: String

        enum CodingKeys: String, CodingKey {
            case selfEntityID = "self_entity_id"
            case displayName = "display_name"
            case aliases
            case roleLabels = "role_labels"
            case goalTitles = "goal_titles"
            case expressionHints = "expression_hints"
            case privacyMode = "privacy_mode"
        }
    }

    struct KnownProfilePayload: Codable, Sendable {
        var entityID: String
        var kind: String
        var displayName: String
        var relationshipToUser: String?
        var mentionCount: Int
        var commonContextLabels: [String]
        var confidence: Double?
        var inclusionReason: String

        enum CodingKeys: String, CodingKey {
            case entityID = "entity_id"
            case kind
            case displayName = "display_name"
            case relationshipToUser = "relationship_to_user"
            case mentionCount = "mention_count"
            case commonContextLabels = "common_context_labels"
            case confidence
            case inclusionReason = "inclusion_reason"
        }
    }

    struct RelatedMemoryPayload: Codable, Sendable {
        var recordID: String
        var title: String
        var snippet: String
        var createdAt: String
        var userMood: String?
        var score: Double
        var inclusionReasons: [String]

        enum CodingKeys: String, CodingKey {
            case recordID = "record_id"
            case title
            case snippet
            case createdAt = "created_at"
            case userMood = "user_mood"
            case score
            case inclusionReasons = "inclusion_reasons"
        }
    }

    struct RelatedArcPayload: Codable, Sendable {
        var arcID: String
        var title: String
        var summary: String
        var status: String
        var sourceRecordIDs: [String]
        var score: Double

        enum CodingKeys: String, CodingKey {
            case arcID = "arc_id"
            case title
            case summary
            case status
            case sourceRecordIDs = "source_record_ids"
            case score
        }
    }

    struct PriorReflectionPayload: Codable, Sendable {
        var reflectionID: String
        var title: String
        var evidenceSummary: String
        var status: String
        var sourceRecordIDs: [String]
        var confidence: Double

        enum CodingKeys: String, CodingKey {
            case reflectionID = "reflection_id"
            case title
            case evidenceSummary = "evidence_summary"
            case status
            case sourceRecordIDs = "source_record_ids"
            case confidence
        }
    }

    struct CorrectionSignalPayload: Codable, Sendable {
        var id: String
        var kind: String
        var targetType: String
        var targetID: String
        var status: String
        var summary: String
        var answeredAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case kind
            case targetType = "target_type"
            case targetID = "target_id"
            case status
            case summary
            case answeredAt = "answered_at"
        }
    }

    struct AffectHistoryPayload: Codable, Sendable {
        var mood: String
        var count: Int
        var latestRecordID: String
        var averageValence: Double?
        var averageArousal: Double?
        var averageDominance: Double?
        var toneHints: [String]
        var sources: [String]

        enum CodingKeys: String, CodingKey {
            case mood
            case count
            case latestRecordID = "latest_record_id"
            case averageValence = "average_valence"
            case averageArousal = "average_arousal"
            case averageDominance = "average_dominance"
            case toneHints = "tone_hints"
            case sources
        }
    }

    struct PrivacyDecisionPayload: Codable, Sendable {
        var sourceType: String
        var sourceID: String?
        var action: String
        var reason: String

        enum CodingKeys: String, CodingKey {
            case sourceType = "source_type"
            case sourceID = "source_id"
            case action
            case reason
        }
    }

    struct BudgetReportPayload: Codable, Sendable {
        var maxProfiles: Int
        var maxRelatedMemories: Int
        var maxArcs: Int
        var maxReflections: Int
        var maxCorrections: Int
        var maxAffectHistory: Int
        var selectedProfiles: Int
        var selectedRelatedMemories: Int
        var selectedArcs: Int
        var selectedReflections: Int
        var selectedCorrections: Int
        var selectedAffectHistory: Int
        var droppedByBudget: Int
        var droppedByPrivacy: Int

        enum CodingKeys: String, CodingKey {
            case maxProfiles = "max_profiles"
            case maxRelatedMemories = "max_related_memories"
            case maxArcs = "max_arcs"
            case maxReflections = "max_reflections"
            case maxCorrections = "max_corrections"
            case maxAffectHistory = "max_affect_history"
            case selectedProfiles = "selected_profiles"
            case selectedRelatedMemories = "selected_related_memories"
            case selectedArcs = "selected_arcs"
            case selectedReflections = "selected_reflections"
            case selectedCorrections = "selected_corrections"
            case selectedAffectHistory = "selected_affect_history"
            case droppedByBudget = "dropped_by_budget"
            case droppedByPrivacy = "dropped_by_privacy"
        }
    }

    struct RetrievalReportPayload: Codable, Sendable {
        var semanticSearchStatus: String
        var retrievalSources: [String]
        var candidateMemoryCount: Int
        var fallbackReason: String?

        enum CodingKeys: String, CodingKey {
            case semanticSearchStatus = "semantic_search_status"
            case retrievalSources = "retrieval_sources"
            case candidateMemoryCount = "candidate_memory_count"
            case fallbackReason = "fallback_reason"
        }
    }

    struct ClientCapabilitiesPayload: Codable, Sendable {
        var supportsProfileProposals: Bool
        var supportsMergeCandidates: Bool
        var supportsAffectSnapshot: Bool
        var supportsContextAwareReflection: Bool
        var supportsProposalOnlyWriteback: Bool

        enum CodingKeys: String, CodingKey {
            case supportsProfileProposals = "supports_profile_proposals"
            case supportsMergeCandidates = "supports_merge_candidates"
            case supportsAffectSnapshot = "supports_affect_snapshot"
            case supportsContextAwareReflection = "supports_context_aware_reflection"
            case supportsProposalOnlyWriteback = "supports_proposal_only_writeback"
        }

        static let moryDefault = ClientCapabilitiesPayload(
            supportsProfileProposals: true,
            supportsMergeCandidates: true,
            supportsAffectSnapshot: true,
            supportsContextAwareReflection: true,
            supportsProposalOnlyWriteback: true
        )
    }
}
