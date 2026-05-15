import Foundation
import SwiftData

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

    init(
        id: UUID,
        createdAt: Date,
        updatedAt: Date,
        captureSourceRawValue: String,
        rawText: String,
        userMood: String? = nil,
        userIntensity: Int? = nil,
        inputContext: String? = nil,
        artifactIDs: [UUID] = []
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
    var summary: String
    var createdAt: Date
    var updatedAt: Date
    var confidence: Double?

    init(
        id: UUID,
        kindRawValue: String,
        displayName: String,
        canonicalName: String,
        summary: String,
        createdAt: Date,
        updatedAt: Date,
        confidence: Double? = nil
    ) {
        self.id = id
        self.kindRawValue = kindRawValue
        self.displayName = displayName
        self.canonicalName = canonicalName
        self.summary = summary
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
    var createdAt: Date

    init(
        id: UUID,
        artifactID: UUID,
        entityID: UUID,
        confidence: Double? = nil,
        source: String,
        createdAt: Date
    ) {
        self.id = id
        self.artifactID = artifactID
        self.entityID = entityID
        self.confidence = confidence
        self.source = source
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
    var lastError: String?
    var lastAttemptAt: Date?
    var completedAt: Date?
    var updatedAt: Date

    init(
        recordID: UUID,
        stageRawValue: String,
        lastError: String? = nil,
        lastAttemptAt: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date
    ) {
        self.recordID = recordID
        self.stageRawValue = stageRawValue
        self.lastError = lastError
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
