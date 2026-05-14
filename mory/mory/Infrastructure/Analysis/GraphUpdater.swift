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
            from: analysis.entityMentions,
            createdAt: analysis.createdAt,
            into: &entityNodes
        )

        for artifactID in linkedArtifactIDs {
            for entityID in resolvedEntityIDs {
                upsertArtifactEntityLink(
                    artifactID: artifactID,
                    entityID: entityID,
                    confidence: analysis.entityMentions.first(where: { $0.id == entityID })?.confidence,
                    source: "analysis",
                    createdAt: analysis.createdAt,
                    into: &artifactEntityLinks
                )
            }
        }

        rebuildEdgesForLatestAnalysis(
            entityIDs: resolvedEntityIDs,
            candidateEdges: analysis.candidateEdges,
            timestamp: analysis.createdAt,
            linkedArtifactIDs: linkedArtifactIDs,
            linkedRecordIDs: linkedRecordIDs,
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
                let mergedAliases = [entityNodes[existingIndex].canonicalName] + reference.aliases
                if let canonical = mergedAliases.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    entityNodes[existingIndex].canonicalName = canonical
                }
                resolvedIDs.append(entityNodes[existingIndex].id)
            } else {
                let node = EntityNode(
                    id: reference.id,
                    kind: reference.kind,
                    displayName: reference.name,
                    canonicalName: reference.aliases.first ?? reference.name,
                    summary: "",
                    createdAt: createdAt,
                    updatedAt: createdAt,
                    confidence: reference.confidence
                )
                entityNodes.append(node)
                resolvedIDs.append(node.id)
            }
        }

        return Array(NSOrderedSet(array: resolvedIDs)) as? [UUID] ?? Array(Set(resolvedIDs))
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
        candidateEdges: [CandidateEntityEdge],
        timestamp: Date,
        linkedArtifactIDs: [UUID],
        linkedRecordIDs: [UUID],
        entityNodes: [EntityNode],
        into entityEdges: inout [EntityEdge]
    ) {
        if !candidateEdges.isEmpty {
            for candidate in candidateEdges {
                guard
                    let fromEntityID = resolvedID(for: candidate.from, in: entityNodes),
                    let toEntityID = resolvedID(for: candidate.to, in: entityNodes),
                    fromEntityID != toEntityID
                else {
                    continue
                }

                upsertEdge(
                    fromEntityID: fromEntityID,
                    toEntityID: toEntityID,
                    relationKind: candidate.relationKind,
                    weightDelta: candidate.confidence ?? 0.25,
                    timestamp: timestamp,
                    linkedArtifactIDs: linkedArtifactIDs,
                    linkedRecordIDs: linkedRecordIDs,
                    into: &entityEdges
                )
            }
            return
        }

        guard entityIDs.count > 1 else { return }
        for leftIndex in entityIDs.indices {
            for rightIndex in entityIDs.indices where rightIndex > leftIndex {
                let leftID = entityIDs[leftIndex]
                let rightID = entityIDs[rightIndex]
                let inferred = inferEdge(between: leftID, and: rightID, entityNodes: entityNodes)
                upsertEdge(
                    fromEntityID: inferred.fromEntityID,
                    toEntityID: inferred.toEntityID,
                    relationKind: inferred.relationKind,
                    weightDelta: 0.2,
                    timestamp: timestamp,
                    linkedArtifactIDs: linkedArtifactIDs,
                    linkedRecordIDs: linkedRecordIDs,
                    into: &entityEdges
                )
            }
        }
    }

    private func resolvedID(for reference: EntityReference, in entityNodes: [EntityNode]) -> UUID? {
        entityNodes.first {
            $0.kind == reference.kind &&
            $0.displayName.localizedCaseInsensitiveCompare(reference.name) == .orderedSame
        }?.id
    }

    private func upsertEdge(
        fromEntityID: UUID,
        toEntityID: UUID,
        relationKind: EntityRelationKind,
        weightDelta: Double,
        timestamp: Date,
        linkedArtifactIDs: [UUID],
        linkedRecordIDs: [UUID],
        into entityEdges: inout [EntityEdge]
    ) {
        if let edgeIndex = entityEdges.firstIndex(where: {
            ($0.fromEntityID == fromEntityID && $0.toEntityID == toEntityID) ||
            ($0.fromEntityID == toEntityID && $0.toEntityID == fromEntityID)
        }) {
            entityEdges[edgeIndex].lastSeenAt = timestamp
            entityEdges[edgeIndex].evidenceCount += 1
            entityEdges[edgeIndex].weight += weightDelta
            entityEdges[edgeIndex].sourceArtifactIDs = mergeUniqueIDs(entityEdges[edgeIndex].sourceArtifactIDs, linkedArtifactIDs)
            entityEdges[edgeIndex].sourceRecordIDs = mergeUniqueIDs(entityEdges[edgeIndex].sourceRecordIDs, linkedRecordIDs)
            if specificity(of: relationKind) > specificity(of: entityEdges[edgeIndex].relationKind) {
                entityEdges[edgeIndex].relationKind = relationKind
                entityEdges[edgeIndex].fromEntityID = fromEntityID
                entityEdges[edgeIndex].toEntityID = toEntityID
            }
        } else {
            entityEdges.append(
                EntityEdge(
                    fromEntityID: fromEntityID,
                    toEntityID: toEntityID,
                    relationKind: relationKind,
                    weight: max(1, 1 + weightDelta),
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

    private func mergeUniqueIDs(_ lhs: [UUID], _ rhs: [UUID]) -> [UUID] {
        Array(NSOrderedSet(array: lhs + rhs)) as? [UUID] ?? Array(Set(lhs + rhs))
    }
}
