import Foundation
import OSLog
import SwiftData

private let log = Logger(subsystem: "com.mory", category: "persistence")

@MainActor
final class MoryMemoryRepository: MoryMemoryRepositorying {
    let modelContext: ModelContext
    let analysisService: any ReflectionAnalysisServing
    let cloudIntelligenceService: (any CloudIntelligenceServing)?
    let architecturePipelineExecutor: AnalysisExecutor
    let homeBoardRuleEngine: HomeBoardRuleEngine
    let graphQueryService: MemoryGraphQueryService
    let memorySearchService: MemorySearchService
    let searchResultMerger: SearchResultMerger
    let spotlightIndexService: any SpotlightIndexServicing
    let spotlightItemBuilder: SpotlightSearchableItemBuilder
    let captureArtifactBuilder: MemoryCaptureArtifactBuilder
    let temporalArcService: TemporalArcService
    let debugDiagnosticsService: DebugDiagnosticsService
    let intelligenceScheduler: IntelligenceScheduler
    let entityEnrichmentService: EntityEnrichmentService
    let clarificationQuestionBuilder: ClarificationQuestionBuilder
    let graphDeltaApplier: GraphDeltaApplier
    let affectSnapshotMapper: AffectSnapshotMapper
    let externalCaptureInboxStore: any ExternalCaptureInboxStoring
    let backgroundOperationStore: any BackgroundOperationStoring
    let backgroundTriggerDispatcher: (any BackgroundTriggerDispatching)?
    var latestAnalysisTrace: DebugPipelineTraceSnapshot?
    var latestReflectionTrace: DebugPipelineTraceSnapshot?

    init(
        modelContext: ModelContext,
        analysisService: any ReflectionAnalysisServing,
        cloudIntelligenceService: (any CloudIntelligenceServing)? = nil,
        spotlightIndexService: (any SpotlightIndexServicing)? = nil,
        localDataOwnerID: String? = nil,
        externalCaptureInboxStore: (any ExternalCaptureInboxStoring)? = nil,
        // Injected services with production defaults — override in tests to supply mocks.
        architecturePipelineExecutor: AnalysisExecutor = AnalysisExecutor(),
        homeBoardRuleEngine: HomeBoardRuleEngine = HomeBoardRuleEngine(),
        graphQueryService: MemoryGraphQueryService = MemoryGraphQueryService(),
        memorySearchService: MemorySearchService = MemorySearchService(),
        searchResultMerger: SearchResultMerger = SearchResultMerger(),
        captureArtifactBuilder: MemoryCaptureArtifactBuilder = MemoryCaptureArtifactBuilder(),
        temporalArcService: TemporalArcService = TemporalArcService(),
        debugDiagnosticsService: DebugDiagnosticsService = DebugDiagnosticsService(),
        intelligenceScheduler: IntelligenceScheduler = IntelligenceScheduler(),
        entityEnrichmentService: EntityEnrichmentService = EntityEnrichmentService(),
        clarificationQuestionBuilder: ClarificationQuestionBuilder = ClarificationQuestionBuilder(),
        graphDeltaApplier: GraphDeltaApplier = GraphDeltaApplier(),
        affectSnapshotMapper: AffectSnapshotMapper = AffectSnapshotMapper(),
        backgroundOperationStore: (any BackgroundOperationStoring)? = nil,
        backgroundTriggerDispatcher: (any BackgroundTriggerDispatching)? = nil
    ) {
        self.modelContext = modelContext
        self.analysisService = analysisService
        self.cloudIntelligenceService = cloudIntelligenceService
        self.spotlightIndexService = spotlightIndexService ?? DefaultSpotlightIndexService()
        self.spotlightItemBuilder = SpotlightSearchableItemBuilder(ownerID: localDataOwnerID)
        self.externalCaptureInboxStore = externalCaptureInboxStore ?? ExternalCaptureInboxDefaultsStore(
            scope: localDataOwnerID.map { .owner($0) } ?? .legacy,
            includeSharedInboxFallback: true
        )
        if let backgroundOperationStore {
            self.backgroundOperationStore = backgroundOperationStore
        } else if let localDataOwnerID {
            self.backgroundOperationStore = BackgroundOperationDefaultsStore(ownerID: localDataOwnerID)
        } else {
            self.backgroundOperationStore = BackgroundOperationMemoryStore()
        }
        self.architecturePipelineExecutor = architecturePipelineExecutor
        self.homeBoardRuleEngine = homeBoardRuleEngine
        self.graphQueryService = graphQueryService
        self.memorySearchService = memorySearchService
        self.searchResultMerger = searchResultMerger
        self.captureArtifactBuilder = captureArtifactBuilder
        self.temporalArcService = temporalArcService
        self.debugDiagnosticsService = debugDiagnosticsService
        self.intelligenceScheduler = intelligenceScheduler
        self.entityEnrichmentService = entityEnrichmentService
        self.clarificationQuestionBuilder = clarificationQuestionBuilder
        self.graphDeltaApplier = graphDeltaApplier
        self.affectSnapshotMapper = affectSnapshotMapper
        self.backgroundTriggerDispatcher = backgroundTriggerDispatcher
    }

    func evaluateQualityTuningExpectation(
        _ expectation: QualityTuningExpectation,
        recordIDs: [UUID],
        arcs: [TemporalArc],
        reflections: [ReflectionSnapshot]
    ) -> Bool {
        switch expectation {
        case .noArcNoReflection:
            return arcs.isEmpty && reflections.isEmpty
        case .arcExpected:
            let recordIDSet = Set(recordIDs)
            return arcs.contains { Set($0.sourceRecordIDs).intersection(recordIDSet).count >= 2 }
        case .reflectionAllowed:
            return !reflections.isEmpty
        case .inspectOnly:
            return true
        }
    }

