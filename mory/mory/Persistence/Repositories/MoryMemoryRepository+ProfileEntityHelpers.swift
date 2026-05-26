import Foundation
import SwiftData

extension MoryMemoryRepository {
// MARK: - Private: Person Profile Building

    func buildPersonProfile(
        detail: EntityDetailSnapshot,
        entityProfile: EntityProfile?,
        existing: PersonProfile?,
        now: Date
    ) throws -> PersonProfile {
        if let existing, existing.isFrozen {
            var frozen = existing
            frozen.sourceRecordIDs = mergeUniqueIDs(frozen.sourceRecordIDs, detail.relatedMemories.map(\.id))
            frozen.updatedAt = now
            return frozen
        }

        let sourceRecordIDs = mergeUniqueIDs(
            existing?.sourceRecordIDs ?? [],
            mergeUniqueIDs(entityProfile?.sourceRecordIDs ?? [], detail.relatedMemories.map(\.id))
        )
        let aliases = normalizedPersonAliases(
            [detail.entity.displayName, detail.entity.canonicalName]
                + detail.entity.aliases
                + (entityProfile?.aliases ?? [])
                + (existing?.aliases ?? [])
        )
        let relationship = preservedUserConfirmedRelationship(existing)
            ?? existing?.relationshipToUser
            ?? entityProfile?.relationshipToUser
        let relationshipHistory = updatedRelationshipHistory(
            existing?.relationshipHistory ?? [],
            relationship: relationship,
            sourceRecordIDs: sourceRecordIDs,
            now: now
        )
        let roleLabels = mergeStrings(
            existing?.roleLabels ?? [],
            relationship.map { [$0.rawValue] } ?? []
        )
        let contextLabels = mergeStrings(
            existing?.commonContextLabels ?? [],
            mergeStrings(entityProfile?.commonContextLabels ?? [], detail.relatedThemes)
        )
        let relatedEntityIDs = try relatedEntityIDsByKind(edges: detail.edges)
        let evidence = refreshedPersonProfileEvidence(
            detail: detail,
            entityProfile: entityProfile,
            existing: existing,
            sourceRecordIDs: sourceRecordIDs,
            relationship: relationship,
            contextLabels: contextLabels,
            now: now
        )

        let portrait = buildPersonPortrait(
            displayName: detail.entity.displayName,
            relationship: relationship,
            relatedMemories: detail.relatedMemories,
            contextLabels: contextLabels,
            existing: existing?.aiPortrait,
            now: now
        )
        let affectPattern = buildPersonAffectPattern(
            recordIDs: sourceRecordIDs,
            now: now
        )

        return PersonProfile(
            id: existing?.id ?? UUID(),
            entityID: detail.entity.id,
            displayName: detail.entity.displayName,
            canonicalName: detail.entity.canonicalName,
            aliases: aliases,
            roleLabels: roleLabels,
            relationshipToUser: relationship,
            relationshipHistory: relationshipHistory,
            relationshipStrength: relationshipStrength(for: relationship, mentionCount: sourceRecordIDs.count),
            importanceScore: importanceScore(
                relationship: relationship,
                mentionCount: sourceRecordIDs.count,
                reflectionCount: detail.relatedReflections.count,
                arcCount: detail.relatedArcs.count
            ),
            interactionFrequency: interactionFrequency(for: detail.relatedMemories),
            commonPlaceIDs: relatedEntityIDs[.place] ?? existing?.commonPlaceIDs ?? [],
            commonThemeIDs: relatedEntityIDs[.theme] ?? existing?.commonThemeIDs ?? [],
            commonDecisionIDs: relatedEntityIDs[.decision] ?? existing?.commonDecisionIDs ?? [],
            commonContextLabels: contextLabels,
            emotionalPattern: affectPattern ?? existing?.emotionalPattern,
            recentChangeSummary: recentChangeSummary(
                displayName: detail.entity.displayName,
                relatedMemories: detail.relatedMemories,
                relationship: relationship
            ),
            userNotes: existing?.userNotes,
            aiPortrait: portrait,
            fieldEvidence: evidence,
            fieldConfidence: fieldConfidence(from: evidence),
            sensitivity: existing?.sensitivity ?? .normal,
            automationPolicy: existing?.automationPolicy ?? .automatic,
            sourceRecordIDs: sourceRecordIDs,
            lastReviewedAt: existing?.lastReviewedAt,
            createdAt: existing?.createdAt ?? detail.entity.createdAt,
            updatedAt: now
        )
    }

