import Foundation

struct GraphUpdateResult: Sendable {
    var entityNodes: [EntityNode]
    var entityEdges: [EntityEdge]
    var artifactEntityLinks: [ArtifactEntityLink]
    var resolvedEntityIDs: [UUID]
}

struct GraphUpdater {
    func apply(
        analysis: RecordAnalysisSnapshot,
        linkedArtifactIDs: [UUID],
        linkedRecordIDs: [UUID],
        existingEntityNodes: [EntityNode],
        existingEntityEdges: [EntityEdge],
        existingArtifactEntityLinks: [ArtifactEntityLink]
    ) -> GraphUpdateResult {
        var entityNodes = existingEntityNodes
        var entityEdges = existingEntityEdges
        var artifactEntityLinks = existingArtifactEntityLinks

        let resolvedEntityIDs = upsertEntities(
            from: analysis.entities,
            createdAt: analysis.createdAt,
            into: &entityNodes
        )

        for artifactID in linkedArtifactIDs {
            for entityID in resolvedEntityIDs {
                upsertArtifactEntityLink(
                    artifactID: artifactID,
                    entityID: entityID,
                    confidence: analysis.entities.first(where: { $0.id == entityID })?.confidence,
                    source: "analysis",
                    createdAt: analysis.createdAt,
                    into: &artifactEntityLinks
                )
            }
        }

        rebuildEdgesForLatestAnalysis(
            entityIDs: resolvedEntityIDs,
            timestamp: analysis.createdAt,
            linkedArtifactIDs: linkedArtifactIDs,
            linkedRecordIDs: linkedRecordIDs,
            candidateEdges: analysis.candidateEdges,
            entityNodes: entityNodes,
            into: &entityEdges
        )

        return GraphUpdateResult(
            entityNodes: entityNodes,
            entityEdges: entityEdges,
            artifactEntityLinks: artifactEntityLinks,
            resolvedEntityIDs: resolvedEntityIDs
        )
    }

    private func upsertEntities(
        from references: [EntityReference],
        createdAt: Date,
        into entityNodes: inout [EntityNode]
    ) -> [UUID] {
        var resolvedIDs: [UUID] = []

        for reference in references {
            if let existingIndex = entityNodes.firstIndex(where: {
                $0.kind == reference.kind &&
                $0.displayName.localizedCaseInsensitiveCompare(reference.name) == .orderedSame
            }) {
                entityNodes[existingIndex].updatedAt = createdAt
                if let confidence = reference.confidence {
                    entityNodes[existingIndex].confidence = confidence
                }
                resolvedIDs.append(entityNodes[existingIndex].id)
            } else {
                let node = EntityNode(
                    id: reference.id,
                    kind: reference.kind,
                    displayName: reference.name,
                    summary: "",
                    createdAt: createdAt,
                    updatedAt: createdAt,
                    confidence: reference.confidence
                )
                entityNodes.append(node)
                resolvedIDs.append(node.id)
            }
        }

        return Array(Set(resolvedIDs))
    }

    private func upsertArtifactEntityLink(
        artifactID: UUID,
        entityID: UUID,
        confidence: Double?,
        source: String,
        createdAt: Date,
        into artifactEntityLinks: inout [ArtifactEntityLink]
    ) {
        guard !artifactEntityLinks.contains(where: { $0.artifactID == artifactID && $0.entityID == entityID }) else { return }
        artifactEntityLinks.append(
            ArtifactEntityLink(
                artifactID: artifactID,
                entityID: entityID,
                confidence: confidence,
                source: source,
                createdAt: createdAt
            )
        )
    }

