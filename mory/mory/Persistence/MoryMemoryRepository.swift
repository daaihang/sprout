import Foundation
import SwiftData

private struct GraphContext {
    let entities: [EntityNode]
    let edges: [EntityEdge]
    let links: [ArtifactEntityLink]
    let artifacts: [Artifact]
    let analyses: [RecordAnalysisSnapshot]
    let reflections: [ReflectionSnapshot]
    let arcs: [TemporalArc]
    let memoriesByRecordID: [UUID: MemorySummary]
}

@MainActor
final class MoryMemoryRepository: MoryMemoryRepositorying {
    private let modelContext: ModelContext
    private let analysisService: any RecordAnalysisServing
    private let analysisPipeline = AnalysisPipeline()
    private let temporalArcService = TemporalArcService()
    private let reflectionBuilder = ReflectionBuilder()
    private var latestReflectionTrace: DebugPipelineTraceSnapshot?

    init(
        modelContext: ModelContext,
        analysisService: any RecordAnalysisServing
    ) {
        self.modelContext = modelContext
        self.analysisService = analysisService
    }

    func createMemory(from draft: MemoryCaptureDraft) async throws -> MemorySummary {
        let now = Date.now
        let recordID = UUID()
        let captureArtifacts = buildArtifacts(from: draft, recordID: recordID, createdAt: now)
        let normalizedText = resolvedRecordRawText(from: draft, artifacts: captureArtifacts)

        let recordShell = RecordShell(
            id: recordID,
            createdAt: now,
            updatedAt: now,
            captureSource: draft.captureSource,
            rawText: normalizedText,
            userMood: draft.mood?.trimmedOrNil,
            userIntensity: nil,
            inputContext: draft.inputContext?.trimmedOrNil,
            artifactIDs: captureArtifacts.map(\.id),
            debugFixtureSeededAt: draft.inputContext == "debug fixture seed" ? now : nil
        )

        try upsert(recordShell: recordShell)
        try captureArtifacts.forEach { try upsert(artifact: $0) }
        try upsertPipelineStatus(
            MemoryPipelineStatusSnapshot(
                recordID: recordID,
                stage: .pending,
                lastError: nil,
                requestBody: nil,
                responseBody: nil,
                rawErrorBody: nil,
                lastHTTPStatusCode: nil,
                failedStage: nil,
                lastAttemptAt: nil,
                completedAt: nil,
                updatedAt: now
            )
        )
        try save()

        return makeMemorySummary(
            record: recordShell,
            artifacts: captureArtifacts,
            pipelineStatus: try fetchPipelineStatus(recordID: recordID)
        )
    }

    func updateMemory(recordID: UUID, draft: MemoryEditDraft) async throws -> MemoryDetailSnapshot? {
        guard let existingRecordStore = try modelContext.fetch(
            FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordID })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let now = Date.now
        let trimmedRawText = draft.rawText.trimmedOrNil ?? existingRecordStore.rawText
        var updatedRecord = existingRecordStore.domainModel
        updatedRecord.rawText = trimmedRawText
        updatedRecord.userMood = draft.userMood?.trimmedOrNil
        updatedRecord.inputContext = draft.inputContext?.trimmedOrNil
        updatedRecord.updatedAt = now

        existingRecordStore.apply(domainModel: updatedRecord)

        if let appendedArtifactText = draft.appendedArtifactText?.trimmedOrNil {
            let appendedArtifact = Artifact(
                recordID: recordID,
                kind: .text,
                title: appendedArtifactText.firstMeaningfulLine ?? "Added Note",
                summary: appendedArtifactText,
                textContent: appendedArtifactText,
                payload: .text(appendedArtifactText),
                metadata: ["origin": "memory_detail_edit"],
                createdAt: now,
                updatedAt: now
            )
            try upsert(artifact: appendedArtifact)
            updatedRecord.artifactIDs.append(appendedArtifact.id)
            updatedRecord.artifactIDs = Array(NSOrderedSet(array: updatedRecord.artifactIDs)) as? [UUID] ?? Array(Set(updatedRecord.artifactIDs))
            existingRecordStore.apply(domainModel: updatedRecord)
        }

        try upsertPipelineStatus(
            MemoryPipelineStatusSnapshot(
                recordID: recordID,
                stage: .pending,
                lastError: nil,
                requestBody: nil,
                responseBody: nil,
                rawErrorBody: nil,
                lastHTTPStatusCode: nil,
                failedStage: nil,
                lastAttemptAt: nil,
                completedAt: nil,
                updatedAt: now
            )
        )
        try save()

