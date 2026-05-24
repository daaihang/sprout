import Foundation
import SwiftData

extension MoryMemoryRepository: AnalysisPipelineQuerying, AnalysisPipelinePersisting, AnalysisPipelineTracing {
    func loadPreAnalysisContext(recordScope: Set<UUID>?) throws -> AnalysisPipelinePreAnalysisContext {
        AnalysisPipelinePreAnalysisContext(
            entityNodes: try fetchExistingEntityNodes(recordScope: recordScope),
            entityEdges: try fetchExistingEntityEdges(recordScope: recordScope),
            artifactEntityLinks: try fetchExistingArtifactEntityLinks(recordScope: recordScope),
            placeProfiles: try fetchExistingPlaceProfiles(recordScope: recordScope)
        )
    }

    func loadPostAnalysisContext(
        replacingWith analysis: RecordAnalysisSnapshot,
        recordScope: Set<UUID>?
    ) throws -> AnalysisPipelinePostAnalysisContext {
        AnalysisPipelinePostAnalysisContext(
            records: try fetchExistingRecordShells(recordScope: recordScope),
            analyses: try fetchExistingAnalyses(replacingWith: analysis, recordScope: recordScope),
            artifacts: try fetchExistingArtifacts(recordScope: recordScope),
            temporalArcs: try fetchExistingTemporalArcs(recordScope: recordScope)
        )
    }

    func persistRecordAnalysis(_ analysis: RecordAnalysisSnapshot) throws {
        try upsert(recordAnalysis: analysis)
    }

    func persistPlaceProfile(_ profile: PlaceProfile) throws {
        try upsert(placeProfile: profile)
    }

    func persistEntityNode(_ entityNode: EntityNode) throws {
        try upsert(entityNode: entityNode)
    }

    func persistEntityEdge(_ entityEdge: EntityEdge) throws {
        try upsert(entityEdge: entityEdge)
    }

    func persistArtifactEntityLink(_ artifactEntityLink: ArtifactEntityLink) throws {
        try upsert(artifactEntityLink: artifactEntityLink)
    }

    func persistTemporalArc(_ temporalArc: TemporalArc) throws {
        try upsert(temporalArc: temporalArc)
    }

    func persistReflection(_ reflection: ReflectionSnapshot) throws {
        try upsert(reflection: reflection)
    }

    func persistAffectSnapshot(_ snapshot: AffectSnapshot) throws {
        try upsert(affectSnapshot: snapshot)
    }

    func persistGraphDelta(_ delta: GraphDelta) throws {
        try upsert(graphDelta: delta)
    }

    func persistClarificationQuestion(_ question: ClarificationQuestion) throws {
        try upsert(clarificationQuestion: question)
    }

    func saveAnalysisPipelineChanges() throws {
        try save()
    }

    func setDebugTrace(_ trace: DebugPipelineTraceSnapshot?) {
        latestAnalysisTrace = trace
    }

    private func fetchExistingRecordShells(recordScope: Set<UUID>?) throws -> [RecordShell] {
        let records = try modelContext.fetch(FetchDescriptor<RecordShellStore>()).map(\.domainModel)
        guard let recordScope else { return records }
        return records.filter { recordScope.contains($0.id) }
    }

    private func fetchExistingAnalyses(
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

    private func fetchExistingArtifacts(recordScope: Set<UUID>?) throws -> [Artifact] {
        let artifacts = try modelContext.fetch(FetchDescriptor<ArtifactStore>()).map(\.domainModel)
        guard let recordScope else { return artifacts }
        return artifacts.filter { recordScope.contains($0.recordID) }
    }

    private func fetchExistingTemporalArcs(recordScope: Set<UUID>?) throws -> [TemporalArc] {
        let arcs = try modelContext.fetch(FetchDescriptor<TemporalArcStore>()).map(\.domainModel)
        guard let recordScope else { return arcs }
        return arcs.filter { !$0.sourceRecordIDs.isEmpty && $0.sourceRecordIDs.allSatisfy { recordScope.contains($0) } }
    }

    private func fetchExistingEntityNodes(recordScope: Set<UUID>?) throws -> [EntityNode] {
        let stores = try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
        let nodes = stores.map(\.domainModel)
        guard let recordScope else { return nodes }
        return nodes.filter { node in
            !node.provenanceRecordIDs.isEmpty && node.provenanceRecordIDs.contains { recordScope.contains($0) }
        }
    }

    private func fetchExistingPlaceProfiles(recordScope: Set<UUID>?) throws -> [PlaceProfile] {
        let stores = try modelContext.fetch(FetchDescriptor<PlaceProfileStore>())
        let profiles = stores.map(\.domainModel)
        guard let recordScope else { return profiles }
        return profiles.filter { profile in
            !profile.sourceRecordIDs.isEmpty && profile.sourceRecordIDs.contains { recordScope.contains($0) }
        }
    }

    private func fetchExistingEntityEdges(recordScope: Set<UUID>?) throws -> [EntityEdge] {
        let stores = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>())
        let edges = stores.map(\.domainModel)
        guard let recordScope else { return edges }
        return edges.filter { edge in
            !edge.sourceRecordIDs.isEmpty && edge.sourceRecordIDs.contains { recordScope.contains($0) }
        }
    }

    private func fetchExistingArtifactEntityLinks(recordScope: Set<UUID>?) throws -> [ArtifactEntityLink] {
        let stores = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        let links = stores.map(\.domainModel)
        guard let recordScope else { return links }
        return links.filter { link in
            link.sourceRecordID.map { recordScope.contains($0) } ?? false
        }
    }
}
