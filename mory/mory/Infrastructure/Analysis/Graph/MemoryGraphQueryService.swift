import Foundation
import SwiftData

struct MemoryGraphQueryService {
    func load(
        modelContext: ModelContext,
        memories: [MemorySummary],
        entityKinds: [EntityKind]? = nil,
        recordIDs: Set<UUID>? = nil
    ) throws -> MemoryGraphContext {
        let recordIDSet = Set(memories.map(\.record.id))
        let visibleRecordIDs = recordIDs ?? recordIDSet
        let existingRecordIDs = Set(
            try modelContext.fetch(FetchDescriptor<RecordShellStore>()).map(\.id)
        )

        let links = try fetchLinks(modelContext: modelContext, recordIDs: visibleRecordIDs)
        let entityIDs = Set(links.map(\.entityID))

        let entities = try fetchEntities(modelContext: modelContext, entityIDs: entityIDs, entityKinds: entityKinds)
        let edges = try fetchEdges(
            modelContext: modelContext,
            entityIDs: entityIDs,
            visibleRecordIDs: visibleRecordIDs,
            existingRecordIDs: existingRecordIDs
        )
        let arcs = try fetchArcs(
            modelContext: modelContext,
            visibleRecordIDs: visibleRecordIDs,
            existingRecordIDs: existingRecordIDs
        )
        let reflections = try fetchReflections(
            modelContext: modelContext,
            visibleRecordIDs: visibleRecordIDs,
            existingRecordIDs: existingRecordIDs,
            arcIDs: Set(arcs.map(\.id))
        )

        let memoriesByRecordID = Dictionary(uniqueKeysWithValues: memories.map { ($0.record.id, $0) })

        return MemoryGraphContext(
            links: links,
            entities: entities,
            edges: edges,
            arcs: arcs,
            reflections: reflections,
            memoriesByRecordID: memoriesByRecordID
        )
    }

    private func fetchLinks(modelContext: ModelContext, recordIDs: Set<UUID>) throws -> [ArtifactEntityLink] {
        let linkStores = try modelContext.fetch(
            FetchDescriptor<ArtifactEntityLinkStore>()
        ).map(\.domainModel)

        return linkStores.filter { link in
            link.sourceRecordID.map { recordIDs.contains($0) } ?? false
        }
    }

    private func fetchEntities(
        modelContext: ModelContext,
        entityIDs: Set<UUID>,
        entityKinds: [EntityKind]?
    ) throws -> [EntityNode] {
        let allStores = try modelContext.fetch(
            FetchDescriptor<EntityNodeStore>()
        ).map(\.domainModel)

        return allStores.filter { entity in
            guard entityIDs.contains(entity.id) else { return false }
            if let kinds = entityKinds {
                return kinds.contains(entity.kind)
            }
            return true
        }
    }

    private func fetchEdges(
        modelContext: ModelContext,
        entityIDs: Set<UUID>,
        visibleRecordIDs: Set<UUID>,
        existingRecordIDs: Set<UUID>
    ) throws -> [EntityEdge] {
        let allStores = try modelContext.fetch(
            FetchDescriptor<EntityEdgeStore>()
        ).map(\.domainModel)

        return allStores.filter { edge in
            guard edge.sourceRecordIDs.allSatisfy({ existingRecordIDs.contains($0) }) else {
                return false
            }
            let connectsToTargetEntity = entityIDs.contains(edge.fromEntityID) || entityIDs.contains(edge.toEntityID)
            let hasSourceRecord = edge.sourceRecordIDs.contains(where: { visibleRecordIDs.contains($0) })
            return connectsToTargetEntity || hasSourceRecord
        }
    }

    private func fetchArcs(
        modelContext: ModelContext,
        visibleRecordIDs: Set<UUID>,
        existingRecordIDs: Set<UUID>
    ) throws -> [TemporalArc] {
        let allStores = try modelContext.fetch(
            FetchDescriptor<TemporalArcStore>()
        ).map(\.domainModel)

        return allStores.filter { arc in
            !arc.sourceRecordIDs.isEmpty
                && arc.sourceRecordIDs.allSatisfy { existingRecordIDs.contains($0) }
                && arc.sourceRecordIDs.contains { visibleRecordIDs.contains($0) }
        }
    }