        return try fetchMemoryDetail(recordID: recordID)
    }

    func refreshMemoryPipeline(recordID: UUID) async throws {
        guard let record = try fetchRecordShell(id: recordID) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let artifacts = try fetchArtifacts(recordID: recordID)
        let attemptAt = Date.now

        try upsertPipelineStatus(
            MemoryPipelineStatusSnapshot(
                recordID: recordID,
                stage: .running,
                lastError: nil,
                requestBody: try fetchPipelineStatus(recordID: recordID)?.requestBody,
                responseBody: nil,
                rawErrorBody: nil,
                lastHTTPStatusCode: nil,
                failedStage: nil,
                lastAttemptAt: attemptAt,
                completedAt: nil,
                updatedAt: attemptAt
            )
        )
        try save()

        do {
            try await runArchitecturePipeline(record: record, artifacts: artifacts)
            let trace = await analysisService.latestDebugTrace()
            let completedAt = Date.now
            try upsertPipelineStatus(
                MemoryPipelineStatusSnapshot(
                    recordID: recordID,
                    stage: .completed,
                    lastError: nil,
                    requestBody: trace?.requestBody,
                    responseBody: trace?.responseBody,
                    rawErrorBody: nil,
                    lastHTTPStatusCode: trace?.statusCode,
                    failedStage: nil,
                    lastAttemptAt: attemptAt,
                    completedAt: completedAt,
                    updatedAt: completedAt
                )
            )
            try save()
        } catch {
            let trace = await analysisService.latestDebugTrace()
            let failedAt = Date.now
            try upsertPipelineStatus(
                MemoryPipelineStatusSnapshot(
                    recordID: recordID,
                    stage: .failed,
                    lastError: error.localizedDescription,
                    requestBody: trace?.requestBody,
                    responseBody: trace?.responseBody,
                    rawErrorBody: trace?.rawErrorBody,
                    lastHTTPStatusCode: trace?.statusCode,
                    failedStage: trace?.failedStage,
                    lastAttemptAt: attemptAt,
                    completedAt: nil,
                    updatedAt: failedAt
                )
            )
            try save()
            throw error
        }
    }

    func fetchRecordShells() throws -> [RecordShell] {
        let descriptor = FetchDescriptor<RecordShellStore>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domainModel)
    }

    func fetchRecentMemories(limit: Int? = nil) throws -> [MemorySummary] {
        let records = try fetchRecordShells()
        let summaries = try records.map { record in
            let artifacts = try fetchArtifacts(recordID: record.id)
            return makeMemorySummary(
                record: record,
                artifacts: artifacts,
                pipelineStatus: try fetchPipelineStatus(recordID: record.id)
            )
        }

        guard let limit else { return summaries }
        return Array(summaries.prefix(limit))
    }

    func fetchHomeBoard(for date: Date, limit: Int = 8) throws -> HomeBoardSnapshot {
        let memories = try fetchRecentMemories(limit: limit)
        let graphContext = try loadGraphContext()
        let boardStore = try ensureHomeBoard(for: date)
        let compositionStore = try ensureHomeComposition(for: boardStore)
        let itemStores = try ensureHomeBoardItems(
            boardStore: boardStore,
            compositionStore: compositionStore,
            memories: memories,
            arcs: fetchBoardEligibleArcs(from: graphContext, limit: 2),
            reflections: fetchBoardEligibleReflections(from: graphContext, limit: 2)
        )

        let memoriesByRecordID = Dictionary(uniqueKeysWithValues: memories.map { ($0.record.id, $0) })
        let arcsByID = Dictionary(uniqueKeysWithValues: graphContext.arcs.map { ($0.id, $0) })
        let reflectionsByID = Dictionary(uniqueKeysWithValues: graphContext.reflections.map { ($0.id, $0) })
        let items = itemStores
            .sorted { $0.zIndex < $1.zIndex }
            .compactMap { store in
                resolveHomeBoardItemSnapshot(
                    from: store.domainModel,
                    memoriesByRecordID: memoriesByRecordID,
                    arcsByID: arcsByID,
                    reflectionsByID: reflectionsByID
                )
            }

        return HomeBoardSnapshot(
            board: boardStore.domainModel,
            composition: compositionStore.domainModel,
            items: items
        )
    }

    func fetchArtifacts(recordID: UUID) throws -> [Artifact] {
        let descriptor = FetchDescriptor<ArtifactStore>(
            predicate: #Predicate { $0.recordID == recordID },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domainModel)
    }

    func fetchRecordShell(id: UUID) throws -> RecordShell? {
        let descriptor = FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func fetchPipelineStatus(recordID: UUID) throws -> MemoryPipelineStatusSnapshot? {
        let descriptor = FetchDescriptor<MemoryPipelineStatusStore>(
            predicate: #Predicate { $0.recordID == recordID }
        )
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func fetchPipelineStatusSummaries(limit: Int? = nil) throws -> [PipelineStatusSummary] {
        let statuses = try modelContext.fetch(
            FetchDescriptor<MemoryPipelineStatusStore>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        ).map(\.domainModel)

        let summaries = try statuses.compactMap { status -> PipelineStatusSummary? in
            guard let record = try fetchRecordShell(id: status.recordID) else { return nil }
            return PipelineStatusSummary(
                recordID: status.recordID,
                title: record.rawText.firstMeaningfulLine ?? "Untitled Memory",
                status: status
            )
        }

        return applyLimit(limit, to: summaries)
    }

    func fetchMemoryDetail(recordID: UUID) throws -> MemoryDetailSnapshot? {
        guard let record = try fetchRecordShell(id: recordID) else {
            return nil
        }

        let graphContext = try loadGraphContext()
        let artifacts = try fetchArtifacts(recordID: recordID)
        let links = graphContext.links.filter { link in artifacts.contains(where: { $0.id == link.artifactID }) }
        let entityIDs = Set(links.map(\.entityID))
        let entities = graphContext.entities.filter { entityIDs.contains($0.id) }
        let arcs = graphContext.arcs.filter { $0.sourceRecordIDs.contains(recordID) }
        let reflections = graphContext.reflections.filter { reflection in
            reflection.sourceRecordIDs.contains(recordID)
                || arcs.contains(where: { $0.id == reflection.linkedTemporalArcID })
        }
        let edgeIDs = Set(entities.map(\.id))
        let edges = graphContext.edges.filter {
            edgeIDs.contains($0.fromEntityID) || edgeIDs.contains($0.toEntityID) || $0.sourceRecordIDs.contains(recordID)
        }

        return MemoryDetailSnapshot(
            record: record,
            artifacts: artifacts,
            analysis: try fetchRecordAnalysis(recordID: recordID),
            pipelineStatus: try fetchPipelineStatus(recordID: recordID),
            entities: entities,
            edges: edges,
            arcs: arcs,
            reflections: reflections
        )
    }

    func fetchRecordAnalysis(recordID: UUID) throws -> RecordAnalysisSnapshot? {
        let descriptor = FetchDescriptor<RecordAnalysisSnapshotStore>(
            predicate: #Predicate { $0.recordID == recordID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func search(query: String, limit: Int? = nil) throws -> SearchSnapshot {
        let needle = query.normalizedSearchTerm
        guard let needle else {
            return SearchSnapshot(query: query, memories: [], entities: [], arcs: [], reflections: [])
        }

        let graphContext = try loadGraphContext()
        let analysesByRecordID = Dictionary(
            uniqueKeysWithValues: graphContext.analyses.map { ($0.recordID, $0) }
        )
        let memories = try fetchRecentMemories(limit: nil)
            .filter { memory in
                [
                    memory.title,
                    memory.summaryText,
                    memory.record.rawText,
                    memory.record.userMood ?? ""
                ].containsSearchTerm(needle)
            }
            .sorted { lhs, rhs in
                let leftScore = analysesByRecordID[lhs.record.id]?.salienceScore ?? 0
                let rightScore = analysesByRecordID[rhs.record.id]?.salienceScore ?? 0
                if leftScore == rightScore {
                    return lhs.record.updatedAt > rhs.record.updatedAt
                }
                return leftScore > rightScore
            }
            .map(SearchMemoryResultSnapshot.init(memory:))

        let entities = graphContext.entities
            .filter { entity in
                [entity.displayName, entity.canonicalName, entity.summary].containsSearchTerm(needle)
            }
            .map { makeSearchEntityResult(entity: $0, graphContext: graphContext) }
            .sorted { lhs, rhs in
                if lhs.arcCount == rhs.arcCount {
                    if lhs.reflectionCount == rhs.reflectionCount {
                        return lhs.relatedMemoryCount > rhs.relatedMemoryCount
                    }
                    return lhs.reflectionCount > rhs.reflectionCount
                }
                return lhs.arcCount > rhs.arcCount
            }

        let arcs = graphContext.arcs
            .filter { arc in
            [arc.title, arc.summary, arc.dominantTheme ?? "", arc.dominantEntityName ?? ""].containsSearchTerm(needle)
                || arc.themeLabels.containsSearchTerm(needle)
                || arc.entityNames.containsSearchTerm(needle)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { arc in
                SearchArcResultSnapshot(
                    summary: TemporalArcSummarySnapshot(
                        arc: arc,
                        relatedMemories: relatedMemories(
                            recordIDs: arc.sourceRecordIDs,
                            memoriesByRecordID: graphContext.memoriesByRecordID,
                            limit: 3
                        ),
                        linkedReflection: graphContext.reflections.first(where: { $0.linkedTemporalArcID == arc.id })
                    )
                )
            }
            .sorted { lhs, rhs in
                if lhs.summary.arc.intensityScore == rhs.summary.arc.intensityScore {
                    return lhs.summary.arc.updatedAt > rhs.summary.arc.updatedAt
                }
                return lhs.summary.arc.intensityScore > rhs.summary.arc.intensityScore
            }

        let reflections = try fetchReflectionSummaries(limit: nil)
            .filter { summary in
                let reflection = summary.reflection
                return [reflection.title, reflection.body, reflection.evidenceSummary].containsSearchTerm(needle)
            }
            .map(SearchReflectionResultSnapshot.init(summary:))
            .sorted { lhs, rhs in
                if lhs.summary.reflection.confidence == rhs.summary.reflection.confidence {
                    return lhs.summary.reflection.createdAt > rhs.summary.reflection.createdAt
                }
                return lhs.summary.reflection.confidence > rhs.summary.reflection.confidence
            }

        return SearchSnapshot(
            query: query,
            memories: applyLimit(limit, to: memories),
            entities: applyLimit(limit, to: entities),
            arcs: applyLimit(limit, to: arcs),
            reflections: applyLimit(limit, to: reflections)
        )
    }

    func fetchEntityDetails(kind: EntityKind, limit: Int? = nil) throws -> [EntityDetailSnapshot] {
        let graphContext = try loadGraphContext()
        let entities = graphContext.entities
            .filter { $0.kind == kind }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { makeEntityDetailSnapshot(entity: $0, graphContext: graphContext) }
        return applyLimit(limit, to: entities)
    }

    func fetchEntityDetail(entityID: UUID) throws -> EntityDetailSnapshot? {
        let graphContext = try loadGraphContext()
        guard let entity = graphContext.entities.first(where: { $0.id == entityID }) else {
            return nil
        }
        return makeEntityDetailSnapshot(entity: entity, graphContext: graphContext)
    }

    func fetchPeopleSummaries(limit: Int? = nil) throws -> [PersonMemorySummary] {
        let personEntities = try modelContext.fetch(
            FetchDescriptor<EntityNodeStore>(
                predicate: #Predicate { $0.kindRawValue == "person" },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        ).map(\.domainModel)

        let graphContext = try loadGraphContext()
        let summaries = personEntities.map { entity in
            makePersonSummary(entity: entity, graphContext: graphContext)
        }
        return applyLimit(limit, to: summaries)
    }

    func fetchThemeSummaries(limit: Int? = nil) throws -> [ThemeMemorySummary] {
        let themeEntities = try modelContext.fetch(
            FetchDescriptor<EntityNodeStore>(
                predicate: #Predicate { $0.kindRawValue == "theme" },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        ).map(\.domainModel)

        let graphContext = try loadGraphContext()
        let summaries = themeEntities.map { entity in
            makeThemeSummary(entity: entity, graphContext: graphContext)
        }

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
        let graphContext = try loadGraphContext()
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

    func fetchTemporalArcs(limit: Int? = nil) throws -> [TemporalArc] {
        let arcs = try modelContext.fetch(
            FetchDescriptor<TemporalArcStore>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        ).map(\.domainModel)
        return applyLimit(limit, to: arcs)
    }

    func fetchTemporalArcSummaries(limit: Int? = nil) throws -> [TemporalArcSummarySnapshot] {
        let graphContext = try loadGraphContext()
        let arcs = applyLimit(
            limit,
            to: graphContext.arcs.sorted { $0.updatedAt > $1.updatedAt }
        )

        let reflectionPairs: [(UUID, ReflectionSnapshot)] = graphContext.reflections.compactMap { reflection in
            guard let arcID = reflection.linkedTemporalArcID else { return nil }
            return (arcID, reflection)
        }
        let reflectionsByArcID = Dictionary(uniqueKeysWithValues: reflectionPairs)

        return arcs.map { arc in
            TemporalArcSummarySnapshot(
                arc: arc,
                relatedMemories: relatedMemories(
                    recordIDs: arc.sourceRecordIDs,
                    memoriesByRecordID: graphContext.memoriesByRecordID,
                    limit: 3
                ),
                linkedReflection: reflectionsByArcID[arc.id]
            )
        }
    }

    func fetchTemporalArcDetail(arcID: UUID) throws -> TemporalArcDetailSnapshot? {
        let graphContext = try loadGraphContext()
        guard let arc = graphContext.arcs.first(where: { $0.id == arcID }) else { return nil }
        let mergePreview = temporalArcService.mergePreview(sourceArcID: arcID, arcs: graphContext.arcs)
        let mergeCandidate = mergePreview.flatMap { preview in
            graphContext.arcs.first(where: { $0.id == preview.candidateArcID })
        }
        let summary = TemporalArcSummarySnapshot(
            arc: arc,
            relatedMemories: relatedMemories(
                recordIDs: arc.sourceRecordIDs,
                memoriesByRecordID: graphContext.memoriesByRecordID,
                limit: 3
            ),
            linkedReflection: graphContext.reflections.first(where: { $0.linkedTemporalArcID == arc.id })
        )
        let reflectionSummaries = graphContext.reflections
            .filter { $0.linkedTemporalArcID == arc.id || $0.sourceRecordIDs.contains(where: { arc.sourceRecordIDs.contains($0) }) }
            .sorted { $0.createdAt > $1.createdAt }
            .map { reflection in
                let linkedArc = reflection.linkedTemporalArcID.flatMap { id in graphContext.arcs.first(where: { $0.id == id }) }
                return ReflectionSummarySnapshot(
                    reflection: reflection,
                    linkedArc: linkedArc,
                    relatedMemories: relatedMemories(
                        recordIDs: mergeUniqueIDs(reflection.sourceRecordIDs, arc.sourceRecordIDs),
                        memoriesByRecordID: graphContext.memoriesByRecordID,
                        limit: 3
                    )
                )
            }
        let entityDetails = graphContext.entities
            .filter { arc.sourceEntityIDs.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { makeEntityDetailSnapshot(entity: $0, graphContext: graphContext) }
        return TemporalArcDetailSnapshot(
            summary: summary,
            reflections: reflectionSummaries,
            entityDetails: entityDetails,
            mergeCandidate: mergeCandidate.map { candidateArc in
                TemporalArcSummarySnapshot(
                    arc: candidateArc,
                    relatedMemories: relatedMemories(
                        recordIDs: candidateArc.sourceRecordIDs,
                        memoriesByRecordID: graphContext.memoriesByRecordID,
                        limit: 3
                    ),
                    linkedReflection: graphContext.reflections.first(where: { $0.linkedTemporalArcID == candidateArc.id })
                )
            },
            mergeCandidateOverlapScore: mergePreview?.overlapScore
        )
    }

    func acceptTemporalArc(arcID: UUID) async throws {
        guard let existing = try modelContext.fetch(FetchDescriptor<TemporalArcStore>(predicate: #Predicate { $0.id == arcID })).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        var updated = existing.domainModel
        updated.status = .accepted
        updated.updatedAt = Date.now
        existing.apply(domainModel: updated)
        try save()
    }

    func archiveTemporalArc(arcID: UUID) async throws {
        guard let existing = try modelContext.fetch(FetchDescriptor<TemporalArcStore>(predicate: #Predicate { $0.id == arcID })).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        var updated = existing.domainModel
        updated.status = .archived
        updated.updatedAt = Date.now
        existing.apply(domainModel: updated)
        try save()
    }

    func mergeTemporalArc(arcID: UUID) async throws -> TemporalArcDetailSnapshot? {
        let graphContext = try loadGraphContext()
        guard let sourceArcStore = try modelContext.fetch(
            FetchDescriptor<TemporalArcStore>(predicate: #Predicate { $0.id == arcID })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        guard let sourceArc = graphContext.arcs.first(where: { $0.id == arcID }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        guard let mergePreview = temporalArcService.mergePreview(sourceArcID: arcID, arcs: graphContext.arcs),
              let candidateArcStore = try modelContext.fetch(FetchDescriptor<TemporalArcStore>()).first(where: { $0.id == mergePreview.candidateArcID }),
              let candidateArc = graphContext.arcs.first(where: { $0.id == mergePreview.candidateArcID }) else {
            return try fetchTemporalArcDetail(arcID: arcID)
        }

        let linkedReflection = sourceArc.linkedReflectionID.flatMap { linkedID in
            graphContext.reflections.first(where: { $0.id == linkedID })
        }
        let mergeResult = temporalArcService.merge(
            sourceArc: sourceArc,
            candidateArc: candidateArc,
            linkedReflection: linkedReflection
        )

        sourceArcStore.apply(domainModel: mergeResult.sourceArc)
        candidateArcStore.apply(domainModel: mergeResult.candidateArc)
        if let updatedReflection = mergeResult.updatedReflection {
            try upsert(reflection: updatedReflection)
        }
        try save()

        return try fetchTemporalArcDetail(arcID: mergeResult.sourceArc.id)
    }

    func fetchReflections(limit: Int? = nil) throws -> [ReflectionSnapshot] {
        let reflections = try modelContext.fetch(
            FetchDescriptor<ReflectionSnapshotStore>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        ).map(\.domainModel)
        return applyLimit(limit, to: reflections)
    }

    func fetchReflectionSummaries(limit: Int? = nil) throws -> [ReflectionSummarySnapshot] {
        let graphContext = try loadGraphContext()
        let reflections = applyLimit(
            limit,
            to: graphContext.reflections.sorted { $0.createdAt > $1.createdAt }
        )
        let arcsByID = Dictionary(uniqueKeysWithValues: graphContext.arcs.map { ($0.id, $0) })

        return reflections.map { reflection in
            let linkedArc = reflection.linkedTemporalArcID.flatMap { arcsByID[$0] }
            let relatedRecordIDs = linkedArc.map { mergeUniqueIDs(reflection.sourceRecordIDs, $0.sourceRecordIDs) } ?? reflection.sourceRecordIDs

            return ReflectionSummarySnapshot(
                reflection: reflection,
                linkedArc: linkedArc,
                relatedMemories: relatedMemories(
                    recordIDs: relatedRecordIDs,
                    memoriesByRecordID: graphContext.memoriesByRecordID,
                    limit: 3
                )
            )
        }
    }

    func fetchReflectionDetail(reflectionID: UUID) throws -> ReflectionDetailSnapshot? {
        let graphContext = try loadGraphContext()
        guard let reflection = graphContext.reflections.first(where: { $0.id == reflectionID }) else { return nil }
        let linkedArc = reflection.linkedTemporalArcID.flatMap { arcID in
            graphContext.arcs.first(where: { $0.id == arcID })
        }
        let summary = ReflectionSummarySnapshot(
            reflection: reflection,
            linkedArc: linkedArc,
            relatedMemories: relatedMemories(
                recordIDs: linkedArc.map { mergeUniqueIDs(reflection.sourceRecordIDs, $0.sourceRecordIDs) } ?? reflection.sourceRecordIDs,
                memoriesByRecordID: graphContext.memoriesByRecordID,
                limit: 3
            )
        )
        let entityDetails = graphContext.entities
            .filter { reflection.sourceEntityIDs.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { makeEntityDetailSnapshot(entity: $0, graphContext: graphContext) }
        return ReflectionDetailSnapshot(
            summary: summary,
            linkedArc: linkedArc.map {
                TemporalArcSummarySnapshot(
                    arc: $0,
                    relatedMemories: relatedMemories(
                        recordIDs: $0.sourceRecordIDs,
                        memoriesByRecordID: graphContext.memoriesByRecordID,
                        limit: 3
                    ),
                    linkedReflection: graphContext.reflections.first(where: { $0.linkedTemporalArcID == reflection.linkedTemporalArcID })
                )
            },
            entityDetails: entityDetails
        )
    }

    func fetchDebugDiagnostics(targetType: DebugAnalysisTarget, targetID: UUID?) throws -> DebugDiagnosticsSnapshot {
        let target = try resolveDebugTarget(targetType: targetType, targetID: targetID)
        let fixture: DebugMemoryFixtureSnapshot?
        if let target {
            switch target.targetType {
            case .memory:
                if let memory = target.memory {
                    fixture = try fetchDebugFixtureSnapshot(recordID: memory.record.id)
                } else {
                    fixture = nil
                }
            case .arc, .reflection:
                fixture = nil
            }
        } else {
            fixture = nil
        }

        let provenance = try fetchDebugProvenance(targetType: targetType, targetID: targetID)
        let analyzePayload = try debugAnalyzePayload(for: target)
        let reflectionPayload = try debugReflectionPayload(for: target)
        let pipelineTrace = try resolveDebugRecordID(targetType: targetType, targetID: targetID)
            .flatMap { try fetchPipelineStatus(recordID: $0) }
            .map {
                DebugPipelineTraceSnapshot(
                    requestBody: $0.requestBody,
                    responseBody: $0.responseBody,
                    rawErrorBody: $0.rawErrorBody,
                    statusCode: $0.lastHTTPStatusCode,
                    failedStage: $0.failedStage
                )
            }

        return DebugDiagnosticsSnapshot(
            target: target,
            analyzePayload: analyzePayload,
            reflectionPayload: reflectionPayload,
            provenance: provenance,
            fixture: fixture,
            pipelineTrace: pipelineTrace
        )
    }

    func rerunDebugPipeline(targetType: DebugAnalysisTarget, targetID: UUID?, mode: DebugRebuildMode) async throws {
        switch mode {
        case .analysisOnly:
            guard let recordID = try resolveDebugRecordID(targetType: targetType, targetID: targetID) else {
                throw CocoaError(.fileNoSuchFile)
            }
            try await refreshMemoryPipeline(recordID: recordID)
        case .graphArcReflection:
            guard let recordID = try resolveDebugRecordID(targetType: targetType, targetID: targetID) else {
                throw CocoaError(.fileNoSuchFile)
            }
            try await rerunGraphArcReflection(recordID: recordID)
        case .reflectionReplay:
            guard let reflection = try resolveDebugTarget(targetType: targetType, targetID: targetID)?.reflection else {
                throw CocoaError(.fileNoSuchFile)
            }
            try await replayDebugReflection(reflectionID: reflection.reflection.id)
        }
    }

    func seedDebugFixtures(count: Int) async throws -> [DebugMemoryFixtureSnapshot] {
        let fixtureCount = max(1, count)
        var fixtures: [DebugMemoryFixtureSnapshot] = []
        for index in 0..<fixtureCount {
            let draft = MemoryCaptureDraft(
                title: "Debug fixture \(index + 1)",
                rawText: "Fixture \(index + 1) with Linh and a planning note.",
                mood: "reflective",
                inputContext: "debug fixture seed",
                captureSource: .manual
            )
            let memory = try await createMemory(from: draft)
            try await refreshMemoryPipeline(recordID: memory.record.id)
            if let fixture = try fetchDebugFixtureSnapshot(recordID: memory.record.id) {
                fixtures.append(fixture)
            }
        }
        return fixtures
    }

    func clearDebugFixtures() throws {
        let records = try fetchRecordShells()
        for record in records {
            guard record.debugFixtureSeededAt != nil || record.inputContext == "debug fixture seed" else {
                continue
            }
            try deleteDebugRecord(recordID: record.id)
        }
        try save()
    }

    func saveReflection(reflectionID: UUID) async throws {
        try updateReflectionStatus(reflectionID: reflectionID, status: .saved)
    }

    func dismissReflection(reflectionID: UUID) async throws {
        try updateReflectionStatus(reflectionID: reflectionID, status: .dismissed)
    }

    func archiveReflection(reflectionID: UUID) async throws {
        try updateReflectionStatus(reflectionID: reflectionID, status: .archived)
    }

    func rerunGraphArcReflection(recordID: UUID) async throws {
        guard let record = try fetchRecordShell(id: recordID) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let artifacts = try fetchArtifacts(recordID: recordID)
        try await runArchitecturePipeline(record: record, artifacts: artifacts)
    }

    func seedDebugFixture() async throws -> DebugMemoryFixtureSnapshot {
        let draft = MemoryCaptureDraft(
            title: "Late train, quiet insight",
            rawText: "Missed the express home after dinner with Linh and ended up walking twenty minutes in the rain. It felt frustrating at first, but the walk made the next quarter plan click into place.",
            mood: "reflective",
            inputContext: "post-dinner voice memo transcribed to text",
            captureSource: .manual
        )
        let memory = try await createMemory(from: draft)

        guard let snapshot = try fetchDebugFixtureSnapshot(recordID: memory.record.id) else {
            throw CocoaError(.coderInvalidValue)
        }
        return snapshot
    }

    private func replayDebugReflection(reflectionID: UUID) async throws {
        guard let reflection = try modelContext.fetch(
            FetchDescriptor<ReflectionSnapshotStore>(predicate: #Predicate { $0.id == reflectionID })
        ).first?.domainModel else {
            throw CocoaError(.fileNoSuchFile)
        }
        let linkedArc = reflection.linkedTemporalArcID.flatMap { arcID in
            try? modelContext.fetch(
                FetchDescriptor<TemporalArcStore>(predicate: #Predicate { $0.id == arcID })
            ).first?.domainModel
        } ?? nil
        let record = try reflection.sourceRecordIDs.first.flatMap { try fetchRecordShell(id: $0) }
        let artifacts = try record.map { try fetchArtifacts(recordID: $0.id) } ?? []
        let knownEntities = try linkedEntityReferences(
            recordID: record?.id,
            arcID: linkedArc?.id,
            reflectionID: reflection.id
        )

        let replayResult = try await analysisService.replayReflection(
            reflection: reflection,
            linkedArc: linkedArc,
            record: record,
            artifacts: artifacts,
            knownEntities: knownEntities,
            prompt: reflection.body
        )
        latestReflectionTrace = replayResult.debugTrace
    }

    private func resolveDebugTarget(targetType: DebugAnalysisTarget, targetID: UUID?) throws -> DebugTargetSnapshot? {
        let graphContext = try loadGraphContext()
        switch targetType {
        case .memory:
            let memory: MemorySummary?
            if let targetID {
                memory = try fetchRecentMemories(limit: nil).first(where: { $0.record.id == targetID })
            } else {
                memory = try fetchRecentMemories(limit: 1).first
            }
            guard let memory else { return nil }
            return DebugTargetSnapshot(targetType: .memory, memory: memory, arc: nil, reflection: nil)
        case .arc:
            let arc = graphContext.arcs.first(where: { $0.id == targetID }) ?? graphContext.arcs.first
            guard let arc else { return nil }
            let summary = TemporalArcSummarySnapshot(
                arc: arc,
                relatedMemories: relatedMemories(recordIDs: arc.sourceRecordIDs, memoriesByRecordID: graphContext.memoriesByRecordID, limit: 3),
                linkedReflection: graphContext.reflections.first(where: { $0.linkedTemporalArcID == arc.id })
            )
            return DebugTargetSnapshot(targetType: .arc, memory: nil, arc: summary, reflection: nil)
        case .reflection:
            let reflection = graphContext.reflections.first(where: { $0.id == targetID }) ?? graphContext.reflections.first
            guard let reflection else { return nil }
            let linkedArc = reflection.linkedTemporalArcID.flatMap { linkedArcID in
                graphContext.arcs.first(where: { $0.id == linkedArcID })
            }
            let summary = ReflectionSummarySnapshot(
                reflection: reflection,
                linkedArc: linkedArc,
                relatedMemories: relatedMemories(recordIDs: reflection.sourceRecordIDs, memoriesByRecordID: graphContext.memoriesByRecordID, limit: 3)
            )
            return DebugTargetSnapshot(targetType: .reflection, memory: nil, arc: nil, reflection: summary)
        }
    }

    private func debugAnalyzePayload(for target: DebugTargetSnapshot?) throws -> DebugAnalyzePayloadSnapshot? {
        guard let target, let memory = target.memory else { return nil }
        let pipelineStatus = try fetchPipelineStatus(recordID: memory.record.id)
        let artifacts = try fetchArtifacts(recordID: memory.record.id)
        let request = AnalyzeRequestBuilder().build(
            record: memory.record,
            artifacts: artifacts,
            knownEntities: []
        )
        let encoded = pipelineStatus?.requestBody ?? String(data: (try? JSONEncoder().encode(request)) ?? Data(), encoding: .utf8) ?? ""
        let response = try fetchRecordAnalysis(recordID: memory.record.id)
        let responseEncoded = pipelineStatus?.responseBody ?? response.flatMap { String(data: (try? JSONEncoder().encode($0)) ?? Data(), encoding: .utf8) } ?? ""
        return DebugAnalyzePayloadSnapshot(
            recordID: memory.record.id,
            requestBody: encoded,
            responseBody: responseEncoded,
            lastError: pipelineStatus?.lastError,
            rawErrorBody: pipelineStatus?.rawErrorBody
        )
    }

    private func debugReflectionPayload(for target: DebugTargetSnapshot?) throws -> DebugReflectionPayloadSnapshot? {
        guard let target else { return nil }
        switch target.targetType {
        case .memory:
            guard let memory = target.memory else { return nil }
            let artifacts = try fetchArtifacts(recordID: memory.record.id)
            let analyzePayload = AnalyzeRequestBuilder().build(record: memory.record, artifacts: artifacts)
            let payload = MoryAPIClient.ReflectionPayload(
                recordShell: analyzePayload.recordShell,
                artifacts: analyzePayload.artifacts,
                linkedArcID: nil,
                knownEntities: [],
                prompt: memory.record.rawText
            )
            let requestBody = String(data: (try? JSONEncoder().encode(payload)) ?? Data(), encoding: .utf8) ?? ""
            return DebugReflectionPayloadSnapshot(
                recordID: memory.record.id,
                arcID: nil,
                requestBody: latestReflectionTrace?.requestBody ?? requestBody,
                responseBody: latestReflectionTrace?.responseBody ?? "",
                lastError: latestReflectionTrace?.failedStage,
                rawErrorBody: latestReflectionTrace?.rawErrorBody
            )
        case .arc:
            guard let arc = target.arc else { return nil }
            let payload = MoryAPIClient.ReflectionPayload(
                recordShell: AnalyzeRequestBuilder().build(record: RecordShell(createdAt: .now, updatedAt: .now, captureSource: .manual, rawText: arc.arc.summary), artifacts: []).recordShell,
                artifacts: [],
                linkedArcID: arc.arc.id.uuidString,
                knownEntities: [],
                prompt: arc.arc.summary
            )
            let requestBody = String(data: (try? JSONEncoder().encode(payload)) ?? Data(), encoding: .utf8) ?? ""
            return DebugReflectionPayloadSnapshot(
                recordID: arc.arc.sourceRecordIDs.first,
                arcID: arc.arc.id,
                requestBody: latestReflectionTrace?.requestBody ?? requestBody,
                responseBody: latestReflectionTrace?.responseBody ?? "",
                lastError: latestReflectionTrace?.failedStage,
                rawErrorBody: latestReflectionTrace?.rawErrorBody
            )
        case .reflection:
            guard let reflection = target.reflection else { return nil }
            struct ReflectionReplayDebugRequest: Encodable {
                let reflectionID: String
                let linkedArcID: String?

                enum CodingKeys: String, CodingKey {
                    case reflectionID = "reflection_id"
                    case linkedArcID = "linked_arc_id"
                }
            }
            let request = ReflectionReplayDebugRequest(
                reflectionID: reflection.reflection.id.uuidString,
                linkedArcID: reflection.linkedArc?.id.uuidString
            )
            let requestBody = latestReflectionTrace?.requestBody ?? String(data: (try? JSONEncoder().encode(request)) ?? Data(), encoding: .utf8) ?? ""
            return DebugReflectionPayloadSnapshot(
                recordID: reflection.reflection.sourceRecordIDs.first,
                arcID: reflection.linkedArc?.id,
                requestBody: requestBody,
                responseBody: latestReflectionTrace?.responseBody ?? reflection.reflection.body,
                lastError: latestReflectionTrace?.failedStage,
                rawErrorBody: latestReflectionTrace?.rawErrorBody
            )
        }
    }

    private func linkedEntityReferences(
        recordID: UUID?,
        arcID: UUID?,
        reflectionID: UUID?
    ) throws -> [EntityReference] {
        let graphContext = try loadGraphContext()
        let recordIDs = [recordID]
            + graphContext.arcs.filter { $0.id == arcID }.flatMap(\.sourceRecordIDs)
            + graphContext.reflections.filter { $0.id == reflectionID }.flatMap(\.sourceRecordIDs)
        let targetRecordIDs = Set(recordIDs.compactMap { $0 })

        return graphContext.entities
            .filter { !Set($0.provenanceRecordIDs).isDisjoint(with: targetRecordIDs) }
            .map {
                EntityReference(
                    id: $0.id,
                    kind: $0.kind,
                    name: $0.displayName,
                    aliases: $0.aliases,
                    confidence: $0.confidence
                )
            }
    }

    private func fetchDebugProvenance(targetType: DebugAnalysisTarget, targetID: UUID?) throws -> [DebugProvenanceSnapshot] {
        let graphContext = try loadGraphContext()
        switch targetType {
        case .memory:
            let fallbackMemoryID = try fetchRecentMemories(limit: 1).first?.record.id
            let memoryID = targetID ?? fallbackMemoryID
            guard let memoryID else { return [] }
            return graphContext.entities
                .filter { $0.provenanceRecordIDs.contains(memoryID) }
                .map { entity in
                    DebugProvenanceSnapshot(
                        entityID: entity.id,
                        aliasCount: entity.aliases.count,
                        provenanceRecordIDs: entity.provenanceRecordIDs,
                        linkedArtifactIDs: graphContext.links.filter { $0.entityID == entity.id }.map(\.artifactID),
                        linkedAnalysisRecordIDs: graphContext.links.filter { $0.entityID == entity.id }.compactMap(\.sourceAnalysisRecordID),
                        evidenceSummary: graphContext.links.filter { $0.entityID == entity.id }.map(\.evidenceSummary).joined(separator: " | ")
                    )
                }
        case .arc, .reflection:
            return graphContext.entities.map { entity in
                DebugProvenanceSnapshot(
                    entityID: entity.id,
                    aliasCount: entity.aliases.count,
                    provenanceRecordIDs: entity.provenanceRecordIDs,
                    linkedArtifactIDs: graphContext.links.filter { $0.entityID == entity.id }.map(\.artifactID),
                    linkedAnalysisRecordIDs: graphContext.links.filter { $0.entityID == entity.id }.compactMap(\.sourceAnalysisRecordID),
                    evidenceSummary: graphContext.links.filter { $0.entityID == entity.id }.map(\.evidenceSummary).joined(separator: " | ")
                )
            }
        }
    }

    private func deleteDebugRecord(recordID: UUID) throws {
        if let record = try modelContext.fetch(FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordID })).first {
            modelContext.delete(record)
        }
        let artifactStores = try modelContext.fetch(FetchDescriptor<ArtifactStore>(predicate: #Predicate { $0.recordID == recordID }))
        artifactStores.forEach { modelContext.delete($0) }
        let pipelineStores = try modelContext.fetch(FetchDescriptor<MemoryPipelineStatusStore>(predicate: #Predicate { $0.recordID == recordID }))
        pipelineStores.forEach { modelContext.delete($0) }
        let analysisStores = try modelContext.fetch(FetchDescriptor<RecordAnalysisSnapshotStore>(predicate: #Predicate { $0.recordID == recordID }))
        analysisStores.forEach { modelContext.delete($0) }
    }

    private func resolveDebugRecordID(targetType: DebugAnalysisTarget, targetID: UUID?) throws -> UUID? {
        let target = try resolveDebugTarget(targetType: targetType, targetID: targetID)
        switch target?.targetType {
        case .memory:
            return target?.memory?.record.id
        case .arc:
            return target?.arc?.arc.sourceRecordIDs.first
        case .reflection:
            return target?.reflection?.reflection.sourceRecordIDs.first
        case nil:
            return nil
        }
    }

    func fetchDebugFixtureSnapshot(recordID: UUID) throws -> DebugMemoryFixtureSnapshot? {
        guard let record = try fetchRecordShell(id: recordID) else {
            return nil
        }

        let artifacts = try fetchArtifacts(recordID: recordID)
        let analysis = try fetchRecordAnalysis(recordID: recordID)
        let pipelineStatus = try fetchPipelineStatus(recordID: recordID)
        let links = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>()).map(\.domainModel)
            .filter { link in artifacts.contains(where: { $0.id == link.artifactID }) }
        let entityIDs = Set(links.map(\.entityID))
        let entities = try modelContext.fetch(FetchDescriptor<EntityNodeStore>()).map(\.domainModel)
            .filter { entityIDs.contains($0.id) }
        let edges = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>()).map(\.domainModel)
            .filter { $0.sourceRecordIDs.contains(recordID) }
        let arcs = try modelContext.fetch(FetchDescriptor<TemporalArcStore>()).map(\.domainModel)
            .filter { $0.sourceRecordIDs.contains(recordID) }
        let reflections = try modelContext.fetch(FetchDescriptor<ReflectionSnapshotStore>()).map(\.domainModel)
            .filter { reflection in
                reflection.sourceRecordIDs.contains(recordID)
                    || arcs.contains(where: { $0.id == reflection.linkedTemporalArcID })
            }

        return DebugMemoryFixtureSnapshot(
            recordID: record.id,
            recordTitle: record.rawText.firstMeaningfulLine ?? "Debug Fixture",
            chain: DebugMemoryChainSnapshot(
                record: record,
                artifacts: artifacts,
                analysis: analysis,
                pipelineStatus: pipelineStatus,
                entities: entities,
                edges: edges,
                links: links,
                arcs: arcs,
                reflections: reflections
            )
        )
    }

    func upsert(recordShell: RecordShell) throws {
        let descriptor = FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordShell.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: recordShell)
        } else {
            modelContext.insert(RecordShellStore(domainModel: recordShell))
        }
    }

    func upsert(artifact: Artifact) throws {
        let descriptor = FetchDescriptor<ArtifactStore>(predicate: #Predicate { $0.id == artifact.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: artifact)
        } else {
            modelContext.insert(ArtifactStore(domainModel: artifact))
        }
    }

    func upsert(recordAnalysis: RecordAnalysisSnapshot) throws {
        let descriptor = FetchDescriptor<RecordAnalysisSnapshotStore>(predicate: #Predicate { $0.id == recordAnalysis.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: recordAnalysis)
        } else {
            modelContext.insert(RecordAnalysisSnapshotStore(domainModel: recordAnalysis))
        }
    }

    func upsertPipelineStatus(_ pipelineStatus: MemoryPipelineStatusSnapshot) throws {
        let recordID = pipelineStatus.recordID
        let descriptor = FetchDescriptor<MemoryPipelineStatusStore>(
            predicate: #Predicate { $0.recordID == recordID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: pipelineStatus)
        } else {
            modelContext.insert(MemoryPipelineStatusStore(domainModel: pipelineStatus))
        }
    }

    func upsert(entityNode: EntityNode) throws {
        let descriptor = FetchDescriptor<EntityNodeStore>(predicate: #Predicate { $0.id == entityNode.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: entityNode)
        } else {
            modelContext.insert(EntityNodeStore(domainModel: entityNode))
        }
    }

    func upsert(entityEdge: EntityEdge) throws {
        let descriptor = FetchDescriptor<EntityEdgeStore>(predicate: #Predicate { $0.id == entityEdge.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: entityEdge)
        } else {
            modelContext.insert(EntityEdgeStore(domainModel: entityEdge))
        }
    }

    func upsert(artifactEntityLink: ArtifactEntityLink) throws {
        let descriptor = FetchDescriptor<ArtifactEntityLinkStore>(predicate: #Predicate { $0.id == artifactEntityLink.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: artifactEntityLink)
        } else {
            modelContext.insert(ArtifactEntityLinkStore(domainModel: artifactEntityLink))
        }
    }

    func upsert(temporalArc: TemporalArc) throws {
        let descriptor = FetchDescriptor<TemporalArcStore>(predicate: #Predicate { $0.id == temporalArc.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: temporalArc)
        } else {
            modelContext.insert(TemporalArcStore(domainModel: temporalArc))
        }
    }

    func upsert(reflection: ReflectionSnapshot) throws {
        let descriptor = FetchDescriptor<ReflectionSnapshotStore>(predicate: #Predicate { $0.id == reflection.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: reflection)
        } else {
            modelContext.insert(ReflectionSnapshotStore(domainModel: reflection))
        }
    }

    func save() throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    private func runArchitecturePipeline(record: RecordShell, artifacts: [Artifact]) async throws {
        let existingAnalyses = try modelContext.fetch(FetchDescriptor<RecordAnalysisSnapshotStore>()).map(\.domainModel)
        let existingEntityNodes = try modelContext.fetch(FetchDescriptor<EntityNodeStore>()).map(\.domainModel)
        let existingEntityEdges = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>()).map(\.domainModel)
        let existingArtifactLinks = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>()).map(\.domainModel)
        let existingArcs = try modelContext.fetch(
            FetchDescriptor<TemporalArcStore>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        ).map(\.domainModel)
        let existingReflections = try modelContext.fetch(
            FetchDescriptor<ReflectionSnapshotStore>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        ).map(\.domainModel)
        let allRecords = try fetchRecordShells()
        let allArtifacts = try modelContext.fetch(FetchDescriptor<ArtifactStore>()).map(\.domainModel)
        let knownEntities = existingEntityNodes.map {
            EntityReference(
                id: $0.id,
                kind: $0.kind,
                name: $0.displayName,
                aliases: $0.canonicalName == $0.displayName ? [] : [$0.canonicalName],
                confidence: $0.confidence
            )
        }

        let analysis = try await analysisService.analyze(
            record: record,
            artifacts: artifacts,
            knownEntities: knownEntities
        )
        try upsert(recordAnalysis: analysis)

        let pipelineResult = analysisPipeline.applyAnalysis(
            analysis,
            records: allRecords,
            analyses: existingAnalyses,
            entityNodes: existingEntityNodes,
            entityEdges: existingEntityEdges,
            artifactEntityLinks: existingArtifactLinks
        )

        try pipelineResult.entityNodes.forEach { try upsert(entityNode: $0) }
        try pipelineResult.entityEdges.forEach { try upsert(entityEdge: $0) }
        try pipelineResult.artifactEntityLinks.forEach { try upsert(artifactEntityLink: $0) }

        let recordReflection = reflectionBuilder.build(record: record, artifacts: artifacts, analysis: analysis)
        try upsert(reflection: resolvedRecordReflection(recordReflection, existingReflections: existingReflections))

        let candidateLimit = max(6, existingArcs.count + 3)
        let candidates = temporalArcService.buildCandidates(
            records: allRecords,
            analyses: pipelineResult.analyses,
            artifacts: allArtifacts,
            artifactEntityLinks: pipelineResult.artifactEntityLinks,
            entityNodes: pipelineResult.entityNodes,
            limit: candidateLimit
        )

        var arcsByID = Dictionary(uniqueKeysWithValues: existingArcs.map { ($0.id, $0) })
        var reflectionsByID = Dictionary(uniqueKeysWithValues: existingReflections.map { ($0.id, $0) })
        if let savedRecordReflection = try modelContext.fetch(
            FetchDescriptor<ReflectionSnapshotStore>(predicate: #Predicate { $0.id == recordReflection.id })
        ).first?.domainModel {
            reflectionsByID[savedRecordReflection.id] = savedRecordReflection
        }

        for candidate in candidates where candidate.recordIDs.contains(record.id) {
            let promoted = temporalArcService.promote(
                candidate: candidate,
                analyses: pipelineResult.analyses,
                artifactEntityLinks: pipelineResult.artifactEntityLinks,
                entityNodes: pipelineResult.entityNodes
            )

            if let mergePreview = temporalArcService.mergePreview(sourceArcID: promoted.arc.id, arcs: Array(arcsByID.values)),
               let sourceArc = arcsByID[mergePreview.sourceArcID],
               let candidateArc = arcsByID[mergePreview.candidateArcID] {
                let mergeResult = temporalArcService.merge(
                    sourceArc: sourceArc,
                    candidateArc: candidateArc,
                    linkedReflection: sourceArc.linkedReflectionID.flatMap { reflectionsByID[$0] }
                )
                arcsByID[mergeResult.sourceArc.id] = mergeResult.sourceArc
                arcsByID[mergeResult.candidateArc.id] = mergeResult.candidateArc
                if let updatedReflection = mergeResult.updatedReflection {
                    reflectionsByID[updatedReflection.id] = updatedReflection
                }
            } else {
                arcsByID[promoted.arc.id] = promoted.arc
                reflectionsByID[promoted.reflection.id] = promoted.reflection
            }
        }

        try arcsByID.values.forEach { try upsert(temporalArc: $0) }
        try reflectionsByID.values.forEach { try upsert(reflection: $0) }
        try save()
    }

    private func resolvedRecordReflection(
        _ reflection: ReflectionSnapshot,
        existingReflections: [ReflectionSnapshot]
    ) -> ReflectionSnapshot {
        if let existing = existingReflections.first(where: {
            $0.type == .record && $0.sourceRecordIDs == [reflection.sourceRecordIDs.first].compactMap { $0 }
        }) {
            var updated = reflection
            updated = ReflectionSnapshot(
                id: existing.id,
                type: reflection.type,
                title: reflection.title,
                body: reflection.body,
                evidenceSummary: reflection.evidenceSummary,
                confidence: reflection.confidence,
                status: existing.status == .saved ? .saved : reflection.status,
                linkedTemporalArcID: existing.linkedTemporalArcID ?? reflection.linkedTemporalArcID,
                sourceRecordIDs: reflection.sourceRecordIDs,
                sourceArtifactIDs: reflection.sourceArtifactIDs,
                sourceEntityIDs: reflection.sourceEntityIDs,
                createdAt: existing.createdAt,
                savedAt: existing.savedAt,
                dismissedAt: existing.dismissedAt
            )
            return updated
        }
        return reflection
    }

    private func updateReflectionStatus(reflectionID: UUID, status: ReflectionStatus) throws {
        guard let existing = try modelContext.fetch(
            FetchDescriptor<ReflectionSnapshotStore>(predicate: #Predicate { $0.id == reflectionID })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        var updated = existing.domainModel
        updated.status = status
        switch status {
        case .saved:
            updated.savedAt = updated.savedAt ?? Date.now
            updated.dismissedAt = nil
        case .dismissed:
            updated.dismissedAt = Date.now
        case .archived:
            break
        case .suggested:
            updated.savedAt = nil
            updated.dismissedAt = nil
        }
        existing.apply(domainModel: updated)
        try save()
    }

    private func ensureHomeBoard(for date: Date) throws -> BoardStore {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let boardKey = homeBoardKey(for: startOfDay)
        let descriptor = FetchDescriptor<BoardStore>()

        if let existing = try modelContext.fetch(descriptor).first(where: { $0.boardKey == boardKey }) {
            existing.title = "Today"
            existing.subtitle = startOfDay.formatted(date: .abbreviated, time: .omitted)
            existing.boardDate = startOfDay
            existing.updatedAt = Date.now
            return existing
        }

        let board = BoardStore(
            id: UUID(),
            boardKey: boardKey,
            kindRawValue: BoardKind.homeDay.rawValue,
            title: "Today",
            subtitle: startOfDay.formatted(date: .abbreviated, time: .omitted),
            boardDate: startOfDay,
            createdAt: Date.now,
            updatedAt: Date.now
        )
        modelContext.insert(board)
        try save()
        return board
    }

    private func ensureHomeComposition(for boardStore: BoardStore) throws -> CompositionStore {
        let descriptor = FetchDescriptor<CompositionStore>()

        if let existing = try modelContext.fetch(descriptor).first(where: {
            $0.boardID == boardStore.id && $0.compositionKey == "home-main"
        }) {
            return existing
        }

        let composition = CompositionStore(
            id: UUID(),
            boardID: boardStore.id,
            compositionKey: "home-main",
            title: "Primary Memory Space",
            sortOrder: 0,
            createdAt: Date.now,
            updatedAt: Date.now
        )
        modelContext.insert(composition)
        try save()
        return composition
    }

    private func ensureHomeBoardItems(
        boardStore: BoardStore,
        compositionStore: CompositionStore,
        memories: [MemorySummary],
        arcs: [TemporalArc],
        reflections: [ReflectionSnapshot]
    ) throws -> [CompositionItemStore] {
        let descriptor = FetchDescriptor<CompositionItemStore>(sortBy: [SortDescriptor(\.zIndex, order: .forward)])
        var existingItems = try modelContext.fetch(descriptor).filter { $0.boardID == boardStore.id }
        let existingTargets = Set(existingItems.map { "\($0.targetTypeRawValue):\($0.targetID.uuidString)" })

        let candidateItems = buildHomeBoardCandidates(
            memories: memories,
            arcs: arcs,
            reflections: reflections
        )

        for candidate in candidateItems where !existingTargets.contains(candidate.key) {
            let layout = homeLayoutPattern(index: existingItems.count, targetType: candidate.targetType)
            let item = CompositionItemStore(
                id: UUID(),
                boardID: boardStore.id,
                boardKey: boardStore.boardKey,
                compositionID: compositionStore.id,
                compositionKey: compositionStore.compositionKey,
                itemKey: candidate.key,
                targetTypeRawValue: candidate.targetType.rawValue,
                targetID: candidate.targetID,
                widthColumns: layout.widthColumns,
                heightUnits: layout.heightUnits,
                zIndex: layout.zIndex,
                rotationDegrees: layout.rotationDegrees,
                scale: layout.scale,
                isHidden: candidate.targetType == .system ? false : candidate.isHidden,
                updatedAt: Date.now
            )
            modelContext.insert(item)
            existingItems.append(item)
        }

        if modelContext.hasChanges {
            compositionStore.updatedAt = Date.now
            boardStore.updatedAt = Date.now
            try save()
            existingItems = try modelContext.fetch(descriptor).filter { $0.boardID == boardStore.id }
        }

        let allowedRecordIDs = Set(memories.map(\.record.id))
        let allowedArcIDs = Set(arcs.map(\.id))
        let allowedReflectionIDs = Set(reflections.map(\.id))

        return existingItems.filter { item in
            switch item.targetTypeRawValue {
            case CompositionTargetType.record.rawValue:
                return allowedRecordIDs.contains(item.targetID)
            case CompositionTargetType.arc.rawValue:
                return allowedArcIDs.contains(item.targetID)
            case CompositionTargetType.reflection.rawValue:
                return allowedReflectionIDs.contains(item.targetID)
            case CompositionTargetType.system.rawValue:
                return true
            default:
                return false
            }
        }
    }

    private func homeBoardKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "home-day-%04d-%02d-%02d", year, month, day)
    }

    private func homeLayoutPattern(index: Int, targetType: CompositionTargetType) -> (widthColumns: Int, heightUnits: Int, zIndex: Int, rotationDegrees: Double, scale: Double) {
        let patterns: [(Int, Int, Double, Double)]
        switch targetType {
        case .record:
            patterns = [
                (2, 2, -1.2, 1.00),
                (1, 1, 0.8, 0.98),
                (1, 1, -0.4, 1.00),
                (2, 1, 1.0, 1.02),
            ]
        case .arc:
            patterns = [
                (2, 1, -0.6, 1.01),
                (2, 1, 0.4, 1.00),
            ]
        case .reflection:
            patterns = [
                (1, 2, -0.3, 0.99),
                (1, 2, 0.5, 1.00),
            ]
        case .system:
            patterns = [
                (1, 1, 0, 1.00),
            ]
        case .artifact:
            patterns = [
                (1, 1, 0, 1.00),
            ]
        }
        let pattern = patterns[index % patterns.count]
        return (
            widthColumns: pattern.0,
            heightUnits: pattern.1,
            zIndex: index,
            rotationDegrees: pattern.2,
            scale: pattern.3
        )
    }

    private func resolveHomeBoardItemSnapshot(
        from item: CompositionItem,
        memoriesByRecordID: [UUID: MemorySummary],
        arcsByID: [UUID: TemporalArc],
        reflectionsByID: [UUID: ReflectionSnapshot]
    ) -> HomeBoardItemSnapshot? {
        switch item.targetType {
        case .record:
            guard let memory = memoriesByRecordID[item.targetID] else { return nil }
            return HomeBoardItemSnapshot(
                compositionItem: item,
                renderValue: .memory(memory)
            )
        case .arc:
            guard let arc = arcsByID[item.targetID] else { return nil }
            return HomeBoardItemSnapshot(
                compositionItem: item,
                renderValue: .arc(arc)
            )
        case .reflection:
            guard let reflection = reflectionsByID[item.targetID] else { return nil }
            return HomeBoardItemSnapshot(
                compositionItem: item,
                renderValue: .reflection(reflection)
            )
        case .system:
            return HomeBoardItemSnapshot(
                compositionItem: item,
                renderValue: .system(
                    title: "Recall Anchor",
                    subtitle: "A system slot reserved for future resurfacing and prompts."
                )
            )
        case .artifact:
            return nil
        }
    }

    private func buildHomeBoardCandidates(
        memories: [MemorySummary],
        arcs: [TemporalArc],
        reflections: [ReflectionSnapshot]
    ) -> [(key: String, targetType: CompositionTargetType, targetID: UUID, isHidden: Bool)] {
        let memoryItems = memories.map {
            (
                key: "record-\($0.record.id.uuidString)",
                targetType: CompositionTargetType.record,
                targetID: $0.record.id,
                isHidden: false
            )
        }
        let arcItems = arcs.map {
            (
                key: "arc-\($0.id.uuidString)",
                targetType: CompositionTargetType.arc,
                targetID: $0.id,
                isHidden: false
            )
        }
        let reflectionItems = reflections.map {
            (
                key: "reflection-\($0.id.uuidString)",
                targetType: CompositionTargetType.reflection,
                targetID: $0.id,
                isHidden: false
            )
        }

        return memoryItems + arcItems + reflectionItems
    }

    private func fetchBoardEligibleArcs(from graphContext: GraphContext, limit: Int) -> [TemporalArc] {
        Array(
            graphContext.arcs
                .filter { $0.status == .accepted || $0.status == .candidate }
                .sorted {
                    if $0.intensityScore == $1.intensityScore {
                        return $0.updatedAt > $1.updatedAt
                    }
                    return $0.intensityScore > $1.intensityScore
                }
                .prefix(limit)
        )
    }

    private func fetchBoardEligibleReflections(from graphContext: GraphContext, limit: Int) -> [ReflectionSnapshot] {
        Array(
            graphContext.reflections
                .filter { $0.status == .saved || $0.status == .suggested }
                .sorted {
                    if $0.confidence == $1.confidence {
                        return $0.createdAt > $1.createdAt
                    }
                    return $0.confidence > $1.confidence
                }
                .prefix(limit)
        )
    }

    private func loadGraphContext() throws -> GraphContext {
        let links = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>()).map(\.domainModel)
        let artifacts = try modelContext.fetch(FetchDescriptor<ArtifactStore>()).map(\.domainModel)
        let analyses = try modelContext.fetch(
            FetchDescriptor<RecordAnalysisSnapshotStore>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        ).map(\.domainModel)
        let reflections = try modelContext.fetch(
            FetchDescriptor<ReflectionSnapshotStore>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        ).map(\.domainModel)
        let entities = try modelContext.fetch(
            FetchDescriptor<EntityNodeStore>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        ).map(\.domainModel)
        let edges = try modelContext.fetch(
            FetchDescriptor<EntityEdgeStore>(sortBy: [SortDescriptor(\.lastSeenAt, order: .reverse)])
        ).map(\.domainModel)
        let arcs = try modelContext.fetch(
            FetchDescriptor<TemporalArcStore>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        ).map(\.domainModel)
        let memories = try fetchRecentMemories(limit: nil)
        let memoriesByRecordID = Dictionary(uniqueKeysWithValues: memories.map { ($0.record.id, $0) })

        return GraphContext(
            entities: entities,
            edges: edges,
            links: links,
            artifacts: artifacts,
            analyses: analyses,
            reflections: reflections,
            arcs: arcs,
            memoriesByRecordID: memoriesByRecordID
        )
    }

    private func relatedMemories(
        recordIDs: [UUID],
        memoriesByRecordID: [UUID: MemorySummary],
        limit: Int
    ) -> [MemorySummary] {
        recordIDs
            .compactMap { memoriesByRecordID[$0] }
            .sorted { $0.record.updatedAt > $1.record.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    private func mergeUniqueIDs(_ lhs: [UUID], _ rhs: [UUID]) -> [UUID] {
        Array(NSOrderedSet(array: lhs + rhs)) as? [UUID] ?? Array(Set(lhs + rhs))
    }

    private func makePersonSummary(entity: EntityNode, graphContext: GraphContext) -> PersonMemorySummary {
        let detail = makeEntityDetailSnapshot(entity: entity, graphContext: graphContext)

        return PersonMemorySummary(
            entity: entity,
            artifactCount: detail.artifactCount,
            relatedMemories: Array(detail.relatedMemories.prefix(3)),
            themeLabels: Array(detail.relatedThemes.prefix(3)),
            reflectionCount: detail.relatedReflections.count
        )
    }

    private func makeThemeSummary(entity: EntityNode, graphContext: GraphContext) -> ThemeMemorySummary {
        let detail = makeEntityDetailSnapshot(entity: entity, graphContext: graphContext)

        return ThemeMemorySummary(
            entity: entity,
            artifactCount: detail.artifactCount,
            relatedMemories: Array(detail.relatedMemories.prefix(3)),
            relatedPeople: Array(detail.relatedPeople.prefix(3)),
            arcCount: detail.relatedArcs.count
        )
    }

    private func makeEntityDetailSnapshot(entity: EntityNode, graphContext: GraphContext) -> EntityDetailSnapshot {
        let artifactIDs = Set(graphContext.links.filter { $0.entityID == entity.id }.map(\.artifactID))
        let relatedArtifacts = graphContext.artifacts.filter { artifactIDs.contains($0.id) }
        let relatedRecordIDs = Array(Set(relatedArtifacts.map(\.recordID)))
        let entityMemories = relatedRecordIDs.compactMap { graphContext.memoriesByRecordID[$0] }
            .sorted { $0.record.updatedAt > $1.record.updatedAt }

        let relatedEntityIDs = Set(
            graphContext.links
                .filter { artifactIDs.contains($0.artifactID) }
                .map(\.entityID)
        )
        let relatedEntities = graphContext.entities.filter { relatedEntityIDs.contains($0.id) && $0.id != entity.id }
        let relatedThemes = relatedEntities
            .filter { $0.kind == .theme }
            .map(\.displayName)
            .uniquedSorted()
        let relatedPeople = relatedEntities
            .filter { $0.kind == .person }
            .map(\.displayName)
            .uniquedSorted()

        let relatedArcs = graphContext.arcs
            .filter { $0.sourceEntityIDs.contains(entity.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { arc in
                TemporalArcSummarySnapshot(
                    arc: arc,
                    relatedMemories: relatedMemories(
                        recordIDs: arc.sourceRecordIDs,
                        memoriesByRecordID: graphContext.memoriesByRecordID,
                        limit: 3
                    ),
                    linkedReflection: graphContext.reflections.first(where: { $0.linkedTemporalArcID == arc.id })
                )
            }

        let relatedReflections = graphContext.reflections
            .filter { $0.sourceEntityIDs.contains(entity.id) }
            .sorted { $0.createdAt > $1.createdAt }
            .map { reflection in
                let linkedArc = reflection.linkedTemporalArcID.flatMap { arcID in
                    graphContext.arcs.first(where: { $0.id == arcID })
                }
                let relatedIDs = linkedArc.map { mergeUniqueIDs(reflection.sourceRecordIDs, $0.sourceRecordIDs) } ?? reflection.sourceRecordIDs
                return ReflectionSummarySnapshot(
                    reflection: reflection,
                    linkedArc: linkedArc,
                    relatedMemories: relatedMemories(
                        recordIDs: relatedIDs,
                        memoriesByRecordID: graphContext.memoriesByRecordID,
                        limit: 3
                    )
                )
            }

        let edges = graphContext.edges
            .filter { $0.fromEntityID == entity.id || $0.toEntityID == entity.id }
            .sorted {
                if $0.weight == $1.weight {
                    return $0.lastSeenAt > $1.lastSeenAt
                }
                return $0.weight > $1.weight
            }

        return EntityDetailSnapshot(
            entity: entity,
            artifactCount: relatedArtifacts.count,
            relatedMemories: Array(entityMemories.prefix(5)),
            relatedThemes: Array(relatedThemes.prefix(5)),
            relatedPeople: Array(relatedPeople.prefix(5)),
            relatedReflections: Array(relatedReflections.prefix(5)),
            relatedArcs: Array(relatedArcs.prefix(5)),
            edges: Array(edges.prefix(8))
        )
    }

    private func makeSearchEntityResult(entity: EntityNode, graphContext: GraphContext) -> SearchEntityResultSnapshot {
        let detail = makeEntityDetailSnapshot(entity: entity, graphContext: graphContext)
        return SearchEntityResultSnapshot(
            entity: entity,
            artifactCount: detail.artifactCount,
            relatedMemoryCount: detail.relatedMemories.count,
            relatedThemes: Array(detail.relatedThemes.prefix(3)),
            relatedPeople: Array(detail.relatedPeople.prefix(3)),
            reflectionCount: detail.relatedReflections.count,
            arcCount: detail.relatedArcs.count
        )
    }

    private func makeMemorySummary(
        record: RecordShell,
        artifacts: [Artifact],
        pipelineStatus: MemoryPipelineStatusSnapshot?
    ) -> MemorySummary {
        MemorySummary(
            record: record,
            primaryArtifact: preferredPrimaryArtifact(from: artifacts),
            artifactCount: artifacts.count,
            pipelineStatus: pipelineStatus
        )
    }

    private func buildArtifacts(from draft: MemoryCaptureDraft, recordID: UUID, createdAt: Date) -> [Artifact] {
        let explicitArtifacts = draft.artifacts.map { artifactDraft in
            makeArtifact(from: artifactDraft, fallbackTitle: draft.title, recordID: recordID, createdAt: createdAt)
        }

        if explicitArtifacts.isEmpty {
            return [
                Artifact(
                    recordID: recordID,
                    kind: .text,
                    title: draft.title?.trimmedOrNil ?? draft.rawText.firstMeaningfulLine ?? "Untitled Memory",
                    summary: draft.rawText.trimmedOrNil ?? "Untitled Memory",
                    textContent: draft.rawText.trimmedOrNil ?? "Untitled Memory",
                    payload: .text(draft.rawText.trimmedOrNil ?? "Untitled Memory"),
                    metadata: [:],
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
            ]
        }

        return explicitArtifacts
    }

    private func resolvedRecordRawText(from draft: MemoryCaptureDraft, artifacts: [Artifact]) -> String {
        if let rawText = draft.rawText.trimmedOrNil {
            return rawText
        }

        let artifactSummary = artifacts
            .compactMap { artifact in
                artifact.textContent.trimmedOrNil
                    ?? artifact.summary.trimmedOrNil
                    ?? artifact.title.trimmedOrNil
            }
            .joined(separator: "\n")
            .trimmedOrNil

        return artifactSummary
            ?? draft.artifacts.map(\.captureSummary).joined(separator: "\n").trimmedOrNil
            ?? draft.title?.trimmedOrNil
            ?? "Untitled Memory"
    }

    private func makeArtifact(
        from draft: CaptureArtifactDraft,
        fallbackTitle: String?,
        recordID: UUID,
        createdAt: Date
    ) -> Artifact {
        switch draft {
        case let .text(title, body):
            let resolvedBody = body.trimmedOrNil ?? "Untitled Memory"
            return Artifact(
                recordID: recordID,
                kind: .text,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? resolvedBody.firstMeaningfulLine ?? "Untitled Memory",
                summary: resolvedBody,
                textContent: resolvedBody,
                payload: .text(resolvedBody),
                metadata: [:],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .photo(title, summary, filename):
            let resolvedSummary = summary.trimmedOrNil ?? "Photo capture"
            return Artifact(
                recordID: recordID,
                kind: .photo,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Photo",
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .media(ArtifactMediaRef(filename: filename, mimeType: "image/jpeg")),
                mediaRef: ArtifactMediaRef(filename: filename, mimeType: "image/jpeg"),
                metadata: [:],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .audio(title, summary, filename):
            let resolvedSummary = summary.trimmedOrNil ?? "Audio capture"
            return Artifact(
                recordID: recordID,
                kind: .audio,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Audio",
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .media(ArtifactMediaRef(filename: filename, mimeType: "audio/m4a")),
                mediaRef: ArtifactMediaRef(filename: filename, mimeType: "audio/m4a"),
                metadata: [:],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .location(title, summary, latitude, longitude):
            let resolvedSummary = summary.trimmedOrNil ?? "Location capture"
            var metadata: [String: String] = [:]
            if let latitude { metadata["latitude"] = String(latitude) }
            if let longitude { metadata["longitude"] = String(longitude) }
            return Artifact(
                recordID: recordID,
                kind: .location,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? "Location",
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .metadata(metadata),
                metadata: metadata,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .link(title, url, note):
            let resolvedSummary = note?.trimmedOrNil ?? url
            return Artifact(
                recordID: recordID,
                kind: .link,
                title: title?.trimmedOrNil ?? fallbackTitle?.trimmedOrNil ?? url,
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .metadata(["url": url]),
                metadata: ["url": url],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        case let .todo(title, note):
            let resolvedSummary = note?.trimmedOrNil ?? title
            return Artifact(
                recordID: recordID,
                kind: .todo,
                title: title,
                summary: resolvedSummary,
                textContent: resolvedSummary,
                payload: .metadata(["todo": "true"]),
                metadata: ["todo": "true"],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        }
    }

    private func preferredPrimaryArtifact(from artifacts: [Artifact]) -> Artifact? {
        artifacts.first(where: { $0.kind == .text && $0.textContent.normalizedNonEmpty != nil })
            ?? artifacts.first(where: { $0.summary.normalizedNonEmpty != nil })
            ?? artifacts.first
    }

    private func applyLimit<T>(_ limit: Int?, to values: [T]) -> [T] {
        guard let limit else { return values }
        return Array(values.prefix(limit))
    }
}

private extension String {
    var normalizedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var normalizedSearchTerm: String? {
        normalizedNonEmpty?.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

private extension Array where Element == String {
    func containsSearchTerm(_ needle: String) -> Bool {
        contains { value in
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(needle)
        }
    }

    func uniquedSorted() -> [String] {
        Array(Set(self)).sorted()
    }
}
