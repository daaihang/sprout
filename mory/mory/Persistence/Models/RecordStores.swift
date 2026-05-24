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
