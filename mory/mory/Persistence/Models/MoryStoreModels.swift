import Foundation
import SwiftData

@Model
final class UserSettingsPreferenceStore {
    @Attribute(.unique) var syncKey: String
    var id: UUID
    var schemaVersion: Int
    var updatedAt: Date
    var appearanceModeRawValue: String
    var voiceLanguageIdentifier: String?
    var linkAutoDetectEnabled: Bool
    var defaultContextSelectionRawValue: String
    var insightFrequencyRawValue: String
    var promptToneRawValue: String

    init(
        id: UUID = UUID(),
        syncKey: String = UserSettingsPreference.defaultSyncKey,
        schemaVersion: Int = UserSettingsPreference.schemaVersion,
        updatedAt: Date,
        appearanceModeRawValue: String,
        voiceLanguageIdentifier: String?,
        linkAutoDetectEnabled: Bool,
        defaultContextSelectionRawValue: String,
        insightFrequencyRawValue: String,
        promptToneRawValue: String
    ) {
        self.id = id
        self.syncKey = syncKey
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.appearanceModeRawValue = appearanceModeRawValue
        self.voiceLanguageIdentifier = voiceLanguageIdentifier
        self.linkAutoDetectEnabled = linkAutoDetectEnabled
        self.defaultContextSelectionRawValue = defaultContextSelectionRawValue
        self.insightFrequencyRawValue = insightFrequencyRawValue
        self.promptToneRawValue = promptToneRawValue
    }
}

@Model
final class QualityTuningPreferenceStore {
    @Attribute(.unique) var syncKey: String
    var id: UUID
    var schemaVersion: Int
    var promptProfileRawValue: String
    var thresholdsData: Data?
    var notes: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        syncKey: String = QualityTuningPreference.defaultSyncKey,
        promptProfileRawValue: String,
        thresholdsData: Data?,
        notes: String,
        updatedAt: Date
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.syncKey = syncKey
        self.promptProfileRawValue = promptProfileRawValue
        self.thresholdsData = thresholdsData
        self.notes = notes
        self.updatedAt = updatedAt
    }
}

@Model
final class HomeBoardPreferenceStore {
    @Attribute(.unique) var syncKey: String
    var id: UUID
    var schemaVersion: Int
    var boardKey: String
    var cardKey: String
    var cardKindRawValue: String
    var targetTypeRawValue: String
    var targetID: UUID
    var isPinned: Bool
    var isHidden: Bool
    var dismissedAt: Date?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = HomeBoardItemPreference.schemaVersion,
        syncKey: String,
        boardKey: String,
        cardKey: String,
        cardKindRawValue: String,
        targetTypeRawValue: String,
        targetID: UUID,
        isPinned: Bool,
        isHidden: Bool,
        dismissedAt: Date?,
        updatedAt: Date
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.syncKey = syncKey
        self.boardKey = boardKey
        self.cardKey = cardKey
        self.cardKindRawValue = cardKindRawValue
        self.targetTypeRawValue = targetTypeRawValue
        self.targetID = targetID
        self.isPinned = isPinned
        self.isHidden = isHidden
        self.dismissedAt = dismissedAt
        self.updatedAt = updatedAt
    }
}

@Model
final class IntelligencePreferenceStore {
    @Attribute(.unique) var syncKey: String
    var id: UUID
    var schemaVersion: Int
    var preferencesData: Data?
    var featureFlagsData: Data?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        syncKey: String = IntelligencePreferences.defaultSyncKey,
        schemaVersion: Int = IntelligencePreferences.schemaVersion,
        preferencesData: Data?,
        featureFlagsData: Data?,
        updatedAt: Date
    ) {
        self.id = id
        self.syncKey = syncKey
        self.schemaVersion = schemaVersion
        self.preferencesData = preferencesData
        self.featureFlagsData = featureFlagsData
        self.updatedAt = updatedAt
    }
}

