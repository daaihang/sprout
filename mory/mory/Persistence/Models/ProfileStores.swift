import Foundation
import SwiftData

@Model
final class SelfProfileStore {
    @Attribute(.unique) var syncKey: String
    var id: UUID
    var schemaVersion: Int
    var selfEntityID: UUID
    var displayName: String?
    var aliases: [String]
    var pronouns: [String]
    var lifeRolesData: Data?
    var longTermGoalsData: Data?
    var preferencesData: Data?
    var sensitiveBoundariesData: Data?
    var importantRelationshipIDs: [UUID]
    var commonPlaceIDs: [UUID]
    var commonThemeIDs: [UUID]
    var expressionPatternsData: Data?
    var privacyModeRawValue: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        syncKey: String = SelfProfile.defaultSyncKey,
        schemaVersion: Int = SelfProfile.schemaVersion,
        selfEntityID: UUID,
        displayName: String?,
        aliases: [String],
        pronouns: [String],
        lifeRolesData: Data?,
        longTermGoalsData: Data?,
        preferencesData: Data?,
        sensitiveBoundariesData: Data?,
        importantRelationshipIDs: [UUID],
        commonPlaceIDs: [UUID],
        commonThemeIDs: [UUID],
        expressionPatternsData: Data?,
        privacyModeRawValue: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.syncKey = syncKey
        self.schemaVersion = schemaVersion
        self.selfEntityID = selfEntityID
        self.displayName = displayName
        self.aliases = aliases
        self.pronouns = pronouns
        self.lifeRolesData = lifeRolesData
        self.longTermGoalsData = longTermGoalsData
        self.preferencesData = preferencesData
        self.sensitiveBoundariesData = sensitiveBoundariesData
        self.importantRelationshipIDs = importantRelationshipIDs
        self.commonPlaceIDs = commonPlaceIDs
        self.commonThemeIDs = commonThemeIDs
        self.expressionPatternsData = expressionPatternsData
        self.privacyModeRawValue = privacyModeRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class PersonProfileStore {
    @Attribute(.unique) var entityID: UUID
    var id: UUID
    var displayName: String
    var canonicalName: String
    var aliases: [String]
    var roleLabels: [String]
    var relationshipToUserRawValue: String?
    var relationshipHistoryData: Data?
    var relationshipStrength: Double?
    var importanceScore: Double?
    var interactionFrequencyRawValue: String
    var commonPlaceIDs: [UUID]
    var commonThemeIDs: [UUID]
    var commonDecisionIDs: [UUID]
    var commonContextLabels: [String]
    var emotionalPatternData: Data?
    var recentChangeSummary: String?
    var userNotes: String?
    var aiPortraitData: Data?
    var fieldEvidenceData: Data?
    var fieldConfidenceData: Data?
    var sensitivityRawValue: String
    var automationPolicyRawValue: String
    var sourceRecordIDs: [UUID]
    var lastReviewedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        entityID: UUID,
        displayName: String,
        canonicalName: String,
        aliases: [String],
        roleLabels: [String],
        relationshipToUserRawValue: String?,
        relationshipHistoryData: Data?,
        relationshipStrength: Double?,
        importanceScore: Double?,
        interactionFrequencyRawValue: String,
        commonPlaceIDs: [UUID],
        commonThemeIDs: [UUID],
        commonDecisionIDs: [UUID],
        commonContextLabels: [String],
        emotionalPatternData: Data?,
        recentChangeSummary: String?,
        userNotes: String?,
        aiPortraitData: Data?,
        fieldEvidenceData: Data?,
        fieldConfidenceData: Data?,
        sensitivityRawValue: String,
        automationPolicyRawValue: String,
        sourceRecordIDs: [UUID],
        lastReviewedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.entityID = entityID
        self.displayName = displayName
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.roleLabels = roleLabels
        self.relationshipToUserRawValue = relationshipToUserRawValue
        self.relationshipHistoryData = relationshipHistoryData
        self.relationshipStrength = relationshipStrength
        self.importanceScore = importanceScore
        self.interactionFrequencyRawValue = interactionFrequencyRawValue
        self.commonPlaceIDs = commonPlaceIDs
        self.commonThemeIDs = commonThemeIDs
        self.commonDecisionIDs = commonDecisionIDs
        self.commonContextLabels = commonContextLabels
        self.emotionalPatternData = emotionalPatternData
        self.recentChangeSummary = recentChangeSummary
        self.userNotes = userNotes
        self.aiPortraitData = aiPortraitData
        self.fieldEvidenceData = fieldEvidenceData
        self.fieldConfidenceData = fieldConfidenceData
        self.sensitivityRawValue = sensitivityRawValue
        self.automationPolicyRawValue = automationPolicyRawValue
        self.sourceRecordIDs = sourceRecordIDs
        self.lastReviewedAt = lastReviewedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class AffectSnapshotStore {
    @Attribute(.unique) var id: UUID
    var recordID: UUID
    var valence: Double?
    var arousal: Double?
    var dominance: Double?
    var intensity: Double?
    var labelRawValues: [String]
    var toneHintRawValues: [String]
    var appraisalData: Data?
    var sourceRawValues: [String]
    var confidence: Double?
    var evidenceData: Data?
    var userConfirmed: Bool
    var needsUserCheck: Bool
    var rawInput: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        recordID: UUID,
        valence: Double?,
        arousal: Double?,
        dominance: Double?,
        intensity: Double?,
        labelRawValues: [String],
        toneHintRawValues: [String],
        appraisalData: Data?,
        sourceRawValues: [String],
        confidence: Double?,
        evidenceData: Data?,
        userConfirmed: Bool,
        needsUserCheck: Bool,
        rawInput: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.recordID = recordID
        self.valence = valence
        self.arousal = arousal
        self.dominance = dominance
        self.intensity = intensity
        self.labelRawValues = labelRawValues
        self.toneHintRawValues = toneHintRawValues
        self.appraisalData = appraisalData
        self.sourceRawValues = sourceRawValues
        self.confidence = confidence
        self.evidenceData = evidenceData
        self.userConfirmed = userConfirmed
        self.needsUserCheck = needsUserCheck
        self.rawInput = rawInput
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class PlaceProfileStore {
    @Attribute(.unique) var id: UUID
    var entityID: UUID
    var displayName: String
    var canonicalName: String
    var aliases: [String]
    var centroidLatitude: Double?
    var centroidLongitude: Double?
    var radiusMeters: Double
    var mentionCount: Int
    var sourceArtifactIDs: [UUID]
    var sourceRecordIDs: [UUID]
    var confirmationStateRawValue: String
    var confidence: Double?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        entityID: UUID,
        displayName: String,
        canonicalName: String,
        aliases: [String] = [],
        centroidLatitude: Double? = nil,
        centroidLongitude: Double? = nil,
        radiusMeters: Double,
        mentionCount: Int,
        sourceArtifactIDs: [UUID] = [],
        sourceRecordIDs: [UUID] = [],
        confirmationStateRawValue: String,
        confidence: Double? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.entityID = entityID
        self.displayName = displayName
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.centroidLatitude = centroidLatitude
        self.centroidLongitude = centroidLongitude
        self.radiusMeters = radiusMeters
        self.mentionCount = mentionCount
        self.sourceArtifactIDs = sourceArtifactIDs
        self.sourceRecordIDs = sourceRecordIDs
        self.confirmationStateRawValue = confirmationStateRawValue
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
