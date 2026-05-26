import Foundation
import OSLog
import Sentry
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
}
