import Foundation

struct GraphEntityInsight: Identifiable, Sendable {
    var id: UUID { entityID }
    var entityID: UUID
    var displayName: String
    var kind: EntityKind
    var mentionCount: Int
    var lastSeenAt: Date?
}

struct GraphEdgeInsight: Identifiable, Sendable {
    var id: UUID { edgeID }
    var edgeID: UUID
    var fromEntityID: UUID
    var toEntityID: UUID
    var fromDisplayName: String
    var toDisplayName: String
    var relationKind: EntityRelationKind
    var weight: Double
    var evidenceCount: Int
    var lastSeenAt: Date
}

struct GraphInsightsSnapshot: Sendable {
    var recentEntities: [GraphEntityInsight]
    var topPeople: [GraphEntityInsight]
    var topThemes: [GraphEntityInsight]
    var hotEdges: [GraphEdgeInsight]
}

struct GraphInsightsBuilder {
    func build(
        entityNodes: [EntityNode],
        entityEdges: [EntityEdge],
        artifactEntityLinks: [ArtifactEntityLink],
        records: [RecordShell],
        artifacts: [Artifact],
        limit: Int
    ) -> GraphInsightsSnapshot {
        let entityIndex = Dictionary(uniqueKeysWithValues: entityNodes.map { ($0.id, $0) })
        let artifactIndex = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })

        let entityInsights = entityNodes.map { entity in
            makeEntityInsight(
                entity: entity,
                artifactEntityLinks: artifactEntityLinks,
                records: records,
                artifactIndex: artifactIndex
            )
        }

        let sortedRecent = entityInsights.sorted { lhs, rhs in
            if lhs.lastSeenAt == rhs.lastSeenAt {
                return lhs.mentionCount > rhs.mentionCount
            }
            return (lhs.lastSeenAt ?? .distantPast) > (rhs.lastSeenAt ?? .distantPast)
        }

        let sortedPeople = entityInsights
            .filter { $0.kind == .person }
            .sorted(by: compareEntityInsight)

        let sortedThemes = entityInsights
            .filter { $0.kind == .theme }
            .sorted(by: compareEntityInsight)

        let sortedEdges: [GraphEdgeInsight] = entityEdges
            .compactMap { edge -> GraphEdgeInsight? in
                guard
                    let from = entityIndex[edge.fromEntityID],
                    let to = entityIndex[edge.toEntityID]
                else { return nil }

                return GraphEdgeInsight(
                    edgeID: edge.id,
                    fromEntityID: edge.fromEntityID,
                    toEntityID: edge.toEntityID,
                    fromDisplayName: from.displayName,
                    toDisplayName: to.displayName,
                    relationKind: edge.relationKind,
                    weight: edge.weight,
                    evidenceCount: edge.evidenceCount,
                    lastSeenAt: edge.lastSeenAt
                )
            }
            .sorted { (lhs: GraphEdgeInsight, rhs: GraphEdgeInsight) in
                if lhs.evidenceCount == rhs.evidenceCount {
                    if lhs.weight == rhs.weight {
                        return lhs.lastSeenAt > rhs.lastSeenAt
                    }
                    return lhs.weight > rhs.weight
                }
                return lhs.evidenceCount > rhs.evidenceCount
            }

        return GraphInsightsSnapshot(
            recentEntities: Array(sortedRecent.prefix(limit)),
            topPeople: Array(sortedPeople.prefix(limit)),
            topThemes: Array(sortedThemes.prefix(limit)),
            hotEdges: Array(sortedEdges.prefix(limit))
        )
    }

    private func makeEntityInsight(
        entity: EntityNode,
        artifactEntityLinks: [ArtifactEntityLink],
        records: [RecordShell],
        artifactIndex: [UUID: Artifact]
    ) -> GraphEntityInsight {
        let links = artifactEntityLinks.filter { $0.entityID == entity.id }
        let artifactIDs = Set(links.map(\.artifactID))
        let recordDates = records
            .filter { !$0.artifactIDs.filter(artifactIDs.contains).isEmpty }
            .map(\.updatedAt)
        let artifactDates = artifactIDs.compactMap { artifactIndex[$0]?.updatedAt }
        let lastSeenAt = ([entity.updatedAt] + artifactDates + recordDates).max()

        return GraphEntityInsight(
            entityID: entity.id,
            displayName: entity.displayName,
            kind: entity.kind,
            mentionCount: links.count,
            lastSeenAt: lastSeenAt
        )
    }

    private func compareEntityInsight(_ lhs: GraphEntityInsight, _ rhs: GraphEntityInsight) -> Bool {
        if lhs.mentionCount == rhs.mentionCount {
            return (lhs.lastSeenAt ?? .distantPast) > (rhs.lastSeenAt ?? .distantPast)
        }
        return lhs.mentionCount > rhs.mentionCount
    }
}