    func preservedUserConfirmedRelationship(_ existing: PersonProfile?) -> EntityRelationshipToUser? {
        guard let existing else { return nil }
        guard existing.relationshipHistory.contains(where: { $0.status == .userConfirmed }) else {
            return nil
        }
        return existing.relationshipToUser
    }

    func updatedRelationshipHistory(
        _ existing: [RelationshipChange],
        relationship: EntityRelationshipToUser?,
        sourceRecordIDs: [UUID],
        now: Date
    ) -> [RelationshipChange] {
        guard let relationship else { return existing }
        if existing.contains(where: { $0.relationship == relationship }) {
            return existing
        }
        return existing + [
            RelationshipChange(
                relationship: relationship,
                note: "Inferred from person profile refresh.",
                sourceRecordIDs: sourceRecordIDs,
                status: .inferred,
                changedAt: now
            )
        ]
    }

    func relatedEntityIDsByKind(edges: [EntityEdge]) throws -> [EntityKind: [UUID]] {
        var result: [EntityKind: [UUID]] = [:]
        for edge in edges {
            for entityID in [edge.fromEntityID, edge.toEntityID] {
                guard let node = try fetchEntityNode(id: entityID) else { continue }
                guard node.kind == .place || node.kind == .theme || node.kind == .decision else { continue }
                result[node.kind, default: []].append(node.id)
            }
        }
        return result.mapValues { Array(NSOrderedSet(array: $0)) as? [UUID] ?? $0 }
    }

    func refreshedPersonProfileEvidence(
        detail: EntityDetailSnapshot,
        entityProfile: EntityProfile?,
        existing: PersonProfile?,
        sourceRecordIDs: [UUID],
        relationship: EntityRelationshipToUser?,
        contextLabels: [String],
        now: Date
    ) -> [ProfileFieldEvidence] {
        let userEvidence = existing?.fieldEvidence.filter { $0.source == .userEdit && $0.status == .userConfirmed } ?? []
        var evidence = userEvidence
        let latestMemories = Array(detail.relatedMemories.prefix(4))
        for memory in latestMemories {
            evidence.append(ProfileFieldEvidence(
                fieldKey: "sourceRecordIDs",
                source: .memory,
                sourceRecordIDs: [memory.id],
                sourceArtifactIDs: memory.primaryArtifact.map { [$0.id] } ?? [],
                snippet: String(memory.summaryText.prefix(260)),
                confidence: entityProfile?.confidence ?? detail.entity.confidence,
                createdAt: now,
                refreshedAt: now
            ))
        }
        if let relationship {
            evidence.append(ProfileFieldEvidence(
                fieldKey: "relationshipToUser",
                source: .profileRefresh,
                sourceRecordIDs: sourceRecordIDs,
                snippet: "Relationship currently reads as \(relationship.rawValue).",
                confidence: entityProfile?.confidence,
                createdAt: now,
                refreshedAt: now
            ))
        }
        if !contextLabels.isEmpty {
            evidence.append(ProfileFieldEvidence(
                fieldKey: "commonContextLabels",
                source: .profileRefresh,
                sourceRecordIDs: sourceRecordIDs,
                snippet: contextLabels.prefix(6).joined(separator: ", "),
                confidence: 0.72,
                createdAt: now,
                refreshedAt: now
            ))
        }
        return evidence
    }

    func fieldConfidence(from evidence: [ProfileFieldEvidence]) -> [String: Double] {
        var result: [String: Double] = [:]
        for item in evidence {
            result[item.fieldKey] = max(result[item.fieldKey] ?? 0, item.confidence ?? 0.5)
        }
        return result
    }

