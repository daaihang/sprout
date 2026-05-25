import Foundation

@MainActor
extension RecordShellStore {
    convenience init(domainModel: RecordShell) {
        self.init(
            id: domainModel.id,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt,
            captureSourceRawValue: domainModel.captureSource.rawValue,
            rawText: domainModel.rawText,
            userMood: domainModel.userMood,
            userIntensity: domainModel.userIntensity,
            inputContext: domainModel.inputContext,
            artifactIDs: domainModel.artifactIDs,
            debugFixtureSeededAt: domainModel.debugFixtureSeededAt
        )
    }

    var domainModel: RecordShell {
        RecordShell(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            captureSource: CaptureSource(rawValue: captureSourceRawValue) ?? .manual,
            rawText: rawText,
            userMood: userMood,
            userIntensity: userIntensity,
            inputContext: inputContext,
            artifactIDs: artifactIDs,
            debugFixtureSeededAt: debugFixtureSeededAt
        )
    }

    func apply(domainModel: RecordShell) {
        id = domainModel.id
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
        captureSourceRawValue = domainModel.captureSource.rawValue
        rawText = domainModel.rawText
        userMood = domainModel.userMood
        userIntensity = domainModel.userIntensity
        inputContext = domainModel.inputContext
        artifactIDs = domainModel.artifactIDs
        debugFixtureSeededAt = domainModel.debugFixtureSeededAt
    }
}

@MainActor
extension ArtifactStore {
    convenience init(domainModel: Artifact) {
        self.init(
            id: domainModel.id,
            recordID: domainModel.recordID,
            kindRawValue: domainModel.kind.rawValue,
            title: domainModel.title,
            summary: domainModel.summary,
            textContent: domainModel.textContent,
            payloadData: PersistenceCoding.encode(domainModel.payload),
            mediaRefData: PersistenceCoding.encode(domainModel.mediaRef),
            metadataData: PersistenceCoding.encode(domainModel.metadata),
            binaryPayload: domainModel.binaryPayload,
            previewPayload: domainModel.previewPayload,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: Artifact {
        Artifact(
            id: id,
            recordID: recordID,
            kind: ArtifactKind(rawValue: kindRawValue) ?? .text,
            title: title,
            summary: summary,
            textContent: textContent,
            payload: PersistenceCoding.decode(ArtifactPayload.self, from: payloadData),
            mediaRef: PersistenceCoding.decode(ArtifactMediaRef.self, from: mediaRefData),
            metadata: PersistenceCoding.decode([String: String].self, from: metadataData) ?? [:],
            binaryPayload: binaryPayload,
            previewPayload: previewPayload,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: Artifact) {
        id = domainModel.id
        recordID = domainModel.recordID
        kindRawValue = domainModel.kind.rawValue
        title = domainModel.title
        summary = domainModel.summary
        textContent = domainModel.textContent
        payloadData = PersistenceCoding.encode(domainModel.payload)
        mediaRefData = PersistenceCoding.encode(domainModel.mediaRef)
        metadataData = PersistenceCoding.encode(domainModel.metadata)
        binaryPayload = domainModel.binaryPayload
        previewPayload = domainModel.previewPayload
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension RecordAnalysisSnapshotStore {
    convenience init(domainModel: RecordAnalysisSnapshot) {
        self.init(
            id: domainModel.id,
            recordID: domainModel.recordID,
            summary: domainModel.summary,
            themes: domainModel.themes,
            emotionInterpretation: domainModel.emotionInterpretation,
            salienceScore: domainModel.salienceScore ?? 0,
            retrievalTerms: domainModel.retrievalTerms,
            entityMentionsData: PersistenceCoding.encode(domainModel.entityMentions),
            candidateEdgesData: PersistenceCoding.encode(domainModel.candidateEdges),
            followUpCandidatesData: PersistenceCoding.encode(domainModel.followUpCandidates),
            reflectionHint: domainModel.reflectionHint,
            createdAt: domainModel.createdAt
        )
    }

    var domainModel: RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            id: id,
            recordID: recordID,
            summary: summary,
            themes: themes,
            emotionInterpretation: emotionInterpretation,
            salienceScore: salienceScore,
            retrievalTerms: retrievalTerms,
            entityMentions: PersistenceCoding.decode([EntityReference].self, from: entityMentionsData) ?? [],
            candidateEdges: PersistenceCoding.decode([CandidateEntityEdge].self, from: candidateEdgesData) ?? [],
            followUpCandidates: PersistenceCoding.decode([FollowUpCandidate].self, from: followUpCandidatesData) ?? [],
            reflectionHint: reflectionHint,
            createdAt: createdAt
        )
    }

    func apply(domainModel: RecordAnalysisSnapshot) {
        id = domainModel.id
        recordID = domainModel.recordID
        summary = domainModel.summary
        themes = domainModel.themes
        emotionInterpretation = domainModel.emotionInterpretation
        salienceScore = domainModel.salienceScore ?? 0
        retrievalTerms = domainModel.retrievalTerms
        entityMentionsData = PersistenceCoding.encode(domainModel.entityMentions)
        candidateEdgesData = PersistenceCoding.encode(domainModel.candidateEdges)
        followUpCandidatesData = PersistenceCoding.encode(domainModel.followUpCandidates)
        reflectionHint = domainModel.reflectionHint
        createdAt = domainModel.createdAt
    }
}

@MainActor
extension MemoryPipelineStatusStore {
    convenience init(domainModel: MemoryPipelineStatusSnapshot) {
        self.init(
            recordID: domainModel.recordID,
            stageRawValue: domainModel.stage.rawValue,
            requestID: domainModel.requestID,
            lastError: domainModel.lastError,
            requestBody: domainModel.requestBody,
            responseBody: domainModel.responseBody,
            rawErrorBody: domainModel.rawErrorBody,
            lastHTTPStatusCode: domainModel.lastHTTPStatusCode,
            failedStage: domainModel.failedStage,
            lastAttemptAt: domainModel.lastAttemptAt,
            completedAt: domainModel.completedAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: MemoryPipelineStatusSnapshot {
        MemoryPipelineStatusSnapshot(
            recordID: recordID,
            stage: MemoryPipelineStage(rawValue: stageRawValue) ?? .pending,
            requestID: requestID,
            lastError: lastError,
            requestBody: requestBody,
            responseBody: responseBody,
            rawErrorBody: rawErrorBody,
            lastHTTPStatusCode: lastHTTPStatusCode,
            failedStage: failedStage,
            lastAttemptAt: lastAttemptAt,
            completedAt: completedAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: MemoryPipelineStatusSnapshot) {
        recordID = domainModel.recordID
        stageRawValue = domainModel.stage.rawValue
        requestID = domainModel.requestID
        lastError = domainModel.lastError
        requestBody = domainModel.requestBody
        responseBody = domainModel.responseBody
        rawErrorBody = domainModel.rawErrorBody
        lastHTTPStatusCode = domainModel.lastHTTPStatusCode
        failedStage = domainModel.failedStage
        lastAttemptAt = domainModel.lastAttemptAt
        completedAt = domainModel.completedAt
        updatedAt = domainModel.updatedAt
    }
}
