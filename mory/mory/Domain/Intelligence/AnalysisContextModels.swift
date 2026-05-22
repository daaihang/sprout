import Foundation

enum SelfProfilePrivacyMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case localFirst
    case cloudMinimal
    case localOnly

    var id: String { rawValue }
}

struct SelfRole: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var label: String
    var detail: String?
    var confidence: Double?

    init(id: UUID = UUID(), label: String, detail: String? = nil, confidence: Double? = nil) {
        self.id = id
        self.label = label
        self.detail = detail
        self.confidence = confidence
    }
}

struct SelfGoal: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var detail: String?
    var status: String?

    init(id: UUID = UUID(), title: String, detail: String? = nil, status: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
    }
}

struct SelfPreference: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var key: String
    var value: String
    var localOnly: Bool

    init(id: UUID = UUID(), key: String, value: String, localOnly: Bool = false) {
        self.id = id
        self.key = key
        self.value = value
        self.localOnly = localOnly
    }
}

struct SensitiveBoundary: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var label: String
    var keywords: [String]
    var policy: String

    init(id: UUID = UUID(), label: String, keywords: [String] = [], policy: String = "drop") {
        self.id = id
        self.label = label
        self.keywords = keywords
        self.policy = policy
    }
}

struct ExpressionPattern: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var phrase: String
    var interpretation: String
    var confidence: Double?

    init(id: UUID = UUID(), phrase: String, interpretation: String, confidence: Double? = nil) {
        self.id = id
        self.phrase = phrase
        self.interpretation = interpretation
        self.confidence = confidence
    }
}

struct SelfProfile: Identifiable, Codable, Hashable, Sendable {
    static let defaultSyncKey = "self-profile.default"
    static let schemaVersion = 1

    let id: UUID
    var syncKey: String
    var schemaVersion: Int
    var selfEntityID: UUID
    var displayName: String?
    var aliases: [String]
    var pronouns: [String]
    var lifeRoles: [SelfRole]
    var longTermGoals: [SelfGoal]
    var preferences: [SelfPreference]
    var sensitiveBoundaries: [SensitiveBoundary]
    var importantRelationshipIDs: [UUID]
    var commonPlaceIDs: [UUID]
    var commonThemeIDs: [UUID]
    var expressionPatterns: [ExpressionPattern]
    var privacyMode: SelfProfilePrivacyMode
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        syncKey: String = SelfProfile.defaultSyncKey,
        schemaVersion: Int = SelfProfile.schemaVersion,
        selfEntityID: UUID = UUID(),
        displayName: String? = nil,
        aliases: [String] = SelfProfile.defaultAliases,
        pronouns: [String] = [],
        lifeRoles: [SelfRole] = [],
        longTermGoals: [SelfGoal] = [],
        preferences: [SelfPreference] = [],
        sensitiveBoundaries: [SensitiveBoundary] = [],
        importantRelationshipIDs: [UUID] = [],
        commonPlaceIDs: [UUID] = [],
        commonThemeIDs: [UUID] = [],
        expressionPatterns: [ExpressionPattern] = [],
        privacyMode: SelfProfilePrivacyMode = .localFirst,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.syncKey = syncKey
        self.schemaVersion = schemaVersion
        self.selfEntityID = selfEntityID
        self.displayName = displayName
        self.aliases = aliases
        self.pronouns = pronouns
        self.lifeRoles = lifeRoles
        self.longTermGoals = longTermGoals
        self.preferences = preferences
        self.sensitiveBoundaries = sensitiveBoundaries
        self.importantRelationshipIDs = importantRelationshipIDs
        self.commonPlaceIDs = commonPlaceIDs
        self.commonThemeIDs = commonThemeIDs
        self.expressionPatterns = expressionPatterns
        self.privacyMode = privacyMode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static var defaultAliases: [String] {
        ["I", "me", "myself", "my", "我", "自己", "本人"]
    }
}

struct SelfContextBrief: Codable, Hashable, Sendable {
    var selfEntityID: UUID
    var displayName: String?
    var aliases: [String]
    var roleLabels: [String]
    var goalTitles: [String]
    var expressionHints: [String]
    var privacyMode: SelfProfilePrivacyMode

    init(profile: SelfProfile, maxCharacters: Int) {
        self.selfEntityID = profile.selfEntityID
        self.displayName = profile.displayName
        self.aliases = Array(profile.aliases.prefix(8))
        self.roleLabels = SelfContextBrief.bounded(profile.lifeRoles.map(\.label), maxCharacters: maxCharacters / 4)
        self.goalTitles = SelfContextBrief.bounded(profile.longTermGoals.map(\.title), maxCharacters: maxCharacters / 4)
        self.expressionHints = SelfContextBrief.bounded(
            profile.expressionPatterns.map { "\($0.phrase): \($0.interpretation)" },
            maxCharacters: maxCharacters / 4
        )
        self.privacyMode = profile.privacyMode
    }

    private static func bounded(_ values: [String], maxCharacters: Int) -> [String] {
        var result: [String] = []
        var count = 0
        for value in values where count + value.count <= maxCharacters {
            result.append(value)
            count += value.count
        }
        return result
    }
}

enum ContextPrivacyAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case include
    case drop
    case redact
    case summarize
    case idOnly
    case localOnly
    case blockCloud

    var id: String { rawValue }
}

