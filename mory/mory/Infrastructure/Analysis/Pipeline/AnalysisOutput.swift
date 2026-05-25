import Foundation

struct AnalysisGraphProjection: Sendable {
    var placeProfiles: [PlaceProfile]
    var entityNodes: [EntityNode]
    var entityEdges: [EntityEdge]
    var artifactEntityLinks: [ArtifactEntityLink]

    init(
        placeProfiles: [PlaceProfile] = [],
        entityNodes: [EntityNode] = [],
        entityEdges: [EntityEdge] = [],
        artifactEntityLinks: [ArtifactEntityLink] = []
    ) {
        self.placeProfiles = placeProfiles
        self.entityNodes = entityNodes
        self.entityEdges = entityEdges
        self.artifactEntityLinks = artifactEntityLinks
    }
}

struct AnalysisProposals: Sendable {
    var affectSnapshots: [AffectSnapshot]
    var graphDeltas: [GraphDelta]
    var temporalArcs: [TemporalArc]
    var reflections: [ReflectionSnapshot]
    var questions: [ClarificationQuestion]

    init(
        affectSnapshots: [AffectSnapshot] = [],
        graphDeltas: [GraphDelta] = [],
        temporalArcs: [TemporalArc] = [],
        reflections: [ReflectionSnapshot] = [],
        questions: [ClarificationQuestion] = []
    ) {
        self.affectSnapshots = affectSnapshots
        self.graphDeltas = graphDeltas
        self.temporalArcs = temporalArcs
        self.reflections = reflections
        self.questions = questions
    }
}

struct AnalysisFollowupPlan: Sendable {
    var jobs: [IntelligenceJob]

    init(jobs: [IntelligenceJob] = []) {
        self.jobs = jobs
    }
}

struct AnalysisOutput: Sendable {
    var recordAnalysis: RecordAnalysisSnapshot
    var graphProjection: AnalysisGraphProjection
    var proposals: AnalysisProposals
    var quality: AnalysisResponseEnvelope.Quality
    var followupPlan: AnalysisFollowupPlan

    init(
        recordAnalysis: RecordAnalysisSnapshot,
        graphProjection: AnalysisGraphProjection = AnalysisGraphProjection(),
        proposals: AnalysisProposals = AnalysisProposals(),
        quality: AnalysisResponseEnvelope.Quality = AnalysisResponseEnvelope.Quality(),
        followupPlan: AnalysisFollowupPlan = AnalysisFollowupPlan()
    ) {
        self.recordAnalysis = recordAnalysis
        self.graphProjection = graphProjection
        self.proposals = proposals
        self.quality = quality
        self.followupPlan = followupPlan
    }
}

@MainActor
struct AnalysisOutputPersister {
    func persist(_ output: AnalysisOutput, using port: any AnalysisPipelinePersisting) throws {
        try port.persistRecordAnalysis(output.recordAnalysis)
        try port.saveAnalysisPipelineChanges()

        for profile in output.graphProjection.placeProfiles {
            try port.persistPlaceProfile(profile)
        }
        for node in output.graphProjection.entityNodes {
            try port.persistEntityNode(node)
        }
        for edge in output.graphProjection.entityEdges {
            try port.persistEntityEdge(edge)
        }
        for link in output.graphProjection.artifactEntityLinks {
            try port.persistArtifactEntityLink(link)
        }
        try port.saveAnalysisPipelineChanges()

        for snapshot in output.proposals.affectSnapshots {
            try port.persistAffectSnapshot(snapshot)
        }
        for delta in output.proposals.graphDeltas {
            try port.persistGraphDelta(delta)
        }
        for arc in output.proposals.temporalArcs {
            try port.persistTemporalArc(arc)
        }
        for reflection in output.proposals.reflections {
            try port.persistReflection(reflection)
        }
        for question in output.proposals.questions {
            try port.persistClarificationQuestion(question)
        }
        try port.saveAnalysisPipelineChanges()
    }
}
