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
    private let debugDiagnosticsService = DebugDiagnosticsService()
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
            debugFixtureSeededAt: draft.inputContext?.hasPrefix("debug fixture seed") == true ? now : nil
        )

        try upsert(recordShell: recordShell)
        try captureArtifacts.forEach { try upsert(artifact: $0) }
        try upsertPipelineStatus(
            MemoryPipelineStatusSnapshot(
                recordID: recordID,
                stage: .pending,
                requestID: nil,
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

    func appendArtifacts(recordID: UUID, drafts: [CaptureArtifactDraft]) async throws -> MemorySummary? {
        guard !drafts.isEmpty else {
            guard let record = try fetchRecordShell(id: recordID) else { return nil }
            return try makeMemorySummary(
                record: record,
                artifacts: fetchArtifacts(recordID: recordID),
                pipelineStatus: fetchPipelineStatus(recordID: recordID)
            )
        }

        guard let recordStore = try modelContext.fetch(
            FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordID })
        ).first else {
            return nil
        }

        let now = Date.now
        let draft = MemoryCaptureDraft(rawText: recordStore.rawText, artifacts: drafts)
        let newArtifacts = captureArtifactBuilder.buildArtifacts(from: draft, recordID: recordID, createdAt: now)
        guard !newArtifacts.isEmpty else {
            return try makeMemorySummary(
                record: recordStore.domainModel,
                artifacts: fetchArtifacts(recordID: recordID),
                pipelineStatus: fetchPipelineStatus(recordID: recordID)
            )
        }

        for artifact in newArtifacts {
            try upsert(artifact: artifact)
        }

        var updatedRecord = recordStore.domainModel
        updatedRecord.artifactIDs.append(contentsOf: newArtifacts.map(\.id))
        updatedRecord.artifactIDs = Array(NSOrderedSet(array: updatedRecord.artifactIDs)) as? [UUID] ?? Array(Set(updatedRecord.artifactIDs))
        updatedRecord.updatedAt = now
        recordStore.apply(domainModel: updatedRecord)

        try upsertPipelineStatus(
            MemoryPipelineStatusSnapshot(
                recordID: recordID,
                stage: .pending,
                requestID: try fetchPipelineStatus(recordID: recordID)?.requestID,
                lastError: nil,
                requestBody: try fetchPipelineStatus(recordID: recordID)?.requestBody,
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

        return try makeMemorySummary(
            record: updatedRecord,
            artifacts: fetchArtifacts(recordID: recordID),
            pipelineStatus: fetchPipelineStatus(recordID: recordID)
        )
    }

    func deleteMemory(recordID: UUID) throws {
        try purgeDerivedData(forRecordIDs: [recordID], includePipelineStatus: true)
        if let record = try modelContext.fetch(FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordID })).first {
            modelContext.delete(record)
        }
        let artifacts = try modelContext.fetch(FetchDescriptor<ArtifactStore>(predicate: #Predicate { $0.recordID == recordID }))
        artifacts.forEach { modelContext.delete($0) }
        try save()
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
                requestID: nil,
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
        let previousStatus = try fetchPipelineStatus(recordID: recordID)

        try purgeDerivedDataForRefresh(recordID: recordID)

        try upsertPipelineStatus(
            MemoryPipelineStatusSnapshot(
                recordID: recordID,
                stage: .running,
                requestID: previousStatus?.requestID,
                lastError: nil,
                requestBody: previousStatus?.requestBody,
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
                    requestID: trace?.requestID,
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
            NotificationCenter.default.post(
                name: .pipelineDidComplete,
                object: nil,
                userInfo: ["recordID": recordID]
            )
        } catch {
            let trace = await analysisService.latestDebugTrace()
            let failedAt = Date.now
            try upsertPipelineStatus(
                MemoryPipelineStatusSnapshot(
                    recordID: recordID,
                    stage: .failed,
                    requestID: trace?.requestID,
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
            NotificationCenter.default.post(
                name: .pipelineDidComplete,
                object: nil,
                userInfo: ["recordID": recordID]
            )
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
        let memories = try fetchRecentMemories(limit: nil)
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

        let artifacts = try fetchArtifacts(recordID: recordID)
        let memories = [makeMemorySummary(record: record, artifacts: artifacts, pipelineStatus: try fetchPipelineStatus(recordID: recordID))]
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories,
            recordIDs: Set([recordID])
        )
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
        return graphContext.makeEntityDetailSnapshot(entity: entity)
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
        let reflectionsByArcID = Dictionary(reflectionPairs, uniquingKeysWith: { first, _ in first })

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
            let relatedRecordIDs = linkedArc.map { graphContext.mergeUniqueIDs(reflection.sourceRecordIDs, $0.sourceRecordIDs) } ?? reflection.sourceRecordIDs

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
        let memories = try fetchRecentMemories(limit: nil)
        return try debugDiagnosticsService.fetchDiagnostics(
            targetType: targetType,
            targetID: targetID,
            modelContext: modelContext,
            memories: memories,
            pipelineStatusFetcher: fetchPipelineStatus,
            recordAnalysisFetcher: fetchRecordAnalysis,
            artifactsFetcher: fetchArtifacts,
            latestReflectionTrace: latestReflectionTrace
        )
    }

    func rerunDebugPipeline(targetType: DebugAnalysisTarget, targetID: UUID?, mode: DebugRebuildMode) async throws {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(modelContext: modelContext, memories: memories)
        switch mode {
        case .analysisOnly:
            let recordID = try resolveRecordIDViaGraph(targetType: targetType, targetID: targetID, graphContext: graphContext)
            guard let recordID else { throw CocoaError(.fileNoSuchFile) }
            try await refreshMemoryPipeline(recordID: recordID)
        case .graphArcReflection:
            let recordID = try resolveRecordIDViaGraph(targetType: targetType, targetID: targetID, graphContext: graphContext)
            guard let recordID else { throw CocoaError(.fileNoSuchFile) }
            try await rerunGraphArcReflection(recordID: recordID)
        case .reflectionReplay:
            let target = try debugDiagnosticsService.fetchDiagnostics(
                targetType: targetType,
                targetID: targetID,
                modelContext: modelContext,
                memories: memories,
                pipelineStatusFetcher: fetchPipelineStatus,
                recordAnalysisFetcher: fetchRecordAnalysis,
                artifactsFetcher: fetchArtifacts,
                latestReflectionTrace: latestReflectionTrace
            )
            guard let reflectionID = target.target?.reflection?.reflection.id else {
                throw CocoaError(.fileNoSuchFile)
            }
            let trace = try await replayDebugReflection(reflectionID: reflectionID)
            if let trace {
                latestReflectionTrace = trace
            } else {
                latestReflectionTrace = await analysisService.latestDebugTrace()
            }
        }
    }

    private func resolveRecordIDViaGraph(targetType: DebugAnalysisTarget, targetID: UUID?, graphContext: MemoryGraphContext) throws -> UUID? {
        switch targetType {
        case .memory:
            if let targetID { return targetID }
            return try fetchRecentMemories(limit: 1).first?.record.id
        case .arc:
            return graphContext.arcs.first(where: { $0.id == targetID })?.sourceRecordIDs.first
                ?? graphContext.arcs.first?.sourceRecordIDs.first
        case .reflection:
            return graphContext.reflections.first(where: { $0.id == targetID })?.sourceRecordIDs.first
                ?? graphContext.reflections.first?.sourceRecordIDs.first
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
        let records = try fetchRecordShells().filter {
            $0.debugFixtureSeededAt != nil || $0.inputContext == "debug fixture seed"
        }
        for record in records {
            try debugDiagnosticsService.deleteRecord(recordID: record.id, modelContext: modelContext)
        }
        try save()
    }

    func clearAllLocalData() throws {
        try deleteAll(CompositionItemStore.self)
        try deleteAll(CompositionStore.self)
        try deleteAll(BoardStore.self)
        try deleteAll(ArtifactEntityLinkStore.self)
        try deleteAll(EntityEdgeStore.self)
        try deleteAll(EntityNodeStore.self)
        try deleteAll(RecordAnalysisSnapshotStore.self)
        try deleteAll(MemoryPipelineStatusStore.self)
        try deleteAll(ReflectionSnapshotStore.self)
        try deleteAll(TemporalArcStore.self)
        try deleteAll(ArtifactStore.self)
        try deleteAll(RecordShellStore.self)
        latestReflectionTrace = nil
        try save()
    }

    func fetchQualityTuningPreference() throws -> QualityTuningPreference {
        let syncKey = QualityTuningPreference.defaultSyncKey
        let descriptor = FetchDescriptor<QualityTuningPreferenceStore>(
            predicate: #Predicate { $0.syncKey == syncKey }
        )
        guard let store = try modelContext.fetch(descriptor).first else {
            return .defaults
        }
        return makeQualityTuningPreference(from: store)
    }

    func saveQualityTuningPreference(_ preference: QualityTuningPreference) throws {
        let syncKey = preference.syncKey
        let descriptor = FetchDescriptor<QualityTuningPreferenceStore>(
            predicate: #Predicate { $0.syncKey == syncKey }
        )
        let data = try JSONEncoder().encode(preference.thresholds)
        if let store = try modelContext.fetch(descriptor).first {
            store.id = preference.id
            store.schemaVersion = preference.schemaVersion
            store.promptProfileRawValue = preference.promptProfile.rawValue
            store.thresholdsData = data
            store.notes = preference.notes
            store.updatedAt = preference.updatedAt
        } else {
            modelContext.insert(
                QualityTuningPreferenceStore(
                    id: preference.id,
                    schemaVersion: preference.schemaVersion,
                    syncKey: preference.syncKey,
                    promptProfileRawValue: preference.promptProfile.rawValue,
                    thresholdsData: data,
                    notes: preference.notes,
                    updatedAt: preference.updatedAt
                )
            )
        }
        try save()
    }

    func runQualityTuningScenario(_ request: QualityTuningRunRequest) async throws -> QualityTuningRunReport {
        QualityTuningRuntime.isEnabled = true
        QualityTuningRuntime.promptProfile = request.promptProfile
        QualityTuningRuntime.thresholds = request.thresholds
        QualityTuningRuntime.activeRecordScope = []
        defer { QualityTuningRuntime.activeRecordScope = nil }

        var createdMemories: [MemorySummary] = []
        let sessionID = UUID()
        for draft in makeQualityTuningDrafts(from: request.scenario, sessionID: sessionID) {
            let memory = try await createMemory(from: draft)
            QualityTuningRuntime.activeRecordScope = Set(createdMemories.map(\.record.id) + [memory.record.id])
            try await refreshMemoryPipeline(recordID: memory.record.id)
            createdMemories.append(memory)
        }

        guard let last = createdMemories.last else {
            throw CocoaError(.fileNoSuchFile)
        }

        let diagnostics = try fetchDebugDiagnostics(targetType: .memory, targetID: last.record.id)
        let reportRecordIDs = createdMemories.map(\.record.id)
        let arcs = try fetchTemporalArcs(limit: nil).filter { arc in
            arc.sourceRecordIDs.contains { reportRecordIDs.contains($0) }
        }
        let reflections = try fetchReflections(limit: nil).filter { reflection in
            reflection.sourceRecordIDs.contains { reportRecordIDs.contains($0) }
                || arcs.contains(where: { $0.id == reflection.linkedTemporalArcID })
        }
        let expectationPassed = evaluateQualityTuningExpectation(
            request.scenario.expectation,
            recordIDs: reportRecordIDs,
            arcs: arcs,
            reflections: reflections
        )

        return QualityTuningRunReport(
            scenarioTitle: request.scenario.title,
            promptProfile: request.promptProfile,
            thresholdsSummary: request.thresholds.summary,
            requestID: diagnostics.pipelineTrace?.requestID ?? latestReflectionTrace?.requestID,
            recordIDs: reportRecordIDs,
            expectation: request.scenario.expectation,
            expectationPassed: expectationPassed,
            requestBody: diagnostics.analyzePayload?.requestBody ?? "",
            rawResponseBody: diagnostics.analyzePayload?.responseBody ?? "",
            filteredSummary: makeQualityTuningFilteredSummary(diagnostics),
            storedSummary: makeQualityTuningStoredSummary(diagnostics: diagnostics, arcs: arcs, reflections: reflections),
            gates: makeQualityTuningGateSnapshots(diagnostics, expectation: request.scenario.expectation),
            createdAt: .now
        )
    }

    private func makeQualityTuningDrafts(from scenario: QualityTuningScenario, sessionID: UUID) -> [MemoryCaptureDraft] {
        func draft(title: String, body: String, mood: String?, context: String, source: CaptureSource, artifacts: [CaptureArtifactDraft]) -> MemoryCaptureDraft {
            MemoryCaptureDraft(
                title: title,
                rawText: body,
                mood: mood,
                inputContext: [
                    "quality tuning session: \(sessionID.uuidString)",
                    "quality tuning lab: \(scenario.id.rawValue)",
                    context.trimmedOrNil
                ].compactMap { $0 }.joined(separator: "\n"),
                captureSource: source,
                artifacts: artifacts.isEmpty ? [.text(title: title, body: body)] : artifacts
            )
        }

        switch scenario.id {
        case .twoRelatedEvents:
            let firstBody = "First planning walk with Linh clarified the launch checklist and the decision to reduce scope."
            return [
                draft(
                    title: "Two related events - first",
                    body: firstBody,
                    mood: scenario.mood,
                    context: scenario.context,
                    source: scenario.captureSource,
                    artifacts: [.text(title: "Two related events - first", body: firstBody)]
                ),
                draft(
                    title: scenario.title,
                    body: scenario.body,
                    mood: scenario.mood,
                    context: scenario.context,
                    source: scenario.captureSource,
                    artifacts: scenario.artifacts
                )
            ]
        case .weakRelatedEvents:
            return [
                draft(title: "Weak related - calendar", body: "Calendar reminder to move the dentist appointment.", mood: nil, context: scenario.context, source: .composer, artifacts: [.text(title: "Weak related - calendar", body: "Calendar reminder to move the dentist appointment.")]),
                draft(title: "Weak related - grocery", body: "Buy lemons, rice, and paper towels after work.", mood: nil, context: scenario.context, source: .composer, artifacts: [.text(title: "Weak related - grocery", body: "Buy lemons, rice, and paper towels after work.")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        case .denseUnrelatedHistory:
            return [
                draft(title: "Dense history - dentist", body: "Move the dentist appointment from Tuesday to Thursday.", mood: nil, context: scenario.context, source: .composer, artifacts: [.text(title: "Dense history - dentist", body: "Move the dentist appointment from Tuesday to Thursday.")]),
                draft(title: "Dense history - groceries", body: "Buy lemons, rice, paper towels, and batteries after work.", mood: nil, context: scenario.context, source: .composer, artifacts: [.text(title: "Dense history - groceries", body: "Buy lemons, rice, paper towels, and batteries after work.")]),
                draft(title: "Dense history - receipt", body: "Receipt photo import with weak OCR and no personal meaning.", mood: nil, context: scenario.context, source: .photo, artifacts: [.photo(title: "Receipt screenshot", summary: "OCR ORC receipt image artifact", filename: "dense_receipt.jpg", imageData: nil, thumbnailData: nil, ocrText: "OCR ORC receipt image artifact")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        case .recurringCareerHistory:
            return [
                draft(title: "Career transition - first", body: "I noticed relief after admitting to Linh that the current launch scope is too wide.", mood: "relieved", context: scenario.context, source: .composer, artifacts: [.text(title: "Career transition - first", body: "I noticed relief after admitting to Linh that the current launch scope is too wide.")]),
                draft(title: "Career transition - second", body: "During planning I chose the smaller launch scope and wrote down the roles I need to hand off.", mood: "focused", context: scenario.context, source: .composer, artifacts: [.text(title: "Career transition - second", body: "During planning I chose the smaller launch scope and wrote down the roles I need to hand off.")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        case .aliasSamePersonHistory:
            return [
                draft(title: "Alias history - Alexander", body: "Alexander Chen said the current launch plan feels too loud and asked for a quieter rollout.", mood: "focused", context: scenario.context, source: .composer, artifacts: [.text(title: "Alias history - Alexander", body: "Alexander Chen said the current launch plan feels too loud and asked for a quieter rollout.")]),
                draft(title: "Alias history - Alex", body: "Alex Chen repeated that the quieter launch plan would help the team finish carefully.", mood: "steady", context: scenario.context, source: .composer, artifacts: [.text(title: "Alias history - Alex", body: "Alex Chen repeated that the quieter launch plan would help the team finish carefully.")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        case .sameNameDifferentPeople:
            return [
                draft(title: "Same-name work Alex", body: "Alex from work asked me to reduce launch scope before the review.", mood: "focused", context: scenario.context, source: .composer, artifacts: [.text(title: "Same-name work Alex", body: "Alex from work asked me to reduce launch scope before the review.")]),
                draft(title: "Same-name neighbor Alex", body: "Alex from the apartment lobby reminded me about the package shelf.", mood: nil, context: scenario.context, source: .composer, artifacts: [.text(title: "Same-name neighbor Alex", body: "Alex from the apartment lobby reminded me about the package shelf.")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        case .relationshipConflictShift:
            return [
                draft(title: "Conflict shift - first", body: "Linh and I argued during the review because decisions were changing live in the room.", mood: "tense", context: scenario.context, source: .composer, artifacts: [.text(title: "Conflict shift - first", body: "Linh and I argued during the review because decisions were changing live in the room.")]),
                draft(title: "Conflict shift - second", body: "Before the next review, Linh suggested writing scope decisions down so we stop debating from memory.", mood: "careful", context: scenario.context, source: .composer, artifacts: [.text(title: "Conflict shift - second", body: "Before the next review, Linh suggested writing scope decisions down so we stop debating from memory.")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        case .longTimelineRecurringHistory:
            return [
                draft(title: "Long timeline - January", body: "In January I protected Monday morning for writing and finished the essay before meetings.", mood: "calm", context: scenario.context, source: .composer, artifacts: [.text(title: "Long timeline - January", body: "In January I protected Monday morning for writing and finished the essay before meetings.")]),
                draft(title: "Long timeline - March", body: "In March I lost the morning block to meetings and the writing slipped again.", mood: "frustrated", context: scenario.context, source: .composer, artifacts: [.text(title: "Long timeline - March", body: "In March I lost the morning block to meetings and the writing slipped again.")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        default:
            return [
                draft(
                    title: scenario.title,
                    body: scenario.body,
                    mood: scenario.mood,
                    context: scenario.context,
                    source: scenario.captureSource,
                    artifacts: scenario.artifacts
                )
            ]
        }
    }

    private func evaluateQualityTuningExpectation(
        _ expectation: QualityTuningExpectation,
        recordIDs: [UUID],
        arcs: [TemporalArc],
        reflections: [ReflectionSnapshot]
    ) -> Bool {
        switch expectation {
        case .noArcNoReflection:
            return arcs.isEmpty && reflections.isEmpty
        case .arcExpected:
            let recordIDSet = Set(recordIDs)
            return arcs.contains { Set($0.sourceRecordIDs).intersection(recordIDSet).count >= 2 }
        case .reflectionAllowed:
            return !reflections.isEmpty
        case .inspectOnly:
            return true
        }
    }

    private func makeQualityTuningFilteredSummary(_ diagnostics: DebugDiagnosticsSnapshot) -> String {
        guard let analysis = diagnostics.fixture?.chain.analysis else {
            return "No stored analysis snapshot."
        }
        return [
            "summary: \(analysis.summary)",
            "themes: \(analysis.themes.joined(separator: ", ").ifEmpty("none"))",
            "salience: \(analysis.salienceScore.map { String(format: "%.2f", $0) } ?? "none")",
            "entities: \(analysis.entityMentions.map { "\($0.kind.rawValue):\($0.name)" }.joined(separator: ", ").ifEmpty("none"))",
            "candidate_edges: \(analysis.candidateEdges.count)",
            "reflection_hint: \(analysis.reflectionHint?.trimmedOrNil ?? "none")"
        ].joined(separator: "\n")
    }

    private func makeQualityTuningStoredSummary(
        diagnostics: DebugDiagnosticsSnapshot,
        arcs: [TemporalArc],
        reflections: [ReflectionSnapshot]
    ) -> String {
        guard let chain = diagnostics.fixture?.chain else {
            return "No fixture chain."
        }
        return [
            "artifacts: \(chain.artifacts.count)",
            "entities: \(chain.entities.map(\.displayName).joined(separator: ", ").ifEmpty("none"))",
            "edges: \(chain.edges.count)",
            "arcs: \(arcs.map { "\($0.title) [\($0.sourceRecordIDs.count) records]" }.joined(separator: ", ").ifEmpty("none"))",
            "reflections: \(reflections.map { "\($0.title) [\($0.status.rawValue)]" }.joined(separator: ", ").ifEmpty("none"))"
        ].joined(separator: "\n")
    }

    private func makeQualityTuningGateSnapshots(
        _ diagnostics: DebugDiagnosticsSnapshot,
        expectation: QualityTuningExpectation
    ) -> [QualityTuningGateSnapshot] {
        guard let chain = diagnostics.fixture?.chain else {
            return [.init(title: "Target", passed: false, detail: "No fixture chain.")]
        }

        let entityPolicy = EntityQualityPolicy()
        let reflectionPolicy = ReflectionQualityPolicy()
        var gates: [QualityTuningGateSnapshot] = []

        if let rawEntities = rawQualityTuningEntities(from: diagnostics.analyzePayload?.responseBody), !rawEntities.isEmpty {
            for entity in rawEntities {
                let result = entityPolicy.evaluate(entity)
                gates.append(.init(
                    title: "Entity \(entity.kind.rawValue): \(entity.name)",
                    passed: result.passed,
                    detail: [result.reason, result.metric].compactMap(\.self).joined(separator: " · ")
                ))
            }
        } else {
            gates.append(.init(title: "Entity gate", passed: true, detail: "No raw entities to filter."))
        }

        if chain.arcs.isEmpty {
            let pass = expectation != .arcExpected
            gates.append(.init(
                title: "Arc gate",
                passed: pass,
                detail: pass ? "No stored arc for target record, as expected." : "No stored arc for target record."
            ))
        } else {
            for arc in chain.arcs {
                gates.append(.init(
                    title: "Arc \(arc.title)",
                    passed: expectation != .noArcNoReflection,
                    detail: "records \(arc.sourceRecordIDs.count) · cluster \(arc.clusterStrength)"
                ))
            }
        }

        if let analysis = chain.analysis {
            let result = reflectionPolicy.shouldRequestRecordReflection(record: chain.record, artifacts: chain.artifacts, analysis: analysis)
            let pass = expectation == .noArcNoReflection ? !result.passed : (result.passed || expectation == .inspectOnly)
            gates.append(.init(
                title: "Record reflection request",
                passed: pass,
                detail: [result.reason, result.metric].compactMap(\.self).joined(separator: " · ")
            ))
        }

        return gates
    }

    private func rawQualityTuningEntities(from responseBody: String?) -> [EntityReference]? {
        guard
            let data = responseBody?.data(using: .utf8),
            let envelope = try? JSONDecoder().decode(AnalyzeResponseEnvelope.self, from: data)
        else {
            return nil
        }
        return envelope.entities.compactMap { entity in
            guard let kind = EntityKind(rawValue: entity.kind.lowercased()) else { return nil }
            return EntityReference(kind: kind, name: entity.name, aliases: entity.aliases ?? [], confidence: entity.confidence)
        }
    }

    private func makeQualityTuningPreference(from store: QualityTuningPreferenceStore) -> QualityTuningPreference {
        let thresholds = store.thresholdsData
            .flatMap { try? JSONDecoder().decode(QualityTuningThresholds.self, from: $0) }
            ?? .defaults
        return QualityTuningPreference(
            id: store.id,
            schemaVersion: store.schemaVersion,
            syncKey: store.syncKey,
            promptProfile: QualityTuningPromptProfile(rawValue: store.promptProfileRawValue) ?? .balanced,
            thresholds: thresholds,
            notes: store.notes,
            updatedAt: store.updatedAt
        )
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let stores = try modelContext.fetch(FetchDescriptor<T>())
        for store in stores {
            modelContext.delete(store)
        }
    }

    private func purgeDerivedDataForRefresh(recordID: UUID) throws {
        try purgeDerivedData(forRecordIDs: [recordID], includePipelineStatus: false)
    }

    private func purgeDerivedData(forRecordIDs recordIDs: Set<UUID>, includePipelineStatus: Bool) throws {
        guard !recordIDs.isEmpty else { return }

        let artifactIDs = Set(
            try modelContext.fetch(FetchDescriptor<ArtifactStore>())
                .filter { recordIDs.contains($0.recordID) }
                .map(\.id)
        )

        let analysisStores = try modelContext.fetch(FetchDescriptor<RecordAnalysisSnapshotStore>())
            .filter { recordIDs.contains($0.recordID) }
        analysisStores.forEach { modelContext.delete($0) }

        if includePipelineStatus {
            let pipelineStores = try modelContext.fetch(FetchDescriptor<MemoryPipelineStatusStore>())
                .filter { recordIDs.contains($0.recordID) }
            pipelineStores.forEach { modelContext.delete($0) }
        }

        let allLinks = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        let linkIDsToDelete = Set(
            allLinks
                .filter { link in
                    artifactIDs.contains(link.artifactID)
                        || link.sourceRecordID.map { recordIDs.contains($0) } == true
                        || link.sourceAnalysisRecordID.map { recordIDs.contains($0) } == true
                }
                .map(\.id)
        )
        allLinks
            .filter { linkIDsToDelete.contains($0.id) }
            .forEach { modelContext.delete($0) }
        let remainingLinkedEntityIDs = Set(
            allLinks
                .filter { !linkIDsToDelete.contains($0.id) }
                .map(\.entityID)
        )

        let edgeStores = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>())
            .filter { store in
                store.sourceRecordIDs.contains { recordIDs.contains($0) }
                    || store.sourceArtifactIDs.contains { artifactIDs.contains($0) }
            }
        edgeStores.forEach { modelContext.delete($0) }

        let arcStores = try modelContext.fetch(FetchDescriptor<TemporalArcStore>())
        let arcIDsToDelete = Set(
            arcStores
                .filter { store in
                    store.sourceRecordIDs.contains { recordIDs.contains($0) }
                        || store.sourceArtifactIDs.contains { artifactIDs.contains($0) }
                }
                .map(\.id)
        )
        arcStores
            .filter { arcIDsToDelete.contains($0.id) }
            .forEach { modelContext.delete($0) }

        let reflectionStores = try modelContext.fetch(FetchDescriptor<ReflectionSnapshotStore>())
            .filter { store in
                store.sourceRecordIDs.contains { recordIDs.contains($0) }
                    || store.sourceArtifactIDs.contains { artifactIDs.contains($0) }
                    || store.linkedTemporalArcID.map { arcIDsToDelete.contains($0) } == true
            }
        reflectionStores.forEach { modelContext.delete($0) }

        try purgeEntityProvenance(removing: recordIDs, remainingLinkedEntityIDs: remainingLinkedEntityIDs)
    }

    private func purgeEntityProvenance(
        removing recordIDs: Set<UUID>,
        remainingLinkedEntityIDs: Set<UUID>
    ) throws {
        let entityStores = try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
        for store in entityStores {
            var entity = store.domainModel
            let originalProvenance = entity.provenanceRecordIDs
            entity.provenanceRecordIDs.removeAll { recordIDs.contains($0) }

            if entity.provenanceRecordIDs.isEmpty && !remainingLinkedEntityIDs.contains(entity.id) {
                modelContext.delete(store)
            } else if entity.provenanceRecordIDs != originalProvenance {
                entity.updatedAt = Date.now
                store.apply(domainModel: entity)
            }
        }
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
        try await refreshMemoryPipeline(recordID: recordID)
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

    private func replayDebugReflection(reflectionID: UUID) async throws -> DebugPipelineTraceSnapshot? {
        let memories = try fetchRecentMemories(limit: nil)
        return try await debugDiagnosticsService.replayReflection(
            reflectionID: reflectionID,
            modelContext: modelContext,
            memories: memories,
            analysisService: analysisService
        )
    }

    func fetchDebugFixtureSnapshot(recordID: UUID) throws -> DebugMemoryFixtureSnapshot? {
        try debugDiagnosticsService.fetchFixtureSnapshot(
            recordID: recordID,
            modelContext: modelContext,
            artifactsFetcher: fetchArtifacts,
            recordAnalysisFetcher: fetchRecordAnalysis,
            pipelineStatusFetcher: fetchPipelineStatus
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
        let recordID = recordAnalysis.recordID
        let descriptor = FetchDescriptor<RecordAnalysisSnapshotStore>(predicate: #Predicate { $0.recordID == recordID })
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

    private func makeMemorySummary(
        record: RecordShell,
        artifacts: [Artifact],
        pipelineStatus: MemoryPipelineStatusSnapshot?
    ) -> MemorySummary {
        let contextKinds: Set<ArtifactKind> = [.location, .weather, .music]
        let contextArtifacts = artifacts
            .filter { contextKinds.contains($0.kind) }
            .sorted { $0.updatedAt > $1.updatedAt }

        return MemorySummary(
            record: record,
            primaryArtifact: captureArtifactBuilder.preferredPrimaryArtifact(from: artifacts),
            contextArtifacts: contextArtifacts,
            artifactCount: artifacts.count,
            pipelineStatus: pipelineStatus
        )
    }

    private func applyLimit<T>(_ limit: Int?, to values: [T]) -> [T] {
        guard let limit else { return values }
        return Array(values.prefix(limit))
    }
}
