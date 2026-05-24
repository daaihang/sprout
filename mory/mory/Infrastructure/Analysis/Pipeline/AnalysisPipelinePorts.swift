import Foundation

struct AnalysisPipelinePreAnalysisContext: Sendable {
    var entityNodes: [EntityNode]
    var entityEdges: [EntityEdge]
    var artifactEntityLinks: [ArtifactEntityLink]
    var placeProfiles: [PlaceProfile]

    init(
        entityNodes: [EntityNode] = [],
        entityEdges: [EntityEdge] = [],
        artifactEntityLinks: [ArtifactEntityLink] = [],
        placeProfiles: [PlaceProfile] = []
    ) {
        self.entityNodes = entityNodes
        self.entityEdges = entityEdges
        self.artifactEntityLinks = artifactEntityLinks
        self.placeProfiles = placeProfiles
    }
}

struct AnalysisPipelinePostAnalysisContext: Sendable {
    var records: [RecordShell]
    var analyses: [RecordAnalysisSnapshot]
    var artifacts: [Artifact]
    var temporalArcs: [TemporalArc]

    init(
        records: [RecordShell] = [],
        analyses: [RecordAnalysisSnapshot] = [],
        artifacts: [Artifact] = [],
        temporalArcs: [TemporalArc] = []
    ) {
        self.records = records
        self.analyses = analyses
        self.artifacts = artifacts
        self.temporalArcs = temporalArcs
    }
}

@MainActor
protocol AnalysisPipelineQuerying {
    func loadPreAnalysisContext(recordScope: Set<UUID>?) throws -> AnalysisPipelinePreAnalysisContext
    func loadPostAnalysisContext(
        replacingWith analysis: RecordAnalysisSnapshot,
        recordScope: Set<UUID>?
    ) throws -> AnalysisPipelinePostAnalysisContext
}

@MainActor
protocol AnalysisPipelinePersisting {
    func persistRecordAnalysis(_ analysis: RecordAnalysisSnapshot) throws
    func persistPlaceProfile(_ profile: PlaceProfile) throws
    func persistEntityNode(_ entityNode: EntityNode) throws
    func persistEntityEdge(_ entityEdge: EntityEdge) throws
    func persistArtifactEntityLink(_ artifactEntityLink: ArtifactEntityLink) throws
    func persistTemporalArc(_ temporalArc: TemporalArc) throws
    func persistReflection(_ reflection: ReflectionSnapshot) throws
    func persistAffectSnapshot(_ snapshot: AffectSnapshot) throws
    func persistGraphDelta(_ delta: GraphDelta) throws
    func persistClarificationQuestion(_ question: ClarificationQuestion) throws
    func saveAnalysisPipelineChanges() throws
}

@MainActor
protocol AnalysisPipelineTracing {
    func setDebugTrace(_ trace: DebugPipelineTraceSnapshot?)
}

@MainActor
protocol AnalysisPipelineRuntimeScoping {
    var activeRecordScope: Set<UUID>? { get }
}

@MainActor
protocol AnalysisPipelineContextPacking {
    func buildContextPack(targetRecordID: UUID) async throws -> AnalysisContextPack
    func fetchAffectSnapshots(recordID: UUID, limit: Int?) throws -> [AffectSnapshot]
}

@MainActor
struct QualityTuningAnalysisPipelineRuntimeScope: AnalysisPipelineRuntimeScoping {
    var activeRecordScope: Set<UUID>? {
        QualityTuningRuntime.activeRecordScope
    }
}

@MainActor
struct AnalysisPipelineDependencies {
    var cloudIntelligenceService: any CloudIntelligenceServing
    var contextProvider: any AnalysisPipelineContextPacking
    var query: any AnalysisPipelineQuerying
    var persist: any AnalysisPipelinePersisting
    var tracing: any AnalysisPipelineTracing
    var runtimeScope: any AnalysisPipelineRuntimeScoping
}

extension ContextPackBuilder: AnalysisPipelineContextPacking {
    func buildContextPack(targetRecordID: UUID) async throws -> AnalysisContextPack {
        try await build(targetRecordID: targetRecordID)
    }

    func fetchAffectSnapshots(recordID: UUID, limit: Int?) throws -> [AffectSnapshot] {
        try repository.fetchAffectSnapshots(recordID: recordID, limit: limit)
    }
}
