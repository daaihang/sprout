import Foundation
import SwiftData

extension Notification.Name {
    static let pipelineDidComplete = Notification.Name("mory.pipelineDidComplete")
}

struct ArchitecturePipelineExecutor {
    private let graphUpdater = GraphUpdater()
    private let candidateBuilder = TemporalArcCandidateBuilder()
    private let temporalArcService = TemporalArcService()
    private let arcQualityPolicy = ArcQualityPolicy()
    private let reflectionQualityPolicy = ReflectionQualityPolicy()

    func run(
        record: RecordShell,
        artifacts: [Artifact],
        modelContext: ModelContext,
        analysisService: any RecordAnalysisServing,
        upsertRecordAnalysis: @escaping (RecordAnalysisSnapshot) throws -> Void,
        upsertEntityNode: @escaping (EntityNode) throws -> Void,
        upsertEntityEdge: @escaping (EntityEdge) throws -> Void,
        upsertArtifactEntityLink: @escaping (ArtifactEntityLink) throws -> Void,
        upsertTemporalArc: @escaping (TemporalArc) throws -> Void,
        upsertReflection: @escaping (ReflectionSnapshot) throws -> Void,
        save: @escaping () throws -> Void
    ) async throws {
        // Step 1: Fetch known entities for context (limit to 20 most recent)
        let activeRecordScope = QualityTuningRuntime.activeRecordScope
        let existingEntityNodes = try fetchExistingEntityNodes(modelContext: modelContext, recordScope: activeRecordScope)
        let knownEntities = existingEntityNodes
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(20)
            .map {
                EntityReference(
                    id: $0.id,
                    kind: $0.kind,
                    name: $0.displayName,
                    aliases: $0.aliases,
                    confidence: $0.confidence
                )
            }

        // Step 2: Analyze the record (API call)
        let analysis = try await analysisService.analyze(
            record: record,
            artifacts: artifacts,
            knownEntities: Array(knownEntities)
        )

        // Step 3: Persist the record analysis snapshot
        try upsertRecordAnalysis(analysis)
        try save()

        // Step 4: Compute entity graph updates (runs while reflection API is in-flight)
        let graphUpdate = graphUpdater.apply(
            analysis: analysis,
            linkedArtifactIDs: record.artifactIDs,
            linkedRecordIDs: [record.id],
            existingEntityNodes: existingEntityNodes,
            existingEntityEdges: try fetchExistingEntityEdges(modelContext: modelContext, recordScope: activeRecordScope),
            existingArtifactEntityLinks: try fetchExistingArtifactEntityLinks(modelContext: modelContext, recordScope: activeRecordScope)
        )

        // Step 5: Persist graph updates
        for node in graphUpdate.entityNodes {
            try upsertEntityNode(node)
        }
        for edge in graphUpdate.entityEdges {
            try upsertEntityEdge(edge)
        }
        for link in graphUpdate.artifactEntityLinks {
            try upsertArtifactEntityLink(link)
        }
        try save()

        // Step 6: Build TemporalArcCandidates
        let candidateRecords = try fetchExistingRecordShells(modelContext: modelContext, recordScope: activeRecordScope)
        let candidateAnalyses = try fetchExistingAnalyses(modelContext: modelContext, replacingWith: analysis, recordScope: activeRecordScope)
        let candidateArtifacts = try fetchExistingArtifacts(modelContext: modelContext, recordScope: activeRecordScope)
        let existingArcs = try fetchExistingTemporalArcs(modelContext: modelContext, recordScope: activeRecordScope)
        let candidates = candidateBuilder.buildCandidates(
            records: candidateRecords,
            analyses: candidateAnalyses,
            artifacts: candidateArtifacts,
            artifactEntityLinks: graphUpdate.artifactEntityLinks,
            entityNodes: graphUpdate.entityNodes,
            focusRecordID: record.id,
            maxCandidates: 3
        )

        // Step 7: Accept candidate arcs via promoter
        var acceptedArcs: [TemporalArc] = []
        for candidate in candidates {
            guard candidate.recordIDs.contains(record.id) else { continue }
            guard arcQualityPolicy.evaluate(candidate).passed else { continue }
            guard !hasExistingArc(for: candidate, existingArcs: existingArcs) else { continue }
            let promotionResult = temporalArcService.promote(
                candidate: candidate,
                analyses: candidateAnalyses,
                artifactEntityLinks: graphUpdate.artifactEntityLinks,
                entityNodes: graphUpdate.entityNodes
            )
            try upsertTemporalArc(promotionResult.arc)
            try upsertReflection(promotionResult.reflection)
            acceptedArcs.append(promotionResult.arc)
        }
        try save()

        let reflectionGate = reflectionQualityPolicy.shouldRequestRecordReflection(
            record: record,
            artifacts: artifacts,
            analysis: analysis
        )
        if reflectionGate.passed {
            let reflectionResult = try await analysisService.generateReflection(
                record: record,
                artifacts: artifacts,
                linkedArcID: acceptedArcs.first?.id,
                knownEntities: Array(knownEntities),
                prompt: analysis.reflectionHint
            )
            if reflectionQualityPolicy.shouldStoreRecordReflection(
                reflectionResult,
                record: record,
                artifacts: artifacts,
                analysis: analysis
            ).passed {
                let reflection = ReflectionSnapshot(
                    type: .record,
                    title: reflectionResult.title,
                    body: reflectionResult.body,
                    evidenceSummary: reflectionResult.evidenceSummary,
                    confidence: reflectionResult.confidence,
                    status: .suggested,
                    linkedTemporalArcID: acceptedArcs.first?.id,
                    sourceRecordIDs: [record.id],
                    sourceArtifactIDs: artifacts.map(\.id),
                    sourceEntityIDs: graphUpdate.resolvedEntityIDs,
                    createdAt: Date.now,
                    savedAt: nil,
                    dismissedAt: nil
                )
                try upsertReflection(reflection)
            }
        }

        // Step 9: Final save
        try save()
    }