@Model
final class EntityProfileStore {
    @Attribute(.unique) var id: UUID
    var entityID: UUID
    var kindRawValue: String
    var displayName: String
    var canonicalName: String
    var aliases: [String]
    var relationshipToUserRawValue: String?
    var userDescription: String?
    var mentionCount: Int
    var firstMentionedAt: Date?
    var lastMentionedAt: Date?
    var commonContextLabels: [String]
    var sourceRecordIDs: [UUID]
    var confirmationStateRawValue: String
    var confidence: Double?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        entityID: UUID,
        kindRawValue: String,
        displayName: String,
        canonicalName: String,
        aliases: [String] = [],
        relationshipToUserRawValue: String? = nil,
        userDescription: String? = nil,
        mentionCount: Int,
        firstMentionedAt: Date? = nil,
        lastMentionedAt: Date? = nil,
        commonContextLabels: [String] = [],
        sourceRecordIDs: [UUID] = [],
        confirmationStateRawValue: String,
        confidence: Double? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.entityID = entityID
        self.kindRawValue = kindRawValue
        self.displayName = displayName
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.relationshipToUserRawValue = relationshipToUserRawValue
        self.userDescription = userDescription
        self.mentionCount = mentionCount
        self.firstMentionedAt = firstMentionedAt
        self.lastMentionedAt = lastMentionedAt
        self.commonContextLabels = commonContextLabels
        self.sourceRecordIDs = sourceRecordIDs
        self.confirmationStateRawValue = confirmationStateRawValue
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ClarificationQuestionStore {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var prompt: String
    var targetTypeRawValue: String
    var targetID: UUID
    var sourceRecordIDs: [UUID]
    var sourceArtifactIDs: [UUID]
    var candidateAnswersData: Data?
    var priority: Double
    var reason: String
    var sensitivityRawValue: String
    var statusRawValue: String
    var answerData: Data?
    var createdAt: Date
    var expiresAt: Date?
    var answeredAt: Date?
    var dismissedAt: Date?
    var askCount: Int

    init(
        id: UUID,
        kindRawValue: String,
        prompt: String,
        targetTypeRawValue: String,
        targetID: UUID,
        sourceRecordIDs: [UUID] = [],
        sourceArtifactIDs: [UUID] = [],
        candidateAnswersData: Data? = nil,
        priority: Double,
        reason: String,
        sensitivityRawValue: String,
        statusRawValue: String,
        answerData: Data? = nil,
        createdAt: Date,
        expiresAt: Date? = nil,
        answeredAt: Date? = nil,
        dismissedAt: Date? = nil,
        askCount: Int
    ) {
        self.id = id
        self.kindRawValue = kindRawValue
        self.prompt = prompt
        self.targetTypeRawValue = targetTypeRawValue
        self.targetID = targetID
        self.sourceRecordIDs = sourceRecordIDs
        self.sourceArtifactIDs = sourceArtifactIDs
        self.candidateAnswersData = candidateAnswersData
        self.priority = priority
        self.reason = reason
        self.sensitivityRawValue = sensitivityRawValue
        self.statusRawValue = statusRawValue
        self.answerData = answerData
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.answeredAt = answeredAt
        self.dismissedAt = dismissedAt
        self.askCount = askCount
    }
}

@Model
final class IntelligenceJobStore {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var targetTypeRawValue: String
    var targetID: UUID
    var statusRawValue: String
    var priority: Double
    var attemptCount: Int
    var lastError: String?
    var scheduledAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var updatedAt: Date
    var dedupeKey: String
    var requiresCloudAI: Bool

    init(
        id: UUID,
        kindRawValue: String,
        targetTypeRawValue: String,
        targetID: UUID,
        statusRawValue: String,
        priority: Double,
        attemptCount: Int,
        lastError: String? = nil,
        scheduledAt: Date,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date,
        dedupeKey: String,
        requiresCloudAI: Bool
    ) {
        self.id = id
        self.kindRawValue = kindRawValue
        self.targetTypeRawValue = targetTypeRawValue
        self.targetID = targetID
        self.statusRawValue = statusRawValue
        self.priority = priority
        self.attemptCount = attemptCount
        self.lastError = lastError
        self.scheduledAt = scheduledAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.dedupeKey = dedupeKey
        self.requiresCloudAI = requiresCloudAI
    }
}

@Model
final class GraphDeltaStore {
    @Attribute(.unique) var id: UUID
    var sourceRawValue: String
    var operationsData: Data?
    var confidence: Double?
    var requiresUserConfirmation: Bool
    var appliedAt: Date?
    var createdAt: Date

