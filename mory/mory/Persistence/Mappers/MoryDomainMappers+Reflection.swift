import Foundation

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