    func makeQualityTuningFilteredSummary(_ diagnostics: DebugDiagnosticsSnapshot) -> String {
        guard let analysis = diagnostics.fixture?.chain.analysis else {
            return "No stored analysis snapshot."
        }
        return [
            "summary: \(analysis.summary)",
            "themes: \(analysis.themes.joined(separator: ", ").ifEmpty("none"))",
            "salience: \(analysis.salienceScore.map { String(format: "%.2f", $0) } ?? "none")",
            "entities: \(analysis.entityMentions.map { "\($0.kind.rawValue):\($0.name)" }.joined(separator: ", ").ifEmpty("none"))",
            "candidate_edges: \(analysis.candidateEdges.count)",
            "reflection_hint: \(analysis.reflectionHint?.trimmedOrNil ?? "none")"
        ].joined(separator: "\n")
    }

    func makeQualityTuningStoredSummary(
        diagnostics: DebugDiagnosticsSnapshot,
        arcs: [TemporalArc],
        reflections: [ReflectionSnapshot]
    ) -> String {
        guard let chain = diagnostics.fixture?.chain else {
            return "No fixture chain."
        }
        return [
            "artifacts: \(chain.artifacts.count)",
            "entities: \(chain.entities.map(\.displayName).joined(separator: ", ").ifEmpty("none"))",
            "edges: \(chain.edges.count)",
            "arcs: \(arcs.map { "\($0.title) [\($0.sourceRecordIDs.count) records]" }.joined(separator: ", ").ifEmpty("none"))",
            "reflections: \(reflections.map { "\($0.title) [\($0.status.rawValue)]" }.joined(separator: ", ").ifEmpty("none"))"
        ].joined(separator: "\n")
    }

    func makeQualityTuningGateSnapshots(
        _ diagnostics: DebugDiagnosticsSnapshot,
        expectation: QualityTuningExpectation
    ) -> [QualityTuningGateSnapshot] {
        guard let chain = diagnostics.fixture?.chain else {
            return [.init(title: "Target", passed: false, detail: "No fixture chain.")]
        }

        let entityPolicy = EntityQualityPolicy()
        let reflectionPolicy = ReflectionQualityPolicy()
        var gates: [QualityTuningGateSnapshot] = []

        if let rawEntities = rawQualityTuningEntities(from: diagnostics.analyzePayload?.responseBody), !rawEntities.isEmpty {
            for entity in rawEntities {
                let result = entityPolicy.evaluate(entity)
                gates.append(.init(
                    title: "Entity \(entity.kind.rawValue): \(entity.name)",
                    passed: result.passed,
                    detail: [result.reason, result.metric].compactMap(\.self).joined(separator: " · ")
                ))
            }
        } else {
            gates.append(.init(title: "Entity gate", passed: true, detail: "No raw entities to filter."))
        }

        if chain.arcs.isEmpty {
            let pass = expectation != .arcExpected
            gates.append(.init(
                title: "Arc gate",
                passed: pass,
                detail: pass ? "No stored arc for target record, as expected." : "No stored arc for target record."
            ))
        } else {
            for arc in chain.arcs {
                gates.append(.init(
                    title: "Arc \(arc.title)",
                    passed: expectation != .noArcNoReflection,
                    detail: "records \(arc.sourceRecordIDs.count) · cluster \(arc.clusterStrength)"
                ))
            }
        }

        if let analysis = chain.analysis {
            let result = reflectionPolicy.shouldRequestRecordReflection(record: chain.record, artifacts: chain.artifacts, analysis: analysis)
            let pass = expectation == .noArcNoReflection ? !result.passed : (result.passed || expectation == .inspectOnly)
            gates.append(.init(
                title: "Record reflection request",
                passed: pass,
                detail: [result.reason, result.metric].compactMap(\.self).joined(separator: " · ")
            ))
        }

        return gates
    }

    func rawQualityTuningEntities(from responseBody: String?) -> [EntityReference]? {
        guard let data = responseBody?.data(using: .utf8) else { return nil }
        let envelope: AnalysisRecordResponse
        do {
            envelope = try JSONDecoder().decode(AnalysisRecordResponse.self, from: data)
        } catch {
            log.warning("rawQualityTuningEntities: Failed to decode AnalysisRecordResponse: \(error)")
            return nil
        }
        return envelope.entities.compactMap { entity in
            guard let kind = EntityKind(rawValue: entity.kind.lowercased()) else { return nil }
            return EntityReference(kind: kind, name: entity.name, aliases: entity.aliases ?? [], confidence: entity.confidence)
        }
    }

    func makeQualityTuningPreference(from store: QualityTuningPreferenceStore) -> QualityTuningPreference {
        let thresholds: QualityTuningThresholds
        if let data = store.thresholdsData {
            do {
                thresholds = try JSONDecoder().decode(QualityTuningThresholds.self, from: data)
            } catch {
                log.warning("makeQualityTuningPreference: Failed to decode thresholds, using defaults: \(error)")
                thresholds = .defaults
            }
        } else {
            thresholds = .defaults
        }
        return QualityTuningPreference(
            id: store.id,
            schemaVersion: store.schemaVersion,
            syncKey: store.syncKey,
            promptProfile: QualityTuningPromptProfile(rawValue: store.promptProfileRawValue) ?? .balanced,
            thresholds: thresholds,
            notes: store.notes,
            updatedAt: store.updatedAt
        )
    }

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
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
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

    // MARK: - Private: Person Profile Building

