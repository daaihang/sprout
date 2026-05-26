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
            captureProvenanceData: PersistenceCoding.encode(domainModel.captureProvenance),
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
            captureProvenance: PersistenceCoding.decode(CaptureProvenance.self, from: captureProvenanceData),
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
        captureProvenanceData = PersistenceCoding.encode(domainModel.captureProvenance)
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
            captureProvenanceData: PersistenceCoding.encode(domainModel.captureProvenance),
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
            captureProvenance: PersistenceCoding.decode(CaptureProvenance.self, from: captureProvenanceData),
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
        captureProvenanceData = PersistenceCoding.encode(domainModel.captureProvenance)
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension ArtifactSemanticDigestStore {
    convenience init(domainModel: ArtifactSemanticDigest) {
        self.init(
            id: domainModel.id,
            recordID: domainModel.recordID,
            artifactID: domainModel.artifactID,
            artifactKindRawValue: domainModel.artifactKind.rawValue,
            schemaVersion: domainModel.schemaVersion,
            sourceRawValue: domainModel.source.rawValue,
            summary: domainModel.summary,
            caption: domainModel.caption,
            ocrText: domainModel.ocrText,
            visualLabels: domainModel.visualLabels,
            transcript: domainModel.transcript,
            languageCode: domainModel.languageCode,
            confidence: domainModel.confidence,
            durationSeconds: domainModel.durationSeconds,
            dimensionsData: PersistenceCoding.encode(domainModel.dimensions),
            captureDate: domainModel.captureDate,
            localIdentifier: domainModel.localIdentifier,
            technicalNotes: domainModel.technicalNotes,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: ArtifactSemanticDigest {
        ArtifactSemanticDigest(
            id: id,
            recordID: recordID,
            artifactID: artifactID,
            artifactKind: ArtifactKind(rawValue: artifactKindRawValue) ?? .document,
            schemaVersion: schemaVersion,
            source: ArtifactSemanticDigestSource(rawValue: sourceRawValue) ?? .localCapture,
            summary: summary,
            caption: caption,
            ocrText: ocrText,
            visualLabels: visualLabels,
            transcript: transcript,
            languageCode: languageCode,
            confidence: confidence,
            durationSeconds: durationSeconds,
            dimensions: PersistenceCoding.decode(ArtifactMediaDimensions.self, from: dimensionsData),
            captureDate: captureDate,
            localIdentifier: localIdentifier,
            technicalNotes: technicalNotes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: ArtifactSemanticDigest) {
        id = domainModel.id
        recordID = domainModel.recordID
        artifactID = domainModel.artifactID
        artifactKindRawValue = domainModel.artifactKind.rawValue
        schemaVersion = domainModel.schemaVersion
        sourceRawValue = domainModel.source.rawValue
        summary = domainModel.summary
        caption = domainModel.caption
        ocrText = domainModel.ocrText
        visualLabels = domainModel.visualLabels
        transcript = domainModel.transcript
        languageCode = domainModel.languageCode
        confidence = domainModel.confidence
        durationSeconds = domainModel.durationSeconds
        dimensionsData = PersistenceCoding.encode(domainModel.dimensions)
        captureDate = domainModel.captureDate
        localIdentifier = domainModel.localIdentifier
        technicalNotes = domainModel.technicalNotes
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension MemoryCardArrangementStore {
    convenience init(domainModel: MemoryCardArrangement) {
        self.init(
            id: domainModel.id,
            recordID: domainModel.recordID,
            schemaVersion: domainModel.schemaVersion,
            nodesData: PersistenceCoding.encode(domainModel.nodes),
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: MemoryCardArrangement {
        MemoryCardArrangement(
            id: id,
            recordID: recordID,
            schemaVersion: schemaVersion,
            nodes: PersistenceCoding.decode([MemoryCardNode].self, from: nodesData) ?? [],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: MemoryCardArrangement) {
        id = domainModel.id
        recordID = domainModel.recordID
        schemaVersion = domainModel.schemaVersion
        nodesData = PersistenceCoding.encode(domainModel.nodes)
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
            stage: MemoryPipelineStage(rawValue: stageRawValue) ?? .notScheduled,
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
