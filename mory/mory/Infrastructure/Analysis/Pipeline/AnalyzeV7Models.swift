import Foundation

struct AnalyzeV7RequestBuilder {
    private let legacyBuilder = AnalyzeRequestBuilder()
    private let dateFormatter = ISO8601DateFormatter()

    func build(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference] = [],
        contextPack: AnalysisContextPack,
        affectSnapshots: [AffectSnapshot] = [],
        clientRequestID: UUID = UUID(),
        analysisReason: String = "capture_ingest_context_v7"
    ) -> AnalyzeV7RequestPayload {
        let legacy = legacyBuilder.build(
            record: record,
            artifacts: artifacts,
            knownEntities: knownEntities,
            analysisReason: analysisReason,
            schemaVersion: "analyze.v7",
            clientVersion: "mory.v7"
        )
        return AnalyzeV7RequestPayload(
            clientRequestID: clientRequestID.uuidString,
            recordShell: legacy.recordShell,
            artifacts: legacy.artifacts,
            knownEntities: legacy.knownEntities,
            moodEvidence: affectSnapshots.map(moodEvidencePayload),
            contextPack: contextPayload(contextPack),
            clientCapabilities: .moryV7Default,
            debugOptions: legacy.debugOptions
        )
    }

    private func moodEvidencePayload(_ snapshot: AffectSnapshot) -> AnalyzeV7RequestPayload.MoodEvidencePayload {
        AnalyzeV7RequestPayload.MoodEvidencePayload(
            id: snapshot.id.uuidString,
            recordID: snapshot.recordID.uuidString,
            valence: snapshot.valence,
            arousal: snapshot.arousal,
            dominance: snapshot.dominance,
            intensity: snapshot.intensity,
            labels: snapshot.labels.map(\.rawValue),
            toneHints: snapshot.toneHints.map(\.rawValue),
            sources: snapshot.sources.map(\.rawValue),
            confidence: snapshot.confidence,
            userConfirmed: snapshot.userConfirmed,
            evidence: snapshot.evidence.map {
                AnalyzeV7RequestPayload.EvidencePayload(
                    recordID: snapshot.recordID.uuidString,
                    artifactID: nil,
                    snippet: $0.summary,
                    createdAt: dateFormatter.string(from: $0.createdAt)
                )
            }
        )
    }

    private func contextPayload(_ pack: AnalysisContextPack) -> AnalyzeV7RequestPayload.ContextPackPayload {
        AnalyzeV7RequestPayload.ContextPackPayload(
            packID: pack.packID.uuidString,
            targetRecordID: pack.targetRecordID.uuidString,
            selfBrief: pack.selfBrief.map { brief in
                AnalyzeV7RequestPayload.SelfBriefPayload(
                    selfEntityID: brief.selfEntityID.uuidString,
                    displayName: brief.displayName,
                    aliases: brief.aliases,
                    roleLabels: brief.roleLabels,
                    goalTitles: brief.goalTitles,
                    expressionHints: brief.expressionHints,
                    privacyMode: brief.privacyMode.rawValue
                )
            },
            knownProfiles: pack.relatedProfiles.map {
                AnalyzeV7RequestPayload.KnownProfilePayload(
                    entityID: $0.entityID.uuidString,
                    kind: $0.kind.rawValue,
                    displayName: $0.displayName,
                    relationshipToUser: $0.relationshipToUser?.rawValue,
                    mentionCount: $0.mentionCount,
                    commonContextLabels: $0.commonContextLabels,
                    confidence: $0.confidence,
                    inclusionReason: $0.inclusionReason
                )
            },
            relatedMemories: pack.relatedMemories.map {
                AnalyzeV7RequestPayload.RelatedMemoryPayload(
                    recordID: $0.recordID.uuidString,
                    title: $0.title,
                    snippet: $0.snippet,
                    createdAt: dateFormatter.string(from: $0.createdAt),
                    userMood: $0.userMood,
                    score: $0.scoreBreakdown.total,
                    inclusionReasons: $0.inclusionReasons
                )
            },
            relatedArcs: pack.relatedArcs.map {
                AnalyzeV7RequestPayload.RelatedArcPayload(
                    arcID: $0.arcID.uuidString,
                    title: $0.title,
                    summary: $0.summary,
                    status: $0.status.rawValue,
                    sourceRecordIDs: $0.sourceRecordIDs.map(\.uuidString),
                    score: $0.score
                )
            },
            priorReflections: pack.priorReflections.map {
                AnalyzeV7RequestPayload.PriorReflectionPayload(
                    reflectionID: $0.reflectionID.uuidString,
                    title: $0.title,
                    evidenceSummary: $0.evidenceSummary,
                    status: $0.status.rawValue,
                    sourceRecordIDs: $0.sourceRecordIDs.map(\.uuidString),
                    confidence: $0.confidence
                )
            },
            correctionSignals: pack.correctionSignals.map {
                AnalyzeV7RequestPayload.CorrectionSignalPayload(
                    id: $0.id.uuidString,
                    kind: $0.kind.rawValue,
                    targetType: $0.targetType.rawValue,
                    targetID: $0.targetID.uuidString,
                    status: $0.status.rawValue,
                    summary: $0.summary,
                    answeredAt: $0.answeredAt.map { dateFormatter.string(from: $0) }
                )
            },
            affectHistory: pack.affectHistory.map {
                AnalyzeV7RequestPayload.AffectHistoryPayload(
                    mood: $0.mood,
                    count: $0.count,
                    latestRecordID: $0.latestRecordID.uuidString,
                    averageValence: $0.averageValence,
                    averageArousal: $0.averageArousal,
                    averageDominance: $0.averageDominance,
                    toneHints: $0.toneHints.map(\.rawValue),
                    sources: $0.sources.map(\.rawValue)
                )
            },
            privacyDecisions: pack.privacyDecisions.map {
                AnalyzeV7RequestPayload.PrivacyDecisionPayload(
                    sourceType: $0.sourceType,
                    sourceID: $0.sourceID?.uuidString,
                    action: $0.action.rawValue,
                    reason: $0.reason
                )
            },
            budgetReport: AnalyzeV7RequestPayload.BudgetReportPayload(
                maxProfiles: pack.budget.limits.maxProfiles,
                maxRelatedMemories: pack.budget.limits.maxRelatedMemories,
                maxArcs: pack.budget.limits.maxArcs,
                maxReflections: pack.budget.limits.maxReflections,
                maxCorrections: pack.budget.limits.maxCorrections,
                maxAffectHistory: pack.budget.limits.maxAffectHistory,
                selectedProfiles: pack.budget.selectedProfiles,
                selectedRelatedMemories: pack.budget.selectedRelatedMemories,
                selectedArcs: pack.budget.selectedArcs,
                selectedReflections: pack.budget.selectedReflections,
                selectedCorrections: pack.budget.selectedCorrections,
                selectedAffectHistory: pack.budget.selectedAffectHistory,
                droppedByBudget: pack.budget.droppedByBudget,
                droppedByPrivacy: pack.budget.droppedByPrivacy
            ),
            retrievalReport: AnalyzeV7RequestPayload.RetrievalReportPayload(
                semanticSearchStatus: pack.retrieval.semanticSearchStatus,
                retrievalSources: pack.retrieval.retrievalSources,
                candidateMemoryCount: pack.retrieval.candidateMemoryCount,
                fallbackReason: pack.retrieval.fallbackReason
            ),
            builtAt: dateFormatter.string(from: pack.builtAt)
        )
    }
}