    private func rebuildEdgesForLatestAnalysis(
        entityIDs: [UUID],
        timestamp: Date,
        linkedArtifactIDs: [UUID],
        linkedRecordIDs: [UUID],
        candidateEdges: [RecordAnalysisSnapshot.CandidateEdge],
        entityNodes: [EntityNode],
        into entityEdges: inout [EntityEdge]
    ) {
        let candidateResolvedEdges = resolvedCandidateEdges(
            from: candidateEdges,
            entityNodes: entityNodes
        )

        if !candidateResolvedEdges.isEmpty {
            for candidateEdge in candidateResolvedEdges {
                upsertEdge(
                    candidateEdge,
                    timestamp: timestamp,
                    linkedArtifactIDs: linkedArtifactIDs,
                    linkedRecordIDs: linkedRecordIDs,
                    into: &entityEdges
                )
            }
        }

        guard entityIDs.count > 1 else { return }
        for leftIndex in entityIDs.indices {
            for rightIndex in entityIDs.indices where rightIndex > leftIndex {
                let leftID = entityIDs[leftIndex]
                let rightID = entityIDs[rightIndex]
                let inferred = inferEdge(
                    between: leftID,
                    and: rightID,
                    entityNodes: entityNodes
                )
                upsertEdge(
                    inferred,
                    timestamp: timestamp,
                    linkedArtifactIDs: linkedArtifactIDs,
                    linkedRecordIDs: linkedRecordIDs,
                    into: &entityEdges
                )
            }
        }
    }

    private func resolvedCandidateEdges(
        from candidateEdges: [RecordAnalysisSnapshot.CandidateEdge],
        entityNodes: [EntityNode]
    ) -> [(fromEntityID: UUID, toEntityID: UUID, relationKind: EntityRelationKind)] {
        var resolved: [(fromEntityID: UUID, toEntityID: UUID, relationKind: EntityRelationKind)] = []
        var seen: Set<String> = []

        for candidate in candidateEdges {
            guard
                let fromKind = normalizeEntityKind(candidate.fromKind),
                let toKind = normalizeEntityKind(candidate.toKind),
                let relationKind = normalizeRelationKind(candidate.relation),
                let fromEntity = matchEntity(named: candidate.fromName, kind: fromKind, in: entityNodes),
                let toEntity = matchEntity(named: candidate.toName, kind: toKind, in: entityNodes),
                fromEntity.id != toEntity.id
            else {
                continue
            }

            let ordered = orderedPair(fromEntity.id, toEntity.id, relationKind: relationKind)
            let key = "\(ordered.fromEntityID.uuidString)|\(ordered.toEntityID.uuidString)|\(ordered.relationKind.rawValue)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            resolved.append(ordered)
        }

        return resolved
    }

    private func upsertEdge(
        _ edge: (fromEntityID: UUID, toEntityID: UUID, relationKind: EntityRelationKind),
        timestamp: Date,
        linkedArtifactIDs: [UUID],
        linkedRecordIDs: [UUID],
        into entityEdges: inout [EntityEdge]
    ) {
        if let edgeIndex = entityEdges.firstIndex(where: {
            ($0.fromEntityID == edge.fromEntityID && $0.toEntityID == edge.toEntityID) ||
            ($0.fromEntityID == edge.toEntityID && $0.toEntityID == edge.fromEntityID)
        }) {
            entityEdges[edgeIndex].lastSeenAt = timestamp
            entityEdges[edgeIndex].evidenceCount += 1
            entityEdges[edgeIndex].weight += 0.2
            entityEdges[edgeIndex].sourceArtifactIDs = mergeUniqueIDs(
                entityEdges[edgeIndex].sourceArtifactIDs,
                linkedArtifactIDs
            )
            entityEdges[edgeIndex].sourceRecordIDs = mergeUniqueIDs(
                entityEdges[edgeIndex].sourceRecordIDs,
                linkedRecordIDs
            )
            if specificity(of: edge.relationKind) > specificity(of: entityEdges[edgeIndex].relationKind) {
                entityEdges[edgeIndex].relationKind = edge.relationKind
                entityEdges[edgeIndex].fromEntityID = edge.fromEntityID
                entityEdges[edgeIndex].toEntityID = edge.toEntityID
            }
        } else {
            entityEdges.append(
                EntityEdge(
                    fromEntityID: edge.fromEntityID,
                    toEntityID: edge.toEntityID,
                    relationKind: edge.relationKind,
                    weight: 1,
                    firstSeenAt: timestamp,
                    lastSeenAt: timestamp,
                    evidenceCount: 1,
                    sourceArtifactIDs: linkedArtifactIDs,
                    sourceRecordIDs: linkedRecordIDs
                )
            )
        }
    }

