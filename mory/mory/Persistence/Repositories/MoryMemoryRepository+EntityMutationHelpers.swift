import Foundation
import SwiftData

extension MoryMemoryRepository {
// MARK: - Private: Place & Entity Mutation

    func makePersonProfile(from entity: EntityNode, updatedAt: Date) -> EntityProfile {
        EntityProfile(
            entityID: entity.id,
            kind: .person,
            displayName: entity.displayName,
            canonicalName: entity.canonicalName,
            aliases: entity.aliases,
            mentionCount: max(1, entity.provenanceRecordIDs.count),
            firstMentionedAt: entity.createdAt,
            lastMentionedAt: updatedAt,
            commonContextLabels: [],
            sourceRecordIDs: entity.provenanceRecordIDs,
            confirmationState: .inferred,
            confidence: entity.confidence,
            createdAt: entity.createdAt,
            updatedAt: updatedAt
        )
    }

    func recalculatedPlaceProfile(_ profile: PlaceProfile, from artifacts: [Artifact], updatedAt: Date) -> PlaceProfile {
        let locationArtifacts = artifacts.filter { $0.kind == .location }
        let coordinates = locationArtifacts.compactMap { PlaceContextResolver.coordinate(for: $0) }
        var updated = profile
        updated.sourceArtifactIDs = mergeUniqueIDs([], locationArtifacts.map(\.id))
        updated.sourceRecordIDs = mergeUniqueIDs([], locationArtifacts.map(\.recordID))
        updated.mentionCount = locationArtifacts.isEmpty ? profile.mentionCount : locationArtifacts.count
        updated.updatedAt = updatedAt

        guard !coordinates.isEmpty else {
            updated.centroidLatitude = nil
            updated.centroidLongitude = nil
            updated.radiusMeters = 0
            return updated
        }

        let latitude = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let longitude = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        let centroid = PlaceCoordinate(latitude: latitude, longitude: longitude)
        let maxDistance = coordinates.map { $0.distance(to: centroid) }.max() ?? 0
        updated.centroidLatitude = latitude
        updated.centroidLongitude = longitude
        updated.radiusMeters = max(120, min(maxDistance + 60, 900))
        return updated
    }

    func upsertPlaceEntityNode(for profile: PlaceProfile, updatedAt: Date) throws {
        let entity = EntityNode(
            id: profile.entityID,
            kind: .place,
            displayName: profile.displayName,
            canonicalName: profile.canonicalName,
            aliases: profile.aliases,
            summary: placeProfileSummary(profile),
            provenanceRecordIDs: profile.sourceRecordIDs,
            createdAt: profile.createdAt,
            updatedAt: updatedAt,
            confidence: profile.confidence
        )
        try upsert(entityNode: entity)
    }

    func placeProfileSummary(_ profile: PlaceProfile) -> String {
        guard let latitude = profile.centroidLatitude, let longitude = profile.centroidLongitude else {
            return profile.canonicalName
        }
        return "\(profile.canonicalName) · \(String(format: "%.5f", latitude)), \(String(format: "%.5f", longitude))"
    }

    func movePlaceArtifactLinks(
        artifactIDs: Set<UUID>,
        fromEntityID: UUID,
        toProfile: PlaceProfile,
        updatedAt: Date
    ) throws {
        let linkStores = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        let artifactStores = try modelContext.fetch(FetchDescriptor<ArtifactStore>())
        let artifactsByID = Dictionary(uniqueKeysWithValues: artifactStores.map { ($0.id, $0.domainModel) })

        for artifactID in artifactIDs {
            var didMoveExistingLink = false
            for store in linkStores where store.artifactID == artifactID && store.entityID == fromEntityID {
                var link = store.domainModel
                link.entityID = toProfile.entityID
                link.confidence = max(link.confidence ?? 0, toProfile.confidence ?? 0)
                link.source = "placeProfile"
                link.sourceRecordID = artifactsByID[artifactID]?.recordID
                link.evidenceSummary = "Moved to place profile: \(toProfile.canonicalName)"
                store.apply(domainModel: link)
                didMoveExistingLink = true
            }

            if !didMoveExistingLink, let artifact = artifactsByID[artifactID] {
                modelContext.insert(ArtifactEntityLinkStore(domainModel: ArtifactEntityLink(
                    artifactID: artifactID,
                    entityID: toProfile.entityID,
                    confidence: toProfile.confidence,
                    source: "placeProfile",
                    sourceRecordID: artifact.recordID,
                    evidenceSummary: "Moved to place profile: \(toProfile.canonicalName)",
                    createdAt: updatedAt
                )))
            }
        }
    }

