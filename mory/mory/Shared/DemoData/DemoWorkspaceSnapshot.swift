import Foundation

struct DemoWorkspaceSnapshot: Codable, Equatable, Sendable {
    var scenarioName: String
    var boards: [Board]
    var compositions: [Composition]
    var items: [CompositionItem]
    var records: [RecordShell]
    var artifacts: [Artifact]
    var reflections: [ReflectionSnapshot]
    var temporalArcs: [TemporalArc]
    var analyses: [RecordAnalysisSnapshot]
    var entityNodes: [EntityNode]
    var entityEdges: [EntityEdge]
    var artifactEntityLinks: [ArtifactEntityLink]
}
