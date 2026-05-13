import Foundation
import Observation

@Observable
@MainActor
final class SproutMemoryRepository {
    struct RecordMemoryView: Sendable {
        var recordShell: RecordShell
        var artifacts: [Artifact]
        var analysis: RecordAnalysisSnapshot?
        var linkedEntities: [EntityNode]
    }

    struct Snapshot: Codable, Sendable {
        var recordShells: [RecordShell]
        var artifacts: [Artifact]
        var analyses: [RecordAnalysisSnapshot]
        var entityNodes: [EntityNode]
        var entityEdges: [EntityEdge]
        var artifactEntityLinks: [ArtifactEntityLink]
    }

    private let graphUpdater = GraphUpdater()

    var recordShells: [RecordShell] = []
    var artifacts: [Artifact] = []
    var analyses: [RecordAnalysisSnapshot] = []
    var entityNodes: [EntityNode] = []
    var entityEdges: [EntityEdge] = []
    var artifactEntityLinks: [ArtifactEntityLink] = []

    init() {
        load()
    }

    func upsertAggregate(_ aggregate: SproutMemoryAggregate) {
        recordShells.removeAll { $0.id == aggregate.recordShell.id }
        recordShells.append(aggregate.recordShell)

        let aggregateArtifactIDs = Set(aggregate.artifacts.map(\.id))
        artifacts.removeAll { aggregateArtifactIDs.contains($0.id) }
        artifacts.append(contentsOf: aggregate.artifacts)

        save()
    }

    func setAnalysis(_ analysis: RecordAnalysisSnapshot, aggregate: SproutMemoryAggregate) {
        upsertAggregate(aggregate)
        analyses.removeAll { $0.recordID == analysis.recordID }
        analyses.append(analysis)

        let graphResult = graphUpdater.apply(
            analysis: analysis,
            linkedArtifactIDs: aggregate.artifacts.map(\.id),
            linkedRecordIDs: [aggregate.recordShell.id],
            existingEntityNodes: entityNodes,
            existingEntityEdges: entityEdges,
            existingArtifactEntityLinks: artifactEntityLinks
        )

        entityNodes = graphResult.entityNodes
        entityEdges = graphResult.entityEdges
        artifactEntityLinks = graphResult.artifactEntityLinks
        save()
    }

    func recordShell(for recordID: UUID) -> RecordShell? {
        recordShells.first { $0.id == recordID }
    }

    func analysis(for recordID: UUID) -> RecordAnalysisSnapshot? {
        analyses.first { $0.recordID == recordID }
    }

    func artifacts(forRecordID recordID: UUID) -> [Artifact] {
        guard let shell = recordShell(for: recordID) else { return [] }
        let artifactIDs = Set(shell.artifactIDs)
        return artifacts
            .filter { artifactIDs.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func linkedEntities(forRecordID recordID: UUID) -> [EntityNode] {
        let artifactIDs = Set(artifacts(forRecordID: recordID).map(\.id))
        let entityIDs = Set(
            artifactEntityLinks
                .filter { artifactIDs.contains($0.artifactID) }
                .map(\.entityID)
        )
        return entityNodes
            .filter { entityIDs.contains($0.id) }
            .sorted {
                if $0.kind == $1.kind {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return $0.kind.rawValue < $1.kind.rawValue
            }
    }

    func memoryView(for recordID: UUID) -> RecordMemoryView? {
        guard let shell = recordShell(for: recordID) else { return nil }
        return RecordMemoryView(
            recordShell: shell,
            artifacts: artifacts(forRecordID: recordID),
            analysis: analysis(for: recordID),
            linkedEntities: linkedEntities(forRecordID: recordID)
        )
    }

    private func storageURL() -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("SproutMemory", isDirectory: true)
            .appendingPathComponent("memory_snapshot.json")
    }

    private func load() {
        guard let url = storageURL() else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        recordShells = snapshot.recordShells
        artifacts = snapshot.artifacts
        analyses = snapshot.analyses
        entityNodes = snapshot.entityNodes
        entityEdges = snapshot.entityEdges
        artifactEntityLinks = snapshot.artifactEntityLinks
    }

    private func save() {
        guard let url = storageURL() else { return }
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let snapshot = Snapshot(
            recordShells: recordShells,
            artifacts: artifacts,
            analyses: analyses,
            entityNodes: entityNodes,
            entityEdges: entityEdges,
            artifactEntityLinks: artifactEntityLinks
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
