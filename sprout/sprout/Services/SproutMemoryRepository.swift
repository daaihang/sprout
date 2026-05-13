import Foundation
import Observation

@Observable
@MainActor
final class SproutMemoryRepository {
    struct EntityMemoryView: Sendable {
        var entity: EntityNode
        var relatedEntities: [EntityNode]
        var relatedRecords: [RecordShell]
        var relatedArtifacts: [Artifact]
        var supportingEdges: [EntityEdge]
    }

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
        var temporalArcs: [TemporalArc]

        enum CodingKeys: String, CodingKey {
            case recordShells
            case artifacts
            case analyses
            case entityNodes
            case entityEdges
            case artifactEntityLinks
            case temporalArcs
        }

        init(
            recordShells: [RecordShell],
            artifacts: [Artifact],
            analyses: [RecordAnalysisSnapshot],
            entityNodes: [EntityNode],
            entityEdges: [EntityEdge],
            artifactEntityLinks: [ArtifactEntityLink],
            temporalArcs: [TemporalArc]
        ) {
            self.recordShells = recordShells
            self.artifacts = artifacts
            self.analyses = analyses
            self.entityNodes = entityNodes
            self.entityEdges = entityEdges
            self.artifactEntityLinks = artifactEntityLinks
            self.temporalArcs = temporalArcs
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            recordShells = try container.decode([RecordShell].self, forKey: .recordShells)
            artifacts = try container.decode([Artifact].self, forKey: .artifacts)
            analyses = try container.decode([RecordAnalysisSnapshot].self, forKey: .analyses)
            entityNodes = try container.decode([EntityNode].self, forKey: .entityNodes)
            entityEdges = try container.decode([EntityEdge].self, forKey: .entityEdges)
            artifactEntityLinks = try container.decode([ArtifactEntityLink].self, forKey: .artifactEntityLinks)
            temporalArcs = try container.decodeIfPresent([TemporalArc].self, forKey: .temporalArcs) ?? []
        }
    }

    private let graphUpdater = GraphUpdater()
    private let temporalArcService = SproutTemporalArcService()

    var recordShells: [RecordShell] = []
    var artifacts: [Artifact] = []
    var analyses: [RecordAnalysisSnapshot] = []
    var entityNodes: [EntityNode] = []
    var entityEdges: [EntityEdge] = []
    var artifactEntityLinks: [ArtifactEntityLink] = []
    var temporalArcs: [TemporalArc] = []

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
        rebuildTemporalArcs()
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

    func entityNode(for entityID: UUID) -> EntityNode? {
        entityNodes.first { $0.id == entityID }
    }

    func featuredTemporalArc(for referenceDate: Date, toleranceDays: Int = 6) -> TemporalArc? {
        let accepted = temporalArcs.filter { $0.status == .accepted }
        let active = accepted.filter { $0.startDate <= referenceDate && $0.endDate >= referenceDate }
        if let current = active.sorted(by: temporalArcSort).first {
            return current
        }

        let tolerance = TimeInterval(60 * 60 * 24 * toleranceDays)
        let nearby = accepted
            .filter {
                abs($0.startDate.timeIntervalSince(referenceDate)) <= tolerance
                    || abs($0.endDate.timeIntervalSince(referenceDate)) <= tolerance
            }
            .sorted(by: temporalArcSort)
        return nearby.first
    }

    func temporalArc(for arcID: UUID) -> TemporalArc? {
        temporalArcs.first { $0.id == arcID }
    }

    func archiveTemporalArc(_ arcID: UUID) {
        guard let index = temporalArcs.firstIndex(where: { $0.id == arcID }) else { return }
        temporalArcs[index].status = .archived
        temporalArcs[index].updatedAt = .now
        save()
    }

    func entityView(for entityID: UUID) -> EntityMemoryView? {
        guard let entity = entityNode(for: entityID) else { return nil }

        let supportingEdges = entityEdges.filter {
            $0.fromEntityID == entityID || $0.toEntityID == entityID
        }

        let relatedEntityIDs = Set(
            supportingEdges.map {
                $0.fromEntityID == entityID ? $0.toEntityID : $0.fromEntityID
            }
        )
        let relatedEntities = entityNodes
            .filter { relatedEntityIDs.contains($0.id) }
            .sorted {
                if $0.kind == $1.kind {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return $0.kind.rawValue < $1.kind.rawValue
            }

        let relatedArtifactIDs = Set(
            artifactEntityLinks
                .filter { $0.entityID == entityID }
                .map(\.artifactID)
        )
        let relatedArtifacts = artifacts
            .filter { relatedArtifactIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }

        let relatedRecordIDs = Set(
            supportingEdges
                .flatMap(\.sourceRecordIDs)
        )
        let relatedRecords = recordShells
            .filter { relatedRecordIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }

        return EntityMemoryView(
            entity: entity,
            relatedEntities: relatedEntities,
            relatedRecords: relatedRecords,
            relatedArtifacts: relatedArtifacts,
            supportingEdges: supportingEdges.sorted { $0.lastSeenAt > $1.lastSeenAt }
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
        temporalArcs = snapshot.temporalArcs
        if temporalArcs.isEmpty && !analyses.isEmpty {
            rebuildTemporalArcs()
        }
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
            artifactEntityLinks: artifactEntityLinks,
            temporalArcs: temporalArcs
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func rebuildTemporalArcs() {
        temporalArcs = temporalArcService.rebuildAcceptedArcs(
            records: recordShells,
            analyses: analyses,
            artifacts: artifacts,
            artifactEntityLinks: artifactEntityLinks,
            entityNodes: entityNodes
        )
    }

    private func temporalArcSort(lhs: TemporalArc, rhs: TemporalArc) -> Bool {
        if lhs.endDate == rhs.endDate {
            return lhs.intensityScore > rhs.intensityScore
        }
        return lhs.endDate > rhs.endDate
    }
}