    func buildPersonProfile(
        detail: EntityDetailSnapshot,
        entityProfile: EntityProfile?,
        existing: PersonProfile?,
        now: Date
    ) throws -> PersonProfile {
        if let existing, existing.isFrozen {
            var frozen = existing
            frozen.sourceRecordIDs = mergeUniqueIDs(frozen.sourceRecordIDs, detail.relatedMemories.map(\.id))
            frozen.updatedAt = now
            return frozen
        }

        let sourceRecordIDs = mergeUniqueIDs(
            existing?.sourceRecordIDs ?? [],
            mergeUniqueIDs(entityProfile?.sourceRecordIDs ?? [], detail.relatedMemories.map(\.id))
        )
        let aliases = normalizedPersonAliases(
            [detail.entity.displayName, detail.entity.canonicalName]
                + detail.entity.aliases
                + (entityProfile?.aliases ?? [])
                + (existing?.aliases ?? [])
        )
        let relationship = preservedUserConfirmedRelationship(existing)
            ?? existing?.relationshipToUser
            ?? entityProfile?.relationshipToUser
        let relationshipHistory = updatedRelationshipHistory(
            existing?.relationshipHistory ?? [],
            relationship: relationship,
            sourceRecordIDs: sourceRecordIDs,
            now: now
        )
        let roleLabels = mergeStrings(
            existing?.roleLabels ?? [],
            relationship.map { [$0.rawValue] } ?? []
        )
        let contextLabels = mergeStrings(
            existing?.commonContextLabels ?? [],
            mergeStrings(entityProfile?.commonContextLabels ?? [], detail.relatedThemes)
        )
        let relatedEntityIDs = try relatedEntityIDsByKind(edges: detail.edges)
        let evidence = refreshedPersonProfileEvidence(
            detail: detail,
            entityProfile: entityProfile,
            existing: existing,
            sourceRecordIDs: sourceRecordIDs,
            relationship: relationship,
            contextLabels: contextLabels,
            now: now
        )

        let portrait = buildPersonPortrait(
            displayName: detail.entity.displayName,
            relationship: relationship,
            relatedMemories: detail.relatedMemories,
            contextLabels: contextLabels,
            existing: existing?.aiPortrait,
            now: now
        )
        let affectPattern = buildPersonAffectPattern(
            recordIDs: sourceRecordIDs,
            now: now
        )

        return PersonProfile(
            id: existing?.id ?? UUID(),
            entityID: detail.entity.id,
            displayName: detail.entity.displayName,
            canonicalName: detail.entity.canonicalName,
            aliases: aliases,
            roleLabels: roleLabels,
            relationshipToUser: relationship,
            relationshipHistory: relationshipHistory,
            relationshipStrength: relationshipStrength(for: relationship, mentionCount: sourceRecordIDs.count),
            importanceScore: importanceScore(
                relationship: relationship,
                mentionCount: sourceRecordIDs.count,
                reflectionCount: detail.relatedReflections.count,
                arcCount: detail.relatedArcs.count
            ),
            interactionFrequency: interactionFrequency(for: detail.relatedMemories),
            commonPlaceIDs: relatedEntityIDs[.place] ?? existing?.commonPlaceIDs ?? [],
            commonThemeIDs: relatedEntityIDs[.theme] ?? existing?.commonThemeIDs ?? [],
            commonDecisionIDs: relatedEntityIDs[.decision] ?? existing?.commonDecisionIDs ?? [],
            commonContextLabels: contextLabels,
            emotionalPattern: affectPattern ?? existing?.emotionalPattern,
            recentChangeSummary: recentChangeSummary(
                displayName: detail.entity.displayName,
                relatedMemories: detail.relatedMemories,
                relationship: relationship
            ),
            userNotes: existing?.userNotes,
            aiPortrait: portrait,
            fieldEvidence: evidence,
            fieldConfidence: fieldConfidence(from: evidence),
            sensitivity: existing?.sensitivity ?? .normal,
            automationPolicy: existing?.automationPolicy ?? .automatic,
            sourceRecordIDs: sourceRecordIDs,
            lastReviewedAt: existing?.lastReviewedAt,
            createdAt: existing?.createdAt ?? detail.entity.createdAt,
            updatedAt: now
        )
    }

    func preservedUserConfirmedRelationship(_ existing: PersonProfile?) -> EntityRelationshipToUser? {
        guard let existing else { return nil }
        guard existing.relationshipHistory.contains(where: { $0.status == .userConfirmed }) else {
            return nil
        }
        return existing.relationshipToUser
    }

    func updatedRelationshipHistory(
        _ existing: [RelationshipChange],
        relationship: EntityRelationshipToUser?,
        sourceRecordIDs: [UUID],
        now: Date
    ) -> [RelationshipChange] {
        guard let relationship else { return existing }
        if existing.contains(where: { $0.relationship == relationship }) {
            return existing
        }
        return existing + [
            RelationshipChange(
                relationship: relationship,
                note: "Inferred from person profile refresh.",
                sourceRecordIDs: sourceRecordIDs,
                status: .inferred,
                changedAt: now
            )
        ]
    }

    func relatedEntityIDsByKind(edges: [EntityEdge]) throws -> [EntityKind: [UUID]] {
        var result: [EntityKind: [UUID]] = [:]
        for edge in edges {
            for entityID in [edge.fromEntityID, edge.toEntityID] {
                guard let node = try fetchEntityNode(id: entityID) else { continue }
                guard node.kind == .place || node.kind == .theme || node.kind == .decision else { continue }
                result[node.kind, default: []].append(node.id)
            }
        }
        return result.mapValues { Array(NSOrderedSet(array: $0)) as? [UUID] ?? $0 }
    }

    func refreshedPersonProfileEvidence(
        detail: EntityDetailSnapshot,
        entityProfile: EntityProfile?,
        existing: PersonProfile?,
        sourceRecordIDs: [UUID],
        relationship: EntityRelationshipToUser?,
        contextLabels: [String],
        now: Date
    ) -> [ProfileFieldEvidence] {
        let userEvidence = existing?.fieldEvidence.filter { $0.source == .userEdit && $0.status == .userConfirmed } ?? []
        var evidence = userEvidence
        let latestMemories = Array(detail.relatedMemories.prefix(4))
        for memory in latestMemories {
            evidence.append(ProfileFieldEvidence(
                fieldKey: "sourceRecordIDs",
                source: .memory,
                sourceRecordIDs: [memory.id],
                sourceArtifactIDs: memory.primaryArtifact.map { [$0.id] } ?? [],
                snippet: String(memory.summaryText.prefix(260)),
                confidence: entityProfile?.confidence ?? detail.entity.confidence,
                createdAt: now,
                refreshedAt: now
            ))
        }
        if let relationship {
            evidence.append(ProfileFieldEvidence(
                fieldKey: "relationshipToUser",
                source: .profileRefresh,
                sourceRecordIDs: sourceRecordIDs,
                snippet: "Relationship currently reads as \(relationship.rawValue).",
                confidence: entityProfile?.confidence,
                createdAt: now,
                refreshedAt: now
            ))
        }
        if !contextLabels.isEmpty {
            evidence.append(ProfileFieldEvidence(
                fieldKey: "commonContextLabels",
                source: .profileRefresh,
                sourceRecordIDs: sourceRecordIDs,
                snippet: contextLabels.prefix(6).joined(separator: ", "),
                confidence: 0.72,
                createdAt: now,
                refreshedAt: now
            ))
        }
        return evidence
    }

