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
        try EntityMutationUseCase(repository: self).refreshPersonProfile(entityID: entityID, now: now)
    }

    func applyPersonProfileMutation(_ mutation: PersonProfileMutation) throws -> PersonProfile {
        try EntityMutationUseCase(repository: self).applyPersonProfileMutation(mutation)
    }

    func deletePersonProfilePortrait(entityID: UUID) throws -> PersonProfile {
        try EntityMutationUseCase(repository: self).deletePersonProfilePortrait(entityID: entityID)
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
        try EntityMutationUseCase(repository: self).renamePlaceProfile(id: id, displayName: displayName, aliases: aliases)
    }

    func mergePlaceProfiles(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> PlaceProfile {
        try EntityMutationUseCase(repository: self).mergePlaceProfiles(
            primaryID: primaryID,
            mergingIDs: mergingIDs,
            displayName: displayName
        )
    }

    func splitPlaceProfile(id: UUID, movingArtifactIDs: [UUID], displayName: String) throws -> PlaceProfile {
        try EntityMutationUseCase(repository: self).splitPlaceProfile(
            id: id,
            movingArtifactIDs: movingArtifactIDs,
            displayName: displayName
        )
    }

    // MARK: - People: Entity Merge & Split

    func mergePersonEntities(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> EntityProfile {
        try EntityMutationUseCase(repository: self).mergePersonEntities(
            primaryID: primaryID,
            mergingIDs: mergingIDs,
            displayName: displayName
        )
    }

    func splitPersonEntity(
        id: UUID,
        movingRecordIDs: [UUID],
        displayName: String,
        aliases: [String]
    ) throws -> EntityProfile {
        try EntityMutationUseCase(repository: self).splitPersonEntity(
            id: id,
            movingRecordIDs: movingRecordIDs,
            displayName: displayName,
            aliases: aliases
        )
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