    func rewritePlaceGraphReferences(replacing replacements: [UUID: UUID]) throws {
        try rewriteEntityLinksAndEdges(replacing: replacements, linkSource: "placeProfile")
    }

    func splitEntityEdges(
        fromEntityID: UUID,
        toEntityID: UUID,
        movingArtifactIDs: Set<UUID>,
        movingRecordIDs: Set<UUID>
    ) throws {
        guard !(movingArtifactIDs.isEmpty && movingRecordIDs.isEmpty) else { return }
        let edgeStores = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>())

        for store in edgeStores {
            let edge = store.domainModel
            guard edge.fromEntityID == fromEntityID || edge.toEntityID == fromEntityID else { continue }
            let movingSourceArtifactIDs = edge.sourceArtifactIDs.filter { movingArtifactIDs.contains($0) }
            let movingSourceRecordIDs = edge.sourceRecordIDs.filter { movingRecordIDs.contains($0) }
            guard !movingSourceArtifactIDs.isEmpty || !movingSourceRecordIDs.isEmpty else { continue }

            let remainingArtifactIDs = edge.sourceArtifactIDs.filter { !movingArtifactIDs.contains($0) }
            let remainingRecordIDs = edge.sourceRecordIDs.filter { !movingRecordIDs.contains($0) }
            var originalEdge = edge
            originalEdge.sourceArtifactIDs = remainingArtifactIDs
            originalEdge.sourceRecordIDs = remainingRecordIDs
            originalEdge.evidenceCount = max(1, remainingArtifactIDs.count + remainingRecordIDs.count)

            var movedEdge = edge
            if movedEdge.fromEntityID == fromEntityID {
                movedEdge.fromEntityID = toEntityID
            }
            if movedEdge.toEntityID == fromEntityID {
                movedEdge.toEntityID = toEntityID
            }
            movedEdge.sourceArtifactIDs = movingSourceArtifactIDs
            movedEdge.sourceRecordIDs = movingSourceRecordIDs
            movedEdge.evidenceCount = max(1, movingSourceArtifactIDs.count + movingSourceRecordIDs.count)

            if remainingArtifactIDs.isEmpty && remainingRecordIDs.isEmpty {
                if movedEdge.fromEntityID == movedEdge.toEntityID {
                    modelContext.delete(store)
                } else {
                    store.apply(domainModel: movedEdge)
                }
            } else {
                store.apply(domainModel: originalEdge)
                if movedEdge.fromEntityID != movedEdge.toEntityID {
                    modelContext.insert(EntityEdgeStore(domainModel: EntityEdge(
                        fromEntityID: movedEdge.fromEntityID,
                        toEntityID: movedEdge.toEntityID,
                        relationKind: movedEdge.relationKind,
                        weight: movedEdge.weight,
                        firstSeenAt: movedEdge.firstSeenAt,
                        lastSeenAt: movedEdge.lastSeenAt,
                        evidenceCount: movedEdge.evidenceCount,
                        sourceArtifactIDs: movedEdge.sourceArtifactIDs,
                        sourceRecordIDs: movedEdge.sourceRecordIDs
                    )))
                }
            }
        }

