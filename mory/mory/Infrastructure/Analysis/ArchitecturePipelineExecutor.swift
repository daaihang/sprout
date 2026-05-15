import Foundation
import SwiftData

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
        // Step 1: Fetch known entities for context
        let existingEntityNodes = try fetchExistingEntityNodes(modelContext: modelContext)
        let knownEntities = existingEntityNodes.map {
            EntityReference(
                id: $0.id,
                kind: $0.kind,
                name: $0.displayName,
                aliases: $0.aliases,
                confidence: $0.confidence
            )
        }

        // Step 2: Analyze the record
        let analysis = try await analysisService.analyze(
            record: record,
            artifacts: artifacts,
            knownEntities: knownEntities
        )

        // Step 3: Persist the record analysis snapshot
        try upsertRecordAnalysis(analysis)
        try save()

        // Step 4: Compute entity graph updates using GraphUpdater
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

        // Step 6: Build TemporalArcCandidates from record+artifacts+analysis
        let allRecords = [record]
        let allAnalyses = [analysis]
        let allArtifacts = artifacts

        let candidates = candidateBuilder.buildCandidates(
            records: allRecords,
            analyses: allAnalyses,
            artifacts: allArtifacts,
            artifactEntityLinks: graphUpdate.artifactEntityLinks,
            entityNodes: graphUpdate.entityNodes,
            maxCandidates: 3
        )

        // Step 7: Accept candidate arcs via promoter
        var acceptedArcs: [TemporalArc] = []
        for candidate in candidates {
            let promotionResult = temporalArcService.promote(
                candidate: candidate,
                analyses: allAnalyses,
                artifactEntityLinks: graphUpdate.artifactEntityLinks,
                entityNodes: graphUpdate.entityNodes
            )
            try upsertTemporalArc(promotionResult.arc)
            try upsertReflection(promotionResult.reflection)
            acceptedArcs.append(promotionResult.arc)
        }
        try save()

        // Step 8: Generate reflection via analysisService
        if let firstArc = acceptedArcs.first {
            let reflectionResult = try await analysisService.generateReflection(
                record: record,
                artifacts: artifacts,
                linkedArcID: firstArc.id,
                knownEntities: knownEntities,
                prompt: analysis.reflectionHint
            )

            let reflection = ReflectionSnapshot(
                type: .record,
                title: reflectionResult.title,
                body: reflectionResult.body,
                evidenceSummary: reflectionResult.evidenceSummary,
                confidence: reflectionResult.confidence,
                status: .suggested,
                linkedTemporalArcID: firstArc.id,
                sourceRecordIDs: [record.id],
                sourceArtifactIDs: artifacts.map(\.id),
                sourceEntityIDs: graphUpdate.resolvedEntityIDs,
                createdAt: Date.now,
                savedAt: nil,
                dismissedAt: nil
            )
            try upsertReflection(reflection)
        } else {
            // Fallback: generate a record-level reflection without arc linkage
            let reflectionResult = try await analysisService.generateReflection(
                record: record,
                artifacts: artifacts,
                linkedArcID: nil,
                knownEntities: knownEntities,
                prompt: analysis.reflectionHint
            )

            let reflection = ReflectionSnapshot(
                type: .record,
                title: reflectionResult.title,
                body: reflectionResult.body,
                evidenceSummary: reflectionResult.evidenceSummary,
                confidence: reflectionResult.confidence,
                status: .suggested,
                linkedTemporalArcID: nil,
                sourceRecordIDs: [record.id],
                sourceArtifactIDs: artifacts.map(\.id),
                sourceEntityIDs: graphUpdate.resolvedEntityIDs,
                createdAt: Date.now,
                savedAt: nil,
                dismissedAt: nil
            )
            try upsertReflection(reflection)
        }

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