    func buildPersonPortrait(
        displayName: String,
        relationship: EntityRelationshipToUser?,
        relatedMemories: [MemorySummary],
        contextLabels: [String],
        existing: PersonPortrait?,
        now: Date
    ) -> PersonPortrait? {
        guard !relatedMemories.isEmpty else {
            return existing
        }
        let memoryCount = relatedMemories.count
        let contexts = Array(contextLabels.prefix(5))
        let relationshipText = relationship?.rawValue ?? "unknown relationship"
        let latest = relatedMemories.max { $0.record.updatedAt < $1.record.updatedAt }
        let summary = "\(displayName) appears in \(memoryCount) \(memoryCount == 1 ? "memory" : "memories"), with relationship marked as \(relationshipText)."
        let recentPattern = latest.map { "Latest related memory: \($0.summaryText)" }
        return PersonPortrait(
            id: existing?.id ?? UUID(),
            summary: summary,
            relationshipTrajectory: relationship == nil ? nil : "Current relationship label is \(relationshipText).",
            recentInteractionPattern: recentPattern.map { String($0.prefix(320)) },
            recurringContexts: contexts,
            affectSummary: nil,
            openUncertainties: relationship == nil ? ["Confirm who \(displayName) is to you."] : [],
            suggestedQuestions: relationship == nil ? ["Who is \(displayName) to you?"] : [],
            evidenceRecordIDs: relatedMemories.map(\.id),
            confidence: min(0.95, 0.45 + Double(memoryCount) * 0.08),
            status: .inferred,
            generatedAt: existing?.generatedAt ?? now,
            updatedAt: now
        )
    }

    func buildPersonAffectPattern(
        recordIDs: [UUID],
        now: Date
    ) -> PersonAffectPattern? {
        let analyses = recordIDs.compactMap { try? fetchRecordAnalysis(recordID: $0) }
        let notes = analyses
            .map(\.emotionInterpretation)
            .compactMap { $0.trimmedOrNil }
        guard !notes.isEmpty else { return nil }
        return PersonAffectPattern(
            dominantLabels: [],
            summary: String(notes.prefix(3).joined(separator: " / ").prefix(360)),
            sourceRecordIDs: analyses.map(\.recordID),
            confidence: 0.58,
            updatedAt: now
        )
    }

    func relationshipStrength(
        for relationship: EntityRelationshipToUser?,
        mentionCount: Int
    ) -> Double? {
        guard let relationship else { return nil }
        let base: Double = switch relationship {
        case .partner: 0.9
        case .family: 0.82
        case .friend: 0.72
        case .manager, .directReport, .coworker, .classmate, .client: 0.56
        case .acquaintance, .creator, .publicFigure, .other, .unknown: 0.35
        }
        return min(1, base + min(0.18, Double(mentionCount) * 0.025))
    }

    func importanceScore(
        relationship: EntityRelationshipToUser?,
        mentionCount: Int,
        reflectionCount: Int,
        arcCount: Int
    ) -> Double {
        var score = min(0.45, Double(mentionCount) * 0.08)
        if relationship != nil {
            score += 0.2
        }
        score += min(0.18, Double(reflectionCount) * 0.06)
        score += min(0.17, Double(arcCount) * 0.08)
        return min(1, score)
    }

    func interactionFrequency(for memories: [MemorySummary]) -> InteractionFrequency {
        guard !memories.isEmpty else { return .unknown }
        guard memories.count >= 2 else { return .rare }
        let dates = memories.map(\.record.updatedAt)
        guard let earliest = dates.min(), let latest = dates.max() else { return .unknown }
        let days = max(1, latest.timeIntervalSince(earliest) / 86_400)
        let rate = Double(memories.count) / days
        if rate >= 1 { return .daily }
        if rate >= 1.0 / 7.0 { return .weekly }
        if rate >= 1.0 / 30.0 { return .monthly }
        return .rare
    }