struct AnalyzeV7RequestPayload: Codable, Sendable {
    var schemaVersion: Int = 7
    var clientRequestID: String
    var recordShell: AnalyzeRequestPayload.RecordShellPayload
    var artifacts: [AnalyzeRequestPayload.ArtifactPayload]
    var knownEntities: [AnalyzeRequestPayload.KnownEntityPayload]
    var moodEvidence: [MoodEvidencePayload]
    var contextPack: ContextPackPayload
    var clientCapabilities: ClientCapabilitiesPayload
    var debugOptions: AnalyzeRequestPayload.DebugOptionsPayload?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case clientRequestID = "client_request_id"
        case recordShell = "record_shell"
        case artifacts
        case knownEntities = "known_entities"
        case moodEvidence = "mood_evidence"
        case contextPack = "context_pack"
        case clientCapabilities = "client_capabilities"
        case debugOptions = "debug_options"
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

        static let moryV7Default = ClientCapabilitiesPayload(
            supportsProfileProposals: true,
            supportsMergeCandidates: true,
            supportsAffectSnapshot: true,
            supportsContextAwareReflection: true,
            supportsProposalOnlyWriteback: true
        )
    }
}

struct AnalyzeV7ResponseEnvelope: Codable, Sendable {
    var analysis: AnalyzeResponseEnvelope
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
        analysis = try container.decode(AnalyzeResponseEnvelope.self, forKey: .analysis)
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
        analysis: AnalyzeResponseEnvelope,
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
        var evidence: [AnalyzeV7RequestPayload.EvidencePayload]
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
        var evidence: [AnalyzeV7RequestPayload.EvidencePayload]

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
        var evidence: [AnalyzeV7RequestPayload.EvidencePayload]
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
        var positiveEvidence: [AnalyzeV7RequestPayload.EvidencePayload]
        var negativeEvidence: [AnalyzeV7RequestPayload.EvidencePayload]
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

struct AnalyzeV7MappedResult: Sendable {
    var analysis: RecordAnalysisSnapshot
    var affectProposals: [AffectSnapshot]
    var graphDeltaProposals: [GraphDelta]
    var arcProposals: [TemporalArc]
    var reflectionProposals: [ReflectionSnapshot]
    var questionProposals: [ClarificationQuestion]
    var mergeSplitQuestions: [ClarificationQuestion]
    var quality: AnalyzeV7ResponseEnvelope.Quality
}

struct AnalyzeV7ResponseMapper {
    private let legacyMapper = AnalyzeResponseMapper()