struct ContextPrivacyDecision: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var sourceType: String
    var sourceID: UUID?
    var action: ContextPrivacyAction
    var reason: String

    init(
        id: UUID = UUID(),
        sourceType: String,
        sourceID: UUID? = nil,
        action: ContextPrivacyAction,
        reason: String
    ) {
        self.id = id
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.action = action
        self.reason = reason
    }
}

struct ContextScoreBreakdown: Codable, Hashable, Sendable {
    var semanticSimilarity: Double
    var entityOverlap: Double
    var recencyWeight: Double
    var salienceWeight: Double
    var userConfirmedWeight: Double
    var openDecisionWeight: Double
    var affectSimilarityWeight: Double
    var sensitivityPenalty: Double
    var repeatedRejectedSignalPenalty: Double

    var total: Double {
        semanticSimilarity
            + entityOverlap
            + recencyWeight
            + salienceWeight
            + userConfirmedWeight
            + openDecisionWeight
            + affectSimilarityWeight
            - sensitivityPenalty
            - repeatedRejectedSignalPenalty
    }

    static let zero = ContextScoreBreakdown(
        semanticSimilarity: 0,
        entityOverlap: 0,
        recencyWeight: 0,
        salienceWeight: 0,
        userConfirmedWeight: 0,
        openDecisionWeight: 0,
        affectSimilarityWeight: 0,
        sensitivityPenalty: 0,
        repeatedRejectedSignalPenalty: 0
    )
}

struct KnownProfileBrief: Identifiable, Codable, Hashable, Sendable {
    var id: UUID { entityID }
    var entityID: UUID
    var kind: EntityKind
    var displayName: String
    var relationshipToUser: EntityRelationshipToUser?
    var mentionCount: Int
    var commonContextLabels: [String]
    var confidence: Double?
    var inclusionReason: String
}

struct RelatedMemoryBrief: Identifiable, Codable, Hashable, Sendable {
    var id: UUID { recordID }
    var recordID: UUID
    var title: String
    var snippet: String
    var createdAt: Date
    var userMood: String?
    var scoreBreakdown: ContextScoreBreakdown
    var inclusionReasons: [String]
}

struct RelatedArcBrief: Identifiable, Codable, Hashable, Sendable {
    var id: UUID { arcID }
    var arcID: UUID
    var title: String
    var summary: String
    var status: TemporalArcStatus
    var sourceRecordIDs: [UUID]
    var score: Double
}

struct PriorReflectionBrief: Identifiable, Codable, Hashable, Sendable {
    var id: UUID { reflectionID }
    var reflectionID: UUID
    var title: String
    var evidenceSummary: String
    var status: ReflectionStatus
    var sourceRecordIDs: [UUID]
    var confidence: Double
}

struct CorrectionSignalBrief: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: ClarificationQuestionKind
    var targetType: ClarificationTargetType
    var targetID: UUID
    var status: ClarificationQuestionStatus
    var summary: String
    var answeredAt: Date?
}

struct AffectHistoryBrief: Identifiable, Codable, Hashable, Sendable {
    var id: String { mood }
    var mood: String
    var count: Int
    var latestRecordID: UUID
}

struct ContextBudgetLimits: Codable, Hashable, Sendable {
    var maxSelfBriefCharacters: Int
    var maxProfiles: Int
    var maxRelatedMemories: Int
    var maxArcs: Int
    var maxReflections: Int
    var maxCorrections: Int
    var maxAffectHistory: Int
    var maxMemorySnippetCharacters: Int

    static let phase1Default = ContextBudgetLimits(
        maxSelfBriefCharacters: 800,
        maxProfiles: 8,
        maxRelatedMemories: 12,
        maxArcs: 6,
        maxReflections: 6,
        maxCorrections: 10,
        maxAffectHistory: 8,
        maxMemorySnippetCharacters: 500
    )
}

struct ContextBudgetReport: Codable, Hashable, Sendable {
    var limits: ContextBudgetLimits
    var selectedProfiles: Int
    var selectedRelatedMemories: Int
    var selectedArcs: Int
    var selectedReflections: Int
    var selectedCorrections: Int
    var selectedAffectHistory: Int
    var droppedByBudget: Int
    var droppedByPrivacy: Int
}

struct ContextPackRetrievalReport: Codable, Hashable, Sendable {
    var semanticSearchStatus: String
    var retrievalSources: [String]
    var candidateMemoryCount: Int
    var fallbackReason: String?
}

struct AnalysisContextPack: Identifiable, Codable, Hashable, Sendable {
    var id: UUID { packID }
    var packID: UUID
    var targetRecordID: UUID
    var selfBrief: SelfContextBrief?
    var relatedProfiles: [KnownProfileBrief]
    var relatedMemories: [RelatedMemoryBrief]
    var relatedArcs: [RelatedArcBrief]
    var priorReflections: [PriorReflectionBrief]
    var correctionSignals: [CorrectionSignalBrief]
    var affectHistory: [AffectHistoryBrief]
    var privacyDecisions: [ContextPrivacyDecision]
    var budget: ContextBudgetReport
    var retrieval: ContextPackRetrievalReport
    var builtAt: Date
}
