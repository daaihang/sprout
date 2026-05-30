import Foundation
import SwiftData

extension MoryMemoryRepository {
    // MARK: - Records & Artifacts

    func createMemory(from draft: MemoryCaptureDraft) async throws -> MemorySummary {
        try await MemoryCreationUseCase(
            repository: self,
            artifactBuilder: captureArtifactBuilder
        ).createMemory(from: draft)
    }

    func applyMemoryMutation(
        recordID: UUID,
        mutation: MemoryMutationDraft,
        refreshPolicy: MemoryMutationRefreshPolicy
    ) async throws -> MemoryMutationResult {
        try await memoryMutationUseCase.applyMemoryMutation(
            recordID: recordID,
            mutation: mutation,
            refreshPolicy: refreshPolicy
        )
    }

    func appendArtifacts(recordID: UUID, drafts: [CaptureArtifactDraft]) async throws -> MemorySummary? {
        try await memoryMutationUseCase.appendArtifacts(recordID: recordID, drafts: drafts)
    }

    func deleteMemory(recordID: UUID) throws {
        try memoryMutationUseCase.deleteMemory(recordID: recordID)
    }

    func updateMemory(recordID: UUID, draft: MemoryEditDraft) async throws -> MemoryDetailSnapshot? {
        try await memoryMutationUseCase.updateMemory(recordID: recordID, draft: draft)
    }

    func refreshMemoryPipeline(recordID: UUID) async throws {
        try await memoryMutationUseCase.refreshMemoryPipeline(recordID: recordID)
    }

