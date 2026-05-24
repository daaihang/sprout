import Foundation
import SwiftData

@MainActor
struct EntityMutationUseCase {
    let repository: MoryMemoryRepository

    func refreshPersonProfile(entityID: UUID, now: Date = .now) throws -> PersonProfile? {
        guard let detail = try repository.fetchEntityDetail(entityID: entityID), detail.entity.kind == .person else {
            return nil
        }
        let entityProfile = try repository.fetchEntityProfile(entityID: entityID)
        let existing = try repository.fetchPersonProfile(entityID: entityID)
        let refreshed = try repository.buildPersonProfile(
            detail: detail,
            entityProfile: entityProfile,
            existing: existing,
            now: now
        )
        try repository.upsert(personProfile: refreshed)
        try repository.save()
        return refreshed
    }

    func applyPersonProfileMutation(_ mutation: PersonProfileMutation) throws -> PersonProfile {
        let now = mutation.createdAt
        let existing = try repository.fetchPersonProfile(entityID: mutation.entityID)
        let profile = if let existing {
            existing
        } else if let refreshed = try refreshPersonProfile(entityID: mutation.entityID, now: now) {
            refreshed
        } else {
            throw PersonEntityMutationError.entityNotFound
        }

        var updated = profile
        switch mutation.field {
        case .displayName:
            guard let value = mutation.stringValue?.trimmedOrNil else {
                throw PersonEntityMutationError.emptyDisplayName
            }
            updated.displayName = value
            updated.canonicalName = value
        case .aliases:
            updated.aliases = repository.normalizedPersonAliases(mutation.stringListValue ?? [])
        case .relationshipToUser:
            updated.relationshipToUser = mutation.relationshipValue
            updated.relationshipHistory.append(RelationshipChange(
                relationship: mutation.relationshipValue,
                note: mutation.note,
                status: .userConfirmed,
                changedAt: now
            ))
        case .roleLabels:
            updated.roleLabels = repository.mergeStrings([], mutation.stringListValue ?? [])
        case .userNotes:
            updated.userNotes = mutation.stringValue?.trimmedOrNil
        case .sensitivity:
            updated.sensitivity = mutation.sensitivityValue ?? updated.sensitivity
        case .automationPolicy:
            updated.automationPolicy = mutation.automationPolicyValue ?? updated.automationPolicy
        case .aiPortrait:
            updated.aiPortrait = nil
        }

        updated.fieldEvidence.removeAll {
            $0.fieldKey == mutation.field.rawValue && $0.source == .userEdit
        }
        updated.fieldEvidence.append(ProfileFieldEvidence(
            fieldKey: mutation.field.rawValue,
            source: .userEdit,
            status: .userConfirmed,
            snippet: mutation.note?.trimmedOrNil ?? "User edited \(mutation.field.rawValue).",
            confidence: 1,
            createdAt: now,
            refreshedAt: now
        ))
        updated.fieldConfidence[mutation.field.rawValue] = 1
        updated.lastReviewedAt = now
        updated.updatedAt = now

        try repository.upsert(personProfile: updated)
        try repository.upsert(correctionEvent: CorrectionEvent(
            kind: .profileFieldUpdated,
            actor: mutation.actor,
            targetEntityIDs: [mutation.entityID],
            note: mutation.note ?? "Person profile field edited: \(mutation.field.rawValue)",
            metadata: [
                "field": mutation.field.rawValue,
            ],
            isReversible: true,
            createdAt: now
        ))
        try repository.save()
        return updated
    }

    func deletePersonProfilePortrait(entityID: UUID) throws -> PersonProfile {
        try applyPersonProfileMutation(
            PersonProfileMutation(
                entityID: entityID,
                field: .aiPortrait,
                note: "AI portrait deleted by user."
            )
        )
    }

    func renamePlaceProfile(id: UUID, displayName: String, aliases: [String]) throws -> PlaceProfile {
        let now = Date.now
        let resolvedName = try repository.normalizedPlaceDisplayName(displayName)
        let store = try repository.requirePlaceProfileStore(id: id)
        var profile = store.domainModel
        profile.displayName = resolvedName
        profile.canonicalName = resolvedName
        profile.aliases = repository.normalizedPlaceAliases([resolvedName] + aliases)
        profile.confirmationState = .userConfirmed
        profile.updatedAt = now
        store.apply(domainModel: profile)
        try repository.upsertPlaceEntityNode(for: profile, updatedAt: now)
        try repository.save()
        return profile
    }

