import Foundation

struct MemorySearchService {

    func search(
        query: String,
        graphContext: MemoryGraphContext,
        memories: [MemorySummary],
        limit: Int?
    ) -> SearchSnapshot {
        let lowercasedQuery = query.lowercased()

        var scoredMemories: [(MemorySummary, Int)] = []
        for memory in memories {
            let score = memoryScore(memory: memory, query: lowercasedQuery)
            if score > 0 {
                scoredMemories.append((memory, score))
            }
        }

        var scoredEntities: [(EntityNode, Int)] = []
        for entity in graphContext.entities {
            let score = entityScore(entity: entity, query: lowercasedQuery)
            if score > 0 {
                scoredEntities.append((entity, score))
            }
        }

        var scoredArcs: [(TemporalArc, Int)] = []
        for arc in graphContext.arcs {
            let score = arcScore(arc: arc, query: lowercasedQuery)
            if score > 0 {
                scoredArcs.append((arc, score))
            }
        }

        var scoredReflections: [(ReflectionSnapshot, Int)] = []
        for reflection in graphContext.reflections {
            let score = reflectionScore(reflection: reflection, query: lowercasedQuery)
            if score > 0 {
                scoredReflections.append((reflection, score))
            }
        }

        let sortedMemories = scoredMemories
            .sorted { $0.1 > $1.1 }
            .prefix(limit ?? scoredMemories.count)
            .map { SearchMemoryResultSnapshot(memory: $0.0) }

        let sortedEntities = scoredEntities
            .sorted { $0.1 > $1.1 }
            .prefix(limit ?? scoredEntities.count)
            .map { entity, _ in
                let entityLinks = graphContext.links.filter { $0.entityID == entity.id }
                let artifactCount = entityLinks.count
                let relatedMemories = graphContext.relatedMemories(
                    recordIDs: entity.provenanceRecordIDs,
                    limit: 100
                )
                let relatedMemoryCount = relatedMemories.count

                let entityArcs = graphContext.arcs.filter { $0.sourceEntityIDs.contains(entity.id) }
                let arcCount = entityArcs.count

                let entityReflections = graphContext.reflections.filter {
                    $0.sourceEntityIDs.contains(entity.id)
                }
                let reflectionCount = entityReflections.count

                let entityEdges = graphContext.edges.filter {
                    $0.fromEntityID == entity.id || $0.toEntityID == entity.id
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
                    graphContext.entities.first { $0.id == id }?.displayName
                }

                let personEntities = graphContext.entities.filter { $0.kind == .person }
                let relatedPeople = relatedEntityNames.filter { name in
                    personEntities.contains { $0.displayName == name }
                }

                let themeEntities = graphContext.entities.filter { $0.kind == .theme }
                let relatedThemes = relatedEntityNames.filter { name in
                    themeEntities.contains { $0.displayName == name }
                }

                return SearchEntityResultSnapshot(
                    entity: entity,
                    artifactCount: artifactCount,
                    relatedMemoryCount: relatedMemoryCount,
                    relatedThemes: Array(Set(relatedThemes)),
                    relatedPeople: Array(Set(relatedPeople)),
                    reflectionCount: reflectionCount,
                    arcCount: arcCount
                )
            }

        let sortedArcs = scoredArcs
            .sorted { $0.1 > $1.1 }
            .prefix(limit ?? scoredArcs.count)
            .map { arc, _ in
                let summary = TemporalArcSummarySnapshot(
                    arc: arc,
                    relatedMemories: graphContext.relatedMemories(recordIDs: arc.sourceRecordIDs, limit: 3),
                    linkedReflection: graphContext.reflections.first { $0.linkedTemporalArcID == arc.id }
                )
                return SearchArcResultSnapshot(summary: summary)
            }

        let sortedReflections = scoredReflections
            .sorted { $0.1 > $1.1 }
            .prefix(limit ?? scoredReflections.count)
            .map { reflection, _ in
                let linkedArc = reflection.linkedTemporalArcID.flatMap { arcID in
                    graphContext.arcs.first { $0.id == arcID }
                }
                let relatedRecordIDs = linkedArc.map {
                    graphContext.mergeUniqueIDs(reflection.sourceRecordIDs, $0.sourceRecordIDs)
                } ?? reflection.sourceRecordIDs
                let summary = ReflectionSummarySnapshot(
                    reflection: reflection,
                    linkedArc: linkedArc,
                    relatedMemories: graphContext.relatedMemories(recordIDs: relatedRecordIDs, limit: 3)
                )
                return SearchReflectionResultSnapshot(summary: summary)
            }

        return SearchSnapshot(
            query: query,
            memories: Array(sortedMemories),
            entities: Array(sortedEntities),
            arcs: Array(sortedArcs),
            reflections: Array(sortedReflections)
        )
    }

    private func memoryScore(memory: MemorySummary, query: String) -> Int {
        var score = 0

        if memory.title.lowercased().contains(query) {
            score += 3
        }
        if memory.summaryText.lowercased().contains(query) {
            score += 2
        }
        if memory.record.rawText.lowercased().contains(query) {
            score += 1
        }

        return score
    }

    private func entityScore(entity: EntityNode, query: String) -> Int {
        var score = 0

        if entity.displayName.lowercased().contains(query) {
            score += 3
        }
        if entity.canonicalName.lowercased().contains(query) {
            score += 2
        }
        if entity.aliases.contains(where: { $0.lowercased().contains(query) }) {
            score += 2
        }
        if entity.summary.lowercased().contains(query) {
            score += 1
        }

        return score
    }

    private func arcScore(arc: TemporalArc, query: String) -> Int {
        var score = 0

        if arc.title.lowercased().contains(query) {
            score += 3
        }
        if arc.summary.lowercased().contains(query) {
            score += 2
        }
        if arc.themeLabels.contains(where: { $0.lowercased().contains(query) }) {
            score += 2
        }
        if arc.entityNames.contains(where: { $0.lowercased().contains(query) }) {
            score += 1
        }

        return score
    }

    private func reflectionScore(reflection: ReflectionSnapshot, query: String) -> Int {
        var score = 0

        if reflection.title.lowercased().contains(query) {
            score += 3
        }
        if reflection.body.lowercased().contains(query) {
            score += 2
        }
        if reflection.evidenceSummary.lowercased().contains(query) {
            score += 1
        }

        return score
    }
}