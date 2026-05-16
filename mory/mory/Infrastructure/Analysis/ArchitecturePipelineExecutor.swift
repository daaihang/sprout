import Foundation
import SwiftData

extension Notification.Name {
    static let pipelineDidComplete = Notification.Name("mory.pipelineDidComplete")
}

struct ArchitecturePipelineExecutor {
    private let graphUpdater = GraphUpdater()
    private let candidateBuilder = TemporalArcCandidateBuilder()
    private let temporalArcService = TemporalArcService()

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

        // === PARALLEL SECTION ===
        // Fire reflection API call immediately (uses analysis.reflectionHint)
        // while graph + arc processing runs on the current context.
        async let reflectionTask = analysisService.generateReflection(
            record: record,
            artifacts: artifacts,
            linkedArcID: nil,
            knownEntities: Array(knownEntities),
            prompt: analysis.reflectionHint
        )

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
        let candidates = candidateBuilder.buildCandidates(
            records: [record],
            analyses: [analysis],
            artifacts: artifacts,
            artifactEntityLinks: graphUpdate.artifactEntityLinks,
            entityNodes: graphUpdate.entityNodes,
            maxCandidates: 3
        )

        // Step 7: Accept candidate arcs via promoter
        var acceptedArcs: [TemporalArc] = []
        for candidate in candidates {
            let promotionResult = temporalArcService.promote(
                candidate: candidate,
                analyses: [analysis],
                artifactEntityLinks: graphUpdate.artifactEntityLinks,
                entityNodes: graphUpdate.entityNodes
            )
            try upsertTemporalArc(promotionResult.arc)
            try upsertReflection(promotionResult.reflection)
            acceptedArcs.append(promotionResult.arc)
        }
        try save()

        // === MERGE: await reflection API result + combine with graph data ===
        let reflectionResult = try await reflectionTask

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

        // Step 9: Final save
        try save()
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