    func fieldConfidence(from evidence: [ProfileFieldEvidence]) -> [String: Double] {
        var result: [String: Double] = [:]
        for item in evidence {
            result[item.fieldKey] = max(result[item.fieldKey] ?? 0, item.confidence ?? 0.5)
        }
        return result
    }

    func buildPersonPortrait(
        displayName: String,
        relationship: EntityRelationshipToUser?,
        relatedMemories: [MemorySummary],
        contextLabels: [String],
        existing: PersonPortrait?,
        now: Date
    ) -> PersonPortrait? {
        guard !relatedMemories.isEmpty else {
            return existing
        }
        let memoryCount = relatedMemories.count
        let contexts = Array(contextLabels.prefix(5))
        let relationshipText = relationship?.rawValue ?? "unknown relationship"
        let latest = relatedMemories.max { $0.record.updatedAt < $1.record.updatedAt }
        let summary = "\(displayName) appears in \(memoryCount) \(memoryCount == 1 ? "memory" : "memories"), with relationship marked as \(relationshipText)."
        let recentPattern = latest.map { "Latest related memory: \($0.summaryText)" }
        return PersonPortrait(
            id: existing?.id ?? UUID(),
            summary: summary,
            relationshipTrajectory: relationship == nil ? nil : "Current relationship label is \(relationshipText).",
            recentInteractionPattern: recentPattern.map { String($0.prefix(320)) },
            recurringContexts: contexts,
            affectSummary: nil,
            openUncertainties: relationship == nil ? ["Confirm who \(displayName) is to you."] : [],
            suggestedQuestions: relationship == nil ? ["Who is \(displayName) to you?"] : [],
            evidenceRecordIDs: relatedMemories.map(\.id),
            confidence: min(0.95, 0.45 + Double(memoryCount) * 0.08),
            status: .inferred,
            generatedAt: existing?.generatedAt ?? now,
            updatedAt: now
        )
    }

    func buildPersonAffectPattern(
        recordIDs: [UUID],
        now: Date
    ) -> PersonAffectPattern? {
        let analyses = recordIDs.compactMap { try? fetchRecordAnalysis(recordID: $0) }
        let notes = analyses
            .map(\.emotionInterpretation)
            .compactMap { $0.trimmedOrNil }
        guard !notes.isEmpty else { return nil }
        return PersonAffectPattern(
            dominantLabels: [],
            summary: String(notes.prefix(3).joined(separator: " / ").prefix(360)),
            sourceRecordIDs: analyses.map(\.recordID),
            confidence: 0.58,
            updatedAt: now
        )
    }

    func relationshipStrength(
        for relationship: EntityRelationshipToUser?,
        mentionCount: Int
    ) -> Double? {
        guard let relationship else { return nil }
        let base: Double = switch relationship {
        case .partner: 0.9
        case .family: 0.82
        case .friend: 0.72
        case .manager, .directReport, .coworker, .classmate, .client: 0.56
        case .acquaintance, .creator, .publicFigure, .other, .unknown: 0.35
        }
        return min(1, base + min(0.18, Double(mentionCount) * 0.025))
    }

    func importanceScore(
        relationship: EntityRelationshipToUser?,
        mentionCount: Int,
        reflectionCount: Int,
        arcCount: Int
    ) -> Double {
        var score = min(0.45, Double(mentionCount) * 0.08)
        if relationship != nil {
            score += 0.2
        }
        score += min(0.18, Double(reflectionCount) * 0.06)
        score += min(0.17, Double(arcCount) * 0.08)
        return min(1, score)
    }

    func interactionFrequency(for memories: [MemorySummary]) -> InteractionFrequency {
        guard !memories.isEmpty else { return .unknown }
        guard memories.count >= 2 else { return .rare }
        let dates = memories.map(\.record.updatedAt)
        guard let earliest = dates.min(), let latest = dates.max() else { return .unknown }
        let days = max(1, latest.timeIntervalSince(earliest) / 86_400)
        let rate = Double(memories.count) / days
        if rate >= 1 { return .daily }
        if rate >= 1.0 / 7.0 { return .weekly }
        if rate >= 1.0 / 30.0 { return .monthly }
        return .rare
    }

    func recentChangeSummary(
        displayName: String,
        relatedMemories: [MemorySummary],
        relationship: EntityRelationshipToUser?
    ) -> String? {
        guard let latest = relatedMemories.max(by: { $0.record.updatedAt < $1.record.updatedAt }) else {
            return nil
        }
        let relationshipText = relationship?.rawValue ?? "unconfirmed"
        return "\(displayName)'s latest related memory is from \(latest.record.updatedAt.formatted(.iso8601)); relationship is \(relationshipText)."
    }

    // MARK: - Private: Entity Node & Edge Helpers

