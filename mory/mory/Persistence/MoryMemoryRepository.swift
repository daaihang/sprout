import Foundation
import SwiftData

@MainActor
final class MoryMemoryRepository: MoryMemoryRepositorying {
    private let modelContext: ModelContext
    private let analysisService: any RecordAnalysisServing
    private let architecturePipelineExecutor = ArchitecturePipelineExecutor()
    private let homeBoardStoreBuilder = HomeBoardStoreBuilder()
    private let graphQueryService = MemoryGraphQueryService()
    private let memorySearchService = MemorySearchService()
    private let captureArtifactBuilder = MemoryCaptureArtifactBuilder()
    private let temporalArcService = TemporalArcService()
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
        let captureArtifacts = captureArtifactBuilder.buildArtifacts(from: draft, recordID: recordID, createdAt: now)
        let normalizedText = captureArtifactBuilder.resolvedRecordRawText(from: draft, artifacts: captureArtifacts)

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

    func fetchTimeline(granularity: TimelineGranularity, limit: Int?) throws -> TimelineSnapshot {
        let memories = try fetchRecentMemories(limit: limit)
        let calendar = Calendar.current

        let groups: [TimelineDayGroup]
        switch granularity {
        case .day:
            let grouped = Dictionary(grouping: memories) { memory in
                calendar.startOfDay(for: memory.record.updatedAt)
            }
            groups = grouped.map { date, mems in
                TimelineDayGroup(date: date, memories: mems.sorted { $0.record.updatedAt > $1.record.updatedAt })
            }.sorted { $0.date > $1.date }
        case .week:
            let grouped = Dictionary(grouping: memories) { memory in
                calendar.dateInterval(of: .weekOfYear, for: memory.record.updatedAt)?.start ?? calendar.startOfDay(for: memory.record.updatedAt)
            }
            groups = grouped.map { date, mems in
                TimelineDayGroup(date: date, memories: mems.sorted { $0.record.updatedAt > $1.record.updatedAt })
            }.sorted { $0.date > $1.date }
        case .month:
            let grouped = Dictionary(grouping: memories) { memory in
                let components = calendar.dateComponents([.year, .month], from: memory.record.updatedAt)
                return calendar.date(from: components) ?? calendar.startOfDay(for: memory.record.updatedAt)
            }
            groups = grouped.map { date, mems in
                TimelineDayGroup(date: date, memories: mems.sorted { $0.record.updatedAt > $1.record.updatedAt })
            }.sorted { $0.date > $1.date }
        }

        return TimelineSnapshot(granularity: granularity, groups: groups, totalCount: memories.count)
    }

    func fetchHomeBoard(for date: Date, limit: Int = 8) throws -> HomeBoardSnapshot {
        let memories = try fetchRecentMemories(limit: limit)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
        return try homeBoardStoreBuilder.fetchHomeBoard(
            date: date,
            limit: limit,
            modelContext: modelContext,
            graphContext: graphContext,
            memories: memories
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

        let memories = [try makeMemorySummary(record: record)].compactMap { $0 }
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories,
            recordIDs: Set([recordID])
        )
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
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
        return memorySearchService.search(
            query: query,
            graphContext: graphContext,
            memories: memories,
            limit: limit
        )
    }

    func fetchEntityDetails(kind: EntityKind, limit: Int? = nil) throws -> [EntityDetailSnapshot] {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories,
            entityKinds: [kind]
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
        return graphContext.makeEntityDetailSnapshot(entity: entity)
    }

