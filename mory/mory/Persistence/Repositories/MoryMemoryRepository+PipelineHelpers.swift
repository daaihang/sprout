import Foundation
import OSLog
import Sentry
import SwiftData

private let pipelineLog = Logger(subsystem: "com.mory", category: "persistence.pipeline")

extension MoryMemoryRepository {
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
        let inputContract: AnalysisInputContract
        if let detail = try fetchMemoryDetail(recordID: record.id) {
            inputContract = AnalysisInputContractBuilder().build(from: detail)
        } else {
            inputContract = AnalysisInputContract(
                record: record,
                artifacts: artifacts,
                semanticDigests: try fetchArtifactSemanticDigests(recordID: record.id)
            )
        }
        try await architecturePipelineExecutor.run(
            record: record,
            artifacts: artifacts,
            inputContract: inputContract,
            dependencies: dependencies
        )
    }

    func updateReflectionStatus(reflectionID: UUID, status: ReflectionStatus) throws {
        guard let existing = try modelContext.fetch(
            FetchDescriptor<ReflectionSnapshotStore>(predicate: #Predicate { $0.id == reflectionID })
        ).first else {
            throw MemoryRepositoryError.reflectionNotFound(reflectionID)
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
            pipelineLog.error("Spotlight indexing failed for memory \(memory.id): \(error)")
            let breadcrumb = Breadcrumb(level: .warning, category: "spotlight.indexing")
            breadcrumb.message = "Spotlight indexing failed for memory \(memory.id)"
            SentrySDK.addBreadcrumb(breadcrumb)
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

struct EntityEdgeKey: Hashable {
    let fromEntityID: UUID
    let toEntityID: UUID
    let relationKind: EntityRelationKind

    init(_ edge: EntityEdge) {
        self.fromEntityID = edge.fromEntityID
        self.toEntityID = edge.toEntityID
        self.relationKind = edge.relationKind
    }
}
