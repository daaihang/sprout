import Foundation

enum ProfileSensitivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal
    case personal
    case sensitive
    case hiddenFromCloud

    var id: String { rawValue }
}

enum ProfileFieldEvidenceStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case inferred
    case proposed
    case userConfirmed
    case userRejected
    case stale
    case revoked

    var id: String { rawValue }
}

enum ProfileEvidenceSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case memory
    case artifact
    case correction
    case userEdit
    case profileRefresh

    var id: String { rawValue }
}

enum InteractionFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case unknown
    case rare
    case monthly
    case weekly
    case daily

    var id: String { rawValue }
}

enum PersonProfileAutomationPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case frozen

    var id: String { rawValue }
}

enum PersonProfileEditableField: String, Codable, CaseIterable, Identifiable, Sendable {
    case displayName
    case aliases
    case relationshipToUser
    case roleLabels
    case userNotes
    case sensitivity
    case automationPolicy
    case aiPortrait

    var id: String { rawValue }
}

struct ProfileFieldEvidence: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var fieldKey: String
    var source: ProfileEvidenceSource
    var status: ProfileFieldEvidenceStatus
    var sourceRecordIDs: [UUID]
    var sourceArtifactIDs: [UUID]
    var snippet: String
    var confidence: Double?
    var createdAt: Date
    var refreshedAt: Date?

    init(
        id: UUID = UUID(),
        fieldKey: String,
        source: ProfileEvidenceSource,
        status: ProfileFieldEvidenceStatus = .inferred,
        sourceRecordIDs: [UUID] = [],
        sourceArtifactIDs: [UUID] = [],
        snippet: String,
        confidence: Double? = nil,
        createdAt: Date = .now,
        refreshedAt: Date? = nil
    ) {
        self.id = id
        self.fieldKey = fieldKey
        self.source = source
        self.status = status
        self.sourceRecordIDs = sourceRecordIDs
        self.sourceArtifactIDs = sourceArtifactIDs
        self.snippet = snippet
        self.confidence = confidence
        self.createdAt = createdAt
        self.refreshedAt = refreshedAt
    }
}

struct RelationshipChange: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var relationship: EntityRelationshipToUser?
    var note: String?
    var sourceRecordIDs: [UUID]
    var status: ProfileFieldEvidenceStatus
    var changedAt: Date

    init(
        id: UUID = UUID(),
        relationship: EntityRelationshipToUser?,
        note: String? = nil,
        sourceRecordIDs: [UUID] = [],
        status: ProfileFieldEvidenceStatus = .inferred,
        changedAt: Date = .now
    ) {
        self.id = id
        self.relationship = relationship
        self.note = note
        self.sourceRecordIDs = sourceRecordIDs
        self.status = status
        self.changedAt = changedAt
    }
}

struct PersonAffectPattern: Codable, Hashable, Sendable {
    var dominantLabels: [String]
    var summary: String?
    var sourceRecordIDs: [UUID]
    var confidence: Double?
    var updatedAt: Date

    init(
        dominantLabels: [String] = [],
        summary: String? = nil,
        sourceRecordIDs: [UUID] = [],
        confidence: Double? = nil,
        updatedAt: Date = .now
    ) {
        self.dominantLabels = dominantLabels
        self.summary = summary
        self.sourceRecordIDs = sourceRecordIDs
        self.confidence = confidence
        self.updatedAt = updatedAt
    }
}

struct PersonPortrait: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var summary: String
    var relationshipTrajectory: String?
    var recentInteractionPattern: String?
    var recurringContexts: [String]
    var affectSummary: String?
    var openUncertainties: [String]
    var suggestedQuestions: [String]
    var evidenceRecordIDs: [UUID]
    var confidence: Double?
    var status: ProfileFieldEvidenceStatus
    var generatedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        summary: String,
        relationshipTrajectory: String? = nil,
        recentInteractionPattern: String? = nil,
        recurringContexts: [String] = [],
        affectSummary: String? = nil,
        openUncertainties: [String] = [],
        suggestedQuestions: [String] = [],
        evidenceRecordIDs: [UUID] = [],
        confidence: Double? = nil,
        status: ProfileFieldEvidenceStatus = .inferred,
        generatedAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.summary = summary
        self.relationshipTrajectory = relationshipTrajectory
        self.recentInteractionPattern = recentInteractionPattern
        self.recurringContexts = recurringContexts
        self.affectSummary = affectSummary
        self.openUncertainties = openUncertainties
        self.suggestedQuestions = suggestedQuestions
        self.evidenceRecordIDs = evidenceRecordIDs
        self.confidence = confidence
        self.status = status
        self.generatedAt = generatedAt
        self.updatedAt = updatedAt
    }
}