    func map(recordID: UUID, response: AnalyzeV7ResponseEnvelope, createdAt: Date = .now) -> AnalyzeV7MappedResult {
        AnalyzeV7MappedResult(
            analysis: legacyMapper.map(recordID: recordID, response: response.analysis, createdAt: createdAt),
            affectProposals: mapAffectProposals(recordID: recordID, response.affectProposals, createdAt: createdAt),
            graphDeltaProposals: mapGraphDeltaProposals(response.graphDeltaProposals, createdAt: createdAt)
                + mapProfileUpdateProposals(response.profileUpdateProposals, createdAt: createdAt),
            arcProposals: mapArcCandidates(response.arcCandidates, createdAt: createdAt),
            reflectionProposals: mapReflectionCandidates(response.reflectionCandidates, createdAt: createdAt),
            questionProposals: mapQuestionCandidates(recordID: recordID, response.questionCandidates, createdAt: createdAt),
            mergeSplitQuestions: mapMergeSplitCandidates(recordID: recordID, response.mergeSplitCandidates, createdAt: createdAt),
            quality: response.quality
        )
    }

    private func mapAffectProposals(
        recordID: UUID,
        _ proposals: [AnalyzeV7ResponseEnvelope.AffectProposal],
        createdAt: Date
    ) -> [AffectSnapshot] {
        proposals.map { proposal in
            AffectSnapshot(
                id: proposal.proposalID.flatMap(UUID.init(uuidString:)) ?? UUID(),
                recordID: recordID,
                valence: proposal.valence,
                arousal: proposal.arousal,
                dominance: proposal.dominance,
                intensity: proposal.intensity,
                labels: proposal.labels.compactMap(AffectLabel.init(rawValue:)),
                toneHints: proposal.toneHints.compactMap(ToneHint.init(rawValue:)),
                appraisal: proposal.appraisal,
                sources: [.aiInferredText],
                confidence: proposal.confidence,
                evidence: proposal.evidence.map {
                    AffectEvidence(
                        source: .aiInferredText,
                        summary: $0.snippet,
                        confidence: proposal.confidence,
                        createdAt: createdAt
                    )
                },
                userConfirmed: false,
                needsUserCheck: proposal.requiresConfirmation,
                rawInput: proposal.rawInput,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        }
    }

    private func mapGraphDeltaProposals(
        _ proposals: [AnalyzeV7ResponseEnvelope.GraphDeltaProposal],
        createdAt: Date
    ) -> [GraphDelta] {
        proposals.compactMap { proposal in
            let operations = proposal.operations.compactMap(mapOperation)
            guard !operations.isEmpty else { return nil }
            return GraphDelta(
                id: proposal.proposalID.flatMap(UUID.init(uuidString:)) ?? UUID(),
                source: .cloudAI,
                operations: operations,
                confidence: proposal.confidence,
                requiresUserConfirmation: proposal.requiresConfirmation,
                appliedAt: nil,
                createdAt: createdAt
            )
        }
    }

    private func mapProfileUpdateProposals(
        _ proposals: [AnalyzeV7ResponseEnvelope.ProfileUpdateProposal],
        createdAt: Date
    ) -> [GraphDelta] {
        proposals.compactMap { proposal in
            guard
                proposal.field == "relationshipToUser",
                let entityID = UUID(uuidString: proposal.targetEntityID)
            else { return nil }
            return GraphDelta(
                id: proposal.proposalID.flatMap(UUID.init(uuidString:)) ?? UUID(),
                source: .cloudAI,
                operations: [
                    GraphDeltaOperation(
                        kind: .setRelationship,
                        targetType: .entity,
                        targetID: entityID,
                        stringValue: proposal.proposedValue,
                        metadata: [
                            "profile_kind": proposal.profileKind,
                            "field": proposal.field,
                            "proposal_source": "analyze_v7"
                        ]
                    )
                ],
                confidence: proposal.confidence,
                requiresUserConfirmation: proposal.requiresConfirmation,
                createdAt: createdAt
            )
        }
    }

    private func mapOperation(_ operation: AnalyzeV7ResponseEnvelope.GraphDeltaProposal.Operation) -> GraphDeltaOperation? {
        guard
            let kind = GraphDeltaOperationKind(rawValue: operation.kind),
            let targetType = ClarificationTargetType(rawValue: operation.targetType),
            let targetID = UUID(uuidString: operation.targetID)
        else { return nil }
        return GraphDeltaOperation(
            kind: kind,
            targetType: targetType,
            targetID: targetID,
            relatedID: operation.relatedID.flatMap(UUID.init(uuidString:)),
            stringValue: operation.stringValue,
            numericValue: operation.numericValue,
            metadata: operation.metadata
        )
    }

    private func mapReflectionCandidates(
        _ candidates: [AnalyzeV7ResponseEnvelope.ReflectionCandidate],
        createdAt: Date
    ) -> [ReflectionSnapshot] {
        candidates.map { candidate in
            ReflectionSnapshot(
                id: candidate.candidateID.flatMap(UUID.init(uuidString:)) ?? UUID(),
                type: .record,
                title: candidate.title,
                body: candidate.body,
                evidenceSummary: candidate.evidenceSummary,
                confidence: candidate.confidence,
                status: .suggested,
                linkedTemporalArcID: nil,
                sourceRecordIDs: candidate.sourceRecordIDs.compactMap(UUID.init(uuidString:)),
                sourceArtifactIDs: candidate.sourceArtifactIDs.compactMap(UUID.init(uuidString:)),
                sourceEntityIDs: candidate.sourceEntityIDs.compactMap(UUID.init(uuidString:)),
                createdAt: createdAt
            )
        }
    }

    private func mapArcCandidates(
        _ candidates: [AnalyzeV7ResponseEnvelope.ArcCandidate],
        createdAt: Date
    ) -> [TemporalArc] {
        candidates.compactMap { candidate in
            let sourceRecordIDs = candidate.sourceRecordIDs.compactMap(UUID.init(uuidString:))
            guard !sourceRecordIDs.isEmpty else { return nil }
            return TemporalArc(
                id: candidate.candidateID.flatMap(UUID.init(uuidString:)) ?? UUID(),
                title: candidate.title,
                summary: candidate.summary,
                status: .candidate,
                sourceRecordIDs: sourceRecordIDs,
                sourceArtifactIDs: [],
                sourceEntityIDs: [],
                startDate: createdAt,
                endDate: createdAt,
                intensityScore: candidate.confidence ?? 0,
                clusterStrength: candidate.confidence ?? 0,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        }
    }

    private func mapQuestionCandidates(
        recordID: UUID,
        _ candidates: [AnalyzeV7ResponseEnvelope.QuestionCandidate],
        createdAt: Date
    ) -> [ClarificationQuestion] {
        candidates.map { candidate in
            makeQuestion(
                recordID: recordID,
                kind: ClarificationQuestionKind(rawValue: candidate.kind) ?? .dailyReflection,
                prompt: candidate.prompt,
                reason: candidate.reason,
                targetType: candidate.targetType.flatMap(ClarificationTargetType.init(rawValue:)) ?? .record,
                targetID: candidate.targetID.flatMap(UUID.init(uuidString:)) ?? recordID,
                sourceRecordIDs: candidate.sourceRecordIDs.compactMap(UUID.init(uuidString:)),
                sourceArtifactIDs: candidate.sourceArtifactIDs.compactMap(UUID.init(uuidString:)),
                candidateAnswers: candidate.candidateAnswers,
                priority: candidate.confidence,
                sensitivity: QuestionSensitivity(rawValue: candidate.sensitivity) ?? .normal,
                createdAt: createdAt
            )
        }
    }

    private func mapMergeSplitCandidates(
        recordID: UUID,
        _ candidates: [AnalyzeV7ResponseEnvelope.MergeSplitCandidate],
        createdAt: Date
    ) -> [ClarificationQuestion] {
        candidates.compactMap { candidate in
            guard let prompt = candidate.question?.trimmedOrNil else { return nil }
            let targetID = candidate.targetEntityID.flatMap(UUID.init(uuidString:))
                ?? candidate.sourceEntityIDs.compactMap(UUID.init(uuidString:)).first
                ?? recordID
            return makeQuestion(
                recordID: recordID,
                kind: candidate.kind.contains("split") ? .entityAlias : .entityMerge,
                prompt: prompt,
                reason: "Analyze v7 identity candidate with confidence \(candidate.confidence ?? 0).",
                targetType: .entity,
                targetID: targetID,
                sourceRecordIDs: [recordID],
                sourceArtifactIDs: [],
                candidateAnswers: ["same person", "not the same", "not sure"],
                priority: candidate.confidence ?? 0,
                sensitivity: .personal,
                createdAt: createdAt
            )
        }
    }

    private func makeQuestion(
        recordID: UUID,
        kind: ClarificationQuestionKind,
        prompt: String,
        reason: String,
        targetType: ClarificationTargetType,
        targetID: UUID,
        sourceRecordIDs: [UUID],
        sourceArtifactIDs: [UUID],
        candidateAnswers: [String],
        priority: Double,
        sensitivity: QuestionSensitivity,
        createdAt: Date
    ) -> ClarificationQuestion {
        ClarificationQuestion(
            kind: kind,
            prompt: prompt,
            targetType: targetType,
            targetID: targetID,
            sourceRecordIDs: sourceRecordIDs.isEmpty ? [recordID] : sourceRecordIDs,
            sourceArtifactIDs: sourceArtifactIDs,
            candidateAnswers: candidateAnswers.map { ClarificationAnswerOption(label: $0) },
            priority: priority,
            reason: reason,
            sensitivity: sensitivity,
            createdAt: createdAt
        )
    }
}