        try deduplicateEntityEdges()
    }

    // MARK: - Private: Entity Rewrite & Merge Helpers

    func rewriteEntityLinksAndEdges(
        replacing replacements: [UUID: UUID],
        linkSource: String?
    ) throws {
        guard !replacements.isEmpty else { return }

        let linkStores = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        for store in linkStores {
            guard let replacementID = replacements[store.entityID] else { continue }
            var link = store.domainModel
            link.entityID = replacementID
            if let linkSource {
                link.source = linkSource
            }
            store.apply(domainModel: link)
        }

        let edgeStores = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>())
        for store in edgeStores {
            var edge = store.domainModel
            var changed = false
            if let replacementID = replacements[edge.fromEntityID] {
                edge.fromEntityID = replacementID
                changed = true
            }
            if let replacementID = replacements[edge.toEntityID] {
                edge.toEntityID = replacementID
                changed = true
            }
            guard changed else { continue }
            if edge.fromEntityID == edge.toEntityID {
                modelContext.delete(store)
            } else {
                store.apply(domainModel: edge)
            }
        }

        try deduplicateEntityEdges()
    }

    func rewriteEntityReferencesForMerge(replacing replacements: [UUID: UUID]) throws {
        guard !replacements.isEmpty else { return }

        let arcStores = try modelContext.fetch(FetchDescriptor<TemporalArcStore>())
        for store in arcStores {
            var arc = store.domainModel
            let remap = remappedUniqueIDs(arc.sourceEntityIDs, replacements: replacements)
            guard remap.changed else { continue }
            arc.sourceEntityIDs = remap.values
            arc.updatedAt = Date.now
            store.apply(domainModel: arc)
        }

        let reflectionStores = try modelContext.fetch(FetchDescriptor<ReflectionSnapshotStore>())
        for store in reflectionStores {
            var reflection = store.domainModel
            let remap = remappedUniqueIDs(reflection.sourceEntityIDs, replacements: replacements)
            guard remap.changed else { continue }
            reflection.sourceEntityIDs = remap.values
            store.apply(domainModel: reflection)
        }

        let questionStores = try modelContext.fetch(FetchDescriptor<ClarificationQuestionStore>())
        for store in questionStores where store.targetTypeRawValue == ClarificationTargetType.entity.rawValue {
            guard let replacementID = replacements[store.targetID] else { continue }
            var question = store.domainModel
            question.targetID = replacementID
            store.apply(domainModel: question)
        }

        let signalStores = try modelContext.fetch(FetchDescriptor<HomeBoardSignalStore>())
        for store in signalStores where store.targetTypeRawValue == ClarificationTargetType.entity.rawValue {
            guard let replacementID = replacements[store.targetID] else { continue }
            var signal = store.domainModel
            signal.targetID = replacementID
            store.apply(domainModel: signal)
        }

        let intentStores = try modelContext.fetch(FetchDescriptor<NotificationIntentStore>())
        for store in intentStores where store.targetTypeRawValue == ClarificationTargetType.entity.rawValue {
            guard let replacementID = replacements[store.targetID] else { continue }
            guard NotificationIntentKind(rawValue: store.kindRawValue) != nil else {
                modelContext.delete(store)
                continue
            }
            var intent = store.domainModel
            intent.targetID = replacementID
            store.apply(domainModel: intent)
        }

        let graphDeltaStores = try modelContext.fetch(FetchDescriptor<GraphDeltaStore>())
        for store in graphDeltaStores {
            var delta = store.domainModel
            var changed = false
            delta.operations = delta.operations.map { operation in
                var operation = operation
                if operation.targetType == .entity, let replacementID = replacements[operation.targetID] {
                    operation.targetID = replacementID
                    changed = true
                }
                if let relatedID = operation.relatedID, let replacementID = replacements[relatedID] {
                    operation.relatedID = replacementID
                    changed = true
                }
                return operation
            }
            if changed {
                store.apply(domainModel: delta)
            }
        }

        if let selfProfileStore = try fetchSelfProfileStore(syncKey: SelfProfile.defaultSyncKey) {
            let profile = selfProfileStore.domainModel
            let remap = remappedUniqueIDs(profile.importantRelationshipIDs, replacements: replacements)
            if remap.changed {
                var updated = profile
                updated.importantRelationshipIDs = remap.values
                updated.updatedAt = Date.now
                selfProfileStore.apply(domainModel: updated)
            }
        }

        let correctionStores = try modelContext.fetch(FetchDescriptor<CorrectionEventStore>())
        for store in correctionStores {
            var event = store.domainModel
            let remap = remappedUniqueIDs(event.targetEntityIDs, replacements: replacements)
            guard remap.changed else { continue }
            event.targetEntityIDs = remap.values
            store.apply(domainModel: event)
        }
    }

    func rewriteEntityReferencesForSplit(
        fromEntityID: UUID,
        toEntityID: UUID,
        movingRecordIDs: Set<UUID>
    ) throws {
        guard !movingRecordIDs.isEmpty else { return }

        let arcStores = try modelContext.fetch(FetchDescriptor<TemporalArcStore>())
        for store in arcStores {
            var arc = store.domainModel
            guard arc.sourceEntityIDs.contains(fromEntityID) else { continue }
            let arcRecordIDs = Set(arc.sourceRecordIDs)
            guard !arcRecordIDs.isDisjoint(with: movingRecordIDs) else { continue }
            if arcRecordIDs.isSubset(of: movingRecordIDs) {
                arc.sourceEntityIDs = remappedUniqueIDs(
                    arc.sourceEntityIDs,
                    replacements: [fromEntityID: toEntityID]
                ).values
            } else if !arc.sourceEntityIDs.contains(toEntityID) {
                arc.sourceEntityIDs.append(toEntityID)
            }
            arc.updatedAt = Date.now
            store.apply(domainModel: arc)
        }

        let reflectionStores = try modelContext.fetch(FetchDescriptor<ReflectionSnapshotStore>())
        for store in reflectionStores {
            var reflection = store.domainModel
            guard reflection.sourceEntityIDs.contains(fromEntityID) else { continue }
            let reflectionRecordIDs = Set(reflection.sourceRecordIDs)
            guard !reflectionRecordIDs.isDisjoint(with: movingRecordIDs) else { continue }
            if reflectionRecordIDs.isSubset(of: movingRecordIDs) {
                reflection.sourceEntityIDs = remappedUniqueIDs(
                    reflection.sourceEntityIDs,
                    replacements: [fromEntityID: toEntityID]
                ).values
            } else if !reflection.sourceEntityIDs.contains(toEntityID) {
                reflection.sourceEntityIDs.append(toEntityID)
            }
            store.apply(domainModel: reflection)
        }

        let questionStores = try modelContext.fetch(FetchDescriptor<ClarificationQuestionStore>())
        for store in questionStores where store.targetTypeRawValue == ClarificationTargetType.entity.rawValue {
            guard store.targetID == fromEntityID else { continue }
            let sourceRecords = Set(store.sourceRecordIDs)
            guard !sourceRecords.isDisjoint(with: movingRecordIDs) else { continue }
            guard sourceRecords.isSubset(of: movingRecordIDs) else { continue }
            var question = store.domainModel
            question.targetID = toEntityID
            store.apply(domainModel: question)
        }

        let signalStores = try modelContext.fetch(FetchDescriptor<HomeBoardSignalStore>())
        for store in signalStores where store.targetTypeRawValue == ClarificationTargetType.entity.rawValue {
            guard store.targetID == fromEntityID else { continue }
            let sourceRecords = Set(store.sourceRecordIDs)
            guard !sourceRecords.isDisjoint(with: movingRecordIDs) else { continue }
            guard sourceRecords.isSubset(of: movingRecordIDs) else { continue }
            var signal = store.domainModel
            signal.targetID = toEntityID
            store.apply(domainModel: signal)
        }
    }

    func movePersonArtifactLinks(
        fromEntityID: UUID,
        toEntityID: UUID,
        movingRecordIDs: Set<UUID>,
        updatedAt: Date
    ) throws -> Set<UUID> {
        let linkStores = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        var movedArtifactIDs = Set<UUID>()
        for store in linkStores where store.entityID == fromEntityID {
            guard let sourceRecordID = store.sourceRecordID, movingRecordIDs.contains(sourceRecordID) else {
                continue
            }
            var link = store.domainModel
            link.entityID = toEntityID
            link.source = "personProfile"
            if link.createdAt > updatedAt {
                link.createdAt = updatedAt
            }
            store.apply(domainModel: link)
            movedArtifactIDs.insert(link.artifactID)
        }
        return movedArtifactIDs
    }

    func remappedUniqueIDs(
        _ values: [UUID],
        replacements: [UUID: UUID]
    ) -> (values: [UUID], changed: Bool) {
        var changed = false
        var seen = Set<UUID>()
        var result: [UUID] = []
        for value in values {
            let remapped = replacements[value] ?? value
            if remapped != value {
                changed = true
            }
            if !seen.contains(remapped) {
                seen.insert(remapped)
                result.append(remapped)
            } else if remapped == value {
                changed = true
            }
        }
        return (result, changed)
    }

    func deduplicateEntityEdges() throws {
        let edgeStores = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>())
        var storesByKey: [EntityEdgeKey: EntityEdgeStore] = [:]

        for store in edgeStores {
            let edge = store.domainModel
            let key = EntityEdgeKey(edge)
            if let existingStore = storesByKey[key] {
                let merged = mergedEntityEdge(existingStore.domainModel, edge)
                existingStore.apply(domainModel: merged)
                modelContext.delete(store)
            } else {
                storesByKey[key] = store
            }
        }
    }

    func mergedEntityEdge(_ lhs: EntityEdge, _ rhs: EntityEdge) -> EntityEdge {
        EntityEdge(
            id: lhs.id,
            fromEntityID: lhs.fromEntityID,
            toEntityID: lhs.toEntityID,
            relationKind: lhs.relationKind,
            weight: max(lhs.weight, rhs.weight),
            firstSeenAt: min(lhs.firstSeenAt, rhs.firstSeenAt),
            lastSeenAt: max(lhs.lastSeenAt, rhs.lastSeenAt),
            evidenceCount: lhs.evidenceCount + rhs.evidenceCount,
            sourceArtifactIDs: mergeUniqueIDs(lhs.sourceArtifactIDs, rhs.sourceArtifactIDs),
            sourceRecordIDs: mergeUniqueIDs(lhs.sourceRecordIDs, rhs.sourceRecordIDs)
        )
    }

    func deletePlaceProfilesAndNodes(stores: [PlaceProfileStore]) throws {
        let entityIDs = Set(stores.map(\.entityID))
        for store in stores {
            modelContext.delete(store)
        }
        let nodeStores = try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
        for store in nodeStores where entityIDs.contains(store.id) && store.kindRawValue == EntityKind.place.rawValue {
            modelContext.delete(store)
        }
    }

    // MARK: - Private: Collection Merge Utilities

    func maxConfidence(_ profiles: [PlaceProfile]) -> Double? {
        profiles.compactMap(\.confidence).max()
    }

    func mergeStrings(_ lhs: [String], _ rhs: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in lhs + rhs {
            guard let trimmed = value.trimmedOrNil else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }
        return result
    }

    func mergeUniqueIDs(_ lhs: [UUID], _ rhs: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        var result: [UUID] = []
        for id in lhs + rhs where !seen.contains(id) {
            seen.insert(id)
            result.append(id)
        }
        return result
    }

    // MARK: - Private: Entity Deletion & Merge

    func deleteEntityProfiles(entityIDs: Set<UUID>) throws {
        guard !entityIDs.isEmpty else { return }
        let profileStores = try modelContext.fetch(FetchDescriptor<EntityProfileStore>())
        for store in profileStores where entityIDs.contains(store.entityID) {
            modelContext.delete(store)
        }
    }

    func deletePersonProfiles(entityIDs: Set<UUID>) throws {
        guard !entityIDs.isEmpty else { return }
        let profileStores = try modelContext.fetch(FetchDescriptor<PersonProfileStore>())
        for store in profileStores where entityIDs.contains(store.entityID) {
            modelContext.delete(store)
        }
    }

    func mergePersonProfiles(
        primaryID: UUID,
        mergingIDs: Set<UUID>,
        mergedEntityProfile: EntityProfile,
        now: Date
    ) throws {
        let primaryPersonProfile = try fetchPersonProfile(entityID: primaryID)
        let mergingPersonProfiles = try mergingIDs.compactMap { try fetchPersonProfile(entityID: $0) }
        guard primaryPersonProfile != nil || !mergingPersonProfiles.isEmpty else {
            try upsert(personProfile: makePersonProfile(from: mergedEntityProfile, now: now))
            return
        }

        var merged = primaryPersonProfile ?? makePersonProfile(from: mergedEntityProfile, now: now)
        merged.displayName = mergedEntityProfile.displayName
        merged.canonicalName = mergedEntityProfile.canonicalName
        merged.aliases = normalizedPersonAliases(
            [merged.displayName, merged.canonicalName]
                + merged.aliases
                + mergingPersonProfiles.flatMap { [$0.displayName, $0.canonicalName] + $0.aliases }
        )
        merged.roleLabels = mergeStrings(merged.roleLabels, mergingPersonProfiles.flatMap(\.roleLabels))
        merged.relationshipHistory = mergeRelationshipHistory(
            merged.relationshipHistory,
            mergingPersonProfiles.flatMap(\.relationshipHistory)
        )
        if merged.relationshipToUser == nil {
            merged.relationshipToUser = mergingPersonProfiles.compactMap(\.relationshipToUser).first
        }
        merged.commonPlaceIDs = mergeUniqueIDs(merged.commonPlaceIDs, mergingPersonProfiles.flatMap(\.commonPlaceIDs))
        merged.commonThemeIDs = mergeUniqueIDs(merged.commonThemeIDs, mergingPersonProfiles.flatMap(\.commonThemeIDs))
        merged.commonDecisionIDs = mergeUniqueIDs(merged.commonDecisionIDs, mergingPersonProfiles.flatMap(\.commonDecisionIDs))
        merged.commonContextLabels = mergeStrings(merged.commonContextLabels, mergingPersonProfiles.flatMap(\.commonContextLabels))
        merged.sourceRecordIDs = mergeUniqueIDs(mergedEntityProfile.sourceRecordIDs, mergingPersonProfiles.flatMap(\.sourceRecordIDs))
        merged.fieldEvidence = merged.fieldEvidence + mergingPersonProfiles.flatMap(\.fieldEvidence)
        merged.fieldConfidence = fieldConfidence(from: merged.fieldEvidence)
        merged.importanceScore = max(merged.importanceScore ?? 0, mergingPersonProfiles.compactMap(\.importanceScore).max() ?? 0)
        merged.relationshipStrength = max(merged.relationshipStrength ?? 0, mergingPersonProfiles.compactMap(\.relationshipStrength).max() ?? 0)
        merged.updatedAt = now
        try upsert(personProfile: merged)
    }

    func splitPersonProfiles(
        fromEntityID: UUID,
        toEntityID: UUID,
        newEntityProfile: EntityProfile,
        movingRecordIDs: Set<UUID>,
        now: Date
    ) throws {
        guard var original = try fetchPersonProfile(entityID: fromEntityID) else {
            try upsert(personProfile: makePersonProfile(from: newEntityProfile, now: now))
            return
        }

        let movedEvidence = original.fieldEvidence.filter {
            !Set($0.sourceRecordIDs).isDisjoint(with: movingRecordIDs)
        }
        original.sourceRecordIDs.removeAll { movingRecordIDs.contains($0) }
        original.fieldEvidence.removeAll {
            !$0.sourceRecordIDs.isEmpty && Set($0.sourceRecordIDs).isSubset(of: movingRecordIDs)
        }
        original.updatedAt = now
        try upsert(personProfile: original)

        var newProfile = makePersonProfile(from: newEntityProfile, now: now)
        newProfile.relationshipToUser = original.relationshipToUser
        newProfile.relationshipHistory = original.relationshipHistory
        newProfile.sensitivity = original.sensitivity
        newProfile.fieldEvidence = movedEvidence
        newProfile.fieldConfidence = fieldConfidence(from: movedEvidence)
        newProfile.updatedAt = now
        try upsert(personProfile: newProfile)
    }

    func makePersonProfile(from entityProfile: EntityProfile, now: Date) -> PersonProfile {
        PersonProfile(
            entityID: entityProfile.entityID,
            displayName: entityProfile.displayName,
            canonicalName: entityProfile.canonicalName,
            aliases: entityProfile.aliases,
            roleLabels: entityProfile.relationshipToUser.map { [$0.rawValue] } ?? [],
            relationshipToUser: entityProfile.relationshipToUser,
            relationshipHistory: entityProfile.relationshipToUser.map {
                [
                    RelationshipChange(
                        relationship: $0,
                        sourceRecordIDs: entityProfile.sourceRecordIDs,
                        status: entityProfile.confirmationState == .userConfirmed ? .userConfirmed : .inferred,
                        changedAt: now
                    )
                ]
            } ?? [],
            interactionFrequency: .unknown,
            commonContextLabels: entityProfile.commonContextLabels,
            sourceRecordIDs: entityProfile.sourceRecordIDs,
            createdAt: entityProfile.createdAt,
            updatedAt: now
        )
    }

    func mergeRelationshipHistory(
        _ lhs: [RelationshipChange],
        _ rhs: [RelationshipChange]
    ) -> [RelationshipChange] {
        var seen = Set<String>()
        var result: [RelationshipChange] = []
        for change in lhs + rhs {
            let key = [
                change.relationship?.rawValue ?? "nil",
                change.note ?? "",
                change.changedAt.timeIntervalSince1970.description,
            ].joined(separator: "|")
            guard seen.insert(key).inserted else { continue }
            result.append(change)
        }
        return result.sorted { $0.changedAt < $1.changedAt }
    }

    func deleteEntityNodes(entityIDs: Set<UUID>) throws {
        guard !entityIDs.isEmpty else { return }
        let nodeStores = try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
        for store in nodeStores where entityIDs.contains(store.id) {
            modelContext.delete(store)
        }
    }

    func markEntityDeletedForTombstones(entityID: UUID, kind: EntityKind, now: Date) throws {
        let tombstoneStores = try modelContext.fetch(FetchDescriptor<EntityTombstoneStore>())
        var hasDeletedTombstone = false

        for store in tombstoneStores {
            var tombstone = store.domainModel
            if tombstone.oldEntityID == entityID {
                hasDeletedTombstone = true
            }
            if tombstone.replacementEntityID == entityID {
                tombstone.replacementEntityID = nil
                tombstone.note = appendTombstoneNote(tombstone.note, "Replacement entity was deleted.")
                store.apply(domainModel: tombstone)
            }
        }

        if !hasDeletedTombstone {
            modelContext.insert(EntityTombstoneStore(domainModel: EntityTombstone(
                oldEntityID: entityID,
                replacementEntityID: nil,
                kind: kind,
                reason: .deleted,
                note: "Entity deleted after its source evidence was removed.",
                createdAt: now
            )))
        }
    }

    func appendTombstoneNote(_ note: String?, _ suffix: String) -> String {
        guard let note = note?.trimmedOrNil else { return suffix }
        guard !note.localizedCaseInsensitiveContains(suffix) else { return note }
        return "\(note) \(suffix)"
    }


}