    func fetchPersonEntityNodes(recordID: UUID, artifactIDs: [UUID]) throws -> [EntityNode] {
        let artifactIDSet = Set(artifactIDs)
        let linkedEntityIDs = Set(
            try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
                .filter { link in
                    link.sourceRecordID == recordID
                        || link.sourceAnalysisRecordID == recordID
                        || artifactIDSet.contains(link.artifactID)
                }
                .map(\.entityID)
        )

        return try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
            .map(\.domainModel)
            .filter { entity in
                entity.kind == .person
                    && (linkedEntityIDs.contains(entity.id) || entity.provenanceRecordIDs.contains(recordID))
            }
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                return lhs.displayName < rhs.displayName
            }
    }

    func fetchEntityNode(id: UUID) throws -> EntityNode? {
        try modelContext.fetch(
            FetchDescriptor<EntityNodeStore>(predicate: #Predicate { $0.id == id })
        ).first?.domainModel
    }

    func fetchEntityNodeStore(id: UUID) throws -> EntityNodeStore? {
        try modelContext.fetch(
            FetchDescriptor<EntityNodeStore>(predicate: #Predicate { $0.id == id })
        ).first
    }

    func requirePersonEntityNodeStore(id: UUID) throws -> EntityNodeStore {
        guard let store = try fetchEntityNodeStore(id: id) else {
            throw PersonEntityMutationError.entityNotFound
        }
        guard store.kindRawValue == EntityKind.person.rawValue else {
            throw PersonEntityMutationError.entityIsNotPerson
        }
        return store
    }

    func fetchPlaceProfileStore(id: UUID) throws -> PlaceProfileStore? {
        try modelContext.fetch(
            FetchDescriptor<PlaceProfileStore>(predicate: #Predicate { $0.id == id })
        ).first
    }

    func requirePlaceProfileStore(id: UUID) throws -> PlaceProfileStore {
        guard let store = try fetchPlaceProfileStore(id: id) else {
            throw PlaceProfileMutationError.profileNotFound
        }
        return store
    }

    func fetchArtifacts(ids: [UUID]) throws -> [Artifact] {
        guard !ids.isEmpty else { return [] }
        let idSet = Set(ids)
        let artifacts = try modelContext.fetch(FetchDescriptor<ArtifactStore>())
            .map(\.domainModel)
            .filter { idSet.contains($0.id) }
        let artifactsByID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
        return ids.compactMap { artifactsByID[$0] }
    }

    // MARK: - Private: Normalization Helpers

    func normalizedPlaceDisplayName(_ displayName: String) throws -> String {
        guard let resolvedName = displayName.trimmedOrNil else {
            throw PlaceProfileMutationError.emptyDisplayName
        }
        return resolvedName
    }

    func normalizedPlaceAliases(_ values: [String?]) -> [String] {
        var seen = Set<String>()
        var aliases: [String] = []
        for value in values {
            guard let trimmed = value?.trimmedOrNil else { continue }
            let key = PlaceContextResolver.normalizedName(trimmed)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            aliases.append(trimmed)
        }
        return aliases
    }

    func normalizedPersonAliases(_ values: [String?]) -> [String] {
        var seen = Set<String>()
        var aliases: [String] = []
        for value in values {
            guard let trimmed = value?.trimmedOrNil else { continue }
            let key = PlaceContextResolver.normalizedName(trimmed)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            aliases.append(trimmed)
        }
        return aliases
    }

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

    // MARK: - Private: Intelligence Job Helpers

    func enqueueEntityMutationRecomputeJobs(
        affectedRecordIDs: Set<UUID>,
        affectedEntityIDs: Set<UUID>
    ) throws {
        let now = Date.now
        for entityID in affectedEntityIDs {
            try upsert(intelligenceJob: IntelligenceJob(
                kind: .entityEnrichment,
                targetType: .entity,
                targetID: entityID,
                status: .pending,
                priority: 0.76,
                scheduledAt: now,
                updatedAt: now,
                requiresCloudAI: false
            ))
            try upsert(intelligenceJob: IntelligenceJob(
                kind: .personProfileRefresh,
                targetType: .entity,
                targetID: entityID,
                status: .pending,
                priority: 0.73,
                scheduledAt: now,
                updatedAt: now,
                requiresCloudAI: false
            ))
        }
        for recordID in affectedRecordIDs {
            try upsert(intelligenceJob: IntelligenceJob(
                kind: .chapterCandidate,
                targetType: .record,
                targetID: recordID,
                status: .pending,
                priority: 0.42,
                scheduledAt: now,
                updatedAt: now,
                requiresCloudAI: false
            ))
        }
    }

    func purgeEntityProvenance(
        removing recordIDs: Set<UUID>,
        remainingLinkedEntityIDs: Set<UUID>
    ) throws {
        let entityStores = try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
        for store in entityStores {
            var entity = store.domainModel
            let originalProvenance = entity.provenanceRecordIDs
            entity.provenanceRecordIDs.removeAll { recordIDs.contains($0) }

            if entity.provenanceRecordIDs.isEmpty && !remainingLinkedEntityIDs.contains(entity.id) {
                try markEntityDeletedForTombstones(entityID: entity.id, kind: entity.kind, now: Date.now)
                modelContext.delete(store)
            } else if entity.provenanceRecordIDs != originalProvenance {
                entity.updatedAt = Date.now
                store.apply(domainModel: entity)
            }
        }
    }

    // MARK: - Private: Affect Helpers

    func makeAffectSnapshots(
        from draft: MemoryCaptureDraft,
        recordID: UUID,
        createdAt: Date
    ) -> [AffectSnapshot] {
        var snapshots = draft.affectSnapshots.map {
            affectSnapshotMapper.snapshot(recordID: recordID, draft: $0, now: createdAt)
        }
        if snapshots.isEmpty,
           let snapshot = affectSnapshotMapper.snapshot(
                recordID: recordID,
                rawMood: draft.mood,
                userIntensity: nil,
                source: .userFreeform,
                now: createdAt
           ) {
            snapshots.append(snapshot)
        }
        return snapshots
    }

    func replaceUserAffectSnapshot(recordID: UUID, rawMood: String?, now: Date) throws {
        let stores = try modelContext.fetch(
            FetchDescriptor<AffectSnapshotStore>(predicate: #Predicate { $0.recordID == recordID })
        )
        for store in stores {
            let snapshot = store.domainModel
            let onlyUserFreeform = snapshot.sources.allSatisfy { $0 == .userFreeform || $0 == .userSelected }
            if onlyUserFreeform {
                modelContext.delete(store)
            }
        }

        if let snapshot = affectSnapshotMapper.snapshot(
            recordID: recordID,
            rawMood: rawMood,
            userIntensity: nil,
            source: .userFreeform,
            now: now
        ) {
            try upsert(affectSnapshot: snapshot)
        }
    }

    func updateSelfExpressionPattern(from correction: AffectCorrection, snapshot: AffectSnapshot, now: Date) throws {
        let phrase = correction.note?.trimmedOrNil
            ?? snapshot.rawInput?.trimmedOrNil
            ?? snapshot.evidence.reversed().compactMap { $0.summary.trimmedOrNil }.first
            ?? (snapshot.labels + correction.labels).map(\.rawValue).joined(separator: ", ").trimmedOrNil
        guard let phrase else { return }
        var profile = try ensureSelfProfile()
        let interpretation = (correction.toneHints + correction.labels.map { label in
            switch label {
            case .irritated, .stressed, .tense, .overwhelmed:
                return ToneHint.serious
            case .playful, .amused, .mockFrustrated:
                return ToneHint.playful
            default:
                return ToneHint.uncertain
            }
        })
        .map(\.rawValue)
        .joined(separator: ", ")
        let pattern = ExpressionPattern(
            phrase: phrase,
            interpretation: interpretation.isEmpty ? "affect correction" : interpretation,
            confidence: 1
        )
        profile.expressionPatterns.removeAll {
            $0.phrase.caseInsensitiveCompare(pattern.phrase) == .orderedSame
        }
        profile.expressionPatterns.insert(pattern, at: 0)
        profile.expressionPatterns = Array(profile.expressionPatterns.prefix(20))
        profile.updatedAt = now
        try upsertSelfProfile(profile)
    }

    func orderedUniqueAffectLabels(_ labels: [AffectLabel]) -> [AffectLabel] {
        var seen = Set<AffectLabel>()
        var result: [AffectLabel] = []
        for label in labels where !seen.contains(label) {
            seen.insert(label)
            result.append(label)
        }
        return result
    }

    func orderedUniqueToneHints(_ hints: [ToneHint]) -> [ToneHint] {
        var seen = Set<ToneHint>()
        var result: [ToneHint] = []
        for hint in hints where !seen.contains(hint) {
            seen.insert(hint)
            result.append(hint)
        }
        return result
    }

    // MARK: - Primitive Upserts

    func upsert(recordShell: RecordShell) throws {
        let descriptor = FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordShell.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: recordShell)
        } else {
            modelContext.insert(RecordShellStore(domainModel: recordShell))
        }
    }

    func upsert(artifact: Artifact) throws {
        let descriptor = FetchDescriptor<ArtifactStore>(predicate: #Predicate { $0.id == artifact.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: artifact)
        } else {
            modelContext.insert(ArtifactStore(domainModel: artifact))
        }
    }

    func upsert(recordAnalysis: RecordAnalysisSnapshot) throws {
        let recordID = recordAnalysis.recordID
        let descriptor = FetchDescriptor<RecordAnalysisSnapshotStore>(predicate: #Predicate { $0.recordID == recordID })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: recordAnalysis)
        } else {
            modelContext.insert(RecordAnalysisSnapshotStore(domainModel: recordAnalysis))
        }
    }

    func upsertPipelineStatus(_ pipelineStatus: MemoryPipelineStatusSnapshot) throws {
        let recordID = pipelineStatus.recordID
        let descriptor = FetchDescriptor<MemoryPipelineStatusStore>(
            predicate: #Predicate { $0.recordID == recordID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: pipelineStatus)
        } else {
            modelContext.insert(MemoryPipelineStatusStore(domainModel: pipelineStatus))
        }
    }

    func upsert(entityNode: EntityNode) throws {
        let descriptor = FetchDescriptor<EntityNodeStore>(predicate: #Predicate { $0.id == entityNode.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: entityNode)
        } else {
            modelContext.insert(EntityNodeStore(domainModel: entityNode))
        }
    }

    func upsert(entityEdge: EntityEdge) throws {
        let descriptor = FetchDescriptor<EntityEdgeStore>(predicate: #Predicate { $0.id == entityEdge.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: entityEdge)
        } else {
            modelContext.insert(EntityEdgeStore(domainModel: entityEdge))
        }
    }

    func upsert(artifactEntityLink: ArtifactEntityLink) throws {
        let descriptor = FetchDescriptor<ArtifactEntityLinkStore>(predicate: #Predicate { $0.id == artifactEntityLink.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: artifactEntityLink)
        } else {
            modelContext.insert(ArtifactEntityLinkStore(domainModel: artifactEntityLink))
        }
    }

    func upsert(temporalArc: TemporalArc) throws {
        let descriptor = FetchDescriptor<TemporalArcStore>(predicate: #Predicate { $0.id == temporalArc.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: temporalArc)
        } else {
            modelContext.insert(TemporalArcStore(domainModel: temporalArc))
        }
    }

    func upsert(reflection: ReflectionSnapshot) throws {
        let descriptor = FetchDescriptor<ReflectionSnapshotStore>(predicate: #Predicate { $0.id == reflection.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: reflection)
        } else {
            modelContext.insert(ReflectionSnapshotStore(domainModel: reflection))
        }
    }

    func upsert(homeBoardPreference: HomeBoardItemPreference) throws {
        let syncKey = homeBoardPreference.syncKey
        let descriptor = FetchDescriptor<HomeBoardPreferenceStore>(predicate: #Predicate { $0.syncKey == syncKey })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: homeBoardPreference)
        } else {
            modelContext.insert(HomeBoardPreferenceStore(domainModel: homeBoardPreference))
        }
    }

    func upsert(userSettingsPreference: UserSettingsPreference) throws {
        let syncKey = userSettingsPreference.syncKey
        let descriptor = FetchDescriptor<UserSettingsPreferenceStore>(predicate: #Predicate { $0.syncKey == syncKey })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: userSettingsPreference)
        } else {
            modelContext.insert(UserSettingsPreferenceStore(domainModel: userSettingsPreference))
        }
    }

    func fetchIntelligencePreferenceStore() throws -> IntelligencePreferenceStore? {
        let syncKey = IntelligencePreferences.defaultSyncKey
        let descriptor = FetchDescriptor<IntelligencePreferenceStore>(
            predicate: #Predicate { $0.syncKey == syncKey },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchSelfProfileStore(syncKey: String) throws -> SelfProfileStore? {
        let descriptor = FetchDescriptor<SelfProfileStore>(
            predicate: #Predicate { $0.syncKey == syncKey },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }

    func upsert(correctionEvent: CorrectionEvent) throws {
        let descriptor = FetchDescriptor<CorrectionEventStore>(predicate: #Predicate { $0.id == correctionEvent.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: correctionEvent)
        } else {
            modelContext.insert(CorrectionEventStore(domainModel: correctionEvent))
        }
    }

    func upsert(entityTombstone: EntityTombstone) throws {
        let descriptor = FetchDescriptor<EntityTombstoneStore>(
            predicate: #Predicate { $0.oldEntityID == entityTombstone.oldEntityID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: entityTombstone)
        } else {
            modelContext.insert(EntityTombstoneStore(domainModel: entityTombstone))
        }
    }

    func upsert(entityProfile: EntityProfile) throws {
        let descriptor = FetchDescriptor<EntityProfileStore>(predicate: #Predicate { $0.id == entityProfile.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: entityProfile)
        } else if let existingByEntity = try modelContext.fetch(
            FetchDescriptor<EntityProfileStore>(predicate: #Predicate { $0.entityID == entityProfile.entityID })
        ).first {
            existingByEntity.apply(domainModel: entityProfile)
        } else {
            modelContext.insert(EntityProfileStore(domainModel: entityProfile))
        }
    }

    func upsert(personProfile: PersonProfile) throws {
        let descriptor = FetchDescriptor<PersonProfileStore>(predicate: #Predicate { $0.id == personProfile.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: personProfile)
        } else if let existingByEntity = try modelContext.fetch(
            FetchDescriptor<PersonProfileStore>(predicate: #Predicate { $0.entityID == personProfile.entityID })
        ).first {
            existingByEntity.apply(domainModel: personProfile)
        } else {
            modelContext.insert(PersonProfileStore(domainModel: personProfile))
        }
    }

    func upsert(affectSnapshot: AffectSnapshot) throws {
        let descriptor = FetchDescriptor<AffectSnapshotStore>(predicate: #Predicate { $0.id == affectSnapshot.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: affectSnapshot)
        } else {
            modelContext.insert(AffectSnapshotStore(domainModel: affectSnapshot))
        }
    }

    func upsert(placeProfile: PlaceProfile) throws {
        let descriptor = FetchDescriptor<PlaceProfileStore>(predicate: #Predicate { $0.id == placeProfile.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: placeProfile)
        } else if let existingByEntity = try modelContext.fetch(
            FetchDescriptor<PlaceProfileStore>(predicate: #Predicate { $0.entityID == placeProfile.entityID })
        ).first {
            existingByEntity.apply(domainModel: placeProfile)
        } else {
            modelContext.insert(PlaceProfileStore(domainModel: placeProfile))
        }
    }

    func upsert(clarificationQuestion: ClarificationQuestion) throws {
        let descriptor = FetchDescriptor<ClarificationQuestionStore>(predicate: #Predicate { $0.id == clarificationQuestion.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: clarificationQuestion)
        } else {
            modelContext.insert(ClarificationQuestionStore(domainModel: clarificationQuestion))
        }
    }

    func upsert(intelligenceJob: IntelligenceJob) throws {
        let descriptor = FetchDescriptor<IntelligenceJobStore>(predicate: #Predicate { $0.id == intelligenceJob.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: intelligenceJob)
        } else if let existingByDedupeKey = try modelContext.fetch(
            FetchDescriptor<IntelligenceJobStore>(predicate: #Predicate { $0.dedupeKey == intelligenceJob.dedupeKey })
        ).first {
            existingByDedupeKey.apply(domainModel: intelligenceJob)
        } else {
            modelContext.insert(IntelligenceJobStore(domainModel: intelligenceJob))
        }
    }

    func upsert(graphDelta: GraphDelta) throws {
        let descriptor = FetchDescriptor<GraphDeltaStore>(predicate: #Predicate { $0.id == graphDelta.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: graphDelta)
        } else {
            modelContext.insert(GraphDeltaStore(domainModel: graphDelta))
        }
    }

    func upsert(notificationIntent: NotificationIntent) throws {
        let intentID = notificationIntent.id
        let descriptor = FetchDescriptor<NotificationIntentStore>(predicate: #Predicate { $0.id == intentID })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: notificationIntent)
        } else {
            modelContext.insert(NotificationIntentStore(domainModel: notificationIntent))
        }
    }

    func save() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    // MARK: - Private: Pipeline & Summary Helpers

    func runArchitecturePipeline(record: RecordShell, artifacts: [Artifact]) async throws {
        guard let cloudIntelligenceService else {
            throw CloudIntelligenceContractError.analyzeMemoryUnavailable
        }
        latestAnalysisTrace = nil
        let dependencies = AnalysisPipelineDependencies(
            cloudIntelligenceService: cloudIntelligenceService,
            contextProvider: ContextPackBuilder(repository: self),
            query: self,
            persist: self,
            tracing: self,
            runtimeScope: QualityTuningAnalysisPipelineRuntimeScope()
        )
        try await architecturePipelineExecutor.run(
            record: record,
            artifacts: artifacts,
            dependencies: dependencies
        )
    }

    func updateReflectionStatus(reflectionID: UUID, status: ReflectionStatus) throws {
        guard let existing = try modelContext.fetch(
            FetchDescriptor<ReflectionSnapshotStore>(predicate: #Predicate { $0.id == reflectionID })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        var updated = existing.domainModel
        updated.status = status
        switch status {
        case .saved:
            updated.savedAt = updated.savedAt ?? Date.now
            updated.dismissedAt = nil
        case .dismissed:
            updated.dismissedAt = Date.now
        case .archived:
            break
        case .suggested:
            updated.savedAt = nil
            updated.dismissedAt = nil
        }
        existing.apply(domainModel: updated)
        try save()
    }

    func makeMemorySummary(
        record: RecordShell,
        artifacts: [Artifact],
        pipelineStatus: MemoryPipelineStatusSnapshot?
    ) -> MemorySummary {
        let contextKinds: Set<ArtifactKind> = [.location, .weather, .music]
        let contextArtifacts = artifacts
            .filter { contextKinds.contains($0.kind) }
            .sorted { $0.updatedAt > $1.updatedAt }

        return MemorySummary(
            record: record,
            primaryArtifact: captureArtifactBuilder.preferredPrimaryArtifact(from: artifacts),
            contextArtifacts: contextArtifacts,
            artifactCount: artifacts.count,
            pipelineStatus: pipelineStatus
        )
    }

    func isSemanticSearchActive() throws -> Bool {
        try fetchIntelligencePreferences().semanticSearchEnabled && fetchV6FeatureFlags().semanticSearch
    }

    func indexMemoryIfPossible(_ memory: MemorySummary) async {
        guard (try? isSemanticSearchActive()) == true else { return }
        guard spotlightIndexService.isIndexingAvailable else { return }

        do {
            let item = spotlightItemBuilder.makeMemoryItem(
                memory: memory,
                artifacts: try fetchArtifacts(recordID: memory.id),
                analysis: try fetchRecordAnalysis(recordID: memory.id)
            )
            try await spotlightIndexService.indexItems([item])
        } catch {
            // Indexing should never block capture or analysis completion.
        }
    }

    func makeMemoryLibraryRow(
        memory: MemorySummary,
        graphContext: MemoryGraphContext
    ) throws -> MemoryLibraryRowSnapshot {
        let artifacts = try fetchArtifacts(recordID: memory.id)
        let artifactKinds = Array(Set(artifacts.map(\.kind))).sorted { $0.rawValue < $1.rawValue }
        let relatedArcs = graphContext.arcs.filter { $0.sourceRecordIDs.contains(memory.id) }
        let relatedArcIDs = Set(relatedArcs.map(\.id))
        let relatedReflections = graphContext.reflections.filter { reflection in
            reflection.sourceRecordIDs.contains(memory.id)
                || reflection.linkedTemporalArcID.map { relatedArcIDs.contains($0) } == true
        }
        let entityIDs = Set(
            graphContext.links
                .filter { $0.sourceRecordID == memory.id || $0.sourceAnalysisRecordID == memory.id }
                .map(\.entityID)
        )

        return MemoryLibraryRowSnapshot(
            memory: memory,
            artifactKinds: artifactKinds,
            hasLocation: artifactKinds.contains(.location),
            hasWeather: artifactKinds.contains(.weather),
            hasMusic: artifactKinds.contains(.music),
            relatedStorylineCount: relatedArcs.count,
            relatedReflectionCount: relatedReflections.count,
            entityCount: entityIDs.count
        )
    }

    func memoryLibraryRow(
        _ row: MemoryLibraryRowSnapshot,
        matches filter: MemoryLibraryFilter
    ) -> Bool {
        if let dateRange = filter.dateRange, !dateRange.contains(row.memory.record.updatedAt) {
            return false
        }
        if !filter.artifactKinds.isEmpty, filter.artifactKinds.isDisjoint(with: Set(row.artifactKinds)) {
            return false
        }
        if !filter.pipelineStages.isEmpty {
            guard let stage = row.memory.pipelineStatus?.stage, filter.pipelineStages.contains(stage) else {
                return false
            }
        }
        switch filter.context {
        case .any:
            break
        case .hasLocation:
            guard row.hasLocation else { return false }
        case .hasWeather:
            guard row.hasWeather else { return false }
        case .hasMusic:
            guard row.hasMusic else { return false }
        }
        switch filter.insight {
        case .any:
            break
        case .hasStoryline:
            guard row.relatedStorylineCount > 0 else { return false }
        case .hasReflection:
            guard row.relatedReflectionCount > 0 else { return false }
        case .hasEntities:
            guard row.entityCount > 0 else { return false }
        }
        return true
    }

    func makeReflectionSummary(
        reflection: ReflectionSnapshot,
        graphContext: MemoryGraphContext
    ) -> ReflectionSummarySnapshot {
        let linkedArc = reflection.linkedTemporalArcID.flatMap { arcID in
            graphContext.arcs.first { $0.id == arcID }
        }
        let relatedRecordIDs = linkedArc.map {
            graphContext.mergeUniqueIDs(reflection.sourceRecordIDs, $0.sourceRecordIDs)
        } ?? reflection.sourceRecordIDs
        return ReflectionSummarySnapshot(
            reflection: reflection,
            linkedArc: linkedArc,
            relatedMemories: graphContext.relatedMemories(recordIDs: relatedRecordIDs, limit: 3)
        )
    }

    func applyLimit<T>(_ limit: Int?, to values: [T]) -> [T] {
        guard let limit else { return values }
        return Array(values.prefix(limit))
    }
}

private struct EntityEdgeKey: Hashable {
    let fromEntityID: UUID
    let toEntityID: UUID
    let relationKind: EntityRelationKind

    init(_ edge: EntityEdge) {
        self.fromEntityID = edge.fromEntityID
        self.toEntityID = edge.toEntityID
        self.relationKind = edge.relationKind
    }
}
