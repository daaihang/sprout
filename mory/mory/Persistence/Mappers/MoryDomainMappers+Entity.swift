import Foundation

@MainActor
extension CorrectionEventStore {
    convenience init(domainModel: CorrectionEvent) {
        self.init(
            id: domainModel.id,
            kindRawValue: domainModel.kind.rawValue,
            actorRawValue: domainModel.actor.rawValue,
            targetEntityIDs: domainModel.targetEntityIDs,
            targetRecordIDs: domainModel.targetRecordIDs,
            sourceRecordIDs: domainModel.sourceRecordIDs,
            note: domainModel.note,
            metadataData: PersistenceCoding.encode(domainModel.metadata),
            isReversible: domainModel.isReversible,
            createdAt: domainModel.createdAt,
            reversedAt: domainModel.reversedAt
        )
    }

    var domainModel: CorrectionEvent {
        CorrectionEvent(
            id: id,
            kind: CorrectionEventKind(rawValue: kindRawValue) ?? .profileFieldIncorrect,
            actor: CorrectionActor(rawValue: actorRawValue) ?? .user,
            targetEntityIDs: targetEntityIDs,
            targetRecordIDs: targetRecordIDs,
            sourceRecordIDs: sourceRecordIDs,
            note: note,
            metadata: PersistenceCoding.decode([String: String].self, from: metadataData) ?? [:],
            isReversible: isReversible,
            createdAt: createdAt,
            reversedAt: reversedAt
        )
    }

    func apply(domainModel: CorrectionEvent) {
        id = domainModel.id
        kindRawValue = domainModel.kind.rawValue
        actorRawValue = domainModel.actor.rawValue
        targetEntityIDs = domainModel.targetEntityIDs
        targetRecordIDs = domainModel.targetRecordIDs
        sourceRecordIDs = domainModel.sourceRecordIDs
        note = domainModel.note
        metadataData = PersistenceCoding.encode(domainModel.metadata)
        isReversible = domainModel.isReversible
        createdAt = domainModel.createdAt
        reversedAt = domainModel.reversedAt
    }
}

@MainActor
extension EntityTombstoneStore {
    convenience init(domainModel: EntityTombstone) {
        self.init(
            id: domainModel.id,
            oldEntityID: domainModel.oldEntityID,
            replacementEntityID: domainModel.replacementEntityID,
            kindRawValue: domainModel.kind.rawValue,
            reasonRawValue: domainModel.reason.rawValue,
            note: domainModel.note,
            createdAt: domainModel.createdAt
        )
    }

    var domainModel: EntityTombstone {
        EntityTombstone(
            id: id,
            oldEntityID: oldEntityID,
            replacementEntityID: replacementEntityID,
            kind: EntityKind(rawValue: kindRawValue) ?? .object,
            reason: EntityTombstoneReason(rawValue: reasonRawValue) ?? .merged,
            note: note,
            createdAt: createdAt
        )
    }

    func apply(domainModel: EntityTombstone) {
        id = domainModel.id
        oldEntityID = domainModel.oldEntityID
        replacementEntityID = domainModel.replacementEntityID
        kindRawValue = domainModel.kind.rawValue
        reasonRawValue = domainModel.reason.rawValue
        note = domainModel.note
        createdAt = domainModel.createdAt
    }
}

@MainActor
extension EntityProfileStore {
    convenience init(domainModel: EntityProfile) {
        self.init(
            id: domainModel.id,
            entityID: domainModel.entityID,
            kindRawValue: domainModel.kind.rawValue,
            displayName: domainModel.displayName,
            canonicalName: domainModel.canonicalName,
            aliases: domainModel.aliases,
            relationshipToUserRawValue: domainModel.relationshipToUser?.rawValue,
            userDescription: domainModel.userDescription,
            mentionCount: domainModel.mentionCount,
            firstMentionedAt: domainModel.firstMentionedAt,
            lastMentionedAt: domainModel.lastMentionedAt,
            commonContextLabels: domainModel.commonContextLabels,
            sourceRecordIDs: domainModel.sourceRecordIDs,
            confirmationStateRawValue: domainModel.confirmationState.rawValue,
            confidence: domainModel.confidence,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: EntityProfile {
        EntityProfile(
            id: id,
            entityID: entityID,
            kind: EntityKind(rawValue: kindRawValue) ?? .object,
            displayName: displayName,
            canonicalName: canonicalName,
            aliases: aliases,
            relationshipToUser: relationshipToUserRawValue.flatMap(EntityRelationshipToUser.init(rawValue:)),
            userDescription: userDescription,
            mentionCount: mentionCount,
            firstMentionedAt: firstMentionedAt,
            lastMentionedAt: lastMentionedAt,
            commonContextLabels: commonContextLabels,
            sourceRecordIDs: sourceRecordIDs,
            confirmationState: IntelligenceConfirmationState(rawValue: confirmationStateRawValue) ?? .inferred,
            confidence: confidence,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: EntityProfile) {
        id = domainModel.id
        entityID = domainModel.entityID
        kindRawValue = domainModel.kind.rawValue
        displayName = domainModel.displayName
        canonicalName = domainModel.canonicalName
        aliases = domainModel.aliases
        relationshipToUserRawValue = domainModel.relationshipToUser?.rawValue
        userDescription = domainModel.userDescription
        mentionCount = domainModel.mentionCount
        firstMentionedAt = domainModel.firstMentionedAt
        lastMentionedAt = domainModel.lastMentionedAt
        commonContextLabels = domainModel.commonContextLabels
        sourceRecordIDs = domainModel.sourceRecordIDs
        confirmationStateRawValue = domainModel.confirmationState.rawValue
        confidence = domainModel.confidence
        createdAt = domainModel.createdAt
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
