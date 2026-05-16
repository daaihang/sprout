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
        let existingEntityNodes = try fetchExistingEntityNodes(modelContext: modelContext)
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
            existingEntityEdges: try fetchExistingEntityEdges(modelContext: modelContext),
            existingArtifactEntityLinks: try fetchExistingArtifactEntityLinks(modelContext: modelContext)
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
        let candidateRecords = try fetchExistingRecordShells(modelContext: modelContext)
        let candidateAnalyses = try fetchExistingAnalyses(modelContext: modelContext, replacingWith: analysis)
        let candidateArtifacts = try fetchExistingArtifacts(modelContext: modelContext)
        let existingArcs = try fetchExistingTemporalArcs(modelContext: modelContext)
        let candidates = candidateBuilder.buildCandidates(
            records: candidateRecords,
            analyses: candidateAnalyses,
            artifacts: candidateArtifacts,
            artifactEntityLinks: graphUpdate.artifactEntityLinks,
            entityNodes: graphUpdate.entityNodes,
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
            if reflectionQualityPolicy.shouldStoreRecordReflection(reflectionResult).passed {
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

    private func fetchExistingRecordShells(modelContext: ModelContext) throws -> [RecordShell] {
        try modelContext.fetch(FetchDescriptor<RecordShellStore>()).map(\.domainModel)
    }

    private func fetchExistingAnalyses(
        modelContext: ModelContext,
        replacingWith current: RecordAnalysisSnapshot
    ) throws -> [RecordAnalysisSnapshot] {
        var analyses = try modelContext.fetch(FetchDescriptor<RecordAnalysisSnapshotStore>()).map(\.domainModel)
        analyses.removeAll { $0.recordID == current.recordID }
        analyses.append(current)
        return analyses
    }

    private func fetchExistingArtifacts(modelContext: ModelContext) throws -> [Artifact] {
        try modelContext.fetch(FetchDescriptor<ArtifactStore>()).map(\.domainModel)
    }

    private func fetchExistingTemporalArcs(modelContext: ModelContext) throws -> [TemporalArc] {
        try modelContext.fetch(FetchDescriptor<TemporalArcStore>()).map(\.domainModel)
    }

    private func hasExistingArc(for candidate: TemporalArcCandidate, existingArcs: [TemporalArc]) -> Bool {
        let candidateRecordIDs = Set(candidate.recordIDs)
        return existingArcs.contains {
            $0.status != .archived && Set($0.sourceRecordIDs) == candidateRecordIDs
        }
    }

    private func fetchExistingEntityNodes(modelContext: ModelContext) throws -> [EntityNode] {
        let stores = try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
        return stores.map(\.domainModel)
    }

    private func fetchExistingEntityEdges(modelContext: ModelContext) throws -> [EntityEdge] {
        let stores = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>())
        return stores.map(\.domainModel)
    }

    private func fetchExistingArtifactEntityLinks(modelContext: ModelContext) throws -> [ArtifactEntityLink] {
        let stores = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        return stores.map(\.domainModel)
    }
}