    init(
        id: UUID,
        sourceRawValue: String,
        operationsData: Data?,
        confidence: Double? = nil,
        requiresUserConfirmation: Bool,
        appliedAt: Date? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.sourceRawValue = sourceRawValue
        self.operationsData = operationsData
        self.confidence = confidence
        self.requiresUserConfirmation = requiresUserConfirmation
        self.appliedAt = appliedAt
        self.createdAt = createdAt
    }
}

@Model
final class HomeBoardSignalStore {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var targetTypeRawValue: String
    var targetID: UUID
    var sourceRecordIDs: [UUID]
    var title: String
    var subtitle: String
    var priority: Double
    var reason: String
    var suggestedWidthColumns: Int
    var suggestedHeightUnits: Int
    var createdAt: Date
    var expiresAt: Date?

    init(
        id: UUID,
        kindRawValue: String,
        targetTypeRawValue: String,
        targetID: UUID,
        sourceRecordIDs: [UUID] = [],
        title: String,
        subtitle: String,
        priority: Double,
        reason: String,
        suggestedWidthColumns: Int,
        suggestedHeightUnits: Int,
        createdAt: Date,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.kindRawValue = kindRawValue
        self.targetTypeRawValue = targetTypeRawValue
        self.targetID = targetID
        self.sourceRecordIDs = sourceRecordIDs
        self.title = title
        self.subtitle = subtitle
        self.priority = priority
        self.reason = reason
        self.suggestedWidthColumns = suggestedWidthColumns
        self.suggestedHeightUnits = suggestedHeightUnits
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}

@Model
final class NotificationIntentStore {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var title: String
    var body: String
    var privacyLevelRawValue: String
    var targetTypeRawValue: String
    var targetID: UUID
    var scheduledAt: Date
    var statusRawValue: String
    var deliveryChannelRawValue: String
    var createdAt: Date
    var deliveredAt: Date?
    var dismissedAt: Date?

    init(
        id: UUID,
        kindRawValue: String,
        title: String,
        body: String,
        privacyLevelRawValue: String,
        targetTypeRawValue: String,
        targetID: UUID,
        scheduledAt: Date,
        statusRawValue: String,
        deliveryChannelRawValue: String,
        createdAt: Date,
        deliveredAt: Date? = nil,
        dismissedAt: Date? = nil
    ) {
        self.id = id
        self.kindRawValue = kindRawValue
        self.title = title
        self.body = body
        self.privacyLevelRawValue = privacyLevelRawValue
        self.targetTypeRawValue = targetTypeRawValue
        self.targetID = targetID
        self.scheduledAt = scheduledAt
        self.statusRawValue = statusRawValue
        self.deliveryChannelRawValue = deliveryChannelRawValue
        self.createdAt = createdAt
        self.deliveredAt = deliveredAt
        self.dismissedAt = dismissedAt
    }
}

@Model
final class RecordShellStore {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var captureSourceRawValue: String
    var rawText: String
    var userMood: String?
    var userIntensity: Int?
    var inputContext: String?
    var artifactIDs: [UUID]
    var debugFixtureSeededAt: Date?

