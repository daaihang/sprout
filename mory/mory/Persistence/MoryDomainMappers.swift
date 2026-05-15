import Foundation

@MainActor
private enum PersistenceCoding {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()

    static func encode<T: Encodable>(_ value: T?) -> Data? {
        guard let value else { return nil }
        return try? encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? decoder.decode(type, from: data)
    }
}

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
extension BoardStore {
    convenience init(domainModel: Board) {
        self.init(
            id: domainModel.id,
            boardKey: domainModel.boardKey,
            kindRawValue: domainModel.kind.rawValue,
            title: domainModel.title,
            subtitle: domainModel.subtitle,
            boardDate: domainModel.boardDate,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: Board {
        Board(
            id: id,
            boardKey: boardKey,
            kind: BoardKind(rawValue: kindRawValue) ?? .homeDay,
            title: title,
            subtitle: subtitle,
            boardDate: boardDate,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: Board) {
        id = domainModel.id
        boardKey = domainModel.boardKey
        kindRawValue = domainModel.kind.rawValue
        title = domainModel.title
        subtitle = domainModel.subtitle
        boardDate = domainModel.boardDate
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension CompositionStore {
    convenience init(domainModel: Composition) {
        self.init(
            id: domainModel.id,
            boardID: domainModel.boardID,
            compositionKey: domainModel.compositionKey,
            title: domainModel.title,
            sortOrder: domainModel.sortOrder,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: Composition {
        Composition(
            id: id,
            boardID: boardID,
            compositionKey: compositionKey,
            title: title,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: Composition) {
        id = domainModel.id
        boardID = domainModel.boardID
        compositionKey = domainModel.compositionKey
        title = domainModel.title
        sortOrder = domainModel.sortOrder
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension CompositionItemStore {
    convenience init(domainModel: CompositionItem) {
        self.init(
            id: domainModel.id,
            boardID: domainModel.boardID,
            boardKey: domainModel.boardKey,
            compositionID: domainModel.compositionID,
            compositionKey: domainModel.compositionKey,
            itemKey: domainModel.itemKey,
            targetTypeRawValue: domainModel.targetType.rawValue,
            targetID: domainModel.targetID,
            widthColumns: domainModel.widthColumns,
            heightUnits: domainModel.heightUnits,
            zIndex: domainModel.zIndex,
            rotationDegrees: domainModel.rotationDegrees,
            scale: domainModel.scale,
            isHidden: domainModel.isHidden,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: CompositionItem {
        CompositionItem(
            id: id,
            boardID: boardID,
            boardKey: boardKey,
            compositionID: compositionID,
            compositionKey: compositionKey,
            itemKey: itemKey,
            targetType: CompositionTargetType(rawValue: targetTypeRawValue) ?? .artifact,
            targetID: targetID,
            widthColumns: widthColumns,
            heightUnits: heightUnits,
            zIndex: zIndex,
            rotationDegrees: rotationDegrees,
            scale: scale,
            isHidden: isHidden,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: CompositionItem) {
        id = domainModel.id
        boardID = domainModel.boardID
        boardKey = domainModel.boardKey
        compositionID = domainModel.compositionID
        compositionKey = domainModel.compositionKey
        itemKey = domainModel.itemKey
        targetTypeRawValue = domainModel.targetType.rawValue
        targetID = domainModel.targetID
        widthColumns = domainModel.widthColumns
        heightUnits = domainModel.heightUnits
        zIndex = domainModel.zIndex
        rotationDegrees = domainModel.rotationDegrees
        scale = domainModel.scale
        isHidden = domainModel.isHidden
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension EntityNodeStore {
    convenience init(domainModel: EntityNode) {
        self.init(
            id: domainModel.id,
            kindRawValue: domainModel.kind.rawValue,
            displayName: domainModel.displayName,
            canonicalName: domainModel.canonicalName,
            aliases: domainModel.aliases,
            summary: domainModel.summary,
            provenanceRecordIDs: domainModel.provenanceRecordIDs,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt,
            confidence: domainModel.confidence
        )
    }

    var domainModel: EntityNode {
        EntityNode(
            id: id,
            kind: EntityKind(rawValue: kindRawValue) ?? .object,
            displayName: displayName,
            canonicalName: canonicalName,
            aliases: aliases,
            summary: summary,
            provenanceRecordIDs: provenanceRecordIDs,
            createdAt: createdAt,
            updatedAt: updatedAt,
            confidence: confidence
        )
    }

    func apply(domainModel: EntityNode) {
        id = domainModel.id
        kindRawValue = domainModel.kind.rawValue
        displayName = domainModel.displayName
        canonicalName = domainModel.canonicalName
        aliases = domainModel.aliases
        summary = domainModel.summary
        provenanceRecordIDs = domainModel.provenanceRecordIDs
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
        confidence = domainModel.confidence
    }
}

@MainActor
extension EntityEdgeStore {
    convenience init(domainModel: EntityEdge) {
        self.init(
            id: domainModel.id,
            fromEntityID: domainModel.fromEntityID,
            toEntityID: domainModel.toEntityID,
            relationKindRawValue: domainModel.relationKind.rawValue,
            weight: domainModel.weight,
            firstSeenAt: domainModel.firstSeenAt,
            lastSeenAt: domainModel.lastSeenAt,
            evidenceCount: domainModel.evidenceCount,
            sourceArtifactIDs: domainModel.sourceArtifactIDs,
            sourceRecordIDs: domainModel.sourceRecordIDs
        )
    }

    var domainModel: EntityEdge {
        EntityEdge(
            id: id,
            fromEntityID: fromEntityID,
            toEntityID: toEntityID,
            relationKind: EntityRelationKind(rawValue: relationKindRawValue) ?? .relatedTo,
            weight: weight,
            firstSeenAt: firstSeenAt,
            lastSeenAt: lastSeenAt,
            evidenceCount: evidenceCount,
            sourceArtifactIDs: sourceArtifactIDs,
            sourceRecordIDs: sourceRecordIDs
        )
    }

    func apply(domainModel: EntityEdge) {
        id = domainModel.id
        fromEntityID = domainModel.fromEntityID
        toEntityID = domainModel.toEntityID
        relationKindRawValue = domainModel.relationKind.rawValue
        weight = domainModel.weight
        firstSeenAt = domainModel.firstSeenAt
        lastSeenAt = domainModel.lastSeenAt
        evidenceCount = domainModel.evidenceCount
        sourceArtifactIDs = domainModel.sourceArtifactIDs
        sourceRecordIDs = domainModel.sourceRecordIDs
    }
}

@MainActor
extension ArtifactEntityLinkStore {
    convenience init(domainModel: ArtifactEntityLink) {
        self.init(
            id: domainModel.id,
            artifactID: domainModel.artifactID,
            entityID: domainModel.entityID,
            confidence: domainModel.confidence,
            source: domainModel.source,
            sourceRecordID: domainModel.sourceRecordID,
            sourceAnalysisRecordID: domainModel.sourceAnalysisRecordID,
            evidenceSummary: domainModel.evidenceSummary,
            createdAt: domainModel.createdAt
        )
    }

    var domainModel: ArtifactEntityLink {
        ArtifactEntityLink(
            id: id,
            artifactID: artifactID,
            entityID: entityID,
            confidence: confidence,
            source: source,
            sourceRecordID: sourceRecordID,
            sourceAnalysisRecordID: sourceAnalysisRecordID,
            evidenceSummary: evidenceSummary,
            createdAt: createdAt
        )
    }

    func apply(domainModel: ArtifactEntityLink) {
        id = domainModel.id
        artifactID = domainModel.artifactID
        entityID = domainModel.entityID
        confidence = domainModel.confidence
        source = domainModel.source
        sourceRecordID = domainModel.sourceRecordID
        sourceAnalysisRecordID = domainModel.sourceAnalysisRecordID
        evidenceSummary = domainModel.evidenceSummary
        createdAt = domainModel.createdAt
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
            salienceScore: domainModel.salienceScore,
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
        salienceScore = domainModel.salienceScore
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

@MainActor
extension ReflectionSnapshotStore {
    convenience init(domainModel: ReflectionSnapshot) {
        self.init(
            id: domainModel.id,
            typeRawValue: domainModel.type.rawValue,
            title: domainModel.title,
            body: domainModel.body,
            evidenceSummary: domainModel.evidenceSummary,
            confidence: domainModel.confidence,
            statusRawValue: domainModel.status.rawValue,
            linkedTemporalArcID: domainModel.linkedTemporalArcID,
            sourceRecordIDs: domainModel.sourceRecordIDs,
            sourceArtifactIDs: domainModel.sourceArtifactIDs,
            sourceEntityIDs: domainModel.sourceEntityIDs,
            createdAt: domainModel.createdAt,
            savedAt: domainModel.savedAt,
            dismissedAt: domainModel.dismissedAt
        )
    }

    var domainModel: ReflectionSnapshot {
        ReflectionSnapshot(
            id: id,
            type: ReflectionType(rawValue: typeRawValue) ?? .record,
            title: title,
            body: body,
            evidenceSummary: evidenceSummary,
            confidence: confidence,
            status: ReflectionStatus(rawValue: statusRawValue) ?? .suggested,
            linkedTemporalArcID: linkedTemporalArcID,
            sourceRecordIDs: sourceRecordIDs,
            sourceArtifactIDs: sourceArtifactIDs,
            sourceEntityIDs: sourceEntityIDs,
            createdAt: createdAt,
            savedAt: savedAt,
            dismissedAt: dismissedAt
        )
    }

    func apply(domainModel: ReflectionSnapshot) {
        id = domainModel.id
        typeRawValue = domainModel.type.rawValue
        title = domainModel.title
        body = domainModel.body
        evidenceSummary = domainModel.evidenceSummary
        confidence = domainModel.confidence
        statusRawValue = domainModel.status.rawValue
        linkedTemporalArcID = domainModel.linkedTemporalArcID
        sourceRecordIDs = domainModel.sourceRecordIDs
        sourceArtifactIDs = domainModel.sourceArtifactIDs
        sourceEntityIDs = domainModel.sourceEntityIDs
        createdAt = domainModel.createdAt
        savedAt = domainModel.savedAt
        dismissedAt = domainModel.dismissedAt
    }
}

@MainActor
extension TemporalArcStore {
    convenience init(domainModel: TemporalArc) {
        self.init(
            id: domainModel.id,
            title: domainModel.title,
            summary: domainModel.summary,
            statusRawValue: domainModel.status.rawValue,
            dominantTheme: domainModel.dominantTheme,
            dominantEntityName: domainModel.dominantEntityName,
            themeLabels: domainModel.themeLabels,
            entityNames: domainModel.entityNames,
            linkedReflectionID: domainModel.linkedReflectionID,
            mergedFromArcIDs: domainModel.mergedFromArcIDs,
            mergedIntoArcID: domainModel.mergedIntoArcID,
            lastMergedAt: domainModel.lastMergedAt,
            sourceRecordIDs: domainModel.sourceRecordIDs,
            sourceArtifactIDs: domainModel.sourceArtifactIDs,
            sourceEntityIDs: domainModel.sourceEntityIDs,
            startDate: domainModel.startDate,
            endDate: domainModel.endDate,
            intensityScore: domainModel.intensityScore,
            clusterStrength: domainModel.clusterStrength,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: TemporalArc {
        TemporalArc(
            id: id,
            title: title,
            summary: summary,
            status: TemporalArcStatus(rawValue: statusRawValue) ?? .candidate,
            dominantTheme: dominantTheme,
            dominantEntityName: dominantEntityName,
            themeLabels: themeLabels,
            entityNames: entityNames,
            linkedReflectionID: linkedReflectionID,
            mergedFromArcIDs: mergedFromArcIDs,
            mergedIntoArcID: mergedIntoArcID,
            lastMergedAt: lastMergedAt,
            sourceRecordIDs: sourceRecordIDs,
            sourceArtifactIDs: sourceArtifactIDs,
            sourceEntityIDs: sourceEntityIDs,
            startDate: startDate,
            endDate: endDate,
            intensityScore: intensityScore,
            clusterStrength: clusterStrength,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: TemporalArc) {
        id = domainModel.id
        title = domainModel.title
        summary = domainModel.summary
        statusRawValue = domainModel.status.rawValue
        dominantTheme = domainModel.dominantTheme
        dominantEntityName = domainModel.dominantEntityName
        themeLabels = domainModel.themeLabels
        entityNames = domainModel.entityNames
        linkedReflectionID = domainModel.linkedReflectionID
        mergedFromArcIDs = domainModel.mergedFromArcIDs
        mergedIntoArcID = domainModel.mergedIntoArcID
        lastMergedAt = domainModel.lastMergedAt
        sourceRecordIDs = domainModel.sourceRecordIDs
        sourceArtifactIDs = domainModel.sourceArtifactIDs
        sourceEntityIDs = domainModel.sourceEntityIDs
        startDate = domainModel.startDate
        endDate = domainModel.endDate
        intensityScore = domainModel.intensityScore
        clusterStrength = domainModel.clusterStrength
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}
