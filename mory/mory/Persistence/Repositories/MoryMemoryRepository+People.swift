import Foundation
import SwiftData

extension MoryMemoryRepository {
    // MARK: - User Settings & Preferences

    func fetchUserSettingsPreference() throws -> UserSettingsPreference {
        let syncKey = UserSettingsPreference.defaultSyncKey
        let descriptor = FetchDescriptor<UserSettingsPreferenceStore>(
            predicate: #Predicate { $0.syncKey == syncKey }
        )
        guard let store = try modelContext.fetch(descriptor).first else {
            return .defaults
        }
        return store.domainModel
    }

    func saveUserSettingsPreference(_ preference: UserSettingsPreference) throws {
        try upsert(userSettingsPreference: preference)
        try save()
    }

    func fetchMemoryDetailPresentationPreference(recordID: UUID) throws -> MemoryDetailPresentationPreference? {
        let descriptor = FetchDescriptor<MemoryDetailPresentationPreferenceStore>(
            predicate: #Predicate { $0.recordID == recordID }
        )
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func saveMemoryDetailPresentationPreference(_ preference: MemoryDetailPresentationPreference) throws {
        let descriptor = FetchDescriptor<MemoryDetailPresentationPreferenceStore>(
            predicate: #Predicate { $0.recordID == preference.recordID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: preference)
        } else {
            modelContext.insert(MemoryDetailPresentationPreferenceStore(domainModel: preference))
        }
        try save()
    }

    func clearMemoryDetailPresentationPreference(recordID: UUID) throws {
        try deleteMemoryDetailPresentationPreference(recordID: recordID, saveAfterDelete: true)
    }

    func fetchIntelligencePreferences() throws -> IntelligencePreferences {
        guard let store = try fetchIntelligencePreferenceStore() else {
            return .defaults
        }
        return store.preferencesDomainModel
    }

    func saveIntelligencePreferences(_ preferences: IntelligencePreferences) throws {
        let syncKey = IntelligencePreferences.defaultSyncKey
        if let existing = try fetchIntelligencePreferenceStore() {
            var normalized = preferences
            normalized.syncKey = syncKey
            existing.apply(preferences: normalized)
        } else {
            var normalized = preferences
            normalized.syncKey = syncKey
            modelContext.insert(IntelligencePreferenceStore(preferences: normalized, featureFlags: .defaults))
        }
        try save()
    }

    func fetchV6FeatureFlags() throws -> V6FeatureFlags {
        guard let store = try fetchIntelligencePreferenceStore() else {
            return .defaults
        }
        return store.featureFlagsDomainModel
    }

    func saveV6FeatureFlags(_ flags: V6FeatureFlags) throws {
        if let existing = try fetchIntelligencePreferenceStore() {
            existing.apply(featureFlags: flags)
        } else {
            modelContext.insert(IntelligencePreferenceStore(preferences: .defaults, featureFlags: flags))
        }
        try save()
    }

    // MARK: - Self Profile & Entity Profiles

    func fetchSelfProfile() throws -> SelfProfile? {
        try fetchSelfProfileStore(syncKey: SelfProfile.defaultSyncKey)?.domainModel
    }

    func upsertSelfProfile(_ profile: SelfProfile) throws {
        if let existing = try fetchSelfProfileStore(syncKey: profile.syncKey) {
            existing.apply(domainModel: profile)
        } else {
            modelContext.insert(SelfProfileStore(domainModel: profile))
        }
        try save()
    }

    func ensureSelfProfile() throws -> SelfProfile {
        if let existing = try fetchSelfProfile() {
            return existing
        }
        let profile = SelfProfile()
        try upsertSelfProfile(profile)
        return profile
    }

    func fetchEntityProfile(entityID: UUID) throws -> EntityProfile? {
        let descriptor = FetchDescriptor<EntityProfileStore>(
            predicate: #Predicate { $0.entityID == entityID }
        )
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func fetchEntityProfiles(kind: EntityKind?, limit: Int?) throws -> [EntityProfile] {
        let stores = try modelContext.fetch(
            FetchDescriptor<EntityProfileStore>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
        let profiles = stores
            .map(\.domainModel)
            .filter { profile in
                guard let kind else { return true }
                return profile.kind == kind
            }
        return applyLimit(limit, to: profiles)
    }

    func upsertEntityProfile(_ profile: EntityProfile) throws {
        try upsert(entityProfile: profile)
        try save()
    }

    // MARK: - People: Person Profiles

    func fetchPersonProfile(entityID: UUID) throws -> PersonProfile? {
        let descriptor = FetchDescriptor<PersonProfileStore>(
            predicate: #Predicate { $0.entityID == entityID }
        )
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func fetchPersonProfiles(limit: Int?) throws -> [PersonProfile] {
        let profiles = try modelContext.fetch(
            FetchDescriptor<PersonProfileStore>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
        .map(\.domainModel)
        return applyLimit(limit, to: profiles)
    }

    func upsertPersonProfile(_ profile: PersonProfile) throws {
        try upsert(personProfile: profile)
        try save()
    }

    func refreshPersonProfile(entityID: UUID, now: Date = .now) throws -> PersonProfile? {
        guard let detail = try fetchEntityDetail(entityID: entityID), detail.entity.kind == .person else {
            return nil
        }
        let entityProfile = try fetchEntityProfile(entityID: entityID)
        let existing = try fetchPersonProfile(entityID: entityID)
        let refreshed = try buildPersonProfile(
            detail: detail,
            entityProfile: entityProfile,
            existing: existing,
            now: now
        )
        try upsert(personProfile: refreshed)
        try save()
        return refreshed
    }

    func applyPersonProfileMutation(_ mutation: PersonProfileMutation) throws -> PersonProfile {
        let now = mutation.createdAt
        let existing = try fetchPersonProfile(entityID: mutation.entityID)
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
            updated.aliases = normalizedPersonAliases(mutation.stringListValue ?? [])
        case .relationshipToUser:
            updated.relationshipToUser = mutation.relationshipValue
            updated.relationshipHistory.append(RelationshipChange(
                relationship: mutation.relationshipValue,
                note: mutation.note,
                status: .userConfirmed,
                changedAt: now
            ))
        case .roleLabels:
            updated.roleLabels = mergeStrings([], mutation.stringListValue ?? [])
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

        try upsert(personProfile: updated)
        try upsert(correctionEvent: CorrectionEvent(
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
        try save()
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

    // MARK: - People: Affect & Place Profiles

    func fetchAffectSnapshot(id: UUID) throws -> AffectSnapshot? {
        let descriptor = FetchDescriptor<AffectSnapshotStore>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func fetchAffectSnapshots(recordID: UUID?, limit: Int?) throws -> [AffectSnapshot] {
        let stores: [AffectSnapshotStore]
        if let recordID {
            stores = try modelContext.fetch(
                FetchDescriptor<AffectSnapshotStore>(
                    predicate: #Predicate { $0.recordID == recordID },
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
        } else {
            stores = try modelContext.fetch(
                FetchDescriptor<AffectSnapshotStore>(
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
        }
        return applyLimit(limit, to: stores.map(\.domainModel))
    }

    func upsertAffectSnapshot(_ snapshot: AffectSnapshot) throws {
        try upsert(affectSnapshot: snapshot)
        try save()
    }

    func applyAffectCorrection(_ correction: AffectCorrection) throws -> AffectSnapshot {
        let now = correction.createdAt
        let existing: AffectSnapshot?
        if let snapshotID = correction.snapshotID {
            existing = try fetchAffectSnapshot(id: snapshotID)
        } else {
            existing = try fetchAffectSnapshots(recordID: correction.recordID, limit: 1).first
        }

        var updated = existing ?? AffectSnapshot(
            recordID: correction.recordID,
            createdAt: now,
            updatedAt: now
        )
        updated.valence = correction.valence ?? updated.valence
        updated.arousal = correction.arousal ?? updated.arousal
        updated.dominance = correction.dominance ?? updated.dominance
        updated.intensity = correction.intensity ?? updated.intensity
        if !correction.labels.isEmpty {
            updated.labels = orderedUniqueAffectLabels(correction.labels)
        }
        if !correction.toneHints.isEmpty {
            updated.toneHints = orderedUniqueToneHints(correction.toneHints)
        }
        updated.appraisal = correction.appraisal ?? updated.appraisal
        if !updated.sources.contains(.userCorrected) {
            updated.sources.append(.userCorrected)
        }
        updated.confidence = 1
        updated.userConfirmed = true
        updated.needsUserCheck = false
        updated.evidence.append(AffectEvidence(
            source: .userCorrected,
            summary: correction.note?.trimmedOrNil ?? "User corrected affect snapshot.",
            confidence: 1,
            createdAt: now
        ))
        updated.updatedAt = now

        try upsert(affectSnapshot: updated)
        try upsert(correctionEvent: CorrectionEvent(
            kind: .affectCorrection,
            actor: .user,
            targetRecordIDs: [correction.recordID],
            sourceRecordIDs: [correction.recordID],
            note: correction.note ?? "Affect snapshot corrected by user.",
            metadata: [
                "snapshotID": updated.id.uuidString,
                "labels": updated.labels.map(\.rawValue).joined(separator: ","),
                "toneHints": updated.toneHints.map(\.rawValue).joined(separator: ",")
            ],
            isReversible: true,
            createdAt: now
        ))
        try updateSelfExpressionPattern(from: correction, snapshot: updated, now: now)
        try save()
        return updated
    }

    func fetchPlaceProfiles(limit: Int?) throws -> [PlaceProfile] {
        let profiles = try modelContext.fetch(
            FetchDescriptor<PlaceProfileStore>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
        .map(\.domainModel)
        return applyLimit(limit, to: profiles)
    }

    func upsertPlaceProfile(_ profile: PlaceProfile) throws {
        try upsert(placeProfile: profile)
        try save()
    }

    func fetchPlaceProfile(id: UUID) throws -> PlaceProfile? {
        try fetchPlaceProfileStore(id: id)?.domainModel
    }

    func fetchPlaceProfileArtifacts(id: UUID) throws -> [Artifact] {
        guard let profile = try fetchPlaceProfile(id: id) else {
            throw PlaceProfileMutationError.profileNotFound
        }
        let artifactsByID = Dictionary(uniqueKeysWithValues: try fetchArtifacts(ids: profile.sourceArtifactIDs).map { ($0.id, $0) })
        return profile.sourceArtifactIDs.compactMap { artifactsByID[$0] }
    }

    func renamePlaceProfile(id: UUID, displayName: String, aliases: [String]) throws -> PlaceProfile {
        let now = Date.now
        let resolvedName = try normalizedPlaceDisplayName(displayName)
        let store = try requirePlaceProfileStore(id: id)
        var profile = store.domainModel
        profile.displayName = resolvedName
        profile.canonicalName = resolvedName
        profile.aliases = normalizedPlaceAliases([resolvedName] + aliases)
        profile.confirmationState = .userConfirmed
        profile.updatedAt = now
        store.apply(domainModel: profile)
        try upsertPlaceEntityNode(for: profile, updatedAt: now)
        try save()
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

        let primaryStore = try requirePlaceProfileStore(id: primaryID)
        let mergingStores = try mergingIDSet.map { try requirePlaceProfileStore(id: $0) }
        let mergingProfiles = mergingStores.map(\.domainModel)
        let mergingEntityIDs = Set(mergingProfiles.map(\.entityID))
        let replacementMap = Dictionary(uniqueKeysWithValues: mergingEntityIDs.map { ($0, primaryStore.entityID) })

        var primaryProfile = primaryStore.domainModel
        if let displayName, let trimmedName = displayName.trimmedOrNil {
            primaryProfile.displayName = trimmedName
            primaryProfile.canonicalName = trimmedName
        }
        primaryProfile.aliases = normalizedPlaceAliases(
            [primaryProfile.displayName, primaryProfile.canonicalName]
                + primaryProfile.aliases
                + mergingProfiles.flatMap { [$0.displayName, $0.canonicalName] + $0.aliases }
        )
        primaryProfile.sourceArtifactIDs = mergeUniqueIDs(
            primaryProfile.sourceArtifactIDs,
            mergingProfiles.flatMap(\.sourceArtifactIDs)
        )
        primaryProfile.sourceRecordIDs = mergeUniqueIDs(
            primaryProfile.sourceRecordIDs,
            mergingProfiles.flatMap(\.sourceRecordIDs)
        )
        primaryProfile.confirmationState = .userConfirmed
        primaryProfile.confidence = maxConfidence([primaryProfile] + mergingProfiles)
        primaryProfile.updatedAt = now

        let mergedArtifacts = try fetchArtifacts(ids: primaryProfile.sourceArtifactIDs)
        primaryProfile = recalculatedPlaceProfile(primaryProfile, from: mergedArtifacts, updatedAt: now)
        primaryStore.apply(domainModel: primaryProfile)

        try rewritePlaceGraphReferences(replacing: replacementMap)
        try upsertPlaceEntityNode(for: primaryProfile, updatedAt: now)
        try deletePlaceProfilesAndNodes(stores: mergingStores)
        try save()
        return primaryProfile
    }

    func splitPlaceProfile(id: UUID, movingArtifactIDs: [UUID], displayName: String) throws -> PlaceProfile {
        let now = Date.now
        let resolvedName = try normalizedPlaceDisplayName(displayName)
        let movingIDSet = Set(movingArtifactIDs)
        guard !movingIDSet.isEmpty else {
            throw PlaceProfileMutationError.splitRequiresMovingArtifacts
        }

        let originalStore = try requirePlaceProfileStore(id: id)
        var originalProfile = originalStore.domainModel
        let originalArtifactIDSet = Set(originalProfile.sourceArtifactIDs)
        guard movingIDSet.isSubset(of: originalArtifactIDSet) else {
            throw PlaceProfileMutationError.splitArtifactsNotInProfile
        }
        guard movingIDSet.count < originalArtifactIDSet.count else {
            throw PlaceProfileMutationError.splitCannotMoveAllArtifacts
        }

        let allArtifacts = try fetchArtifacts(ids: originalProfile.sourceArtifactIDs)
        let movingArtifacts = allArtifacts.filter { movingIDSet.contains($0.id) }
        guard movingArtifacts.allSatisfy({ $0.kind == .location }) else {
            throw PlaceProfileMutationError.splitArtifactsMustBeLocations
        }
        let remainingArtifacts = allArtifacts.filter { !movingIDSet.contains($0.id) }

        let newProfile = recalculatedPlaceProfile(
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
        originalProfile.sourceRecordIDs = mergeUniqueIDs([], remainingArtifacts.map(\.recordID))
        originalProfile.confirmationState = .userConfirmed
        originalProfile.updatedAt = now
        originalProfile = recalculatedPlaceProfile(originalProfile, from: remainingArtifacts, updatedAt: now)

        originalStore.apply(domainModel: originalProfile)
        modelContext.insert(PlaceProfileStore(domainModel: newProfile))
        try movePlaceArtifactLinks(
            artifactIDs: movingIDSet,
            fromEntityID: originalProfile.entityID,
            toProfile: newProfile,
            updatedAt: now
        )
        try splitEntityEdges(
            fromEntityID: originalProfile.entityID,
            toEntityID: newProfile.entityID,
            movingArtifactIDs: movingIDSet,
            movingRecordIDs: Set(movingArtifacts.map(\.recordID))
        )
        try upsertPlaceEntityNode(for: originalProfile, updatedAt: now)
        try upsertPlaceEntityNode(for: newProfile, updatedAt: now)
        try save()
        return newProfile
    }

    // MARK: - People: Entity Merge & Split

    func mergePersonEntities(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> EntityProfile {
        let now = Date.now
        let mergingIDSet = Set(mergingIDs)
        guard !mergingIDSet.isEmpty else {
            throw PersonEntityMutationError.mergeRequiresAtLeastOneOtherEntity
        }
        guard !mergingIDSet.contains(primaryID) else {
            throw PersonEntityMutationError.mergeCannotIncludePrimary
        }

        let primaryStore = try requirePersonEntityNodeStore(id: primaryID)
        let mergingStores = try mergingIDSet.map { try requirePersonEntityNodeStore(id: $0) }
        let mergingNodes = mergingStores.map(\.domainModel)
        let replacementMap = Dictionary(uniqueKeysWithValues: mergingNodes.map { ($0.id, primaryID) })

        var primaryNode = primaryStore.domainModel
        if let displayName, let normalized = displayName.trimmedOrNil {
            primaryNode.displayName = normalized
            primaryNode.canonicalName = normalized
        }
        primaryNode.aliases = normalizedPersonAliases(
            [primaryNode.displayName, primaryNode.canonicalName]
                + primaryNode.aliases
                + mergingNodes.flatMap { [$0.displayName, $0.canonicalName] + $0.aliases }
        )
        primaryNode.provenanceRecordIDs = mergeUniqueIDs(
            primaryNode.provenanceRecordIDs,
            mergingNodes.flatMap(\.provenanceRecordIDs)
        )
        primaryNode.updatedAt = now
        let nodeConfidences = [primaryNode.confidence].compactMap { $0 } + mergingNodes.compactMap(\.confidence)
        primaryNode.confidence = nodeConfidences.max()

        let primaryProfile = try fetchEntityProfile(entityID: primaryID)
            ?? makePersonProfile(from: primaryNode, updatedAt: now)
        let mergingProfiles = try mergingIDSet.compactMap { entityID in
            try fetchEntityProfile(entityID: entityID)
        }

        var mergedProfile = primaryProfile
        mergedProfile.displayName = primaryNode.displayName
        mergedProfile.canonicalName = primaryNode.canonicalName
        mergedProfile.aliases = normalizedPersonAliases(
            [primaryNode.displayName, primaryNode.canonicalName]
                + primaryProfile.aliases
                + mergingProfiles.flatMap { [$0.displayName, $0.canonicalName] + $0.aliases }
        )
        mergedProfile.sourceRecordIDs = mergeUniqueIDs(
            primaryProfile.sourceRecordIDs,
            mergingProfiles.flatMap(\.sourceRecordIDs) + primaryNode.provenanceRecordIDs
        )
        mergedProfile.mentionCount = max(
            mergedProfile.sourceRecordIDs.count,
            primaryProfile.mentionCount + mergingProfiles.map(\.mentionCount).reduce(0, +)
        )
        mergedProfile.commonContextLabels = mergeStrings(
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
        try upsert(entityProfile: mergedProfile)
        try mergePersonProfiles(
            primaryID: primaryID,
            mergingIDs: mergingIDSet,
            mergedEntityProfile: mergedProfile,
            now: now
        )
        try rewriteEntityLinksAndEdges(replacing: replacementMap, linkSource: "personProfile")
        try rewriteEntityReferencesForMerge(replacing: replacementMap)
        try deleteEntityProfiles(entityIDs: mergingIDSet)
        try deletePersonProfiles(entityIDs: mergingIDSet)
        try deleteEntityNodes(entityIDs: mergingIDSet)

        let affectedRecordIDs = Set(primaryNode.provenanceRecordIDs + mergingNodes.flatMap(\.provenanceRecordIDs))
        for mergingID in mergingIDSet {
            try upsert(entityTombstone: EntityTombstone(
                oldEntityID: mergingID,
                replacementEntityID: primaryID,
                kind: .person,
                reason: .merged,
                note: "Merged into \(primaryNode.displayName)",
                createdAt: now
            ))
            try upsert(correctionEvent: CorrectionEvent(
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

        try enqueueEntityMutationRecomputeJobs(
            affectedRecordIDs: affectedRecordIDs,
            affectedEntityIDs: Set([primaryID] + Array(mergingIDSet))
        )
        try save()
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

        let originalStore = try requirePersonEntityNodeStore(id: id)
        var originalNode = originalStore.domainModel
        let originalProfile = try fetchEntityProfile(entityID: id) ?? makePersonProfile(from: originalNode, updatedAt: now)

        let originalRecordIDSet = Set(mergeUniqueIDs(originalNode.provenanceRecordIDs, originalProfile.sourceRecordIDs))
        guard movingRecordIDSet.isSubset(of: originalRecordIDSet) else {
            throw PersonEntityMutationError.splitRecordsNotInEntity
        }
        guard movingRecordIDSet.count < originalRecordIDSet.count else {
            throw PersonEntityMutationError.splitCannotMoveAllRecords
        }

        let newEntityID = UUID()
        let movedAliases = normalizedPersonAliases([normalizedName] + aliases)
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
        try upsert(entityNode: newNode)

        var updatedOriginalProfile = originalProfile
        updatedOriginalProfile.sourceRecordIDs = remainingRecordIDArray
        updatedOriginalProfile.mentionCount = max(1, remainingRecordIDArray.count)
        updatedOriginalProfile.updatedAt = now
        updatedOriginalProfile.lastMentionedAt = now
        try upsert(entityProfile: updatedOriginalProfile)

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
        try upsert(entityProfile: newProfile)
        try splitPersonProfiles(
            fromEntityID: id,
            toEntityID: newEntityID,
            newEntityProfile: newProfile,
            movingRecordIDs: movingRecordIDSet,
            now: now
        )

        let movedArtifactIDs = try movePersonArtifactLinks(
            fromEntityID: id,
            toEntityID: newEntityID,
            movingRecordIDs: movingRecordIDSet,
            updatedAt: now
        )
        try splitEntityEdges(
            fromEntityID: id,
            toEntityID: newEntityID,
            movingArtifactIDs: movedArtifactIDs,
            movingRecordIDs: movingRecordIDSet
        )
        try rewriteEntityReferencesForSplit(
            fromEntityID: id,
            toEntityID: newEntityID,
            movingRecordIDs: movingRecordIDSet
        )
        try upsert(correctionEvent: CorrectionEvent(
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
        try enqueueEntityMutationRecomputeJobs(
            affectedRecordIDs: Set(mergeUniqueIDs(Array(originalRecordIDSet), Array(movingRecordIDSet))),
            affectedEntityIDs: Set([id, newEntityID])
        )
        try save()
        return newProfile
    }

    // MARK: - Correction Events & Entity Tombstones

    func fetchCorrectionEvents(kind: CorrectionEventKind?, limit: Int?) throws -> [CorrectionEvent] {
        let stores = try modelContext.fetch(
            FetchDescriptor<CorrectionEventStore>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )
        let events = stores.map(\.domainModel).filter { event in
            guard let kind else { return true }
            return event.kind == kind
        }
        return applyLimit(limit, to: events)
    }

    func upsertCorrectionEvent(_ event: CorrectionEvent) throws {
        try upsert(correctionEvent: event)
        try save()
    }

    func reverseCorrectionEvent(_ id: UUID, reversedAt: Date = .now) throws {
        guard let existing = try modelContext.fetch(
            FetchDescriptor<CorrectionEventStore>(predicate: #Predicate { $0.id == id })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        var updated = existing.domainModel
        updated.reversedAt = reversedAt
        existing.apply(domainModel: updated)
        try save()
    }

    func fetchEntityTombstones(limit: Int?) throws -> [EntityTombstone] {
        let tombstones = try modelContext.fetch(
            FetchDescriptor<EntityTombstoneStore>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        ).map(\.domainModel)
        return applyLimit(limit, to: tombstones)
    }

}