    init(
        id: UUID,
        createdAt: Date,
        updatedAt: Date,
        captureSourceRawValue: String,
        rawText: String,
        userMood: String? = nil,
        userIntensity: Int? = nil,
        inputContext: String? = nil,
        artifactIDs: [UUID] = [],
        debugFixtureSeededAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.captureSourceRawValue = captureSourceRawValue
        self.rawText = rawText
        self.userMood = userMood
        self.userIntensity = userIntensity
        self.inputContext = inputContext
        self.artifactIDs = artifactIDs
        self.debugFixtureSeededAt = debugFixtureSeededAt
    }
}

@Model
final class ArtifactStore {
    @Attribute(.unique) var id: UUID
    var recordID: UUID
    var kindRawValue: String
    var title: String
    var summary: String
    var textContent: String
    var payloadData: Data?
    var mediaRefData: Data?
    var metadataData: Data?
    @Attribute(.externalStorage) var binaryPayload: Data?
    @Attribute(.externalStorage) var previewPayload: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        recordID: UUID,
        kindRawValue: String,
        title: String,
        summary: String,
        textContent: String,
        payloadData: Data? = nil,
        mediaRefData: Data? = nil,
        metadataData: Data? = nil,
        binaryPayload: Data? = nil,
        previewPayload: Data? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.recordID = recordID
        self.kindRawValue = kindRawValue
        self.title = title
        self.summary = summary
        self.textContent = textContent
        self.payloadData = payloadData
        self.mediaRefData = mediaRefData
        self.metadataData = metadataData
        self.binaryPayload = binaryPayload
        self.previewPayload = previewPayload
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class BoardStore {
    @Attribute(.unique) var id: UUID
    var boardKey: String
    var kindRawValue: String
    var title: String
    var subtitle: String
    var boardDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        boardKey: String,
        kindRawValue: String,
        title: String,
        subtitle: String,
        boardDate: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.boardKey = boardKey
        self.kindRawValue = kindRawValue
        self.title = title
        self.subtitle = subtitle
        self.boardDate = boardDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class CompositionStore {
    @Attribute(.unique) var id: UUID
    var boardID: UUID
    var compositionKey: String
    var title: String
    var sortOrder: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        boardID: UUID,
        compositionKey: String,
        title: String,
        sortOrder: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.boardID = boardID
        self.compositionKey = compositionKey
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class CompositionItemStore {
    @Attribute(.unique) var id: UUID
    var boardID: UUID
    var boardKey: String
    var compositionID: UUID
    var compositionKey: String
    var itemKey: String
    var targetTypeRawValue: String
    var targetID: UUID
    var widthColumns: Int
    var heightUnits: Int
    var zIndex: Int
    var rotationDegrees: Double
    var scale: Double
    var isHidden: Bool
    var updatedAt: Date

    init(
        id: UUID,
        boardID: UUID,
        boardKey: String,
        compositionID: UUID,
        compositionKey: String,
        itemKey: String,
        targetTypeRawValue: String,
        targetID: UUID,
        widthColumns: Int,
        heightUnits: Int,
        zIndex: Int,
        rotationDegrees: Double,
        scale: Double,
        isHidden: Bool,
        updatedAt: Date
    ) {
        self.id = id
        self.boardID = boardID
        self.boardKey = boardKey
        self.compositionID = compositionID
        self.compositionKey = compositionKey
        self.itemKey = itemKey
        self.targetTypeRawValue = targetTypeRawValue
        self.targetID = targetID
        self.widthColumns = widthColumns
        self.heightUnits = heightUnits
        self.zIndex = zIndex
        self.rotationDegrees = rotationDegrees
        self.scale = scale
        self.isHidden = isHidden
        self.updatedAt = updatedAt
    }
}

@Model
final class EntityNodeStore {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var displayName: String
    var canonicalName: String
    var aliases: [String]
    var summary: String
    var provenanceRecordIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date
    var confidence: Double?

    init(
        id: UUID,
        kindRawValue: String,
        displayName: String,
        canonicalName: String,
        aliases: [String] = [],
        summary: String,
        provenanceRecordIDs: [UUID] = [],
        createdAt: Date,
        updatedAt: Date,
        confidence: Double? = nil
    ) {
        self.id = id
        self.kindRawValue = kindRawValue
        self.displayName = displayName
        self.canonicalName = canonicalName
        self.aliases = aliases
        self.summary = summary
        self.provenanceRecordIDs = provenanceRecordIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.confidence = confidence
    }
}

@Model
final class EntityEdgeStore {
    @Attribute(.unique) var id: UUID
    var fromEntityID: UUID
    var toEntityID: UUID
    var relationKindRawValue: String
    var weight: Double
    var firstSeenAt: Date
    var lastSeenAt: Date
    var evidenceCount: Int
    var sourceArtifactIDs: [UUID]
    var sourceRecordIDs: [UUID]

    init(
        id: UUID,
        fromEntityID: UUID,
        toEntityID: UUID,
        relationKindRawValue: String,
        weight: Double,
        firstSeenAt: Date,
        lastSeenAt: Date,
        evidenceCount: Int,
        sourceArtifactIDs: [UUID] = [],
        sourceRecordIDs: [UUID] = []
    ) {
        self.id = id
        self.fromEntityID = fromEntityID
        self.toEntityID = toEntityID
        self.relationKindRawValue = relationKindRawValue
        self.weight = weight
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.evidenceCount = evidenceCount
        self.sourceArtifactIDs = sourceArtifactIDs
        self.sourceRecordIDs = sourceRecordIDs
    }
}

@Model
final class ArtifactEntityLinkStore {
    @Attribute(.unique) var id: UUID
    var artifactID: UUID
    var entityID: UUID
    var confidence: Double?
    var source: String
    var sourceRecordID: UUID?
    var sourceAnalysisRecordID: UUID?
    var evidenceSummary: String
    var createdAt: Date

    init(
        id: UUID,
        artifactID: UUID,
        entityID: UUID,
        confidence: Double? = nil,
        source: String,
        sourceRecordID: UUID? = nil,
        sourceAnalysisRecordID: UUID? = nil,
        evidenceSummary: String = "",
        createdAt: Date
    ) {
        self.id = id
        self.artifactID = artifactID
        self.entityID = entityID
        self.confidence = confidence
        self.source = source
        self.sourceRecordID = sourceRecordID
        self.sourceAnalysisRecordID = sourceAnalysisRecordID
        self.evidenceSummary = evidenceSummary
        self.createdAt = createdAt
    }
}

@Model
final class RecordAnalysisSnapshotStore {
    @Attribute(.unique) var id: UUID
    var recordID: UUID
    var summary: String
    var themes: [String]
    var emotionInterpretation: String
    var salienceScore: Double
    var retrievalTerms: [String]
    var entityMentionsData: Data?
    var candidateEdgesData: Data?
    var followUpCandidatesData: Data?
    var reflectionHint: String?
    var createdAt: Date

    init(
        id: UUID,
        recordID: UUID,
        summary: String,
        themes: [String],
        emotionInterpretation: String,
        salienceScore: Double,
        retrievalTerms: [String],
        entityMentionsData: Data? = nil,
        candidateEdgesData: Data? = nil,
        followUpCandidatesData: Data? = nil,
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
        self.entityMentionsData = entityMentionsData
        self.candidateEdgesData = candidateEdgesData
        self.followUpCandidatesData = followUpCandidatesData
        self.reflectionHint = reflectionHint
        self.createdAt = createdAt
    }
}

@Model
final class MemoryPipelineStatusStore {
    @Attribute(.unique) var recordID: UUID
    var stageRawValue: String
    var requestID: String?
    var lastError: String?
    var requestBody: String?
    var responseBody: String?
    var rawErrorBody: String?
    var lastHTTPStatusCode: Int?
    var failedStage: String?
    var lastAttemptAt: Date?
    var completedAt: Date?
    var updatedAt: Date

    init(
        recordID: UUID,
        stageRawValue: String,
        requestID: String? = nil,
        lastError: String? = nil,
        requestBody: String? = nil,
        responseBody: String? = nil,
        rawErrorBody: String? = nil,
        lastHTTPStatusCode: Int? = nil,
        failedStage: String? = nil,
        lastAttemptAt: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date
    ) {
        self.recordID = recordID
        self.stageRawValue = stageRawValue
        self.requestID = requestID
        self.lastError = lastError
        self.requestBody = requestBody
        self.responseBody = responseBody
        self.rawErrorBody = rawErrorBody
        self.lastHTTPStatusCode = lastHTTPStatusCode
        self.failedStage = failedStage
        self.lastAttemptAt = lastAttemptAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ReflectionSnapshotStore {
    @Attribute(.unique) var id: UUID
    var typeRawValue: String
    var title: String
    var body: String
    var evidenceSummary: String
    var confidence: Double
    var statusRawValue: String
    var linkedTemporalArcID: UUID?
    var sourceRecordIDs: [UUID]
    var sourceArtifactIDs: [UUID]
    var sourceEntityIDs: [UUID]
    var createdAt: Date
    var savedAt: Date?
    var dismissedAt: Date?

    init(
        id: UUID,
        typeRawValue: String,
        title: String,
        body: String,
        evidenceSummary: String,
        confidence: Double,
        statusRawValue: String,
        linkedTemporalArcID: UUID? = nil,
        sourceRecordIDs: [UUID],
        sourceArtifactIDs: [UUID],
        sourceEntityIDs: [UUID] = [],
        createdAt: Date,
        savedAt: Date? = nil,
        dismissedAt: Date? = nil
    ) {
        self.id = id
        self.typeRawValue = typeRawValue
        self.title = title
        self.body = body
        self.evidenceSummary = evidenceSummary
        self.confidence = confidence
        self.statusRawValue = statusRawValue
        self.linkedTemporalArcID = linkedTemporalArcID
        self.sourceRecordIDs = sourceRecordIDs
        self.sourceArtifactIDs = sourceArtifactIDs
        self.sourceEntityIDs = sourceEntityIDs
        self.createdAt = createdAt
        self.savedAt = savedAt
        self.dismissedAt = dismissedAt
    }
}

@Model
final class TemporalArcStore {
    @Attribute(.unique) var id: UUID
    var title: String
    var summary: String
    var statusRawValue: String
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
        id: UUID,
        title: String,
        summary: String,
        statusRawValue: String,
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
        self.statusRawValue = statusRawValue
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