    func fetchPeopleSummaries(limit: Int? = nil) throws -> [PersonMemorySummary] {
        let personEntities = try modelContext.fetch(
            FetchDescriptor<EntityNodeStore>(
                predicate: #Predicate { $0.kindRawValue == "person" },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        ).map(\.domainModel)

        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories,
            entityKinds: [.person]
        )
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

        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories,
            entityKinds: [.theme]
        )
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

    func fetchTemporalArcs(limit: Int? = nil) throws -> [TemporalArc] {
        let arcs = try modelContext.fetch(
            FetchDescriptor<TemporalArcStore>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        ).map(\.domainModel)
        return applyLimit(limit, to: arcs)
    }

    func fetchTemporalArcSummaries(limit: Int? = nil) throws -> [TemporalArcSummarySnapshot] {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
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
                    relatedMemories: graphContext.relatedMemories(recordIDs: arc.sourceRecordIDs, limit: 3),
                    linkedReflection: reflectionsByArcID[arc.id]
                )
            }
    }

    func fetchTemporalArcDetail(arcID: UUID) throws -> TemporalArcDetailSnapshot? {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
        guard let arc = graphContext.arcs.first(where: { $0.id == arcID }) else { return nil }
        let mergePreview = temporalArcService.mergePreview(sourceArcID: arcID, arcs: graphContext.arcs)
        let mergeCandidate = mergePreview.flatMap { preview in
            graphContext.arcs.first(where: { $0.id == preview.candidateArcID })
        }
        let summary = TemporalArcSummarySnapshot(
            arc: arc,
            relatedMemories: graphContext.relatedMemories(recordIDs: arc.sourceRecordIDs, limit: 3),
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
                    relatedMemories: graphContext.relatedMemories(
                        recordIDs: graphContext.mergeUniqueIDs(reflection.sourceRecordIDs, arc.sourceRecordIDs),
                        limit: 3
                    )
                )
            }
        let entityDetails = graphContext.entities
            .filter { arc.sourceEntityIDs.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { graphContext.makeEntityDetailSnapshot(entity: $0) }
        return TemporalArcDetailSnapshot(
            summary: summary,
            reflections: reflectionSummaries,
            entityDetails: entityDetails,
            mergeCandidate: mergeCandidate.map { candidateArc in
                TemporalArcSummarySnapshot(
                    arc: candidateArc,
                    relatedMemories: graphContext.relatedMemories(recordIDs: candidateArc.sourceRecordIDs, limit: 3),
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
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
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
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
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
                relatedMemories: graphContext.relatedMemories(recordIDs: relatedRecordIDs, limit: 3)
            )
        }
    }

    func fetchReflectionDetail(reflectionID: UUID) throws -> ReflectionDetailSnapshot? {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
        guard let reflection = graphContext.reflections.first(where: { $0.id == reflectionID }) else { return nil }
        let linkedArc = reflection.linkedTemporalArcID.flatMap { arcID in
            graphContext.arcs.first(where: { $0.id == arcID })
        }
        let summary = ReflectionSummarySnapshot(
            reflection: reflection,
            linkedArc: linkedArc,
            relatedMemories: graphContext.relatedMemories(
                recordIDs: linkedArc.map { graphContext.mergeUniqueIDs(reflection.sourceRecordIDs, $0.sourceRecordIDs) } ?? reflection.sourceRecordIDs,
                limit: 3
            )
        )
        let entityDetails = graphContext.entities
            .filter { reflection.sourceEntityIDs.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { graphContext.makeEntityDetailSnapshot(entity: $0) }
        return ReflectionDetailSnapshot(
            summary: summary,
            linkedArc: linkedArc.map {
                TemporalArcSummarySnapshot(
                    arc: $0,
                    relatedMemories: graphContext.relatedMemories(recordIDs: $0.sourceRecordIDs, limit: 3),
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
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
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
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
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
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
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
        try await architecturePipelineExecutor.run(
            record: record,
            artifacts: artifacts,
            modelContext: modelContext,
            analysisService: analysisService,
            upsertRecordAnalysis: upsert(recordAnalysis:),
            upsertEntityNode: upsert(entityNode:),
            upsertEntityEdge: upsert(entityEdge:),
            upsertArtifactEntityLink: upsert(artifactEntityLink:),
            upsertTemporalArc: upsert(temporalArc:),
            upsertReflection: upsert(reflection:),
            save: save
        )
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

    private func makePersonSummary(entity: EntityNode, graphContext: MemoryGraphContext) -> PersonMemorySummary {
        let detail = graphContext.makeEntityDetailSnapshot(entity: entity)

        return PersonMemorySummary(
            entity: entity,
            artifactCount: detail.artifactCount,
            relatedMemories: Array(detail.relatedMemories.prefix(3)),
            themeLabels: Array(detail.relatedThemes.prefix(3)),
            reflectionCount: detail.relatedReflections.count
        )
    }

    private func makeThemeSummary(entity: EntityNode, graphContext: MemoryGraphContext) -> ThemeMemorySummary {
        let detail = graphContext.makeEntityDetailSnapshot(entity: entity)

        return ThemeMemorySummary(
            entity: entity,
            artifactCount: detail.artifactCount,
            relatedMemories: Array(detail.relatedMemories.prefix(3)),
            relatedPeople: Array(detail.relatedPeople.prefix(3)),
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
            primaryArtifact: captureArtifactBuilder.preferredPrimaryArtifact(from: artifacts),
            artifactCount: artifacts.count,
            pipelineStatus: pipelineStatus
        )
    }

    private func applyLimit<T>(_ limit: Int?, to values: [T]) -> [T] {
        guard let limit else { return values }
        return Array(values.prefix(limit))
    }
}