    private func fetchExistingRecordShells(modelContext: ModelContext, recordScope: Set<UUID>?) throws -> [RecordShell] {
        let records = try modelContext.fetch(FetchDescriptor<RecordShellStore>()).map(\.domainModel)
        guard let recordScope else { return records }
        return records.filter { recordScope.contains($0.id) }
    }

    private func fetchExistingAnalyses(
        modelContext: ModelContext,
        replacingWith current: RecordAnalysisSnapshot,
        recordScope: Set<UUID>?
    ) throws -> [RecordAnalysisSnapshot] {
        var analyses = try modelContext.fetch(FetchDescriptor<RecordAnalysisSnapshotStore>()).map(\.domainModel)
        analyses.removeAll { $0.recordID == current.recordID }
        analyses.append(current)
        if let recordScope {
            analyses.removeAll { !recordScope.contains($0.recordID) }
        }
        return analyses
    }

    private func fetchExistingArtifacts(modelContext: ModelContext, recordScope: Set<UUID>?) throws -> [Artifact] {
        let artifacts = try modelContext.fetch(FetchDescriptor<ArtifactStore>()).map(\.domainModel)
        guard let recordScope else { return artifacts }
        return artifacts.filter { recordScope.contains($0.recordID) }
    }

    private func fetchExistingTemporalArcs(modelContext: ModelContext, recordScope: Set<UUID>?) throws -> [TemporalArc] {
        let arcs = try modelContext.fetch(FetchDescriptor<TemporalArcStore>()).map(\.domainModel)
        guard let recordScope else { return arcs }
        return arcs.filter { !$0.sourceRecordIDs.isEmpty && $0.sourceRecordIDs.allSatisfy { recordScope.contains($0) } }
    }

    private func hasExistingArc(for candidate: TemporalArcCandidate, existingArcs: [TemporalArc]) -> Bool {
        let candidateRecordIDs = Set(candidate.recordIDs)
        return existingArcs.contains {
            $0.status != .archived && Set($0.sourceRecordIDs) == candidateRecordIDs
        }
    }

    private func fetchExistingEntityNodes(modelContext: ModelContext, recordScope: Set<UUID>?) throws -> [EntityNode] {
        let stores = try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
        let nodes = stores.map(\.domainModel)
        guard let recordScope else { return nodes }
        return nodes.filter { node in
            !node.provenanceRecordIDs.isEmpty && node.provenanceRecordIDs.contains { recordScope.contains($0) }
        }
    }

    private func fetchExistingEntityEdges(modelContext: ModelContext, recordScope: Set<UUID>?) throws -> [EntityEdge] {
        let stores = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>())
        let edges = stores.map(\.domainModel)
        guard let recordScope else { return edges }
        return edges.filter { edge in
            !edge.sourceRecordIDs.isEmpty && edge.sourceRecordIDs.contains { recordScope.contains($0) }
        }
    }

    private func fetchExistingArtifactEntityLinks(modelContext: ModelContext, recordScope: Set<UUID>?) throws -> [ArtifactEntityLink] {
        let stores = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        let links = stores.map(\.domainModel)
        guard let recordScope else { return links }
        return links.filter { link in
            link.sourceRecordID.map { recordScope.contains($0) } ?? false
        }
    }
}