    private var memoryMutationUseCase: MemoryMutationUseCase {
        MemoryMutationUseCase(
            repository: self,
            artifactBuilder: captureArtifactBuilder
        )
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

    func fetchMemoryLibrary(filter: MemoryLibraryFilter, limit: Int? = nil) throws -> MemoryLibrarySnapshot {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
        let rows = try memories.map { memory in
            try makeMemoryLibraryRow(memory: memory, graphContext: graphContext)
        }
        let filteredRows = rows.filter { row in
            memoryLibraryRow(row, matches: filter)
        }
        let limitedRows = applyLimit(limit, to: filteredRows)
        let calendar = Calendar.current
        let groups = Dictionary(grouping: limitedRows) { row in
            calendar.startOfDay(for: row.memory.record.updatedAt)
        }
        .map { date, rows in
            MemoryLibraryDayGroup(
                date: date,
                rows: rows.sorted { $0.memory.record.updatedAt > $1.memory.record.updatedAt }
            )
        }
        .sorted { $0.date > $1.date }

        let availableArtifactKinds = Array(Set(rows.flatMap(\.artifactKinds))).sorted { $0.rawValue < $1.rawValue }
        let availablePipelineStages = Array(Set(rows.compactMap(\.memory.pipelineStatus?.stage))).sorted { $0.rawValue < $1.rawValue }

        return MemoryLibrarySnapshot(
            filter: filter,
            groups: groups,
            totalCount: rows.count,
            filteredCount: filteredRows.count,
            metadata: MemoryLibraryFilterMetadata(
                availableArtifactKinds: availableArtifactKinds,
                availablePipelineStages: availablePipelineStages,
                contextMemoryCount: rows.filter(\.hasContext).count,
                insightMemoryCount: rows.filter(\.hasInsights).count
            )
        )
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

    // MARK: - Records Fetching & Search

    func fetchArtifacts(recordID: UUID) throws -> [Artifact] {
        let descriptor = FetchDescriptor<ArtifactStore>(
            predicate: #Predicate { $0.recordID == recordID },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domainModel)
    }

    func fetchArtifactSemanticDigests(recordID: UUID) throws -> [ArtifactSemanticDigest] {
        let descriptor = FetchDescriptor<ArtifactSemanticDigestStore>(
            predicate: #Predicate { $0.recordID == recordID },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domainModel)
    }

    func fetchMemoryCardArrangement(recordID: UUID) throws -> MemoryCardArrangement? {
        let descriptor = FetchDescriptor<MemoryCardArrangementStore>(
            predicate: #Predicate { $0.recordID == recordID }
        )
        return try modelContext.fetch(descriptor).first?.domainModel
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
            artifactSemanticDigests: try fetchArtifactSemanticDigests(recordID: recordID),
            cardArrangement: try fetchMemoryCardArrangement(recordID: recordID),
            analysis: try fetchRecordAnalysis(recordID: recordID),
            pipelineStatus: try fetchPipelineStatus(recordID: recordID),
            entities: entities,
            edges: edges,
            arcs: arcs,
            reflections: reflections
        )
    }

    func fetchArtifact(id: UUID) throws -> Artifact? {
        let descriptor = FetchDescriptor<ArtifactStore>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func fetchArtifactOriginRepairPreview() throws -> ArtifactOriginRepairPreview {
        let stores = try modelContext.fetch(FetchDescriptor<ArtifactStore>())
        let missingStores = stores.filter { store in
            store.domainModel.metadata["captureOrigin"] == nil
        }
        let groupedKinds = Dictionary(grouping: missingStores) { store in
            ArtifactKind(rawValue: store.kindRawValue) ?? .text
        }
        let kindCounts = groupedKinds
            .map { ArtifactOriginRepairKindCount(kind: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return lhs.count > rhs.count
            }

        return ArtifactOriginRepairPreview(
            totalArtifactCount: stores.count,
            missingOriginCount: missingStores.count,
            kindCounts: kindCounts,
            generatedAt: Date.now
        )
    }

    func backfillMissingArtifactOrigins(_ origin: CaptureArtifactOrigin) throws -> ArtifactOriginRepairResult {
        let stores = try modelContext.fetch(FetchDescriptor<ArtifactStore>())
        let now = Date.now
        var repairedArtifactIDs: [UUID] = []

        for store in stores {
            var artifact = store.domainModel
            guard artifact.metadata["captureOrigin"] == nil else { continue }
            artifact.metadata["captureOrigin"] = origin.rawValue
            artifact.updatedAt = now
            store.apply(domainModel: artifact)
            repairedArtifactIDs.append(artifact.id)
        }

        if !repairedArtifactIDs.isEmpty {
            try save()
        }

        return ArtifactOriginRepairResult(
            repairedCount: repairedArtifactIDs.count,
            origin: origin,
            repairedArtifactIDs: repairedArtifactIDs,
            generatedAt: now
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

    func searchSemanticFirst(query: String, limit: Int? = nil) async throws -> SearchSnapshot {
        var fallback = try search(query: query, limit: limit)
        guard query.trimmedOrNil != nil else { return fallback }
        guard try isSemanticSearchActive() else {
            fallback.semanticSearchStatus = .disabled
            return fallback
        }
        guard spotlightIndexService.isIndexingAvailable else {
            fallback.semanticSearchStatus = .unavailable
            return fallback
        }

        do {
            let semanticMemoryIDs = try await spotlightIndexService.searchMemoryIDs(
                query: query,
                limit: limit ?? 12,
                domainIdentifier: spotlightItemBuilder.memoryDomain
            )
            let memories = try fetchRecentMemories(limit: nil)
            return searchResultMerger.merge(
                fallback: fallback,
                semanticMemoryIDs: semanticMemoryIDs,
                memories: memories,
                limit: limit
            )
        } catch {
            fallback.semanticSearchStatus = .failed(error.localizedDescription)
            return fallback
        }
    }

    func rebuildSpotlightIndex() async throws -> SpotlightIndexReport {
        guard try isSemanticSearchActive() else {
            return .skipped("Semantic search is disabled.")
        }
        guard spotlightIndexService.isIndexingAvailable else {
            return .skipped("Core Spotlight indexing is unavailable.")
        }

        let memories = try fetchRecentMemories(limit: nil)
        let analyses = try fetchRecordAnalysisIndex()
        let items = try memories.map { memory in
            spotlightItemBuilder.makeMemoryItem(
                memory: memory,
                artifacts: try fetchArtifacts(recordID: memory.id),
                analysis: analyses[memory.id]
            )
        }
        try await spotlightIndexService.indexItems(items)
        return SpotlightIndexReport(indexedItemCount: items.count, deletedItemCount: 0, skippedReason: nil)
    }

    func deleteSpotlightIndex() async throws -> SpotlightIndexReport {
        guard spotlightIndexService.isIndexingAvailable else {
            return .skipped("Core Spotlight indexing is unavailable.")
        }
        try await spotlightIndexService.deleteDomain(spotlightItemBuilder.memoryDomain)
        return SpotlightIndexReport(indexedItemCount: 0, deletedItemCount: 0, skippedReason: nil)
    }

}