    private func fetchReflections(
        modelContext: ModelContext,
        visibleRecordIDs: Set<UUID>,
        existingRecordIDs: Set<UUID>,
        arcIDs: Set<UUID>
    ) throws -> [ReflectionSnapshot] {
        let allStores = try modelContext.fetch(
            FetchDescriptor<ReflectionSnapshotStore>()
        ).map(\.domainModel)

        return allStores.filter { reflection in
            let hasValidSourceRecords = !reflection.sourceRecordIDs.isEmpty
                && reflection.sourceRecordIDs.allSatisfy { existingRecordIDs.contains($0) }
                && reflection.sourceRecordIDs.contains { visibleRecordIDs.contains($0) }
            let linkedToArc = reflection.linkedTemporalArcID.map { arcIDs.contains($0) } ?? false
            return hasValidSourceRecords || linkedToArc
        }
    }
}

struct MemoryGraphContext {
    let links: [ArtifactEntityLink]
    let entities: [EntityNode]
    let edges: [EntityEdge]
    let arcs: [TemporalArc]
    let reflections: [ReflectionSnapshot]
    private let memoriesByRecordID: [UUID: MemorySummary]

    init(
        links: [ArtifactEntityLink],
        entities: [EntityNode],
        edges: [EntityEdge],
        arcs: [TemporalArc],
        reflections: [ReflectionSnapshot],
        memoriesByRecordID: [UUID: MemorySummary]
    ) {
        self.links = links
        self.entities = entities
        self.edges = edges
        self.arcs = arcs
        self.reflections = reflections
        self.memoriesByRecordID = memoriesByRecordID
    }

    func relatedMemories(recordIDs: [UUID], limit: Int) -> [MemorySummary] {
        let matched = recordIDs.compactMap { memoriesByRecordID[$0] }
        let unique = Array(NSOrderedSet(array: matched)) as? [MemorySummary] ?? matched
        return Array(unique.sorted { $0.record.updatedAt > $1.record.updatedAt }.prefix(limit))
    }

    func mergeUniqueIDs(_ first: [UUID], _ second: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        var result: [UUID] = []
        for id in first + second {
            if !seen.contains(id) {
                seen.insert(id)
                result.append(id)
            }
        }
        return result
    }

    func makeEntityDetailSnapshot(entity: EntityNode) -> EntityDetailSnapshot {
        let artifactLinks = links.filter { $0.entityID == entity.id }
        let linkedArtifactIDs = Set(artifactLinks.map(\.artifactID))

        let entityEdges = edges.filter { $0.fromEntityID == entity.id || $0.toEntityID == entity.id }

        let entityArcs = arcs.filter { $0.sourceEntityIDs.contains(entity.id) }
        let arcSummaries = entityArcs.map { arc in
            TemporalArcSummarySnapshot(
                arc: arc,
                relatedMemories: relatedMemories(recordIDs: arc.sourceRecordIDs, limit: 3),
                linkedReflection: reflections.first { $0.linkedTemporalArcID == arc.id }
            )
        }

        let entityReflections = reflections.filter { $0.sourceEntityIDs.contains(entity.id) }
        let reflectionSummaries = entityReflections.map { reflection in
            let linkedArc = reflection.linkedTemporalArcID.flatMap { arcID in
                arcs.first { $0.id == arcID }
            }
            let relatedRecordIDs = linkedArc.map { mergeUniqueIDs(reflection.sourceRecordIDs, $0.sourceRecordIDs) } ?? reflection.sourceRecordIDs
            return ReflectionSummarySnapshot(
                reflection: reflection,
                linkedArc: linkedArc,
                relatedMemories: relatedMemories(recordIDs: relatedRecordIDs, limit: 3)
            )
        }

        let relatedEntityIDs = entityEdges.flatMap { edge -> [UUID] in
            if edge.fromEntityID == entity.id {
                return [edge.toEntityID]
            } else if edge.toEntityID == entity.id {
                return [edge.fromEntityID]
            }
            return []
        }
        let uniqueRelatedEntityIDs = Array(Set(relatedEntityIDs))
        let relatedEntityNames = uniqueRelatedEntityIDs.compactMap { id in
            entities.first { $0.id == id }?.displayName
        }

        let personEntities = entities.filter { $0.kind == .person }
        let relatedPeople = relatedEntityNames.filter { name in
            personEntities.contains { $0.displayName == name }
        }

        let themeEntities = entities.filter { $0.kind == .theme }
        let relatedThemes = relatedEntityNames.filter { name in
            themeEntities.contains { $0.displayName == name }
        }

        let artifactRecordIDs = artifactLinks.flatMap { link -> [UUID] in
            [link.sourceRecordID, link.sourceAnalysisRecordID].compactMap { $0 }
        }
        let arcRecordIDs = entityArcs.flatMap(\.sourceRecordIDs)
        let reflectionRecordIDs = entityReflections.flatMap { reflection -> [UUID] in
            let linkedArcRecordIDs = reflection.linkedTemporalArcID
                .flatMap { arcID in arcs.first { $0.id == arcID }?.sourceRecordIDs } ?? []
            return mergeUniqueIDs(reflection.sourceRecordIDs, linkedArcRecordIDs)
        }
        let relatedRecordIDs = mergeUniqueIDs(
            mergeUniqueIDs(entity.provenanceRecordIDs, artifactRecordIDs),
            mergeUniqueIDs(arcRecordIDs, reflectionRecordIDs)
        )
        let provenanceMemories = relatedMemories(recordIDs: relatedRecordIDs, limit: 5)

        return EntityDetailSnapshot(
            entity: entity,
            artifactCount: linkedArtifactIDs.count,
            relatedMemories: provenanceMemories,
            relatedThemes: Array(Set(relatedThemes)),
            relatedPeople: Array(Set(relatedPeople)),
            relatedReflections: reflectionSummaries,
            relatedArcs: arcSummaries,
            edges: entityEdges
        )
    }