    func mergePlaceProfiles(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> PlaceProfile {
        let now = Date.now
        let mergingIDSet = Set(mergingIDs)
        guard !mergingIDSet.isEmpty else {
            throw PlaceProfileMutationError.mergeRequiresAtLeastOneOtherProfile
        }
        guard !mergingIDSet.contains(primaryID) else {
            throw PlaceProfileMutationError.mergeCannotIncludePrimary
        }

        let primaryStore = try repository.requirePlaceProfileStore(id: primaryID)
        let mergingStores = try mergingIDSet.map { try repository.requirePlaceProfileStore(id: $0) }
        let mergingProfiles = mergingStores.map(\.domainModel)
        let mergingEntityIDs = Set(mergingProfiles.map(\.entityID))
        let replacementMap = Dictionary(uniqueKeysWithValues: mergingEntityIDs.map { ($0, primaryStore.entityID) })

        var primaryProfile = primaryStore.domainModel
        if let displayName, let trimmedName = displayName.trimmedOrNil {
            primaryProfile.displayName = trimmedName
            primaryProfile.canonicalName = trimmedName
        }
        primaryProfile.aliases = repository.normalizedPlaceAliases(
            [primaryProfile.displayName, primaryProfile.canonicalName]
                + primaryProfile.aliases
                + mergingProfiles.flatMap { [$0.displayName, $0.canonicalName] + $0.aliases }
        )
        primaryProfile.sourceArtifactIDs = repository.mergeUniqueIDs(
            primaryProfile.sourceArtifactIDs,
            mergingProfiles.flatMap(\.sourceArtifactIDs)
        )
        primaryProfile.sourceRecordIDs = repository.mergeUniqueIDs(
            primaryProfile.sourceRecordIDs,
            mergingProfiles.flatMap(\.sourceRecordIDs)
        )
        primaryProfile.confirmationState = .userConfirmed
        primaryProfile.confidence = repository.maxConfidence([primaryProfile] + mergingProfiles)
        primaryProfile.updatedAt = now

        let mergedArtifacts = try repository.fetchArtifacts(ids: primaryProfile.sourceArtifactIDs)
        primaryProfile = repository.recalculatedPlaceProfile(primaryProfile, from: mergedArtifacts, updatedAt: now)
        primaryStore.apply(domainModel: primaryProfile)

        try repository.rewritePlaceGraphReferences(replacing: replacementMap)
        try repository.upsertPlaceEntityNode(for: primaryProfile, updatedAt: now)
        try repository.deletePlaceProfilesAndNodes(stores: mergingStores)
        try repository.save()
        return primaryProfile
    }

    func splitPlaceProfile(id: UUID, movingArtifactIDs: [UUID], displayName: String) throws -> PlaceProfile {
        let now = Date.now
        let resolvedName = try repository.normalizedPlaceDisplayName(displayName)
        let movingIDSet = Set(movingArtifactIDs)
        guard !movingIDSet.isEmpty else {
            throw PlaceProfileMutationError.splitRequiresMovingArtifacts
        }

        let originalStore = try repository.requirePlaceProfileStore(id: id)
        var originalProfile = originalStore.domainModel
        let originalArtifactIDSet = Set(originalProfile.sourceArtifactIDs)
        guard movingIDSet.isSubset(of: originalArtifactIDSet) else {
            throw PlaceProfileMutationError.splitArtifactsNotInProfile
        }
        guard movingIDSet.count < originalArtifactIDSet.count else {
            throw PlaceProfileMutationError.splitCannotMoveAllArtifacts
        }

        let allArtifacts = try repository.fetchArtifacts(ids: originalProfile.sourceArtifactIDs)
        let movingArtifacts = allArtifacts.filter { movingIDSet.contains($0.id) }
        guard movingArtifacts.allSatisfy({ $0.kind == .location }) else {
            throw PlaceProfileMutationError.splitArtifactsMustBeLocations
        }
        let remainingArtifacts = allArtifacts.filter { !movingIDSet.contains($0.id) }

        let newProfile = repository.recalculatedPlaceProfile(
            PlaceProfile(
                entityID: UUID(),
                displayName: resolvedName,
                aliases: [resolvedName],
                sourceArtifactIDs: movingArtifacts.map(\.id),
                sourceRecordIDs: movingArtifacts.map(\.recordID),
                confirmationState: .userConfirmed,
                confidence: originalProfile.confidence,
                createdAt: now,
                updatedAt: now
            ),
            from: movingArtifacts,
            updatedAt: now
        )
        originalProfile.sourceArtifactIDs = remainingArtifacts.map(\.id)
        originalProfile.sourceRecordIDs = repository.mergeUniqueIDs([], remainingArtifacts.map(\.recordID))
        originalProfile.confirmationState = .userConfirmed
        originalProfile.updatedAt = now
        originalProfile = repository.recalculatedPlaceProfile(originalProfile, from: remainingArtifacts, updatedAt: now)

        originalStore.apply(domainModel: originalProfile)
        repository.modelContext.insert(PlaceProfileStore(domainModel: newProfile))
        try repository.movePlaceArtifactLinks(
            artifactIDs: movingIDSet,
            fromEntityID: originalProfile.entityID,
            toProfile: newProfile,
            updatedAt: now
        )
        try repository.splitEntityEdges(
            fromEntityID: originalProfile.entityID,
            toEntityID: newProfile.entityID,
            movingArtifactIDs: movingIDSet,
            movingRecordIDs: Set(movingArtifacts.map(\.recordID))
        )
        try repository.upsertPlaceEntityNode(for: originalProfile, updatedAt: now)
        try repository.upsertPlaceEntityNode(for: newProfile, updatedAt: now)
        try repository.save()
        return newProfile
    }

    func mergePersonEntities(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> EntityProfile {
        let now = Date.now
        let mergingIDSet = Set(mergingIDs)
        guard !mergingIDSet.isEmpty else {
            throw PersonEntityMutationError.mergeRequiresAtLeastOneOtherEntity
        }
        guard !mergingIDSet.contains(primaryID) else {
            throw PersonEntityMutationError.mergeCannotIncludePrimary
        }

        let primaryStore = try repository.requirePersonEntityNodeStore(id: primaryID)
        let mergingStores = try mergingIDSet.map { try repository.requirePersonEntityNodeStore(id: $0) }
        let mergingNodes = mergingStores.map(\.domainModel)
        let replacementMap = Dictionary(uniqueKeysWithValues: mergingNodes.map { ($0.id, primaryID) })

        var primaryNode = primaryStore.domainModel
        if let displayName, let normalized = displayName.trimmedOrNil {
            primaryNode.displayName = normalized
            primaryNode.canonicalName = normalized
        }
        primaryNode.aliases = repository.normalizedPersonAliases(
            [primaryNode.displayName, primaryNode.canonicalName]
                + primaryNode.aliases
                + mergingNodes.flatMap { [$0.displayName, $0.canonicalName] + $0.aliases }
        )
        primaryNode.provenanceRecordIDs = repository.mergeUniqueIDs(
            primaryNode.provenanceRecordIDs,
            mergingNodes.flatMap(\.provenanceRecordIDs)
        )
        primaryNode.updatedAt = now
        let nodeConfidences = [primaryNode.confidence].compactMap { $0 } + mergingNodes.compactMap(\.confidence)
        primaryNode.confidence = nodeConfidences.max()

        let primaryProfile = try repository.fetchEntityProfile(entityID: primaryID)
            ?? repository.makePersonProfile(from: primaryNode, updatedAt: now)
        let mergingProfiles = try mergingIDSet.compactMap { entityID in
            try repository.fetchEntityProfile(entityID: entityID)
        }

        var mergedProfile = primaryProfile
        mergedProfile.displayName = primaryNode.displayName
        mergedProfile.canonicalName = primaryNode.canonicalName
        mergedProfile.aliases = repository.normalizedPersonAliases(
            [primaryNode.displayName, primaryNode.canonicalName]
                + primaryProfile.aliases
                + mergingProfiles.flatMap { [$0.displayName, $0.canonicalName] + $0.aliases }
        )
        mergedProfile.sourceRecordIDs = repository.mergeUniqueIDs(
            primaryProfile.sourceRecordIDs,
            mergingProfiles.flatMap(\.sourceRecordIDs) + primaryNode.provenanceRecordIDs
        )
        mergedProfile.mentionCount = max(
            mergedProfile.sourceRecordIDs.count,
            primaryProfile.mentionCount + mergingProfiles.map(\.mentionCount).reduce(0, +)
        )
        mergedProfile.commonContextLabels = repository.mergeStrings(
            primaryProfile.commonContextLabels,
            mergingProfiles.flatMap(\.commonContextLabels)
        )
        if mergedProfile.relationshipToUser == nil {
            mergedProfile.relationshipToUser = mergingProfiles.compactMap(\.relationshipToUser).first
        }
        mergedProfile.userDescription = mergedProfile.userDescription?.trimmedOrNil
            ?? mergingProfiles.compactMap(\.userDescription).map { $0.trimmedOrNil }.compactMap { $0 }.first
        mergedProfile.confirmationState = .userConfirmed
        let profileConfidences = [primaryProfile.confidence].compactMap { $0 } + mergingProfiles.compactMap(\.confidence)
        mergedProfile.confidence = profileConfidences.max()
        mergedProfile.updatedAt = now
        if mergedProfile.firstMentionedAt == nil {
            mergedProfile.firstMentionedAt = now
        }
        mergedProfile.lastMentionedAt = now

        primaryStore.apply(domainModel: primaryNode)
        try repository.upsert(entityProfile: mergedProfile)
        try repository.mergePersonProfiles(
            primaryID: primaryID,
            mergingIDs: mergingIDSet,
            mergedEntityProfile: mergedProfile,
            now: now
        )
        try repository.rewriteEntityLinksAndEdges(replacing: replacementMap, linkSource: "personProfile")
        try repository.rewriteEntityReferencesForMerge(replacing: replacementMap)
        try repository.deleteEntityProfiles(entityIDs: mergingIDSet)
        try repository.deletePersonProfiles(entityIDs: mergingIDSet)
        try repository.deleteEntityNodes(entityIDs: mergingIDSet)

        let affectedRecordIDs = Set(primaryNode.provenanceRecordIDs + mergingNodes.flatMap(\.provenanceRecordIDs))
        for mergingID in mergingIDSet {
            try repository.upsert(entityTombstone: EntityTombstone(
                oldEntityID: mergingID,
                replacementEntityID: primaryID,
                kind: .person,
                reason: .merged,
                note: "Merged into \(primaryNode.displayName)",
                createdAt: now
            ))
            try repository.upsert(correctionEvent: CorrectionEvent(
                kind: .sameEntity,
                actor: .user,
                targetEntityIDs: [primaryID, mergingID],
                targetRecordIDs: [],
                sourceRecordIDs: Array(affectedRecordIDs),
                note: "Person merge",
                metadata: [
                    "primaryEntityID": primaryID.uuidString,
                    "mergedEntityID": mergingID.uuidString,
                ],
                isReversible: true,
                createdAt: now
            ))
        }

        try repository.enqueueEntityMutationRecomputeJobs(
            affectedRecordIDs: affectedRecordIDs,
            affectedEntityIDs: Set([primaryID] + Array(mergingIDSet))
        )
        try repository.save()
        return mergedProfile
    }

    func splitPersonEntity(
        id: UUID,
        movingRecordIDs: [UUID],
        displayName: String,
        aliases: [String]
    ) throws -> EntityProfile {
        let now = Date.now
        guard let normalizedName = displayName.trimmedOrNil else {
            throw PersonEntityMutationError.emptyDisplayName
        }
        let movingRecordIDSet = Set(movingRecordIDs)
        guard !movingRecordIDSet.isEmpty else {
            throw PersonEntityMutationError.splitRequiresMovingRecords
        }

        let originalStore = try repository.requirePersonEntityNodeStore(id: id)
        var originalNode = originalStore.domainModel
        let originalProfile = try repository.fetchEntityProfile(entityID: id) ?? repository.makePersonProfile(from: originalNode, updatedAt: now)

        let originalRecordIDSet = Set(repository.mergeUniqueIDs(originalNode.provenanceRecordIDs, originalProfile.sourceRecordIDs))
        guard movingRecordIDSet.isSubset(of: originalRecordIDSet) else {
            throw PersonEntityMutationError.splitRecordsNotInEntity
        }
        guard movingRecordIDSet.count < originalRecordIDSet.count else {
            throw PersonEntityMutationError.splitCannotMoveAllRecords
        }

        let newEntityID = UUID()
        let movedAliases = repository.normalizedPersonAliases([normalizedName] + aliases)
        let movingRecordIDArray = originalProfile.sourceRecordIDs.filter { movingRecordIDSet.contains($0) }
        let remainingRecordIDArray = originalProfile.sourceRecordIDs.filter { !movingRecordIDSet.contains($0) }

        var newNode = EntityNode(
            id: newEntityID,
            kind: .person,
            displayName: normalizedName,
            canonicalName: normalizedName,
            aliases: movedAliases,
            summary: originalNode.summary,
            provenanceRecordIDs: originalNode.provenanceRecordIDs.filter { movingRecordIDSet.contains($0) },
            createdAt: now,
            updatedAt: now,
            confidence: originalNode.confidence
        )
        if newNode.provenanceRecordIDs.isEmpty {
            newNode.provenanceRecordIDs = Array(movingRecordIDSet)
        }

        originalNode.provenanceRecordIDs.removeAll { movingRecordIDSet.contains($0) }
        originalNode.updatedAt = now
        originalStore.apply(domainModel: originalNode)
        try repository.upsert(entityNode: newNode)

        var updatedOriginalProfile = originalProfile
        updatedOriginalProfile.sourceRecordIDs = remainingRecordIDArray
        updatedOriginalProfile.mentionCount = max(1, remainingRecordIDArray.count)
        updatedOriginalProfile.updatedAt = now
        updatedOriginalProfile.lastMentionedAt = now
        try repository.upsert(entityProfile: updatedOriginalProfile)

        let newProfile = EntityProfile(
            entityID: newEntityID,
            kind: .person,
            displayName: normalizedName,
            canonicalName: normalizedName,
            aliases: movedAliases,
            relationshipToUser: originalProfile.relationshipToUser,
            userDescription: originalProfile.userDescription,
            mentionCount: max(1, movingRecordIDArray.count),
            firstMentionedAt: originalProfile.firstMentionedAt,
            lastMentionedAt: now,
            commonContextLabels: originalProfile.commonContextLabels,
            sourceRecordIDs: movingRecordIDArray,
            confirmationState: .suggested,
            confidence: originalProfile.confidence,
            createdAt: now,
            updatedAt: now
        )
        try repository.upsert(entityProfile: newProfile)
        try repository.splitPersonProfiles(
            fromEntityID: id,
            toEntityID: newEntityID,
            newEntityProfile: newProfile,
            movingRecordIDs: movingRecordIDSet,
            now: now
        )

        let movedArtifactIDs = try repository.movePersonArtifactLinks(
            fromEntityID: id,
            toEntityID: newEntityID,
            movingRecordIDs: movingRecordIDSet,
            updatedAt: now
        )
        try repository.splitEntityEdges(
            fromEntityID: id,
            toEntityID: newEntityID,
            movingArtifactIDs: movedArtifactIDs,
            movingRecordIDs: movingRecordIDSet
        )
        try repository.rewriteEntityReferencesForSplit(
            fromEntityID: id,
            toEntityID: newEntityID,
            movingRecordIDs: movingRecordIDSet
        )
        try repository.upsert(correctionEvent: CorrectionEvent(
            kind: .splitEntity,
            actor: .user,
            targetEntityIDs: [id, newEntityID],
            sourceRecordIDs: Array(movingRecordIDSet),
            note: "Person split",
            metadata: [
                "fromEntityID": id.uuidString,
                "toEntityID": newEntityID.uuidString,
            ],
            isReversible: true,
            createdAt: now
        ))
        try repository.enqueueEntityMutationRecomputeJobs(
            affectedRecordIDs: Set(repository.mergeUniqueIDs(Array(originalRecordIDSet), Array(movingRecordIDSet))),
            affectedEntityIDs: Set([id, newEntityID])
        )
        try repository.save()
        return newProfile
    }
}
