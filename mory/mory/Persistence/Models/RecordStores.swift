import Foundation
import SwiftData

@Model
final class RecordShellStore {
    @Attribute(.unique) var id: UUID
    var title: String?
    var createdAt: Date
    var updatedAt: Date
    var captureSourceRawValue: String
    var rawText: String
    var userMood: String?
    var userIntensity: Int?
    var inputContext: String?
    var artifactIDs: [UUID]
    var captureProvenanceData: Data?
    var debugFixtureSeededAt: Date?

    init(
        id: UUID,
        title: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        captureSourceRawValue: String,
        rawText: String,
        userMood: String? = nil,
        userIntensity: Int? = nil,
        inputContext: String? = nil,
        artifactIDs: [UUID] = [],
        captureProvenanceData: Data? = nil,
        debugFixtureSeededAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.captureSourceRawValue = captureSourceRawValue
        self.rawText = rawText
        self.userMood = userMood
        self.userIntensity = userIntensity
        self.inputContext = inputContext
        self.artifactIDs = artifactIDs
        self.captureProvenanceData = captureProvenanceData
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
    var captureProvenanceData: Data?
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
        captureProvenanceData: Data? = nil,
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
        self.captureProvenanceData = captureProvenanceData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ArtifactSemanticDigestStore {
    @Attribute(.unique) var id: UUID
    var recordID: UUID
    var artifactID: UUID
    var artifactKindRawValue: String
    var schemaVersion: Int
    var sourceRawValue: String
    var summary: String?
    var caption: String?
    var ocrText: String?
    var visualLabels: [String]
    var transcript: String?
    var languageCode: String?
    var confidence: Double?
    var durationSeconds: Double?
    var dimensionsData: Data?
    var captureDate: String?
    var localIdentifier: String?
    var technicalNotes: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        recordID: UUID,
        artifactID: UUID,
        artifactKindRawValue: String,
        schemaVersion: Int,
        sourceRawValue: String,
        summary: String? = nil,
        caption: String? = nil,
        ocrText: String? = nil,
        visualLabels: [String] = [],
        transcript: String? = nil,
        languageCode: String? = nil,
        confidence: Double? = nil,
        durationSeconds: Double? = nil,
        dimensionsData: Data? = nil,
        captureDate: String? = nil,
        localIdentifier: String? = nil,
        technicalNotes: [String] = [],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.recordID = recordID
        self.artifactID = artifactID
        self.artifactKindRawValue = artifactKindRawValue
        self.schemaVersion = schemaVersion
        self.sourceRawValue = sourceRawValue
        self.summary = summary
        self.caption = caption
        self.ocrText = ocrText
        self.visualLabels = visualLabels
        self.transcript = transcript
        self.languageCode = languageCode
        self.confidence = confidence
        self.durationSeconds = durationSeconds
        self.dimensionsData = dimensionsData
        self.captureDate = captureDate
        self.localIdentifier = localIdentifier
        self.technicalNotes = technicalNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class MemoryCardArrangementStore {
    @Attribute(.unique) var recordID: UUID
    var id: UUID
    var schemaVersion: Int
    var nodesData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        recordID: UUID,
        schemaVersion: Int,
        nodesData: Data? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.recordID = recordID
        self.schemaVersion = schemaVersion
        self.nodesData = nodesData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
