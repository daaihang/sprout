import Foundation

struct GraphUpdateResult: Sendable {
    var entityNodes: [EntityNode]
    var entityEdges: [EntityEdge]
    var artifactEntityLinks: [ArtifactEntityLink]
    var resolvedEntityIDs: [UUID]
}

struct GraphUpdater {
    private let entityQualityPolicy = EntityQualityPolicy()

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
        let entityMentions = entityQualityPolicy.filter(analysis.entityMentions)

        let resolvedEntityIDs = upsertEntities(
            from: entityMentions,
            sourceRecordIDs: linkedRecordIDs,
            createdAt: analysis.createdAt,
            into: &entityNodes
        )

        for artifactID in linkedArtifactIDs {
            for entityID in resolvedEntityIDs {
                let confidence = entityConfidence(for: entityID, references: analysis.entityMentions, entityNodes: entityNodes)
                upsertArtifactEntityLink(
                    artifactID: artifactID,
                    entityID: entityID,
                    confidence: confidence,
                    source: "analysis",
                    sourceRecordID: linkedRecordIDs.first,
                    sourceAnalysisRecordID: analysis.recordID,
                    evidenceSummary: analysis.summary,
                    createdAt: analysis.createdAt,
                    into: &artifactEntityLinks
                )
            }
        }

        rebuildEdgesForLatestAnalysis(
            entityIDs: resolvedEntityIDs,
            candidateEdges: filteredCandidateEdges(analysis.candidateEdges),
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

    private func filteredCandidateEdges(_ edges: [CandidateEntityEdge]) -> [CandidateEntityEdge] {
        edges.filter {
            entityQualityPolicy.evaluate($0.from).passed &&
            entityQualityPolicy.evaluate($0.to).passed &&
            ($0.confidence ?? 0) >= 0.55
        }
    }

    private func upsertEntities(
        from references: [EntityReference],
        sourceRecordIDs: [UUID],
        createdAt: Date,
        into entityNodes: inout [EntityNode]
    ) -> [UUID] {
        var resolvedIDs: [UUID] = []

        for reference in references {
            if let existingIndex = entityNodes.firstIndex(where: { matches(reference: reference, node: $0) }) {
                entityNodes[existingIndex].updatedAt = createdAt
                if let confidence = reference.confidence {
                    entityNodes[existingIndex].confidence = confidence
                }
                entityNodes[existingIndex].aliases = mergeNormalizedStrings(
                    entityNodes[existingIndex].aliases,
                    [entityNodes[existingIndex].displayName, entityNodes[existingIndex].canonicalName] + reference.aliases
                )
                if !entityNodes[existingIndex].aliases.contains(where: { $0.caseInsensitiveCompare(reference.name) == .orderedSame }) {
                    entityNodes[existingIndex].aliases.append(reference.name)
                }
                entityNodes[existingIndex].canonicalName = preferredCanonicalName(
                    current: entityNodes[existingIndex].canonicalName,
                    displayName: entityNodes[existingIndex].displayName,
                    aliases: entityNodes[existingIndex].aliases
                )
                entityNodes[existingIndex].provenanceRecordIDs = mergeUniqueIDs(
                    entityNodes[existingIndex].provenanceRecordIDs,
                    sourceRecordIDs
                )
                resolvedIDs.append(entityNodes[existingIndex].id)
            } else {
                let node = EntityNode(
                    id: reference.id,
                    kind: reference.kind,
                    displayName: reference.name,
                    canonicalName: preferredCanonicalName(
                        current: reference.name,
                        displayName: reference.name,
                        aliases: reference.aliases
                    ),
                    aliases: mergeNormalizedStrings([], reference.aliases),
                    summary: "",
                    provenanceRecordIDs: sourceRecordIDs,
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
        sourceRecordID: UUID?,
        sourceAnalysisRecordID: UUID?,
        evidenceSummary: String,
        createdAt: Date,
        into artifactEntityLinks: inout [ArtifactEntityLink]
    ) {
        if let existingIndex = artifactEntityLinks.firstIndex(where: { $0.artifactID == artifactID && $0.entityID == entityID }) {
            artifactEntityLinks[existingIndex].confidence = maxConfidence(existing: artifactEntityLinks[existingIndex].confidence, incoming: confidence)
            artifactEntityLinks[existingIndex].sourceRecordID = sourceRecordID ?? artifactEntityLinks[existingIndex].sourceRecordID
            artifactEntityLinks[existingIndex].sourceAnalysisRecordID = sourceAnalysisRecordID ?? artifactEntityLinks[existingIndex].sourceAnalysisRecordID
            if !evidenceSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                artifactEntityLinks[existingIndex].evidenceSummary = evidenceSummary
            }
            return
        }
        artifactEntityLinks.append(
            ArtifactEntityLink(
                artifactID: artifactID,
                entityID: entityID,
                confidence: confidence,
                source: source,
                sourceRecordID: sourceRecordID,
                sourceAnalysisRecordID: sourceAnalysisRecordID,
                evidenceSummary: evidenceSummary,
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
        entityNodes.first(where: { matches(reference: reference, node: $0) })?.id
    }

    private func matches(reference: EntityReference, node: EntityNode) -> Bool {
        guard node.kind == reference.kind else { return false }
        let normalizedReference = reference.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedReference.isEmpty else { return false }

        let candidates = [node.displayName, node.canonicalName] + node.aliases
        return candidates.contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(normalizedReference) == .orderedSame
        }
    }

    private func preferredCanonicalName(
        current: String,
        displayName: String,
        aliases: [String]
    ) -> String {
        let candidates = [current, displayName] + aliases
        return candidates.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? displayName
    }

    private func mergeNormalizedStrings(_ lhs: [String], _ rhs: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        for value in lhs + rhs {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            ordered.append(trimmed)
        }

        return ordered
    }

    private func maxConfidence(existing: Double?, incoming: Double?) -> Double? {
        switch (existing, incoming) {
        case let (.some(left), .some(right)):
            return max(left, right)
        case let (.some(left), nil):
            return left
        case let (nil, .some(right)):
            return right
        case (nil, nil):
            return nil
        }
    }

    private func entityConfidence(
        for entityID: UUID,
        references: [EntityReference],
        entityNodes: [EntityNode]
    ) -> Double? {
        guard let node = entityNodes.first(where: { $0.id == entityID }) else { return nil }
        return references.first(where: { matches(reference: $0, node: node) })?.confidence ?? node.confidence
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
