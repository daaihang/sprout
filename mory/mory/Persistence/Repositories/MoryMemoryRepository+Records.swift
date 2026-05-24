import Foundation
import SwiftData

extension MoryMemoryRepository {
    // MARK: - Records & Artifacts

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
        try makeAffectSnapshots(from: draft, recordID: recordID, createdAt: now).forEach { try upsert(affectSnapshot: $0) }
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

        let summary = makeMemorySummary(
            record: recordShell,
            artifacts: captureArtifacts,
            pipelineStatus: try fetchPipelineStatus(recordID: recordID)
        )
        await indexMemoryIfPossible(summary)
        return summary
    }

    func applyMemoryMutation(
        recordID: UUID,
        mutation: MemoryMutationDraft,
        refreshPolicy: MemoryMutationRefreshPolicy
    ) async throws -> MemoryMutationResult {
        let mutationID = UUID()
        guard mutation.hasChanges else {
            let detail = try fetchMemoryDetail(recordID: recordID)
            let pipelineStatus = if let detail {
                detail.pipelineStatus
            } else {
                try fetchPipelineStatus(recordID: recordID)
            }
            return MemoryMutationResult(
                mutationID: mutationID,
                detail: detail,
                addedArtifactIDs: [],
                updatedArtifactIDs: [],
                deletedArtifactIDs: [],
                reorderedArtifactIDs: [],
                invalidatedDerivedData: false,
                pipelineStatus: pipelineStatus
            )
        }

        guard let recordStore = try modelContext.fetch(
            FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordID })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let now = Date.now
        var updatedRecord = recordStore.domainModel
        let existingArtifactIDs = Set(updatedRecord.artifactIDs)
        let deletedArtifactIDs = orderedUniqueUUIDs(mutation.deletedArtifactIDs)

        switch mutation.recordPatch.rawText {
        case .unchanged:
            break
        case let .set(rawText):
            updatedRecord.rawText = rawText?.trimmedOrNil ?? updatedRecord.rawText
        }

        switch mutation.recordPatch.userMood {
        case .unchanged:
            break
        case let .set(userMood):
            updatedRecord.userMood = userMood?.trimmedOrNil
        }

        switch mutation.recordPatch.inputContext {
        case .unchanged:
            break
        case let .set(inputContext):
            updatedRecord.inputContext = inputContext?.trimmedOrNil
        }

        switch mutation.recordPatch.captureSource {
        case .unchanged:
            break
        case let .set(captureSource):
            if let captureSource {
                updatedRecord.captureSource = captureSource
            }
        }

        let addedArtifacts = mutation.addedArtifacts.isEmpty
            ? []
            : captureArtifactBuilder.buildArtifacts(
                from: MemoryCaptureDraft(rawText: "", artifacts: mutation.addedArtifacts),
                recordID: recordID,
                createdAt: now
            )

        var updatedArtifactIDs: [UUID] = []
        var normalizedUpdatedArtifacts: [Artifact] = []
        for var artifact in mutation.updatedArtifacts {
            guard artifact.recordID == recordID else {
                throw CocoaError(.fileNoSuchFile)
            }
            guard try fetchArtifact(id: artifact.id)?.recordID == recordID else {
                throw CocoaError(.fileNoSuchFile)
            }
            artifact.updatedAt = now
            normalizedUpdatedArtifacts.append(artifact)
            updatedArtifactIDs.append(artifact.id)
        }
        updatedArtifactIDs = orderedUniqueUUIDs(updatedArtifactIDs)

        for artifactID in deletedArtifactIDs {
            let belongsToRecord: Bool
            if existingArtifactIDs.contains(artifactID) {
                belongsToRecord = true
            } else {
                belongsToRecord = try fetchArtifact(id: artifactID)?.recordID == recordID
            }
            guard belongsToRecord else {
                throw CocoaError(.fileNoSuchFile)
            }
        }

        var artifactIDs = updatedRecord.artifactIDs
        artifactIDs.removeAll { deletedArtifactIDs.contains($0) }
        artifactIDs.append(contentsOf: addedArtifacts.map(\.id))
        artifactIDs = orderedUniqueUUIDs(artifactIDs)

        var reorderedArtifactIDs: [UUID] = []
        if let requestedOrder = mutation.artifactOrder {
            let uniqueRequestedOrder = orderedUniqueUUIDs(requestedOrder)
            let requestedSet = Set(uniqueRequestedOrder)
            let knownSet = Set(artifactIDs)
            guard requestedSet.isSubset(of: knownSet) else {
                throw CocoaError(.fileNoSuchFile)
            }
            let remaining = artifactIDs.filter { !requestedSet.contains($0) }
            artifactIDs = uniqueRequestedOrder + remaining
            reorderedArtifactIDs = uniqueRequestedOrder
        }

        try purgeDerivedDataForRefresh(recordID: recordID)

        for artifact in addedArtifacts {
            try upsert(artifact: artifact)
        }
        for artifact in normalizedUpdatedArtifacts {
            try upsert(artifact: artifact)
        }
        for artifactID in deletedArtifactIDs {
            if let store = try modelContext.fetch(FetchDescriptor<ArtifactStore>(predicate: #Predicate { $0.id == artifactID })).first {
                modelContext.delete(store)
            }
        }

        updatedRecord.artifactIDs = artifactIDs
        updatedRecord.updatedAt = now
        recordStore.apply(domainModel: updatedRecord)
        if mutation.recordPatch.userMood.shouldUpdate {
            try replaceUserAffectSnapshot(recordID: recordID, rawMood: updatedRecord.userMood, now: now)
        }

        try upsertPendingPipelineStatus(recordID: recordID, updatedAt: now)
        try save()

        var detail = try fetchMemoryDetail(recordID: recordID)
        if let detail {
            await indexMemoryIfPossible(
                makeMemorySummary(
                    record: detail.record,
                    artifacts: detail.artifacts,
                    pipelineStatus: detail.pipelineStatus
                )
            )
        }

        if refreshPolicy == .runImmediately {
            try await refreshMemoryPipeline(recordID: recordID)
            detail = try fetchMemoryDetail(recordID: recordID)
        }

        let pipelineStatus = if let detail {
            detail.pipelineStatus
        } else {
            try fetchPipelineStatus(recordID: recordID)
        }

        return MemoryMutationResult(
            mutationID: mutationID,
            detail: detail,
            addedArtifactIDs: addedArtifacts.map(\.id),
            updatedArtifactIDs: updatedArtifactIDs,
            deletedArtifactIDs: deletedArtifactIDs,
            reorderedArtifactIDs: reorderedArtifactIDs,
            invalidatedDerivedData: true,
            pipelineStatus: pipelineStatus
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

        let result = try await applyMemoryMutation(
            recordID: recordID,
            mutation: MemoryMutationDraft(addedArtifacts: drafts),
            refreshPolicy: .markPending
        )
        guard let detail = result.detail else { return nil }
        return makeMemorySummary(
            record: detail.record,
            artifacts: detail.artifacts,
            pipelineStatus: detail.pipelineStatus
        )
    }

    func deleteMemory(recordID: UUID) throws {
        try purgeDerivedData(forRecordIDs: [recordID], includePipelineStatus: true)
        try deleteMemoryDetailPresentationPreference(recordID: recordID, saveAfterDelete: false)
        if let record = try modelContext.fetch(FetchDescriptor<RecordShellStore>(predicate: #Predicate { $0.id == recordID })).first {
            modelContext.delete(record)
        }
        let affectSnapshots = try modelContext.fetch(FetchDescriptor<AffectSnapshotStore>(predicate: #Predicate { $0.recordID == recordID }))
        affectSnapshots.forEach { modelContext.delete($0) }
        let artifacts = try modelContext.fetch(FetchDescriptor<ArtifactStore>(predicate: #Predicate { $0.recordID == recordID }))
        artifacts.forEach { modelContext.delete($0) }
        try save()
        Task { @MainActor [spotlightIndexService, spotlightItemBuilder] in
            try? await spotlightIndexService.deleteItems(
                identifiers: [spotlightItemBuilder.memoryIdentifier(recordID)]
            )
        }
    }

    func updateMemory(recordID: UUID, draft: MemoryEditDraft) async throws -> MemoryDetailSnapshot? {
        let addedArtifacts: [CaptureArtifactDraft]
        if let appendedArtifactText = draft.appendedArtifactText?.trimmedOrNil {
            addedArtifacts = [.text(title: appendedArtifactText.firstMeaningfulLine ?? "Added Note", body: appendedArtifactText)]
        } else {
            addedArtifacts = []
        }

        let result = try await applyMemoryMutation(
            recordID: recordID,
            mutation: MemoryMutationDraft(
                recordPatch: MemoryMutationRecordPatch(
                    rawText: .set(draft.rawText),
                    userMood: .set(draft.userMood),
                    inputContext: .set(draft.inputContext)
                ),
                addedArtifacts: addedArtifacts
            ),
            refreshPolicy: .markPending
        )
        return result.detail
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
            do {
                try runLocalIntelligenceLoop(record: record, artifacts: artifacts)
            } catch {
                try markLatestPostAnalysisJobFailed(recordID: recordID, error: error)
            }
            let trace = latestAnalysisTrace
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
            if let summary = try? makeMemorySummary(
                record: record,
                artifacts: artifacts,
                pipelineStatus: fetchPipelineStatus(recordID: recordID)
            ) {
                await indexMemoryIfPossible(summary)
            }
            NotificationCenter.default.post(
                name: .pipelineDidComplete,
                object: nil,
                userInfo: ["recordID": recordID]
            )
        } catch {
            let trace = latestAnalysisTrace
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
