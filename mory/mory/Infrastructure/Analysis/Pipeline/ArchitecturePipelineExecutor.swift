import Foundation
import SwiftData

extension Notification.Name {
    static let pipelineDidComplete = Notification.Name("mory.pipelineDidComplete")
}

struct V7ProductionParameters {
    var cloudIntelligenceService: any CloudIntelligenceServing
    var contextPackBuilder: ContextPackBuilder
    var upsertAffectSnapshot: (AffectSnapshot) throws -> Void
    var upsertGraphDelta: (GraphDelta) throws -> Void
    var upsertReflection: (ReflectionSnapshot) throws -> Void
    var upsertClarificationQuestion: (ClarificationQuestion) throws -> Void
    var upsertTemporalArc: (TemporalArc) throws -> Void
    var setDebugTrace: @MainActor (DebugPipelineTraceSnapshot?) -> Void
    var save: () throws -> Void
}

struct ArchitecturePipelineExecutor {
    private let graphUpdater = GraphUpdater()
    private let placeProfileResolver = PlaceProfileResolver()
    private let candidateBuilder = TemporalArcCandidateBuilder()
    private let temporalArcService = TemporalArcService()
    private let arcQualityPolicy = ArcQualityPolicy()

    func run(
        record: RecordShell,
        artifacts: [Artifact],
        modelContext: ModelContext,
        v7: V7ProductionParameters,
        upsertRecordAnalysis: @escaping (RecordAnalysisSnapshot) throws -> Void,
        upsertPlaceProfile: @escaping (PlaceProfile) throws -> Void,
        upsertEntityNode: @escaping (EntityNode) throws -> Void,
        upsertEntityEdge: @escaping (EntityEdge) throws -> Void,
        upsertArtifactEntityLink: @escaping (ArtifactEntityLink) throws -> Void,
        upsertTemporalArc: @escaping (TemporalArc) throws -> Void,
        upsertReflection: @escaping (ReflectionSnapshot) throws -> Void,
        save: @escaping () throws -> Void
    ) async throws {
        // Step 1: Fetch known entities for compact compatibility context.
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

        // Step 2: Build a bounded v7 context pack and send the production Analyze v7 request.
        let contextPack = try await v7.contextPackBuilder.build(targetRecordID: record.id)
        let affectSnapshots = (try? v7.contextPackBuilder.repository.fetchAffectSnapshots(recordID: record.id, limit: 10)) ?? []
        let payload = AnalyzeV7RequestBuilder().build(
            record: record,
            artifacts: artifacts,
            knownEntities: Array(knownEntities),
            contextPack: contextPack,
            affectSnapshots: affectSnapshots
        )
        let requestBody = String(data: (try? JSONEncoder().encode(payload)) ?? Data(), encoding: .utf8)
        let envelope: AnalyzeV7ResponseEnvelope
        do {
            envelope = try await v7.cloudIntelligenceService.analyzeV7(payload)
            let responseBody = String(data: (try? JSONEncoder().encode(envelope)) ?? Data(), encoding: .utf8)
            let requestID: String?
            if let debugging = v7.cloudIntelligenceService as? any CloudIntelligenceDebugging {
                requestID = await debugging.latestCloudDebugRequestID()
            } else {
                requestID = payload.clientRequestID
            }
            v7.setDebugTrace(
                DebugPipelineTraceSnapshot(
                    requestID: requestID,
                    requestBody: requestBody,
                    responseBody: responseBody,
                    rawErrorBody: nil,
                    statusCode: 200,
                    failedStage: nil
                )
            )
        } catch {
            let debugError: MoryAPIClient.DebugErrorSnapshot?
            let requestID: String?
            if let debugging = v7.cloudIntelligenceService as? any CloudIntelligenceDebugging {
                debugError = await debugging.latestCloudDebugError()
                requestID = await debugging.latestCloudDebugRequestID()
            } else {
                debugError = nil
                requestID = payload.clientRequestID
            }
            v7.setDebugTrace(
                DebugPipelineTraceSnapshot(
                    requestID: debugError?.requestID ?? requestID,
                    requestBody: requestBody,
                    responseBody: debugError?.responseBody,
                    rawErrorBody: debugError?.rawErrorBody,
                    statusCode: debugError?.statusCode,
                    failedStage: debugError?.failedStage ?? "analysis_v7"
                )
            )
            throw error
        }
        let mapped = AnalyzeV7ResponseMapper().map(
            recordID: record.id,
            response: envelope,
            createdAt: Date.now
        )
        let analysis = mapped.analysis

        // Step 3: Persist the record analysis snapshot
        try upsertRecordAnalysis(analysis)
        try save()

        // Step 4: Compute entity graph updates after analysis and before reflection.
        let graphUpdate = graphUpdater.apply(
            analysis: analysis,
            linkedArtifactIDs: record.artifactIDs,
            linkedRecordIDs: [record.id],
            existingEntityNodes: existingEntityNodes,
            existingEntityEdges: try fetchExistingEntityEdges(modelContext: modelContext, recordScope: activeRecordScope),
            existingArtifactEntityLinks: try fetchExistingArtifactEntityLinks(modelContext: modelContext, recordScope: activeRecordScope)
        )
        let placeResolution = placeProfileResolver.resolve(
            locationArtifacts: artifacts.filter { $0.kind == .location },
            recordID: record.id,
            existingProfiles: try fetchExistingPlaceProfiles(modelContext: modelContext, recordScope: activeRecordScope),
            existingEntityNodes: graphUpdate.entityNodes,
            existingArtifactEntityLinks: graphUpdate.artifactEntityLinks,
            timestamp: analysis.createdAt
        )
        // Step 5: Persist graph updates
        for profile in placeResolution.profiles {
            try upsertPlaceProfile(profile)
        }
        for node in placeResolution.entityNodes {
            try upsertEntityNode(node)
        }
        for edge in graphUpdate.entityEdges {
            try upsertEntityEdge(edge)
        }
        for link in placeResolution.artifactEntityLinks {
            try upsertArtifactEntityLink(link)
        }
        try save()

        // Step 6: Persist Analyze v7 proposals. Graph deltas remain staged unless
        // explicitly applied by local policy/debug tooling.
        for snapshot in mapped.affectProposals {
            try v7.upsertAffectSnapshot(snapshot)
        }
        for delta in mapped.graphDeltaProposals {
            try v7.upsertGraphDelta(delta)
        }
        for arc in mapped.arcProposals {
            try v7.upsertTemporalArc(arc)
        }
        for reflection in mapped.reflectionProposals {
            try v7.upsertReflection(reflection)
        }
        for question in mapped.questionProposals + mapped.mergeSplitQuestions {
            try v7.upsertClarificationQuestion(question)
        }
        try v7.save()

        // Step 7: Build deterministic local TemporalArcCandidates from the v7 analysis.
        let candidateRecords = try fetchExistingRecordShells(modelContext: modelContext, recordScope: activeRecordScope)
        let candidateAnalyses = try fetchExistingAnalyses(modelContext: modelContext, replacingWith: analysis, recordScope: activeRecordScope)
        let candidateArtifacts = try fetchExistingArtifacts(modelContext: modelContext, recordScope: activeRecordScope)
        let existingArcs = try fetchExistingTemporalArcs(modelContext: modelContext, recordScope: activeRecordScope)
        let candidates = candidateBuilder.buildCandidates(
            records: candidateRecords,
            analyses: candidateAnalyses,
            artifacts: candidateArtifacts,
            artifactEntityLinks: placeResolution.artifactEntityLinks,
            entityNodes: placeResolution.entityNodes,
            focusRecordID: record.id,
            maxCandidates: 3
        )

        // Step 8: Accept local candidate arcs via promoter.
        for candidate in candidates {
            guard candidate.recordIDs.contains(record.id) else { continue }
            guard arcQualityPolicy.evaluate(candidate).passed else { continue }
            guard !hasExistingArc(for: candidate, existingArcs: existingArcs) else { continue }
            let promotionResult = temporalArcService.promote(
                candidate: candidate,
                analyses: candidateAnalyses,
                artifactEntityLinks: placeResolution.artifactEntityLinks,
                entityNodes: placeResolution.entityNodes
            )
            try upsertTemporalArc(promotionResult.arc)
            try upsertReflection(promotionResult.reflection)
        }
        try save()

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

    private func fetchExistingPlaceProfiles(modelContext: ModelContext, recordScope: Set<UUID>?) throws -> [PlaceProfile] {
        let stores = try modelContext.fetch(FetchDescriptor<PlaceProfileStore>())
        let profiles = stores.map(\.domainModel)
        guard let recordScope else { return profiles }
        return profiles.filter { profile in
            !profile.sourceRecordIDs.isEmpty && profile.sourceRecordIDs.contains { recordScope.contains($0) }
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
