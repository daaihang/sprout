import Foundation
import SwiftData

extension MoryMemoryRepository {
    // MARK: - Entity Graph

    func fetchEntityDetails(kind: EntityKind, limit: Int? = nil) throws -> [EntityDetailSnapshot] {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
        let entities = graphContext.entities
            .filter { $0.kind == kind }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { graphContext.makeEntityDetailSnapshot(entity: $0) }
        return applyLimit(limit, to: entities)
    }

    func fetchEntityDetail(entityID: UUID) throws -> EntityDetailSnapshot? {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
        guard let entity = graphContext.entities.first(where: { $0.id == entityID }) else {
            return nil
        }
        let detail = graphContext.makeEntityDetailSnapshot(entity: entity)
        let flags = try fetchV6FeatureFlags()
        let profile = flags.entityProfiles ? try fetchEntityProfile(entityID: entityID) : nil
        let pendingQuestions = flags.clarificationQuestions
            ? try fetchClarificationQuestions(status: .pending, limit: nil)
                .filter { $0.targetType == .entity && $0.targetID == entityID }
                .sorted {
                    if $0.priority != $1.priority { return $0.priority > $1.priority }
                    return $0.createdAt > $1.createdAt
                }
            : []
        return EntityDetailSnapshot(
            entity: detail.entity,
            artifactCount: detail.artifactCount,
            relatedMemories: detail.relatedMemories,
            relatedThemes: detail.relatedThemes,
            relatedPeople: detail.relatedPeople,
            relatedReflections: detail.relatedReflections,
            relatedArcs: detail.relatedArcs,
            edges: detail.edges,
            intelligenceProfile: profile,
            pendingQuestions: pendingQuestions
        )
    }

    func fetchPeopleSummaries(limit: Int? = nil) throws -> [PersonMemorySummary] {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories,
            entityKinds: [.person]
        )
        let summaries = graphContext.entities
            .filter { $0.kind == .person }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { graphContext.makePersonSummary(entity: $0) }
        return applyLimit(limit, to: summaries)
    }

    func fetchThemeSummaries(limit: Int? = nil) throws -> [ThemeMemorySummary] {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories,
            entityKinds: [.theme]
        )
        let summaries = graphContext.entities
            .filter { $0.kind == .theme }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { graphContext.makeThemeSummary(entity: $0) }

        return applyLimit(limit, to: summaries)
    }

    func fetchPersonDetail(entityID: UUID) throws -> PersonDetailSnapshot? {
        guard let entity = try fetchEntityDetail(entityID: entityID) else {
            return nil
        }
        guard let personSummary = try fetchPeopleSummaries(limit: nil).first(where: { $0.entity.id == entityID }) else {
            return nil
        }
        return PersonDetailSnapshot(
            summary: personSummary,
            relatedArcs: entity.relatedArcs,
            relatedReflections: entity.relatedReflections
        )
    }

    func fetchGraphOverview(limitPerKind: Int? = nil, edgeLimit: Int? = nil) throws -> GraphOverviewSnapshot {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
        let groupedEntities = Dictionary(grouping: graphContext.entities, by: \.kind)
        let orderedKinds: [EntityKind] = [.person, .place, .theme, .decision]

        let entitySections: [GraphEntitySectionSnapshot] = orderedKinds.compactMap { kind -> GraphEntitySectionSnapshot? in
            guard let entities = groupedEntities[kind], !entities.isEmpty else { return nil }
            let limited = applyLimit(limitPerKind, to: entities.sorted { $0.updatedAt > $1.updatedAt })
            return GraphEntitySectionSnapshot(kind: kind, entities: limited)
        }

        let topEdges = applyLimit(
            edgeLimit,
            to: graphContext.edges.sorted {
                if $0.weight == $1.weight {
                    return $0.lastSeenAt > $1.lastSeenAt
                }
                return $0.weight > $1.weight
            }
        )

        let people = try fetchPeopleSummaries(limit: limitPerKind)
        let themes = try fetchThemeSummaries(limit: limitPerKind)

        return GraphOverviewSnapshot(
            entitySections: entitySections,
            topEdges: topEdges,
            people: people,
            themes: themes
        )
    }

    func fetchInsightsPresentation(limitPerSection: Int? = nil) throws -> InsightsPresentationSnapshot {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
        let activeStorylines = graphContext.arcs
            .filter { $0.status != .archived && $0.status != .merged }
            .sorted { lhs, rhs in
                if lhs.status != rhs.status {
                    return lhs.status == .accepted
                }
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.clusterStrength > rhs.clusterStrength
            }
            .map { arc in
                TemporalArcSummarySnapshot(
                    arc: arc,
                    relatedMemories: graphContext.relatedMemories(recordIDs: arc.sourceRecordIDs, limit: 3),
                    linkedReflection: graphContext.reflections.first { $0.linkedTemporalArcID == arc.id }
                )
            }
        let suggestedReflections = graphContext.reflections
            .filter { $0.status == .suggested }
            .sorted { lhs, rhs in
                if lhs.confidence != rhs.confidence {
                    return lhs.confidence > rhs.confidence
                }
                return lhs.createdAt > rhs.createdAt
            }
            .map { reflection in
                makeReflectionSummary(reflection: reflection, graphContext: graphContext)
            }
        let savedReflections = graphContext.reflections
            .filter { $0.status == .saved }
            .sorted { $0.createdAt > $1.createdAt }
            .map { reflection in
                makeReflectionSummary(reflection: reflection, graphContext: graphContext)
            }
        let entityDetails = graphContext.entities
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { graphContext.makeEntityDetailSnapshot(entity: $0) }

        return InsightsPresentationSnapshot(
            highlightedStoryline: activeStorylines.first(where: { $0.arc.status == .accepted }) ?? activeStorylines.first,
            storylines: applyLimit(limitPerSection, to: activeStorylines),
            suggestedReflections: applyLimit(limitPerSection, to: suggestedReflections),
            savedReflections: applyLimit(limitPerSection, to: savedReflections),
            people: applyLimit(limitPerSection, to: entityDetails.filter { $0.entity.kind == .person }),
            places: applyLimit(limitPerSection, to: entityDetails.filter { $0.entity.kind == .place }),
            themes: applyLimit(limitPerSection, to: entityDetails.filter { $0.entity.kind == .theme }),
            decisions: applyLimit(limitPerSection, to: entityDetails.filter { $0.entity.kind == .decision }),
            topEdges: applyLimit(limitPerSection, to: graphContext.edges.sorted {
                if $0.weight == $1.weight {
                    return $0.lastSeenAt > $1.lastSeenAt
                }
                return $0.weight > $1.weight
            }),
            totalStorylineCount: activeStorylines.count,
            totalReflectionCount: graphContext.reflections.filter { $0.status != .archived && $0.status != .dismissed }.count,
            totalEntityCount: entityDetails.count
        )
    }

    func upsertEntityNode(_ entityNode: EntityNode) throws {
        try upsert(entityNode: entityNode)
        try save()
    }

}
