import Foundation

struct PrototypeWorkspaceRepository {
    static func loadDefaultSnapshot() -> DemoWorkspaceSnapshot {
        if let persisted = try? PrototypeLocalPersistence.load() {
            return persisted
        }
        let scenario = DemoScenarios.relationshipArc()
        return DemoWorkspaceSnapshot(
            scenarioName: scenario.name,
            boards: scenario.boards,
            compositions: scenario.compositions,
            items: scenario.items,
            records: scenario.records,
            artifacts: scenario.artifacts,
            reflections: scenario.reflections,
            temporalArcs: scenario.temporalArcs,
            analyses: scenario.analyses,
            entityNodes: scenario.entityNodes,
            entityEdges: scenario.entityEdges,
            artifactEntityLinks: scenario.artifactEntityLinks
        )
    }

    static func snapshot(from scenario: DemoScenario) -> DemoWorkspaceSnapshot {
        DemoWorkspaceSnapshot(
            scenarioName: scenario.name,
            boards: scenario.boards,
            compositions: scenario.compositions,
            items: scenario.items,
            records: scenario.records,
            artifacts: scenario.artifacts,
            reflections: scenario.reflections,
            temporalArcs: scenario.temporalArcs,
            analyses: scenario.analyses,
            entityNodes: scenario.entityNodes,
            entityEdges: scenario.entityEdges,
            artifactEntityLinks: scenario.artifactEntityLinks
        )
    }
}