struct PersonProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var entityID: UUID
    var displayName: String
    var canonicalName: String
    var aliases: [String]
    var roleLabels: [String]
    var relationshipToUser: EntityRelationshipToUser?
    var relationshipHistory: [RelationshipChange]
    var relationshipStrength: Double?
    var importanceScore: Double?
    var interactionFrequency: InteractionFrequency
    var commonPlaceIDs: [UUID]
    var commonThemeIDs: [UUID]
    var commonDecisionIDs: [UUID]
    var commonContextLabels: [String]
    var emotionalPattern: PersonAffectPattern?
    var recentChangeSummary: String?
    var userNotes: String?
    var aiPortrait: PersonPortrait?
    var fieldEvidence: [ProfileFieldEvidence]
    var fieldConfidence: [String: Double]
    var sensitivity: ProfileSensitivity
    var automationPolicy: PersonProfileAutomationPolicy
    var sourceRecordIDs: [UUID]
    var lastReviewedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        entityID: UUID,
        displayName: String,
        canonicalName: String? = nil,
        aliases: [String] = [],
        roleLabels: [String] = [],
        relationshipToUser: EntityRelationshipToUser? = nil,
        relationshipHistory: [RelationshipChange] = [],
        relationshipStrength: Double? = nil,
        importanceScore: Double? = nil,
        interactionFrequency: InteractionFrequency = .unknown,
        commonPlaceIDs: [UUID] = [],
        commonThemeIDs: [UUID] = [],
        commonDecisionIDs: [UUID] = [],
        commonContextLabels: [String] = [],
        emotionalPattern: PersonAffectPattern? = nil,
        recentChangeSummary: String? = nil,
        userNotes: String? = nil,
        aiPortrait: PersonPortrait? = nil,
        fieldEvidence: [ProfileFieldEvidence] = [],
        fieldConfidence: [String: Double] = [:],
        sensitivity: ProfileSensitivity = .normal,
        automationPolicy: PersonProfileAutomationPolicy = .automatic,
        sourceRecordIDs: [UUID] = [],
        lastReviewedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.entityID = entityID
        self.displayName = displayName
        self.canonicalName = canonicalName ?? displayName
        self.aliases = aliases
        self.roleLabels = roleLabels
        self.relationshipToUser = relationshipToUser
        self.relationshipHistory = relationshipHistory
        self.relationshipStrength = relationshipStrength
        self.importanceScore = importanceScore
        self.interactionFrequency = interactionFrequency
        self.commonPlaceIDs = commonPlaceIDs
        self.commonThemeIDs = commonThemeIDs
        self.commonDecisionIDs = commonDecisionIDs
        self.commonContextLabels = commonContextLabels
        self.emotionalPattern = emotionalPattern
        self.recentChangeSummary = recentChangeSummary
        self.userNotes = userNotes
        self.aiPortrait = aiPortrait
        self.fieldEvidence = fieldEvidence
        self.fieldConfidence = fieldConfidence
        self.sensitivity = sensitivity
        self.automationPolicy = automationPolicy
        self.sourceRecordIDs = sourceRecordIDs
        self.lastReviewedAt = lastReviewedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isFrozen: Bool {
        automationPolicy == .frozen
    }
}

struct PersonProfileMutation: Codable, Hashable, Sendable {
    var entityID: UUID
    var field: PersonProfileEditableField
    var stringValue: String?
    var stringListValue: [String]?
    var relationshipValue: EntityRelationshipToUser?
    var sensitivityValue: ProfileSensitivity?
    var automationPolicyValue: PersonProfileAutomationPolicy?
    var note: String?
    var actor: CorrectionActor
    var createdAt: Date

    init(
        entityID: UUID,
        field: PersonProfileEditableField,
        stringValue: String? = nil,
        stringListValue: [String]? = nil,
        relationshipValue: EntityRelationshipToUser? = nil,
        sensitivityValue: ProfileSensitivity? = nil,
        automationPolicyValue: PersonProfileAutomationPolicy? = nil,
        note: String? = nil,
        actor: CorrectionActor = .user,
        createdAt: Date = .now
    ) {
        self.entityID = entityID
        self.field = field
        self.stringValue = stringValue
        self.stringListValue = stringListValue
        self.relationshipValue = relationshipValue
        self.sensitivityValue = sensitivityValue
        self.automationPolicyValue = automationPolicyValue
        self.note = note
        self.actor = actor
        self.createdAt = createdAt
    }
}

struct PersonProfileContextBrief: Codable, Hashable, Sendable {
    var entityID: UUID
    var displayName: String
    var aliases: [String]
    var roleLabels: [String]
    var relationshipToUser: EntityRelationshipToUser?
    var importanceScore: Double?
    var interactionFrequency: InteractionFrequency
    var commonContextLabels: [String]
    var portraitSummary: String?
    var userNotes: String?
    var sensitivity: ProfileSensitivity
    var cloudAction: ContextPrivacyAction

    init(profile: PersonProfile, includeSensitive: Bool, maxCharacters: Int = 800) {
        entityID = profile.entityID
        displayName = profile.displayName
        aliases = Array(profile.aliases.prefix(8))
        roleLabels = Array(profile.roleLabels.prefix(8))
        relationshipToUser = profile.relationshipToUser
        importanceScore = profile.importanceScore
        interactionFrequency = profile.interactionFrequency
        commonContextLabels = Array(profile.commonContextLabels.prefix(8))
        sensitivity = profile.sensitivity

        switch profile.sensitivity {
        case .normal, .personal:
            cloudAction = .include
            portraitSummary = PersonProfileContextBrief.trim(profile.aiPortrait?.summary, maxCharacters: maxCharacters)
            userNotes = includeSensitive ? PersonProfileContextBrief.trim(profile.userNotes, maxCharacters: maxCharacters / 2) : nil
        case .sensitive:
            cloudAction = includeSensitive ? .include : .redact
            portraitSummary = includeSensitive ? PersonProfileContextBrief.trim(profile.aiPortrait?.summary, maxCharacters: maxCharacters / 2) : nil
            userNotes = includeSensitive ? PersonProfileContextBrief.trim(profile.userNotes, maxCharacters: maxCharacters / 2) : nil
        case .hiddenFromCloud:
            cloudAction = .idOnly
            aliases = []
            roleLabels = []
            relationshipToUser = nil
            importanceScore = nil
            commonContextLabels = []
            portraitSummary = nil
            userNotes = nil
        }
    }

    private static func trim(_ value: String?, maxCharacters: Int) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        guard value.count > maxCharacters else {
            return value
        }
        return String(value.prefix(maxCharacters))
    }
}