    func recentChangeSummary(
        displayName: String,
        relatedMemories: [MemorySummary],
        relationship: EntityRelationshipToUser?
    ) -> String? {
        guard let latest = relatedMemories.max(by: { $0.record.updatedAt < $1.record.updatedAt }) else {
            return nil
        }
        let relationshipText = relationship?.rawValue ?? "unconfirmed"
        return "\(displayName)'s latest related memory is from \(latest.record.updatedAt.formatted(.iso8601)); relationship is \(relationshipText)."
    }

    // MARK: - Private: Entity Node & Edge Helpers

    func fetchPersonEntityNodes(recordID: UUID, artifactIDs: [UUID]) throws -> [EntityNode] {
        let artifactIDSet = Set(artifactIDs)
        let linkedEntityIDs = Set(
            try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
                .filter { link in
                    link.sourceRecordID == recordID
                        || link.sourceAnalysisRecordID == recordID
                        || artifactIDSet.contains(link.artifactID)
                }
                .map(\.entityID)
        )

        return try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
            .map(\.domainModel)
            .filter { entity in
                entity.kind == .person
                    && (linkedEntityIDs.contains(entity.id) || entity.provenanceRecordIDs.contains(recordID))
            }
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                return lhs.displayName < rhs.displayName
            }
    }

    func fetchEntityNode(id: UUID) throws -> EntityNode? {
        try modelContext.fetch(
            FetchDescriptor<EntityNodeStore>(predicate: #Predicate { $0.id == id })
        ).first?.domainModel
    }

    func fetchEntityNodeStore(id: UUID) throws -> EntityNodeStore? {
        try modelContext.fetch(
            FetchDescriptor<EntityNodeStore>(predicate: #Predicate { $0.id == id })
        ).first
    }

    func requirePersonEntityNodeStore(id: UUID) throws -> EntityNodeStore {
        guard let store = try fetchEntityNodeStore(id: id) else {
            throw PersonEntityMutationError.entityNotFound
        }
        guard store.kindRawValue == EntityKind.person.rawValue else {
            throw PersonEntityMutationError.entityIsNotPerson
        }
        return store
    }

    func fetchPlaceProfileStore(id: UUID) throws -> PlaceProfileStore? {
        try modelContext.fetch(
            FetchDescriptor<PlaceProfileStore>(predicate: #Predicate { $0.id == id })
        ).first
    }

    func requirePlaceProfileStore(id: UUID) throws -> PlaceProfileStore {
        guard let store = try fetchPlaceProfileStore(id: id) else {
            throw PlaceProfileMutationError.profileNotFound
        }
        return store
    }

    func fetchArtifacts(ids: [UUID]) throws -> [Artifact] {
        guard !ids.isEmpty else { return [] }
        let idSet = Set(ids)
        let artifacts = try modelContext.fetch(FetchDescriptor<ArtifactStore>())
            .map(\.domainModel)
            .filter { idSet.contains($0.id) }
        let artifactsByID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
        return ids.compactMap { artifactsByID[$0] }
    }

    // MARK: - Private: Normalization Helpers

    func normalizedPlaceDisplayName(_ displayName: String) throws -> String {
        guard let resolvedName = displayName.trimmedOrNil else {
            throw PlaceProfileMutationError.emptyDisplayName
        }
        return resolvedName
    }

    func normalizedPlaceAliases(_ values: [String?]) -> [String] {
        var seen = Set<String>()
        var aliases: [String] = []
        for value in values {
            guard let trimmed = value?.trimmedOrNil else { continue }
            let key = PlaceContextResolver.normalizedName(trimmed)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            aliases.append(trimmed)
        }
        return aliases
    }

    func normalizedPersonAliases(_ values: [String?]) -> [String] {
        var seen = Set<String>()
        var aliases: [String] = []
        for value in values {
            guard let trimmed = value?.trimmedOrNil else { continue }
            let key = PlaceContextResolver.normalizedName(trimmed)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            aliases.append(trimmed)
        }
        return aliases
    }


}