    func makePersonSummary(entity: EntityNode) -> PersonMemorySummary {
        let detail = makeEntityDetailSnapshot(entity: entity)
        return PersonMemorySummary(
            entity: entity,
            artifactCount: detail.artifactCount,
            relatedMemories: Array(detail.relatedMemories.prefix(3)),
            themeLabels: Array(detail.relatedThemes.prefix(3)),
            reflectionCount: detail.relatedReflections.count
        )
    }

    func makeThemeSummary(entity: EntityNode) -> ThemeMemorySummary {
        let detail = makeEntityDetailSnapshot(entity: entity)
        return ThemeMemorySummary(
            entity: entity,
            artifactCount: detail.artifactCount,
            relatedMemories: Array(detail.relatedMemories.prefix(3)),
            relatedPeople: Array(detail.relatedPeople.prefix(3)),
            arcCount: detail.relatedArcs.count
        )
    }
}

enum TemporalArcStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case candidate
    case accepted
    case archived
    case merged

    var id: String { rawValue }
}

struct TemporalArc: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var summary: String
    var status: TemporalArcStatus
    var dominantTheme: String?
    var dominantEntityName: String?
    var themeLabels: [String]
    var entityNames: [String]
    var linkedReflectionID: UUID?
    var mergedFromArcIDs: [UUID]
    var mergedIntoArcID: UUID?
    var lastMergedAt: Date?
    var sourceRecordIDs: [UUID]
    var sourceArtifactIDs: [UUID]
    var sourceEntityIDs: [UUID]
    var startDate: Date
    var endDate: Date
    var intensityScore: Double
    var clusterStrength: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        status: TemporalArcStatus,
        dominantTheme: String? = nil,
        dominantEntityName: String? = nil,
        themeLabels: [String] = [],
        entityNames: [String] = [],
        linkedReflectionID: UUID? = nil,
        mergedFromArcIDs: [UUID] = [],
        mergedIntoArcID: UUID? = nil,
        lastMergedAt: Date? = nil,
        sourceRecordIDs: [UUID],
        sourceArtifactIDs: [UUID],
        sourceEntityIDs: [UUID],
        startDate: Date,
        endDate: Date,
        intensityScore: Double,
        clusterStrength: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.status = status
        self.dominantTheme = dominantTheme
        self.dominantEntityName = dominantEntityName
        self.themeLabels = themeLabels
        self.entityNames = entityNames
        self.linkedReflectionID = linkedReflectionID
        self.mergedFromArcIDs = mergedFromArcIDs
        self.mergedIntoArcID = mergedIntoArcID
        self.lastMergedAt = lastMergedAt
        self.sourceRecordIDs = sourceRecordIDs
        self.sourceArtifactIDs = sourceArtifactIDs
        self.sourceEntityIDs = sourceEntityIDs
        self.startDate = startDate
        self.endDate = endDate
        self.intensityScore = intensityScore
        self.clusterStrength = clusterStrength
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