    private func inferEdge(
        between leftID: UUID,
        and rightID: UUID,
        entityNodes: [EntityNode]
    ) -> (fromEntityID: UUID, toEntityID: UUID, relationKind: EntityRelationKind) {
        guard
            let left = entityNodes.first(where: { $0.id == leftID }),
            let right = entityNodes.first(where: { $0.id == rightID })
        else {
            return orderedPair(leftID, rightID, relationKind: .mentionedWith)
        }

        let kinds = Set([left.kind, right.kind])

        if kinds == Set([.person, .decision]) {
            let personID = left.kind == .person ? left.id : right.id
            let decisionID = left.kind == .decision ? left.id : right.id
            return (personID, decisionID, .decidedAt)
        }

        if kinds == Set([.place, .theme]) {
            let placeID = left.kind == .place ? left.id : right.id
            let themeID = left.kind == .theme ? left.id : right.id
            return (placeID, themeID, .repeatedIn)
        }

        if kinds == Set([.theme]) {
            return orderedPair(left.id, right.id, relationKind: .repeatedIn)
        }

        if kinds == Set([.decision, .theme]) {
            let decisionID = left.kind == .decision ? left.id : right.id
            let themeID = left.kind == .theme ? left.id : right.id
            return (decisionID, themeID, .relatedTo)
        }

        if kinds == Set([.person, .theme]) || kinds == Set([.person, .place]) || kinds == Set([.place, .decision]) {
            return orderedPair(left.id, right.id, relationKind: .relatedTo)
        }

        return orderedPair(left.id, right.id, relationKind: .mentionedWith)
    }

    private func orderedPair(
        _ leftID: UUID,
        _ rightID: UUID,
        relationKind: EntityRelationKind
    ) -> (fromEntityID: UUID, toEntityID: UUID, relationKind: EntityRelationKind) {
        leftID.uuidString < rightID.uuidString
            ? (leftID, rightID, relationKind)
            : (rightID, leftID, relationKind)
    }

    private func specificity(of relationKind: EntityRelationKind) -> Int {
        switch relationKind {
        case .mentionedWith: 0
        case .relatedTo: 1
        case .repeatedIn: 2
        case .decidedAt: 3
        }
    }

    private func matchEntity(
        named rawName: String,
        kind: EntityKind,
        in entityNodes: [EntityNode]
    ) -> EntityNode? {
        let normalizedName = normalized(rawName)
        return entityNodes.first {
            $0.kind == kind &&
            (
                normalized($0.displayName) == normalizedName ||
                normalized($0.canonicalName) == normalizedName ||
                normalized($0.summary) == normalizedName
            )
        }
    }

    private func normalizeEntityKind(_ rawValue: String) -> EntityKind? {
        switch normalized(rawValue) {
        case "person", "people", "human":
            return .person
        case "place", "location", "city", "area":
            return .place
        case "theme", "tag", "topic":
            return .theme
        case "decision", "choice", "plan":
            return .decision
        default:
            return EntityKind(rawValue: rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
    }

    private func normalizeRelationKind(_ rawValue: String) -> EntityRelationKind? {
        switch normalized(rawValue) {
        case "mentioned_with", "mentionedwith", "cooccurred", "co-occurred":
            return .mentionedWith
        case "repeated_in", "repeatedin":
            return .repeatedIn
        case "decided_at", "decidedat":
            return .decidedAt
        case "related_to", "relatedto":
            return .relatedTo
        default:
            return EntityRelationKind(rawValue: rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private func mergeUniqueIDs(_ lhs: [UUID], _ rhs: [UUID]) -> [UUID] {
        Array(Set(lhs + rhs))
    }
}
