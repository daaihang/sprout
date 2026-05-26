import Foundation
import SwiftData

extension MoryMemoryRepository {
// MARK: - Private: Cross-Domain Helpers

    func fetchRecordAnalysisIndex() throws -> [UUID: RecordAnalysisSnapshot] {
        let analyses = try modelContext.fetch(FetchDescriptor<RecordAnalysisSnapshotStore>())
            .map(\.domainModel)
        return Dictionary(uniqueKeysWithValues: analyses.map { ($0.recordID, $0) })
    }

    func fetchHomeBoardPreferences() throws -> [HomeBoardItemPreference] {
        let descriptor = FetchDescriptor<HomeBoardPreferenceStore>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domainModel)
    }

    func fetchHomeBoardPreference(syncKey: String) throws -> HomeBoardItemPreference? {
        let descriptor = FetchDescriptor<HomeBoardPreferenceStore>(
            predicate: #Predicate { $0.syncKey == syncKey }
        )
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func homeBoardPreferenceSyncKey(cardKey: String) -> String {
        "home-board:\(cardKey)"
    }

    func shouldShowClarificationQuestions(
        flags: V6FeatureFlags,
        preferences: IntelligencePreferences
    ) -> Bool {
        flags.clarificationQuestions && preferences.localIntelligenceEnabled && preferences.homeSuggestionsEnabled
    }

    func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let stores = try modelContext.fetch(FetchDescriptor<T>())
        for store in stores {
            modelContext.delete(store)
        }
    }

    func deleteMemoryDetailPresentationPreference(recordID: UUID, saveAfterDelete: Bool) throws {
        let descriptor = FetchDescriptor<MemoryDetailPresentationPreferenceStore>(
            predicate: #Predicate { $0.recordID == recordID }
        )
        for store in try modelContext.fetch(descriptor) {
            modelContext.delete(store)
        }
        if saveAfterDelete {
            try save()
        }
    }

    func purgeDerivedDataForRefresh(recordID: UUID) throws {
        try purgeDerivedData(forRecordIDs: [recordID], includePipelineStatus: false)
    }

    func upsertPendingPipelineStatus(recordID: UUID, updatedAt: Date) throws {
        try upsertPipelineStatus(
            MemoryPipelineStatusSnapshot(
                recordID: recordID,
                stage: .pending,
                requestID: nil,
                lastError: nil,
                requestBody: nil,
                responseBody: nil,
                rawErrorBody: nil,
                lastHTTPStatusCode: nil,
                failedStage: nil,
                lastAttemptAt: nil,
                completedAt: nil,
                updatedAt: updatedAt
            )
        )
    }

    func orderedUniqueUUIDs(_ ids: [UUID]) -> [UUID] {
        OrderedCollections.unique(ids)
    }

    func applyAnalysisFollowups(record: RecordShell, artifacts: [Artifact]) throws {
        let flags = try fetchV6FeatureFlags()
        let preferences = try fetchIntelligencePreferences()
        guard preferences.localIntelligenceEnabled else { return }
        guard flags.intelligenceJobs || flags.entityProfiles || flags.clarificationQuestions else { return }
        guard let analysis = try fetchRecordAnalysis(recordID: record.id) else { return }

        let personNodes = try fetchPersonEntityNodes(recordID: record.id, artifactIDs: artifacts.map(\.id))
        guard !personNodes.isEmpty else { return }

        let now = Date.now
        let scheduled = intelligenceScheduler.schedulePostAnalysis(
            recordID: record.id,
            personEntityIDs: personNodes.map(\.id),
            now: now
        )

        if flags.intelligenceJobs {
            try upsert(intelligenceJob: updateJob(scheduled.postAnalysisJob, status: .running, at: now))
            try scheduled.entityEnrichmentJobs.forEach { try upsert(intelligenceJob: $0) }
            try scheduled.personProfileRefreshJobs.forEach { try upsert(intelligenceJob: $0) }
            try scheduled.questionGenerationJobs.forEach { try upsert(intelligenceJob: $0) }
        }

        let existingProfiles = Dictionary(uniqueKeysWithValues: try fetchEntityProfiles(kind: .person, limit: nil).map { ($0.entityID, $0) })
        let enrichedProfiles = entityEnrichmentService.enrichPeople(
            record: record,
            analysis: analysis,
            people: personNodes,
            existingProfiles: existingProfiles
        )

        if flags.entityProfiles {
            for profile in enrichedProfiles {
                try upsert(entityProfile: profile)
                _ = try refreshPersonProfile(entityID: profile.entityID, now: now)
            }
        }

        if flags.intelligenceJobs {
            for job in scheduled.entityEnrichmentJobs {
                try upsert(intelligenceJob: updateJob(job, status: .completed, at: now))
            }
            let personProfileJobStatus: IntelligenceJobStatus = flags.entityProfiles ? .completed : .cancelled
            for job in scheduled.personProfileRefreshJobs {
                try upsert(intelligenceJob: updateJob(job, status: personProfileJobStatus, at: now))
            }
        }

        if flags.clarificationQuestions {
            let existingQuestions = try fetchClarificationQuestions(status: nil, limit: nil)
            for profile in enrichedProfiles {
                if let question = clarificationQuestionBuilder.buildQuestion(
                    for: profile,
                    record: record,
                    artifactIDs: artifacts.map(\.id),
                    existingQuestions: existingQuestions,
                    latestSummary: analysis.summary
                ) {
                    try upsert(clarificationQuestion: question)
                }
            }
        }

        if flags.intelligenceJobs {
            let questionJobStatus: IntelligenceJobStatus = flags.clarificationQuestions ? .completed : .cancelled
            for job in scheduled.questionGenerationJobs {
                try upsert(intelligenceJob: updateJob(job, status: questionJobStatus, at: now))
            }
            try upsert(intelligenceJob: updateJob(scheduled.postAnalysisJob, status: .completed, at: now))
        }

        try save()
    }

    func markLatestPostAnalysisJobFailed(recordID: UUID, error: Error) throws {
        guard let job = try fetchIntelligenceJobs(status: nil, limit: nil)
            .first(where: { $0.kind == .postAnalysis && $0.targetType == .record && $0.targetID == recordID }) else {
            return
        }

        try upsert(intelligenceJob: updateJob(job, status: .failed, at: .now, error: error.localizedDescription))
        try save()
    }

    func updateJob(
        _ job: IntelligenceJob,
        status: IntelligenceJobStatus,
        at date: Date,
        error: String? = nil
    ) -> IntelligenceJob {
        var updated = job
        updated.status = status
        updated.updatedAt = date
        switch status {
        case .running:
            updated.startedAt = date
            updated.completedAt = nil
            updated.lastError = nil
        case .completed:
            updated.completedAt = date
            updated.lastError = nil
        case .failed:
            updated.completedAt = nil
            updated.lastError = error
            updated.attemptCount += 1
        case .cancelled, .pending:
            updated.lastError = error
        }
        return updated
    }

    // MARK: - Private: Purge & Cleanup

    func purgeDerivedData(forRecordIDs recordIDs: Set<UUID>, includePipelineStatus: Bool) throws {
        guard !recordIDs.isEmpty else { return }

        let artifactIDs = Set(
            try modelContext.fetch(FetchDescriptor<ArtifactStore>())
                .filter { recordIDs.contains($0.recordID) }
                .map(\.id)
        )

        let analysisStores = try modelContext.fetch(FetchDescriptor<RecordAnalysisSnapshotStore>())
            .filter { recordIDs.contains($0.recordID) }
        analysisStores.forEach { modelContext.delete($0) }

        if includePipelineStatus {
            let pipelineStores = try modelContext.fetch(FetchDescriptor<MemoryPipelineStatusStore>())
                .filter { recordIDs.contains($0.recordID) }
            pipelineStores.forEach { modelContext.delete($0) }
        }

        let allLinks = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        let linkIDsToDelete = Set(
            allLinks
                .filter { link in
                    artifactIDs.contains(link.artifactID)
                        || link.sourceRecordID.map { recordIDs.contains($0) } == true
                        || link.sourceAnalysisRecordID.map { recordIDs.contains($0) } == true
                }
                .map(\.id)
        )
        allLinks
            .filter { linkIDsToDelete.contains($0.id) }
            .forEach { modelContext.delete($0) }
        let remainingLinkedEntityIDs = Set(
            allLinks
                .filter { !linkIDsToDelete.contains($0.id) }
                .map(\.entityID)
        )

        let edgeStores = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>())
            .filter { store in
                store.sourceRecordIDs.contains { recordIDs.contains($0) }
                    || store.sourceArtifactIDs.contains { artifactIDs.contains($0) }
            }
        edgeStores.forEach { modelContext.delete($0) }

        let arcStores = try modelContext.fetch(FetchDescriptor<TemporalArcStore>())
        let arcIDsToDelete = Set(
            arcStores
                .filter { store in
                    store.sourceRecordIDs.contains { recordIDs.contains($0) }
                        || store.sourceArtifactIDs.contains { artifactIDs.contains($0) }
                }
                .map(\.id)
        )
        arcStores
            .filter { arcIDsToDelete.contains($0.id) }
            .forEach { modelContext.delete($0) }

        let reflectionStores = try modelContext.fetch(FetchDescriptor<ReflectionSnapshotStore>())
            .filter { store in
                store.sourceRecordIDs.contains { recordIDs.contains($0) }
                    || store.sourceArtifactIDs.contains { artifactIDs.contains($0) }
                    || store.linkedTemporalArcID.map { arcIDsToDelete.contains($0) } == true
            }
        reflectionStores.forEach { modelContext.delete($0) }

        let deletedClarificationQuestionIDs = try purgeClarificationQuestions(
            removingRecordIDs: recordIDs,
            artifactIDs: artifactIDs
        )
        let deletedGraphDeltaIDs = try purgeGraphDeltas(
            removingRecordIDs: recordIDs,
            artifactIDs: artifactIDs
        )
        try purgeIntelligenceJobs(
            removingRecordIDs: recordIDs,
            artifactIDs: artifactIDs,
            clarificationQuestionIDs: deletedClarificationQuestionIDs,
            graphDeltaIDs: deletedGraphDeltaIDs
        )
        try purgeHomeBoardSignals(
            removingRecordIDs: recordIDs,
            artifactIDs: artifactIDs
        )
        try purgeNotificationIntents(
            removingRecordIDs: recordIDs,
            artifactIDs: artifactIDs
        )
        try purgePlaceProfiles(removingRecordIDs: recordIDs, artifactIDs: artifactIDs)
        try purgePersonProfiles(removingRecordIDs: recordIDs, artifactIDs: artifactIDs)
        try purgeEntityProfiles(removing: recordIDs)
        try purgeEntityProvenance(removing: recordIDs, remainingLinkedEntityIDs: remainingLinkedEntityIDs)
    }

    func purgeClarificationQuestions(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>
    ) throws -> Set<UUID> {
        let stores = try modelContext.fetch(FetchDescriptor<ClarificationQuestionStore>())
        var deletedIDs = Set<UUID>()

        for store in stores {
            var question = store.domainModel
            let originalRecordIDs = question.sourceRecordIDs
            let originalArtifactIDs = question.sourceArtifactIDs

            question.sourceRecordIDs.removeAll { recordIDs.contains($0) }
            question.sourceArtifactIDs.removeAll { artifactIDs.contains($0) }

            let deletedTarget = switch question.targetType {
            case .record:
                recordIDs.contains(question.targetID)
            case .artifact:
                artifactIDs.contains(question.targetID)
            default:
                false
            }

            if deletedTarget || (question.sourceRecordIDs.isEmpty && question.sourceArtifactIDs.isEmpty) {
                deletedIDs.insert(store.id)
                modelContext.delete(store)
                continue
            }

            if question.sourceRecordIDs != originalRecordIDs || question.sourceArtifactIDs != originalArtifactIDs {
                store.apply(domainModel: question)
            }
        }

        return deletedIDs
    }

    func purgeGraphDeltas(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>
    ) throws -> Set<UUID> {
        let stores = try modelContext.fetch(FetchDescriptor<GraphDeltaStore>())
        var deletedIDs = Set<UUID>()

        for store in stores {
            let shouldDelete = store.domainModel.operations.contains { operation in
                if operation.targetType == .record, recordIDs.contains(operation.targetID) {
                    return true
                }
                if operation.targetType == .artifact, artifactIDs.contains(operation.targetID) {
                    return true
                }
                if let relatedID = operation.relatedID, recordIDs.contains(relatedID) || artifactIDs.contains(relatedID) {
                    return true
                }
                return false
            }

            if shouldDelete {
                deletedIDs.insert(store.id)
                modelContext.delete(store)
            }
        }

        return deletedIDs
    }

    func purgeIntelligenceJobs(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>,
        clarificationQuestionIDs: Set<UUID>,
        graphDeltaIDs: Set<UUID>
    ) throws {
        let stores = try modelContext.fetch(FetchDescriptor<IntelligenceJobStore>())

        for store in stores {
            let shouldDelete = switch store.domainModel.targetType {
            case .record:
                recordIDs.contains(store.targetID)
            case .artifact:
                artifactIDs.contains(store.targetID)
            case .question:
                clarificationQuestionIDs.contains(store.targetID)
            case .graphDelta:
                graphDeltaIDs.contains(store.targetID)
            default:
                false
            }

            if shouldDelete {
                modelContext.delete(store)
            }
        }
    }

    func purgeHomeBoardSignals(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>
    ) throws {
        let stores = try modelContext.fetch(FetchDescriptor<HomeBoardSignalStore>())

        for store in stores {
            var signal = store.domainModel
            let originalRecordIDs = signal.sourceRecordIDs
            signal.sourceRecordIDs.removeAll { recordIDs.contains($0) }

            let deletedTarget = switch signal.targetType {
            case .record:
                recordIDs.contains(signal.targetID)
            case .artifact:
                artifactIDs.contains(signal.targetID)
            default:
                false
            }

            if deletedTarget || signal.sourceRecordIDs.isEmpty {
                modelContext.delete(store)
                continue
            }

            if signal.sourceRecordIDs != originalRecordIDs {
                store.apply(domainModel: signal)
            }
        }
    }

    func purgeNotificationIntents(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>
    ) throws {
        let stores = try modelContext.fetch(FetchDescriptor<NotificationIntentStore>())

        for store in stores {
            let targetType = ClarificationTargetType(rawValue: store.targetTypeRawValue) ?? .record
            let shouldDelete = switch targetType {
            case .record:
                recordIDs.contains(store.targetID)
            case .artifact:
                artifactIDs.contains(store.targetID)
            default:
                false
            }

            if shouldDelete {
                modelContext.delete(store)
            }
        }
    }

    func purgeEntityProfiles(removing recordIDs: Set<UUID>) throws {
        let stores = try modelContext.fetch(FetchDescriptor<EntityProfileStore>())

        for store in stores {
            var profile = store.domainModel
            let originalRecordIDs = profile.sourceRecordIDs
            profile.sourceRecordIDs.removeAll { recordIDs.contains($0) }

            guard profile.sourceRecordIDs != originalRecordIDs else { continue }

            if profile.sourceRecordIDs.isEmpty && !shouldRetainEntityProfileWithoutSource(profile) {
                modelContext.delete(store)
                continue
            }

            if profile.sourceRecordIDs.isEmpty {
                profile.firstMentionedAt = nil
                profile.lastMentionedAt = nil
            }
            profile.updatedAt = Date.now
            store.apply(domainModel: profile)
        }
    }

    func shouldRetainEntityProfileWithoutSource(_ profile: EntityProfile) -> Bool {
        profile.confirmationState == .userConfirmed
            || profile.relationshipToUser != nil
            || !(profile.userDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            || !profile.aliases.isEmpty
    }

    func purgePersonProfiles(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>
    ) throws {
        let stores = try modelContext.fetch(FetchDescriptor<PersonProfileStore>())
        let now = Date.now

        for store in stores {
            var profile = store.domainModel
            let originalSourceRecordIDs = profile.sourceRecordIDs
            let originalEvidence = profile.fieldEvidence
            profile.sourceRecordIDs.removeAll { recordIDs.contains($0) }
            profile.fieldEvidence = profile.fieldEvidence.map { evidence in
                var updated = evidence
                let touched = !Set(updated.sourceRecordIDs).isDisjoint(with: recordIDs)
                    || !Set(updated.sourceArtifactIDs).isDisjoint(with: artifactIDs)
                guard touched else { return updated }
                updated.sourceRecordIDs.removeAll { recordIDs.contains($0) }
                updated.sourceArtifactIDs.removeAll { artifactIDs.contains($0) }
                updated.status = .stale
                updated.refreshedAt = now
                return updated
            }

            if let portrait = profile.aiPortrait {
                let remainingEvidence = portrait.evidenceRecordIDs.filter { !recordIDs.contains($0) }
                if remainingEvidence.count != portrait.evidenceRecordIDs.count {
                    if remainingEvidence.isEmpty {
                        profile.aiPortrait = nil
                    } else {
                        var updatedPortrait = portrait
                        updatedPortrait.evidenceRecordIDs = remainingEvidence
                        updatedPortrait.status = .stale
                        updatedPortrait.updatedAt = now
                        profile.aiPortrait = updatedPortrait
                    }
                }
            }

            let changed = profile.sourceRecordIDs != originalSourceRecordIDs
                || profile.fieldEvidence != originalEvidence
            guard changed else { continue }

            if profile.sourceRecordIDs.isEmpty && !shouldRetainPersonProfileWithoutSource(profile) {
                modelContext.delete(store)
                continue
            }

            profile.updatedAt = now
            store.apply(domainModel: profile)
        }
    }

    func shouldRetainPersonProfileWithoutSource(_ profile: PersonProfile) -> Bool {
        profile.relationshipHistory.contains { $0.status == .userConfirmed }
            || !(profile.userNotes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            || profile.fieldEvidence.contains { $0.status == .userConfirmed && $0.source == .userEdit }
            || profile.automationPolicy == .frozen
    }

    func purgePlaceProfiles(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>
    ) throws {
        let stores = try modelContext.fetch(FetchDescriptor<PlaceProfileStore>())

        for store in stores {
            var profile = store.domainModel
            let originalArtifactIDs = profile.sourceArtifactIDs
            let originalRecordIDs = profile.sourceRecordIDs
            profile.sourceArtifactIDs.removeAll { artifactIDs.contains($0) }
            profile.sourceRecordIDs.removeAll { recordIDs.contains($0) }

            guard profile.sourceArtifactIDs != originalArtifactIDs || profile.sourceRecordIDs != originalRecordIDs else {
                continue
            }

            if profile.sourceArtifactIDs.isEmpty {
                modelContext.delete(store)
                continue
            }

            let remainingArtifacts = try fetchArtifacts(ids: profile.sourceArtifactIDs)
            profile = recalculatedPlaceProfile(profile, from: remainingArtifacts, updatedAt: Date.now)
            store.apply(domainModel: profile)
            try upsertPlaceEntityNode(for: profile, updatedAt: profile.updatedAt)
        }
    }


}
