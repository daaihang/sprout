import Foundation
import SwiftData

@MainActor
final class MoryMemoryRepository: MoryMemoryRepositorying {
    private let modelContext: ModelContext
    private let analysisService: any RecordAnalysisServing
    private let architecturePipelineExecutor = ArchitecturePipelineExecutor()
    private let homeBoardRuleEngine = HomeBoardRuleEngine()
    private let graphQueryService = MemoryGraphQueryService()
    private let memorySearchService = MemorySearchService()
    private let searchResultMerger = SearchResultMerger()
    private let spotlightIndexService: any SpotlightIndexServicing
    private let spotlightItemBuilder: SpotlightSearchableItemBuilder
    private let captureArtifactBuilder = MemoryCaptureArtifactBuilder()
    private let temporalArcService = TemporalArcService()
    private let debugDiagnosticsService = DebugDiagnosticsService()
    private let intelligenceScheduler = IntelligenceScheduler()
    private let entityEnrichmentService = EntityEnrichmentService()
    private let clarificationQuestionBuilder = ClarificationQuestionBuilder()
    private let graphDeltaApplier = GraphDeltaApplier()
    private let affectSnapshotMapper = AffectSnapshotMapper()
    private var latestReflectionTrace: DebugPipelineTraceSnapshot?

    init(
        modelContext: ModelContext,
        analysisService: any RecordAnalysisServing,
        spotlightIndexService: (any SpotlightIndexServicing)? = nil,
        localDataOwnerID: String? = nil
    ) {
        self.modelContext = modelContext
        self.analysisService = analysisService
        self.spotlightIndexService = spotlightIndexService ?? DefaultSpotlightIndexService()
        self.spotlightItemBuilder = SpotlightSearchableItemBuilder(ownerID: localDataOwnerID)
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

    func fetchHomeBoard(for date: Date, limit: Int = 8) throws -> HomeBoardSnapshot {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
        let flags = try fetchV6FeatureFlags()
        let intelligencePreferences = try fetchIntelligencePreferences()
        return homeBoardRuleEngine.buildHomeBoard(
            date: date,
            limit: limit,
            graphContext: graphContext,
            memories: memories,
            analyses: try fetchRecordAnalysisIndex(),
            pipelineStatuses: try fetchPipelineStatusSummaries(limit: nil),
            preferences: try fetchHomeBoardPreferences(),
            clarificationQuestions: shouldShowClarificationQuestions(flags: flags, preferences: intelligencePreferences)
                ? try fetchClarificationQuestions(status: .pending, limit: 4)
                : [],
            entityProfiles: flags.entityProfiles ? try fetchEntityProfiles(kind: .person, limit: nil) : []
        )
    }

    func fetchHomeBoardDebugSnapshot(for date: Date, limit: Int = 8) throws -> HomeBoardDebugSnapshot {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(
            modelContext: modelContext,
            memories: memories
        )
        let analyses = try fetchRecordAnalysisIndex()
        let pipelineStatuses = try fetchPipelineStatusSummaries(limit: nil)
        let preferences = try fetchHomeBoardPreferences()
        let flags = try fetchV6FeatureFlags()
        let intelligencePreferences = try fetchIntelligencePreferences()
        let board = homeBoardRuleEngine.buildHomeBoard(
            date: date,
            limit: limit,
            graphContext: graphContext,
            memories: memories,
            analyses: analyses,
            pipelineStatuses: pipelineStatuses,
            preferences: preferences,
            clarificationQuestions: shouldShowClarificationQuestions(flags: flags, preferences: intelligencePreferences)
                ? try fetchClarificationQuestions(status: .pending, limit: 4)
                : [],
            entityProfiles: flags.entityProfiles ? try fetchEntityProfiles(kind: .person, limit: nil) : []
        )
        let calendar = Calendar.current
        let recent24HourCutoff = date.addingTimeInterval(-24 * 60 * 60)
        let recent7DayCutoff = date.addingTimeInterval(-7 * 24 * 60 * 60)
        let recentRecordIDs = Set(memories.filter { $0.record.updatedAt >= recent24HourCutoff }.map(\.id))
        let acceptedArcs = graphContext.arcs.filter { $0.status == .accepted }
        let activeAcceptedArcs = acceptedArcs.filter { arc in
            arc.updatedAt >= recent7DayCutoff || arc.sourceRecordIDs.contains { recentRecordIDs.contains($0) }
        }

        return HomeBoardDebugSnapshot(
            generatedAt: .now,
            date: date,
            limit: limit,
            input: HomeBoardDebugInputSnapshot(
                memoryCount: memories.count,
                todayMemoryCount: memories.filter { calendar.isDate($0.record.updatedAt, inSameDayAs: date) }.count,
                recent24HourMemoryCount: recentRecordIDs.count,
                contextMemoryCount: memories.filter { !$0.contextArtifacts.isEmpty }.count,
                highSalienceMemoryCount: analyses.values.filter { ($0.salienceScore ?? 0) >= 0.65 }.count,
                graphLinkCount: graphContext.links.count,
                entityCount: graphContext.entities.count,
                edgeCount: graphContext.edges.count,
                acceptedArcCount: acceptedArcs.count,
                activeAcceptedArcCount: activeAcceptedArcs.count,
                suggestedReflectionCount: graphContext.reflections.filter { $0.status == .suggested }.count,
                savedReflectionCount: graphContext.reflections.filter { $0.status == .saved }.count,
                runningPipelineCount: pipelineStatuses.filter { $0.status.stage == .running }.count,
                failedPipelineCount: pipelineStatuses.filter { $0.status.stage == .failed }.count
            ),
            preferences: HomeBoardDebugPreferenceSnapshot(
                totalCount: preferences.count,
                pinnedCount: preferences.filter(\.isPinned).count,
                hiddenCount: preferences.filter(\.isHidden).count,
                dismissedCount: preferences.filter { $0.dismissedAt != nil }.count
            ),
            board: board
        )
    }

    func updateHomeBoardItemPreference(_ item: HomeBoardItemSnapshot, action: HomeBoardPreferenceAction) throws {
        let now = Date.now
        try applyHomeBoardItemPreference(item, action: action, updatedAt: now)
        try save()
    }

    func updateHomeBoardItemPreferences(_ updates: [(item: HomeBoardItemSnapshot, action: HomeBoardPreferenceAction)]) throws {
        let now = Date.now
        for update in updates {
            try applyHomeBoardItemPreference(update.item, action: update.action, updatedAt: now)
        }
        try save()
    }

    private func applyHomeBoardItemPreference(
        _ item: HomeBoardItemSnapshot,
        action: HomeBoardPreferenceAction,
        updatedAt now: Date
    ) throws {
        let syncKey = homeBoardPreferenceSyncKey(cardKey: item.compositionItem.itemKey)
        let existing = try fetchHomeBoardPreference(syncKey: syncKey)
        var preference = existing ?? HomeBoardItemPreference(
            syncKey: syncKey,
            boardKey: item.compositionItem.boardKey,
            cardKey: item.compositionItem.itemKey,
            cardKind: item.cardKind,
            targetType: item.compositionItem.targetType,
            targetID: item.compositionItem.targetID,
            updatedAt: now
        )

        preference.cardKind = item.cardKind
        preference.targetType = item.compositionItem.targetType
        preference.targetID = item.compositionItem.targetID
        preference.updatedAt = now
        switch action {
        case .addToBoard:
            preference.acceptedAt = preference.acceptedAt ?? now
            preference.userSortIndex = preference.userSortIndex ?? now.timeIntervalSinceReferenceDate
            preference.widthColumns = preference.widthColumns ?? item.layout.span.widthColumns
            preference.heightUnits = preference.heightUnits ?? item.layout.span.heightUnits
            preference.isHidden = false
            preference.dismissedAt = nil
        case let .pin(isPinned):
            preference.isPinned = isPinned
            preference.isHidden = false
            preference.dismissedAt = nil
            if isPinned {
                preference.acceptedAt = preference.acceptedAt ?? now
                preference.userSortIndex = preference.userSortIndex ?? now.timeIntervalSinceReferenceDate
            }
        case let .resize(span):
            let clamped = span.clamped(to: 8)
            preference.widthColumns = clamped.widthColumns
            preference.heightUnits = clamped.heightUnits
            preference.acceptedAt = preference.acceptedAt ?? now
            preference.isHidden = false
            preference.dismissedAt = nil
        case let .setUserOrder(sortIndex):
            preference.userSortIndex = sortIndex
            preference.acceptedAt = preference.acceptedAt ?? now
            preference.isHidden = false
            preference.dismissedAt = nil
        case .preferMore:
            preference.feedbackAdjustment = min(preference.feedbackAdjustment + 12, 36)
            preference.feedbackUpdatedAt = now
            preference.isHidden = false
            preference.dismissedAt = nil
        case .preferLess:
            preference.feedbackAdjustment = max(preference.feedbackAdjustment - 18, -48)
            preference.feedbackUpdatedAt = now
            preference.isHidden = false
            preference.dismissedAt = nil
        case .resetFeedback:
            preference.feedbackAdjustment = 0
            preference.feedbackUpdatedAt = now
            preference.isHidden = false
            preference.dismissedAt = nil
        case .hide:
            preference.isHidden = true
            preference.isPinned = false
        case .dismiss:
            preference.dismissedAt = now
            preference.isPinned = false
        }

        try upsert(homeBoardPreference: preference)
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
        try deleteAll(NotificationIntentStore.self)
        try deleteAll(HomeBoardSignalStore.self)
        try deleteAll(GraphDeltaStore.self)
        try deleteAll(IntelligenceJobStore.self)
        try deleteAll(CorrectionEventStore.self)
        try deleteAll(EntityTombstoneStore.self)
        try deleteAll(ClarificationQuestionStore.self)
        try deleteAll(PlaceProfileStore.self)
        try deleteAll(SelfProfileStore.self)
        try deleteAll(PersonProfileStore.self)
        try deleteAll(AffectSnapshotStore.self)
        try deleteAll(EntityProfileStore.self)
        try deleteAll(HomeBoardPreferenceStore.self)
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
        try deleteAll(MemoryDetailPresentationPreferenceStore.self)
        try deleteAll(ArtifactStore.self)
        try deleteAll(RecordShellStore.self)
        latestReflectionTrace = nil
        try save()
        Task { @MainActor [spotlightIndexService, spotlightItemBuilder] in
            try? await spotlightIndexService.deleteDomain(spotlightItemBuilder.memoryDomain)
        }
    }

    func fetchUserSettingsPreference() throws -> UserSettingsPreference {
        let syncKey = UserSettingsPreference.defaultSyncKey
        let descriptor = FetchDescriptor<UserSettingsPreferenceStore>(
            predicate: #Predicate { $0.syncKey == syncKey }
        )
        guard let store = try modelContext.fetch(descriptor).first else {
            return .defaults
        }
        return store.domainModel
    }

    func saveUserSettingsPreference(_ preference: UserSettingsPreference) throws {
        try upsert(userSettingsPreference: preference)
        try save()
    }

    func fetchMemoryDetailPresentationPreference(recordID: UUID) throws -> MemoryDetailPresentationPreference? {
        let descriptor = FetchDescriptor<MemoryDetailPresentationPreferenceStore>(
            predicate: #Predicate { $0.recordID == recordID }
        )
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func saveMemoryDetailPresentationPreference(_ preference: MemoryDetailPresentationPreference) throws {
        let descriptor = FetchDescriptor<MemoryDetailPresentationPreferenceStore>(
            predicate: #Predicate { $0.recordID == preference.recordID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: preference)
        } else {
            modelContext.insert(MemoryDetailPresentationPreferenceStore(domainModel: preference))
        }
        try save()
    }

    func clearMemoryDetailPresentationPreference(recordID: UUID) throws {
        try deleteMemoryDetailPresentationPreference(recordID: recordID, saveAfterDelete: true)
    }

    func fetchIntelligencePreferences() throws -> IntelligencePreferences {
        guard let store = try fetchIntelligencePreferenceStore() else {
            return .defaults
        }
        return store.preferencesDomainModel
    }

    func saveIntelligencePreferences(_ preferences: IntelligencePreferences) throws {
        let syncKey = IntelligencePreferences.defaultSyncKey
        if let existing = try fetchIntelligencePreferenceStore() {
            var normalized = preferences
            normalized.syncKey = syncKey
            existing.apply(preferences: normalized)
        } else {
            var normalized = preferences
            normalized.syncKey = syncKey
            modelContext.insert(IntelligencePreferenceStore(preferences: normalized, featureFlags: .defaults))
        }
        try save()
    }

    func fetchV6FeatureFlags() throws -> V6FeatureFlags {
        guard let store = try fetchIntelligencePreferenceStore() else {
            return .defaults
        }
        return store.featureFlagsDomainModel
    }

    func saveV6FeatureFlags(_ flags: V6FeatureFlags) throws {
        if let existing = try fetchIntelligencePreferenceStore() {
            existing.apply(featureFlags: flags)
        } else {
            modelContext.insert(IntelligencePreferenceStore(preferences: .defaults, featureFlags: flags))
        }
        try save()
    }

    func fetchSelfProfile() throws -> SelfProfile? {
        try fetchSelfProfileStore(syncKey: SelfProfile.defaultSyncKey)?.domainModel
    }

    func upsertSelfProfile(_ profile: SelfProfile) throws {
        if let existing = try fetchSelfProfileStore(syncKey: profile.syncKey) {
            existing.apply(domainModel: profile)
        } else {
            modelContext.insert(SelfProfileStore(domainModel: profile))
        }
        try save()
    }

    func ensureSelfProfile() throws -> SelfProfile {
        if let existing = try fetchSelfProfile() {
            return existing
        }
        let profile = SelfProfile()
        try upsertSelfProfile(profile)
        return profile
    }

    func fetchEntityProfile(entityID: UUID) throws -> EntityProfile? {
        let descriptor = FetchDescriptor<EntityProfileStore>(
            predicate: #Predicate { $0.entityID == entityID }
        )
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func fetchEntityProfiles(kind: EntityKind?, limit: Int?) throws -> [EntityProfile] {
        let stores = try modelContext.fetch(
            FetchDescriptor<EntityProfileStore>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
        let profiles = stores
            .map(\.domainModel)
            .filter { profile in
                guard let kind else { return true }
                return profile.kind == kind
            }
        return applyLimit(limit, to: profiles)
    }

    func upsertEntityProfile(_ profile: EntityProfile) throws {
        try upsert(entityProfile: profile)
        try save()
    }

    func fetchPersonProfile(entityID: UUID) throws -> PersonProfile? {
        let descriptor = FetchDescriptor<PersonProfileStore>(
            predicate: #Predicate { $0.entityID == entityID }
        )
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func fetchPersonProfiles(limit: Int?) throws -> [PersonProfile] {
        let profiles = try modelContext.fetch(
            FetchDescriptor<PersonProfileStore>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
        .map(\.domainModel)
        return applyLimit(limit, to: profiles)
    }

    func upsertPersonProfile(_ profile: PersonProfile) throws {
        try upsert(personProfile: profile)
        try save()
    }

    func refreshPersonProfile(entityID: UUID, now: Date = .now) throws -> PersonProfile? {
        guard let detail = try fetchEntityDetail(entityID: entityID), detail.entity.kind == .person else {
            return nil
        }
        let entityProfile = try fetchEntityProfile(entityID: entityID)
        let existing = try fetchPersonProfile(entityID: entityID)
        let refreshed = try buildPersonProfile(
            detail: detail,
            entityProfile: entityProfile,
            existing: existing,
            now: now
        )
        try upsert(personProfile: refreshed)
        try save()
        return refreshed
    }

    func applyPersonProfileMutation(_ mutation: PersonProfileMutation) throws -> PersonProfile {
        let now = mutation.createdAt
        let existing = try fetchPersonProfile(entityID: mutation.entityID)
        let profile = if let existing {
            existing
        } else if let refreshed = try refreshPersonProfile(entityID: mutation.entityID, now: now) {
            refreshed
        } else {
            throw PersonEntityMutationError.entityNotFound
        }

        var updated = profile
        switch mutation.field {
        case .displayName:
            guard let value = mutation.stringValue?.trimmedOrNil else {
                throw PersonEntityMutationError.emptyDisplayName
            }
            updated.displayName = value
            updated.canonicalName = value
        case .aliases:
            updated.aliases = normalizedPersonAliases(mutation.stringListValue ?? [])
        case .relationshipToUser:
            updated.relationshipToUser = mutation.relationshipValue
            updated.relationshipHistory.append(RelationshipChange(
                relationship: mutation.relationshipValue,
                note: mutation.note,
                status: .userConfirmed,
                changedAt: now
            ))
        case .roleLabels:
            updated.roleLabels = mergeStrings([], mutation.stringListValue ?? [])
        case .userNotes:
            updated.userNotes = mutation.stringValue?.trimmedOrNil
        case .sensitivity:
            updated.sensitivity = mutation.sensitivityValue ?? updated.sensitivity
        case .automationPolicy:
            updated.automationPolicy = mutation.automationPolicyValue ?? updated.automationPolicy
        case .aiPortrait:
            updated.aiPortrait = nil
        }

        updated.fieldEvidence.removeAll {
            $0.fieldKey == mutation.field.rawValue && $0.source == .userEdit
        }
        updated.fieldEvidence.append(ProfileFieldEvidence(
            fieldKey: mutation.field.rawValue,
            source: .userEdit,
            status: .userConfirmed,
            snippet: mutation.note?.trimmedOrNil ?? "User edited \(mutation.field.rawValue).",
            confidence: 1,
            createdAt: now,
            refreshedAt: now
        ))
        updated.fieldConfidence[mutation.field.rawValue] = 1
        updated.lastReviewedAt = now
        updated.updatedAt = now

        try upsert(personProfile: updated)
        try upsert(correctionEvent: CorrectionEvent(
            kind: .profileFieldUpdated,
            actor: mutation.actor,
            targetEntityIDs: [mutation.entityID],
            note: mutation.note ?? "Person profile field edited: \(mutation.field.rawValue)",
            metadata: [
                "field": mutation.field.rawValue,
            ],
            isReversible: true,
            createdAt: now
        ))
        try save()
        return updated
    }

    func deletePersonProfilePortrait(entityID: UUID) throws -> PersonProfile {
        try applyPersonProfileMutation(
            PersonProfileMutation(
                entityID: entityID,
                field: .aiPortrait,
                note: "AI portrait deleted by user."
            )
        )
    }

    func fetchAffectSnapshot(id: UUID) throws -> AffectSnapshot? {
        let descriptor = FetchDescriptor<AffectSnapshotStore>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    func fetchAffectSnapshots(recordID: UUID?, limit: Int?) throws -> [AffectSnapshot] {
        let stores: [AffectSnapshotStore]
        if let recordID {
            stores = try modelContext.fetch(
                FetchDescriptor<AffectSnapshotStore>(
                    predicate: #Predicate { $0.recordID == recordID },
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
        } else {
            stores = try modelContext.fetch(
                FetchDescriptor<AffectSnapshotStore>(
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
        }
        return applyLimit(limit, to: stores.map(\.domainModel))
    }

    func upsertAffectSnapshot(_ snapshot: AffectSnapshot) throws {
        try upsert(affectSnapshot: snapshot)
        try save()
    }

    func applyAffectCorrection(_ correction: AffectCorrection) throws -> AffectSnapshot {
        let now = correction.createdAt
        let existing: AffectSnapshot?
        if let snapshotID = correction.snapshotID {
            existing = try fetchAffectSnapshot(id: snapshotID)
        } else {
            existing = try fetchAffectSnapshots(recordID: correction.recordID, limit: 1).first
        }

        var updated = existing ?? AffectSnapshot(
            recordID: correction.recordID,
            createdAt: now,
            updatedAt: now
        )
        updated.valence = correction.valence ?? updated.valence
        updated.arousal = correction.arousal ?? updated.arousal
        updated.dominance = correction.dominance ?? updated.dominance
        updated.intensity = correction.intensity ?? updated.intensity
        if !correction.labels.isEmpty {
            updated.labels = orderedUniqueAffectLabels(correction.labels)
        }
        if !correction.toneHints.isEmpty {
            updated.toneHints = orderedUniqueToneHints(correction.toneHints)
        }
        updated.appraisal = correction.appraisal ?? updated.appraisal
        if !updated.sources.contains(.userCorrected) {
            updated.sources.append(.userCorrected)
        }
        updated.confidence = 1
        updated.userConfirmed = true
        updated.needsUserCheck = false
        updated.evidence.append(AffectEvidence(
            source: .userCorrected,
            summary: correction.note?.trimmedOrNil ?? "User corrected affect snapshot.",
            confidence: 1,
            createdAt: now
        ))
        updated.updatedAt = now

        try upsert(affectSnapshot: updated)
        try upsert(correctionEvent: CorrectionEvent(
            kind: .affectCorrection,
            actor: .user,
            targetRecordIDs: [correction.recordID],
            sourceRecordIDs: [correction.recordID],
            note: correction.note ?? "Affect snapshot corrected by user.",
            metadata: [
                "snapshotID": updated.id.uuidString,
                "labels": updated.labels.map(\.rawValue).joined(separator: ","),
                "toneHints": updated.toneHints.map(\.rawValue).joined(separator: ",")
            ],
            isReversible: true,
            createdAt: now
        ))
        try updateSelfExpressionPattern(from: correction, now: now)
        try save()
        return updated
    }

    func fetchPlaceProfiles(limit: Int?) throws -> [PlaceProfile] {
        let profiles = try modelContext.fetch(
            FetchDescriptor<PlaceProfileStore>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
        .map(\.domainModel)
        return applyLimit(limit, to: profiles)
    }

    func upsertPlaceProfile(_ profile: PlaceProfile) throws {
        try upsert(placeProfile: profile)
        try save()
    }

    func fetchPlaceProfile(id: UUID) throws -> PlaceProfile? {
        try fetchPlaceProfileStore(id: id)?.domainModel
    }

    func fetchPlaceProfileArtifacts(id: UUID) throws -> [Artifact] {
        guard let profile = try fetchPlaceProfile(id: id) else {
            throw PlaceProfileMutationError.profileNotFound
        }
        let artifactsByID = Dictionary(uniqueKeysWithValues: try fetchArtifacts(ids: profile.sourceArtifactIDs).map { ($0.id, $0) })
        return profile.sourceArtifactIDs.compactMap { artifactsByID[$0] }
    }

    func renamePlaceProfile(id: UUID, displayName: String, aliases: [String]) throws -> PlaceProfile {
        let now = Date.now
        let resolvedName = try normalizedPlaceDisplayName(displayName)
        let store = try requirePlaceProfileStore(id: id)
        var profile = store.domainModel
        profile.displayName = resolvedName
        profile.canonicalName = resolvedName
        profile.aliases = normalizedPlaceAliases([resolvedName] + aliases)
        profile.confirmationState = .userConfirmed
        profile.updatedAt = now
        store.apply(domainModel: profile)
        try upsertPlaceEntityNode(for: profile, updatedAt: now)
        try save()
        return profile
    }

    func mergePlaceProfiles(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> PlaceProfile {
        let now = Date.now
        let mergingIDSet = Set(mergingIDs)
        guard !mergingIDSet.isEmpty else {
            throw PlaceProfileMutationError.mergeRequiresAtLeastOneOtherProfile
        }
        guard !mergingIDSet.contains(primaryID) else {
            throw PlaceProfileMutationError.mergeCannotIncludePrimary
        }

        let primaryStore = try requirePlaceProfileStore(id: primaryID)
        let mergingStores = try mergingIDSet.map { try requirePlaceProfileStore(id: $0) }
        let mergingProfiles = mergingStores.map(\.domainModel)
        let mergingEntityIDs = Set(mergingProfiles.map(\.entityID))
        let replacementMap = Dictionary(uniqueKeysWithValues: mergingEntityIDs.map { ($0, primaryStore.entityID) })

        var primaryProfile = primaryStore.domainModel
        if let displayName, let trimmedName = displayName.trimmedOrNil {
            primaryProfile.displayName = trimmedName
            primaryProfile.canonicalName = trimmedName
        }
        primaryProfile.aliases = normalizedPlaceAliases(
            [primaryProfile.displayName, primaryProfile.canonicalName]
                + primaryProfile.aliases
                + mergingProfiles.flatMap { [$0.displayName, $0.canonicalName] + $0.aliases }
        )
        primaryProfile.sourceArtifactIDs = mergeUniqueIDs(
            primaryProfile.sourceArtifactIDs,
            mergingProfiles.flatMap(\.sourceArtifactIDs)
        )
        primaryProfile.sourceRecordIDs = mergeUniqueIDs(
            primaryProfile.sourceRecordIDs,
            mergingProfiles.flatMap(\.sourceRecordIDs)
        )
        primaryProfile.confirmationState = .userConfirmed
        primaryProfile.confidence = maxConfidence([primaryProfile] + mergingProfiles)
        primaryProfile.updatedAt = now

        let mergedArtifacts = try fetchArtifacts(ids: primaryProfile.sourceArtifactIDs)
        primaryProfile = recalculatedPlaceProfile(primaryProfile, from: mergedArtifacts, updatedAt: now)
        primaryStore.apply(domainModel: primaryProfile)

        try rewritePlaceGraphReferences(replacing: replacementMap)
        try upsertPlaceEntityNode(for: primaryProfile, updatedAt: now)
        try deletePlaceProfilesAndNodes(stores: mergingStores)
        try save()
        return primaryProfile
    }

    func splitPlaceProfile(id: UUID, movingArtifactIDs: [UUID], displayName: String) throws -> PlaceProfile {
        let now = Date.now
        let resolvedName = try normalizedPlaceDisplayName(displayName)
        let movingIDSet = Set(movingArtifactIDs)
        guard !movingIDSet.isEmpty else {
            throw PlaceProfileMutationError.splitRequiresMovingArtifacts
        }

        let originalStore = try requirePlaceProfileStore(id: id)
        var originalProfile = originalStore.domainModel
        let originalArtifactIDSet = Set(originalProfile.sourceArtifactIDs)
        guard movingIDSet.isSubset(of: originalArtifactIDSet) else {
            throw PlaceProfileMutationError.splitArtifactsNotInProfile
        }
        guard movingIDSet.count < originalArtifactIDSet.count else {
            throw PlaceProfileMutationError.splitCannotMoveAllArtifacts
        }

        let allArtifacts = try fetchArtifacts(ids: originalProfile.sourceArtifactIDs)
        let movingArtifacts = allArtifacts.filter { movingIDSet.contains($0.id) }
        guard movingArtifacts.allSatisfy({ $0.kind == .location }) else {
            throw PlaceProfileMutationError.splitArtifactsMustBeLocations
        }
        let remainingArtifacts = allArtifacts.filter { !movingIDSet.contains($0.id) }

        let newProfile = recalculatedPlaceProfile(
            PlaceProfile(
                entityID: UUID(),
                displayName: resolvedName,
                aliases: [resolvedName],
                sourceArtifactIDs: movingArtifacts.map(\.id),
                sourceRecordIDs: movingArtifacts.map(\.recordID),
                confirmationState: .userConfirmed,
                confidence: originalProfile.confidence,
                createdAt: now,
                updatedAt: now
            ),
            from: movingArtifacts,
            updatedAt: now
        )
        originalProfile.sourceArtifactIDs = remainingArtifacts.map(\.id)
        originalProfile.sourceRecordIDs = mergeUniqueIDs([], remainingArtifacts.map(\.recordID))
        originalProfile.confirmationState = .userConfirmed
        originalProfile.updatedAt = now
        originalProfile = recalculatedPlaceProfile(originalProfile, from: remainingArtifacts, updatedAt: now)

        originalStore.apply(domainModel: originalProfile)
        modelContext.insert(PlaceProfileStore(domainModel: newProfile))
        try movePlaceArtifactLinks(
            artifactIDs: movingIDSet,
            fromEntityID: originalProfile.entityID,
            toProfile: newProfile,
            updatedAt: now
        )
        try splitEntityEdges(
            fromEntityID: originalProfile.entityID,
            toEntityID: newProfile.entityID,
            movingArtifactIDs: movingIDSet,
            movingRecordIDs: Set(movingArtifacts.map(\.recordID))
        )
        try upsertPlaceEntityNode(for: originalProfile, updatedAt: now)
        try upsertPlaceEntityNode(for: newProfile, updatedAt: now)
        try save()
        return newProfile
    }

    func mergePersonEntities(primaryID: UUID, mergingIDs: [UUID], displayName: String?) throws -> EntityProfile {
        let now = Date.now
        let mergingIDSet = Set(mergingIDs)
        guard !mergingIDSet.isEmpty else {
            throw PersonEntityMutationError.mergeRequiresAtLeastOneOtherEntity
        }
        guard !mergingIDSet.contains(primaryID) else {
            throw PersonEntityMutationError.mergeCannotIncludePrimary
        }

        let primaryStore = try requirePersonEntityNodeStore(id: primaryID)
        let mergingStores = try mergingIDSet.map { try requirePersonEntityNodeStore(id: $0) }
        let mergingNodes = mergingStores.map(\.domainModel)
        let replacementMap = Dictionary(uniqueKeysWithValues: mergingNodes.map { ($0.id, primaryID) })

        var primaryNode = primaryStore.domainModel
        if let displayName, let normalized = displayName.trimmedOrNil {
            primaryNode.displayName = normalized
            primaryNode.canonicalName = normalized
        }
        primaryNode.aliases = normalizedPersonAliases(
            [primaryNode.displayName, primaryNode.canonicalName]
                + primaryNode.aliases
                + mergingNodes.flatMap { [$0.displayName, $0.canonicalName] + $0.aliases }
        )
        primaryNode.provenanceRecordIDs = mergeUniqueIDs(
            primaryNode.provenanceRecordIDs,
            mergingNodes.flatMap(\.provenanceRecordIDs)
        )
        primaryNode.updatedAt = now
        let nodeConfidences = [primaryNode.confidence].compactMap { $0 } + mergingNodes.compactMap(\.confidence)
        primaryNode.confidence = nodeConfidences.max()

        let primaryProfile = try fetchEntityProfile(entityID: primaryID)
            ?? makePersonProfile(from: primaryNode, updatedAt: now)
        let mergingProfiles = try mergingIDSet.compactMap { entityID in
            try fetchEntityProfile(entityID: entityID)
        }

        var mergedProfile = primaryProfile
        mergedProfile.displayName = primaryNode.displayName
        mergedProfile.canonicalName = primaryNode.canonicalName
        mergedProfile.aliases = normalizedPersonAliases(
            [primaryNode.displayName, primaryNode.canonicalName]
                + primaryProfile.aliases
                + mergingProfiles.flatMap { [$0.displayName, $0.canonicalName] + $0.aliases }
        )
        mergedProfile.sourceRecordIDs = mergeUniqueIDs(
            primaryProfile.sourceRecordIDs,
            mergingProfiles.flatMap(\.sourceRecordIDs) + primaryNode.provenanceRecordIDs
        )
        mergedProfile.mentionCount = max(
            mergedProfile.sourceRecordIDs.count,
            primaryProfile.mentionCount + mergingProfiles.map(\.mentionCount).reduce(0, +)
        )
        mergedProfile.commonContextLabels = mergeStrings(
            primaryProfile.commonContextLabels,
            mergingProfiles.flatMap(\.commonContextLabels)
        )
        if mergedProfile.relationshipToUser == nil {
            mergedProfile.relationshipToUser = mergingProfiles.compactMap(\.relationshipToUser).first
        }
        mergedProfile.userDescription = mergedProfile.userDescription?.trimmedOrNil
            ?? mergingProfiles.compactMap(\.userDescription).map { $0.trimmedOrNil }.compactMap { $0 }.first
        mergedProfile.confirmationState = .userConfirmed
        let profileConfidences = [primaryProfile.confidence].compactMap { $0 } + mergingProfiles.compactMap(\.confidence)
        mergedProfile.confidence = profileConfidences.max()
        mergedProfile.updatedAt = now
        if mergedProfile.firstMentionedAt == nil {
            mergedProfile.firstMentionedAt = now
        }
        mergedProfile.lastMentionedAt = now

        primaryStore.apply(domainModel: primaryNode)
        try upsert(entityProfile: mergedProfile)
        try mergePersonProfiles(
            primaryID: primaryID,
            mergingIDs: mergingIDSet,
            mergedEntityProfile: mergedProfile,
            now: now
        )
        try rewriteEntityLinksAndEdges(replacing: replacementMap, linkSource: "personProfile")
        try rewriteEntityReferencesForMerge(replacing: replacementMap)
        try deleteEntityProfiles(entityIDs: mergingIDSet)
        try deletePersonProfiles(entityIDs: mergingIDSet)
        try deleteEntityNodes(entityIDs: mergingIDSet)

        let affectedRecordIDs = Set(primaryNode.provenanceRecordIDs + mergingNodes.flatMap(\.provenanceRecordIDs))
        for mergingID in mergingIDSet {
            try upsert(entityTombstone: EntityTombstone(
                oldEntityID: mergingID,
                replacementEntityID: primaryID,
                kind: .person,
                reason: .merged,
                note: "Merged into \(primaryNode.displayName)",
                createdAt: now
            ))
            try upsert(correctionEvent: CorrectionEvent(
                kind: .sameEntity,
                actor: .user,
                targetEntityIDs: [primaryID, mergingID],
                targetRecordIDs: [],
                sourceRecordIDs: Array(affectedRecordIDs),
                note: "Person merge",
                metadata: [
                    "primaryEntityID": primaryID.uuidString,
                    "mergedEntityID": mergingID.uuidString,
                ],
                isReversible: true,
                createdAt: now
            ))
        }

        try enqueueEntityMutationRecomputeJobs(
            affectedRecordIDs: affectedRecordIDs,
            affectedEntityIDs: Set([primaryID] + Array(mergingIDSet))
        )
        try save()
        return mergedProfile
    }

    func splitPersonEntity(
        id: UUID,
        movingRecordIDs: [UUID],
        displayName: String,
        aliases: [String]
    ) throws -> EntityProfile {
        let now = Date.now
        guard let normalizedName = displayName.trimmedOrNil else {
            throw PersonEntityMutationError.emptyDisplayName
        }
        let movingRecordIDSet = Set(movingRecordIDs)
        guard !movingRecordIDSet.isEmpty else {
            throw PersonEntityMutationError.splitRequiresMovingRecords
        }

        let originalStore = try requirePersonEntityNodeStore(id: id)
        var originalNode = originalStore.domainModel
        let originalProfile = try fetchEntityProfile(entityID: id) ?? makePersonProfile(from: originalNode, updatedAt: now)

        let originalRecordIDSet = Set(mergeUniqueIDs(originalNode.provenanceRecordIDs, originalProfile.sourceRecordIDs))
        guard movingRecordIDSet.isSubset(of: originalRecordIDSet) else {
            throw PersonEntityMutationError.splitRecordsNotInEntity
        }
        guard movingRecordIDSet.count < originalRecordIDSet.count else {
            throw PersonEntityMutationError.splitCannotMoveAllRecords
        }

        let newEntityID = UUID()
        let movedAliases = normalizedPersonAliases([normalizedName] + aliases)
        let movingRecordIDArray = originalProfile.sourceRecordIDs.filter { movingRecordIDSet.contains($0) }
        let remainingRecordIDArray = originalProfile.sourceRecordIDs.filter { !movingRecordIDSet.contains($0) }

        var newNode = EntityNode(
            id: newEntityID,
            kind: .person,
            displayName: normalizedName,
            canonicalName: normalizedName,
            aliases: movedAliases,
            summary: originalNode.summary,
            provenanceRecordIDs: originalNode.provenanceRecordIDs.filter { movingRecordIDSet.contains($0) },
            createdAt: now,
            updatedAt: now,
            confidence: originalNode.confidence
        )
        if newNode.provenanceRecordIDs.isEmpty {
            newNode.provenanceRecordIDs = Array(movingRecordIDSet)
        }

        originalNode.provenanceRecordIDs.removeAll { movingRecordIDSet.contains($0) }
        originalNode.updatedAt = now
        originalStore.apply(domainModel: originalNode)
        try upsert(entityNode: newNode)

        var updatedOriginalProfile = originalProfile
        updatedOriginalProfile.sourceRecordIDs = remainingRecordIDArray
        updatedOriginalProfile.mentionCount = max(1, remainingRecordIDArray.count)
        updatedOriginalProfile.updatedAt = now
        updatedOriginalProfile.lastMentionedAt = now
        try upsert(entityProfile: updatedOriginalProfile)

        let newProfile = EntityProfile(
            entityID: newEntityID,
            kind: .person,
            displayName: normalizedName,
            canonicalName: normalizedName,
            aliases: movedAliases,
            relationshipToUser: originalProfile.relationshipToUser,
            userDescription: originalProfile.userDescription,
            mentionCount: max(1, movingRecordIDArray.count),
            firstMentionedAt: originalProfile.firstMentionedAt,
            lastMentionedAt: now,
            commonContextLabels: originalProfile.commonContextLabels,
            sourceRecordIDs: movingRecordIDArray,
            confirmationState: .suggested,
            confidence: originalProfile.confidence,
            createdAt: now,
            updatedAt: now
        )
        try upsert(entityProfile: newProfile)
        try splitPersonProfiles(
            fromEntityID: id,
            toEntityID: newEntityID,
            newEntityProfile: newProfile,
            movingRecordIDs: movingRecordIDSet,
            now: now
        )

        let movedArtifactIDs = try movePersonArtifactLinks(
            fromEntityID: id,
            toEntityID: newEntityID,
            movingRecordIDs: movingRecordIDSet,
            updatedAt: now
        )
        try splitEntityEdges(
            fromEntityID: id,
            toEntityID: newEntityID,
            movingArtifactIDs: movedArtifactIDs,
            movingRecordIDs: movingRecordIDSet
        )
        try rewriteEntityReferencesForSplit(
            fromEntityID: id,
            toEntityID: newEntityID,
            movingRecordIDs: movingRecordIDSet
        )
        try upsert(correctionEvent: CorrectionEvent(
            kind: .splitEntity,
            actor: .user,
            targetEntityIDs: [id, newEntityID],
            sourceRecordIDs: Array(movingRecordIDSet),
            note: "Person split",
            metadata: [
                "fromEntityID": id.uuidString,
                "toEntityID": newEntityID.uuidString,
            ],
            isReversible: true,
            createdAt: now
        ))
        try enqueueEntityMutationRecomputeJobs(
            affectedRecordIDs: Set(mergeUniqueIDs(Array(originalRecordIDSet), Array(movingRecordIDSet))),
            affectedEntityIDs: Set([id, newEntityID])
        )
        try save()
        return newProfile
    }

    func fetchCorrectionEvents(kind: CorrectionEventKind?, limit: Int?) throws -> [CorrectionEvent] {
        let stores = try modelContext.fetch(
            FetchDescriptor<CorrectionEventStore>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )
        let events = stores.map(\.domainModel).filter { event in
            guard let kind else { return true }
            return event.kind == kind
        }
        return applyLimit(limit, to: events)
    }

    func upsertCorrectionEvent(_ event: CorrectionEvent) throws {
        try upsert(correctionEvent: event)
        try save()
    }

    func fetchEntityTombstones(limit: Int?) throws -> [EntityTombstone] {
        let tombstones = try modelContext.fetch(
            FetchDescriptor<EntityTombstoneStore>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        ).map(\.domainModel)
        return applyLimit(limit, to: tombstones)
    }

    func fetchClarificationQuestions(status: ClarificationQuestionStatus?, limit: Int?) throws -> [ClarificationQuestion] {
        let stores = try modelContext.fetch(
            FetchDescriptor<ClarificationQuestionStore>(
                sortBy: [
                    SortDescriptor(\.priority, order: .reverse),
                    SortDescriptor(\.createdAt, order: .reverse),
                ]
            )
        )
        let questions = stores
            .map(\.domainModel)
            .filter { question in
                guard let status else { return true }
                return question.status == status
            }
        return applyLimit(limit, to: questions)
    }

    func upsertClarificationQuestion(_ question: ClarificationQuestion) throws {
        try upsert(clarificationQuestion: question)
        try save()
    }

    func answerClarificationQuestion(_ id: UUID, answer: ClarificationAnswer) throws {
        guard let existing = try modelContext.fetch(
            FetchDescriptor<ClarificationQuestionStore>(predicate: #Predicate { $0.id == id })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        var updated = existing.domainModel
        updated.status = .answered
        updated.answer = answer
        updated.answeredAt = answer.answeredAt
        updated.dismissedAt = nil
        existing.apply(domainModel: updated)

        if let delta = graphDeltaApplier.buildDelta(for: updated, answer: answer) {
            try upsert(graphDelta: delta)
            let profile = try fetchEntityProfile(entityID: updated.targetID)
            let entityNode = try fetchEntityNode(id: updated.targetID)
            let application = graphDeltaApplier.apply(
                delta: delta,
                profile: profile,
                entityNode: entityNode,
                appliedAt: answer.answeredAt
            )
            if let updatedProfile = application.profile {
                try upsert(entityProfile: updatedProfile)
            }
            if let updatedEntityNode = application.entityNode {
                try upsert(entityNode: updatedEntityNode)
            }
            for operation in delta.operations where operation.kind == .mergeEntity {
                guard operation.targetType == .entity else { continue }
                guard let relatedID = operation.relatedID else { continue }
                _ = try mergePersonEntities(
                    primaryID: operation.targetID,
                    mergingIDs: [relatedID],
                    displayName: nil
                )
            }
            if let existingDelta = try modelContext.fetch(
                FetchDescriptor<GraphDeltaStore>(predicate: #Predicate { $0.id == delta.id })
            ).first {
                var appliedDelta = existingDelta.domainModel
                appliedDelta.appliedAt = answer.answeredAt
                existingDelta.apply(domainModel: appliedDelta)
            }
        }

        try save()
    }

    func dismissClarificationQuestion(_ id: UUID) throws {
        guard let existing = try modelContext.fetch(
            FetchDescriptor<ClarificationQuestionStore>(predicate: #Predicate { $0.id == id })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        var updated = existing.domainModel
        updated.status = .dismissed
        updated.dismissedAt = Date.now
        existing.apply(domainModel: updated)
        try save()
    }

    func fetchNotificationIntents(status: NotificationIntentStatus?, limit: Int?) throws -> [NotificationIntent] {
        let stores = try modelContext.fetch(
            FetchDescriptor<NotificationIntentStore>(
                sortBy: [
                    SortDescriptor(\.scheduledAt, order: .forward),
                    SortDescriptor(\.createdAt, order: .reverse),
                ]
            )
        )
        let intents = stores
            .map(\.domainModel)
            .filter { intent in
                guard let status else { return true }
                return intent.status == status
            }
        return applyLimit(limit, to: intents)
    }

    func upsertNotificationIntent(_ intent: NotificationIntent) throws {
        try upsert(notificationIntent: intent)
        try save()
    }

    func fetchIntelligenceJobs(status: IntelligenceJobStatus?, limit: Int?) throws -> [IntelligenceJob] {
        let stores = try modelContext.fetch(
            FetchDescriptor<IntelligenceJobStore>(
                sortBy: [
                    SortDescriptor(\.priority, order: .reverse),
                    SortDescriptor(\.scheduledAt, order: .forward),
                ]
            )
        )
        let jobs = stores
            .map(\.domainModel)
            .filter { job in
                guard let status else { return true }
                return job.status == status
            }
        return applyLimit(limit, to: jobs)
    }

    func upsertIntelligenceJob(_ job: IntelligenceJob) throws {
        try upsert(intelligenceJob: job)
        try save()
    }

    func fetchGraphDeltas(applied: Bool?, limit: Int?) throws -> [GraphDelta] {
        let stores = try modelContext.fetch(
            FetchDescriptor<GraphDeltaStore>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )
        let deltas = stores
            .map(\.domainModel)
            .filter { delta in
                guard let applied else { return true }
                return (delta.appliedAt != nil) == applied
            }
        return applyLimit(limit, to: deltas)
    }

    func upsertGraphDelta(_ delta: GraphDelta) throws {
        try upsert(graphDelta: delta)
        try save()
    }

    func markGraphDeltaApplied(_ id: UUID, appliedAt: Date = .now) throws {
        guard let existing = try modelContext.fetch(
            FetchDescriptor<GraphDeltaStore>(predicate: #Predicate { $0.id == id })
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        var updated = existing.domainModel
        updated.appliedAt = appliedAt
        existing.apply(domainModel: updated)
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

    private func fetchRecordAnalysisIndex() throws -> [UUID: RecordAnalysisSnapshot] {
        let analyses = try modelContext.fetch(FetchDescriptor<RecordAnalysisSnapshotStore>())
            .map(\.domainModel)
        return Dictionary(uniqueKeysWithValues: analyses.map { ($0.recordID, $0) })
    }

    private func fetchHomeBoardPreferences() throws -> [HomeBoardItemPreference] {
        let descriptor = FetchDescriptor<HomeBoardPreferenceStore>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.domainModel)
    }

    private func fetchHomeBoardPreference(syncKey: String) throws -> HomeBoardItemPreference? {
        let descriptor = FetchDescriptor<HomeBoardPreferenceStore>(
            predicate: #Predicate { $0.syncKey == syncKey }
        )
        return try modelContext.fetch(descriptor).first?.domainModel
    }

    private func homeBoardPreferenceSyncKey(cardKey: String) -> String {
        "home-board:\(cardKey)"
    }

    private func shouldShowClarificationQuestions(
        flags: V6FeatureFlags,
        preferences: IntelligencePreferences
    ) -> Bool {
        flags.clarificationQuestions && preferences.localIntelligenceEnabled && preferences.homeSuggestionsEnabled
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let stores = try modelContext.fetch(FetchDescriptor<T>())
        for store in stores {
            modelContext.delete(store)
        }
    }

    private func deleteMemoryDetailPresentationPreference(recordID: UUID, saveAfterDelete: Bool) throws {
        let descriptor = FetchDescriptor<MemoryDetailPresentationPreferenceStore>(
            predicate: #Predicate { $0.recordID == recordID }
        )
        for store in try modelContext.fetch(descriptor) {
            modelContext.delete(store)
        }
        if saveAfterDelete {
            try save()
        }
    }

    private func purgeDerivedDataForRefresh(recordID: UUID) throws {
        try purgeDerivedData(forRecordIDs: [recordID], includePipelineStatus: false)
    }

    private func upsertPendingPipelineStatus(recordID: UUID, updatedAt: Date) throws {
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
                updatedAt: updatedAt
            )
        )
    }

    private func orderedUniqueUUIDs(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }

    private func runLocalIntelligenceLoop(record: RecordShell, artifacts: [Artifact]) throws {
        let flags = try fetchV6FeatureFlags()
        let preferences = try fetchIntelligencePreferences()
        guard preferences.localIntelligenceEnabled else { return }
        guard flags.intelligenceJobs || flags.entityProfiles || flags.clarificationQuestions else { return }
        guard let analysis = try fetchRecordAnalysis(recordID: record.id) else { return }

        let personNodes = try fetchPersonEntityNodes(recordID: record.id, artifactIDs: artifacts.map(\.id))
        guard !personNodes.isEmpty else { return }

        let now = Date.now
        let scheduled = intelligenceScheduler.schedulePostAnalysis(
            recordID: record.id,
            personEntityIDs: personNodes.map(\.id),
            now: now
        )

        if flags.intelligenceJobs {
            try upsert(intelligenceJob: updateJob(scheduled.postAnalysisJob, status: .running, at: now))
            try scheduled.entityEnrichmentJobs.forEach { try upsert(intelligenceJob: $0) }
            try scheduled.personProfileRefreshJobs.forEach { try upsert(intelligenceJob: $0) }
            try scheduled.questionGenerationJobs.forEach { try upsert(intelligenceJob: $0) }
        }

        let existingProfiles = Dictionary(uniqueKeysWithValues: try fetchEntityProfiles(kind: .person, limit: nil).map { ($0.entityID, $0) })
        let enrichedProfiles = entityEnrichmentService.enrichPeople(
            record: record,
            analysis: analysis,
            people: personNodes,
            existingProfiles: existingProfiles
        )

        if flags.entityProfiles {
            for profile in enrichedProfiles {
                try upsert(entityProfile: profile)
                _ = try refreshPersonProfile(entityID: profile.entityID, now: now)
            }
        }

        if flags.intelligenceJobs {
            for job in scheduled.entityEnrichmentJobs {
                try upsert(intelligenceJob: updateJob(job, status: .completed, at: now))
            }
            let personProfileJobStatus: IntelligenceJobStatus = flags.entityProfiles ? .completed : .cancelled
            for job in scheduled.personProfileRefreshJobs {
                try upsert(intelligenceJob: updateJob(job, status: personProfileJobStatus, at: now))
            }
        }

        if flags.clarificationQuestions {
            let existingQuestions = try fetchClarificationQuestions(status: nil, limit: nil)
            for profile in enrichedProfiles {
                if let question = clarificationQuestionBuilder.buildQuestion(
                    for: profile,
                    record: record,
                    artifactIDs: artifacts.map(\.id),
                    existingQuestions: existingQuestions,
                    latestSummary: analysis.summary
                ) {
                    try upsert(clarificationQuestion: question)
                }
            }
        }

        if flags.intelligenceJobs {
            let questionJobStatus: IntelligenceJobStatus = flags.clarificationQuestions ? .completed : .cancelled
            for job in scheduled.questionGenerationJobs {
                try upsert(intelligenceJob: updateJob(job, status: questionJobStatus, at: now))
            }
            try upsert(intelligenceJob: updateJob(scheduled.postAnalysisJob, status: .completed, at: now))
        }

        try save()
    }

    private func markLatestPostAnalysisJobFailed(recordID: UUID, error: Error) throws {
        guard let job = try fetchIntelligenceJobs(status: nil, limit: nil)
            .first(where: { $0.kind == .postAnalysis && $0.targetType == .record && $0.targetID == recordID }) else {
            return
        }

        try upsert(intelligenceJob: updateJob(job, status: .failed, at: .now, error: error.localizedDescription))
        try save()
    }

    private func updateJob(
        _ job: IntelligenceJob,
        status: IntelligenceJobStatus,
        at date: Date,
        error: String? = nil
    ) -> IntelligenceJob {
        var updated = job
        updated.status = status
        updated.updatedAt = date
        switch status {
        case .running:
            updated.startedAt = date
            updated.completedAt = nil
            updated.lastError = nil
        case .completed:
            updated.completedAt = date
            updated.lastError = nil
        case .failed:
            updated.completedAt = nil
            updated.lastError = error
            updated.attemptCount += 1
        case .cancelled, .pending:
            updated.lastError = error
        }
        return updated
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

        let deletedClarificationQuestionIDs = try purgeClarificationQuestions(
            removingRecordIDs: recordIDs,
            artifactIDs: artifactIDs
        )
        let deletedGraphDeltaIDs = try purgeGraphDeltas(
            removingRecordIDs: recordIDs,
            artifactIDs: artifactIDs
        )
        try purgeIntelligenceJobs(
            removingRecordIDs: recordIDs,
            artifactIDs: artifactIDs,
            clarificationQuestionIDs: deletedClarificationQuestionIDs,
            graphDeltaIDs: deletedGraphDeltaIDs
        )
        try purgeHomeBoardSignals(
            removingRecordIDs: recordIDs,
            artifactIDs: artifactIDs
        )
        try purgeNotificationIntents(
            removingRecordIDs: recordIDs,
            artifactIDs: artifactIDs
        )
        try purgePlaceProfiles(removingRecordIDs: recordIDs, artifactIDs: artifactIDs)
        try purgePersonProfiles(removingRecordIDs: recordIDs, artifactIDs: artifactIDs)
        try purgeEntityProfiles(removing: recordIDs)
        try purgeEntityProvenance(removing: recordIDs, remainingLinkedEntityIDs: remainingLinkedEntityIDs)
    }

    private func purgeClarificationQuestions(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>
    ) throws -> Set<UUID> {
        let stores = try modelContext.fetch(FetchDescriptor<ClarificationQuestionStore>())
        var deletedIDs = Set<UUID>()

        for store in stores {
            var question = store.domainModel
            let originalRecordIDs = question.sourceRecordIDs
            let originalArtifactIDs = question.sourceArtifactIDs

            question.sourceRecordIDs.removeAll { recordIDs.contains($0) }
            question.sourceArtifactIDs.removeAll { artifactIDs.contains($0) }

            let deletedTarget = switch question.targetType {
            case .record:
                recordIDs.contains(question.targetID)
            case .artifact:
                artifactIDs.contains(question.targetID)
            default:
                false
            }

            if deletedTarget || (question.sourceRecordIDs.isEmpty && question.sourceArtifactIDs.isEmpty) {
                deletedIDs.insert(store.id)
                modelContext.delete(store)
                continue
            }

            if question.sourceRecordIDs != originalRecordIDs || question.sourceArtifactIDs != originalArtifactIDs {
                store.apply(domainModel: question)
            }
        }

        return deletedIDs
    }

    private func purgeGraphDeltas(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>
    ) throws -> Set<UUID> {
        let stores = try modelContext.fetch(FetchDescriptor<GraphDeltaStore>())
        var deletedIDs = Set<UUID>()

        for store in stores {
            let shouldDelete = store.domainModel.operations.contains { operation in
                if operation.targetType == .record, recordIDs.contains(operation.targetID) {
                    return true
                }
                if operation.targetType == .artifact, artifactIDs.contains(operation.targetID) {
                    return true
                }
                if let relatedID = operation.relatedID, recordIDs.contains(relatedID) || artifactIDs.contains(relatedID) {
                    return true
                }
                return false
            }

            if shouldDelete {
                deletedIDs.insert(store.id)
                modelContext.delete(store)
            }
        }

        return deletedIDs
    }

    private func purgeIntelligenceJobs(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>,
        clarificationQuestionIDs: Set<UUID>,
        graphDeltaIDs: Set<UUID>
    ) throws {
        let stores = try modelContext.fetch(FetchDescriptor<IntelligenceJobStore>())

        for store in stores {
            let shouldDelete = switch store.domainModel.targetType {
            case .record:
                recordIDs.contains(store.targetID)
            case .artifact:
                artifactIDs.contains(store.targetID)
            case .question:
                clarificationQuestionIDs.contains(store.targetID)
            case .graphDelta:
                graphDeltaIDs.contains(store.targetID)
            default:
                false
            }

            if shouldDelete {
                modelContext.delete(store)
            }
        }
    }

    private func purgeHomeBoardSignals(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>
    ) throws {
        let stores = try modelContext.fetch(FetchDescriptor<HomeBoardSignalStore>())

        for store in stores {
            var signal = store.domainModel
            let originalRecordIDs = signal.sourceRecordIDs
            signal.sourceRecordIDs.removeAll { recordIDs.contains($0) }

            let deletedTarget = switch signal.targetType {
            case .record:
                recordIDs.contains(signal.targetID)
            case .artifact:
                artifactIDs.contains(signal.targetID)
            default:
                false
            }

            if deletedTarget || signal.sourceRecordIDs.isEmpty {
                modelContext.delete(store)
                continue
            }

            if signal.sourceRecordIDs != originalRecordIDs {
                store.apply(domainModel: signal)
            }
        }
    }

    private func purgeNotificationIntents(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>
    ) throws {
        let stores = try modelContext.fetch(FetchDescriptor<NotificationIntentStore>())

        for store in stores {
            let shouldDelete = switch store.domainModel.targetType {
            case .record:
                recordIDs.contains(store.targetID)
            case .artifact:
                artifactIDs.contains(store.targetID)
            default:
                false
            }

            if shouldDelete {
                modelContext.delete(store)
            }
        }
    }

    private func purgeEntityProfiles(removing recordIDs: Set<UUID>) throws {
        let stores = try modelContext.fetch(FetchDescriptor<EntityProfileStore>())

        for store in stores {
            var profile = store.domainModel
            let originalRecordIDs = profile.sourceRecordIDs
            profile.sourceRecordIDs.removeAll { recordIDs.contains($0) }

            guard profile.sourceRecordIDs != originalRecordIDs else { continue }

            if profile.sourceRecordIDs.isEmpty && !shouldRetainEntityProfileWithoutSource(profile) {
                modelContext.delete(store)
                continue
            }

            if profile.sourceRecordIDs.isEmpty {
                profile.firstMentionedAt = nil
                profile.lastMentionedAt = nil
            }
            profile.updatedAt = Date.now
            store.apply(domainModel: profile)
        }
    }

    private func shouldRetainEntityProfileWithoutSource(_ profile: EntityProfile) -> Bool {
        profile.confirmationState == .userConfirmed
            || profile.relationshipToUser != nil
            || !(profile.userDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            || !profile.aliases.isEmpty
    }

    private func purgePersonProfiles(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>
    ) throws {
        let stores = try modelContext.fetch(FetchDescriptor<PersonProfileStore>())
        let now = Date.now

        for store in stores {
            var profile = store.domainModel
            let originalSourceRecordIDs = profile.sourceRecordIDs
            let originalEvidence = profile.fieldEvidence
            profile.sourceRecordIDs.removeAll { recordIDs.contains($0) }
            profile.fieldEvidence = profile.fieldEvidence.map { evidence in
                var updated = evidence
                let touched = !Set(updated.sourceRecordIDs).isDisjoint(with: recordIDs)
                    || !Set(updated.sourceArtifactIDs).isDisjoint(with: artifactIDs)
                guard touched else { return updated }
                updated.sourceRecordIDs.removeAll { recordIDs.contains($0) }
                updated.sourceArtifactIDs.removeAll { artifactIDs.contains($0) }
                updated.status = .stale
                updated.refreshedAt = now
                return updated
            }

            if let portrait = profile.aiPortrait {
                let remainingEvidence = portrait.evidenceRecordIDs.filter { !recordIDs.contains($0) }
                if remainingEvidence.count != portrait.evidenceRecordIDs.count {
                    if remainingEvidence.isEmpty {
                        profile.aiPortrait = nil
                    } else {
                        var updatedPortrait = portrait
                        updatedPortrait.evidenceRecordIDs = remainingEvidence
                        updatedPortrait.status = .stale
                        updatedPortrait.updatedAt = now
                        profile.aiPortrait = updatedPortrait
                    }
                }
            }

            let changed = profile.sourceRecordIDs != originalSourceRecordIDs
                || profile.fieldEvidence != originalEvidence
            guard changed else { continue }

            if profile.sourceRecordIDs.isEmpty && !shouldRetainPersonProfileWithoutSource(profile) {
                modelContext.delete(store)
                continue
            }

            profile.updatedAt = now
            store.apply(domainModel: profile)
        }
    }

    private func shouldRetainPersonProfileWithoutSource(_ profile: PersonProfile) -> Bool {
        profile.relationshipHistory.contains { $0.status == .userConfirmed }
            || !(profile.userNotes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            || profile.fieldEvidence.contains { $0.status == .userConfirmed && $0.source == .userEdit }
            || profile.automationPolicy == .frozen
    }

    private func purgePlaceProfiles(
        removingRecordIDs recordIDs: Set<UUID>,
        artifactIDs: Set<UUID>
    ) throws {
        let stores = try modelContext.fetch(FetchDescriptor<PlaceProfileStore>())

        for store in stores {
            var profile = store.domainModel
            let originalArtifactIDs = profile.sourceArtifactIDs
            let originalRecordIDs = profile.sourceRecordIDs
            profile.sourceArtifactIDs.removeAll { artifactIDs.contains($0) }
            profile.sourceRecordIDs.removeAll { recordIDs.contains($0) }

            guard profile.sourceArtifactIDs != originalArtifactIDs || profile.sourceRecordIDs != originalRecordIDs else {
                continue
            }

            if profile.sourceArtifactIDs.isEmpty {
                modelContext.delete(store)
                continue
            }

            let remainingArtifacts = try fetchArtifacts(ids: profile.sourceArtifactIDs)
            profile = recalculatedPlaceProfile(profile, from: remainingArtifacts, updatedAt: Date.now)
            store.apply(domainModel: profile)
            try upsertPlaceEntityNode(for: profile, updatedAt: profile.updatedAt)
        }
    }

    private func buildPersonProfile(
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

    private func preservedUserConfirmedRelationship(_ existing: PersonProfile?) -> EntityRelationshipToUser? {
        guard let existing else { return nil }
        guard existing.relationshipHistory.contains(where: { $0.status == .userConfirmed }) else {
            return nil
        }
        return existing.relationshipToUser
    }

    private func updatedRelationshipHistory(
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

    private func relatedEntityIDsByKind(edges: [EntityEdge]) throws -> [EntityKind: [UUID]] {
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

    private func refreshedPersonProfileEvidence(
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

    private func fieldConfidence(from evidence: [ProfileFieldEvidence]) -> [String: Double] {
        var result: [String: Double] = [:]
        for item in evidence {
            result[item.fieldKey] = max(result[item.fieldKey] ?? 0, item.confidence ?? 0.5)
        }
        return result
    }

    private func buildPersonPortrait(
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

    private func buildPersonAffectPattern(
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

    private func relationshipStrength(
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

    private func importanceScore(
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

    private func interactionFrequency(for memories: [MemorySummary]) -> InteractionFrequency {
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

    private func recentChangeSummary(
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

    private func fetchPersonEntityNodes(recordID: UUID, artifactIDs: [UUID]) throws -> [EntityNode] {
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

    private func fetchEntityNode(id: UUID) throws -> EntityNode? {
        try modelContext.fetch(
            FetchDescriptor<EntityNodeStore>(predicate: #Predicate { $0.id == id })
        ).first?.domainModel
    }

    private func fetchEntityNodeStore(id: UUID) throws -> EntityNodeStore? {
        try modelContext.fetch(
            FetchDescriptor<EntityNodeStore>(predicate: #Predicate { $0.id == id })
        ).first
    }

    private func requirePersonEntityNodeStore(id: UUID) throws -> EntityNodeStore {
        guard let store = try fetchEntityNodeStore(id: id) else {
            throw PersonEntityMutationError.entityNotFound
        }
        guard store.kindRawValue == EntityKind.person.rawValue else {
            throw PersonEntityMutationError.entityIsNotPerson
        }
        return store
    }

    private func fetchPlaceProfileStore(id: UUID) throws -> PlaceProfileStore? {
        try modelContext.fetch(
            FetchDescriptor<PlaceProfileStore>(predicate: #Predicate { $0.id == id })
        ).first
    }

    private func requirePlaceProfileStore(id: UUID) throws -> PlaceProfileStore {
        guard let store = try fetchPlaceProfileStore(id: id) else {
            throw PlaceProfileMutationError.profileNotFound
        }
        return store
    }

    private func fetchArtifacts(ids: [UUID]) throws -> [Artifact] {
        guard !ids.isEmpty else { return [] }
        let idSet = Set(ids)
        let artifacts = try modelContext.fetch(FetchDescriptor<ArtifactStore>())
            .map(\.domainModel)
            .filter { idSet.contains($0.id) }
        let artifactsByID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
        return ids.compactMap { artifactsByID[$0] }
    }

    private func normalizedPlaceDisplayName(_ displayName: String) throws -> String {
        guard let resolvedName = displayName.trimmedOrNil else {
            throw PlaceProfileMutationError.emptyDisplayName
        }
        return resolvedName
    }

    private func normalizedPlaceAliases(_ values: [String?]) -> [String] {
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

    private func normalizedPersonAliases(_ values: [String?]) -> [String] {
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

    private func makePersonProfile(from entity: EntityNode, updatedAt: Date) -> EntityProfile {
        EntityProfile(
            entityID: entity.id,
            kind: .person,
            displayName: entity.displayName,
            canonicalName: entity.canonicalName,
            aliases: entity.aliases,
            mentionCount: max(1, entity.provenanceRecordIDs.count),
            firstMentionedAt: entity.createdAt,
            lastMentionedAt: updatedAt,
            commonContextLabels: [],
            sourceRecordIDs: entity.provenanceRecordIDs,
            confirmationState: .inferred,
            confidence: entity.confidence,
            createdAt: entity.createdAt,
            updatedAt: updatedAt
        )
    }

    private func recalculatedPlaceProfile(_ profile: PlaceProfile, from artifacts: [Artifact], updatedAt: Date) -> PlaceProfile {
        let locationArtifacts = artifacts.filter { $0.kind == .location }
        let coordinates = locationArtifacts.compactMap { PlaceContextResolver.coordinate(for: $0) }
        var updated = profile
        updated.sourceArtifactIDs = mergeUniqueIDs([], locationArtifacts.map(\.id))
        updated.sourceRecordIDs = mergeUniqueIDs([], locationArtifacts.map(\.recordID))
        updated.mentionCount = locationArtifacts.isEmpty ? profile.mentionCount : locationArtifacts.count
        updated.updatedAt = updatedAt

        guard !coordinates.isEmpty else {
            updated.centroidLatitude = nil
            updated.centroidLongitude = nil
            updated.radiusMeters = 0
            return updated
        }

        let latitude = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let longitude = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        let centroid = PlaceCoordinate(latitude: latitude, longitude: longitude)
        let maxDistance = coordinates.map { $0.distance(to: centroid) }.max() ?? 0
        updated.centroidLatitude = latitude
        updated.centroidLongitude = longitude
        updated.radiusMeters = max(120, min(maxDistance + 60, 900))
        return updated
    }

    private func upsertPlaceEntityNode(for profile: PlaceProfile, updatedAt: Date) throws {
        let entity = EntityNode(
            id: profile.entityID,
            kind: .place,
            displayName: profile.displayName,
            canonicalName: profile.canonicalName,
            aliases: profile.aliases,
            summary: placeProfileSummary(profile),
            provenanceRecordIDs: profile.sourceRecordIDs,
            createdAt: profile.createdAt,
            updatedAt: updatedAt,
            confidence: profile.confidence
        )
        try upsert(entityNode: entity)
    }

    private func placeProfileSummary(_ profile: PlaceProfile) -> String {
        guard let latitude = profile.centroidLatitude, let longitude = profile.centroidLongitude else {
            return profile.canonicalName
        }
        return "\(profile.canonicalName) · \(String(format: "%.5f", latitude)), \(String(format: "%.5f", longitude))"
    }

    private func movePlaceArtifactLinks(
        artifactIDs: Set<UUID>,
        fromEntityID: UUID,
        toProfile: PlaceProfile,
        updatedAt: Date
    ) throws {
        let linkStores = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        let artifactStores = try modelContext.fetch(FetchDescriptor<ArtifactStore>())
        let artifactsByID = Dictionary(uniqueKeysWithValues: artifactStores.map { ($0.id, $0.domainModel) })

        for artifactID in artifactIDs {
            var didMoveExistingLink = false
            for store in linkStores where store.artifactID == artifactID && store.entityID == fromEntityID {
                var link = store.domainModel
                link.entityID = toProfile.entityID
                link.confidence = max(link.confidence ?? 0, toProfile.confidence ?? 0)
                link.source = "placeProfile"
                link.sourceRecordID = artifactsByID[artifactID]?.recordID
                link.evidenceSummary = "Moved to place profile: \(toProfile.canonicalName)"
                store.apply(domainModel: link)
                didMoveExistingLink = true
            }

            if !didMoveExistingLink, let artifact = artifactsByID[artifactID] {
                modelContext.insert(ArtifactEntityLinkStore(domainModel: ArtifactEntityLink(
                    artifactID: artifactID,
                    entityID: toProfile.entityID,
                    confidence: toProfile.confidence,
                    source: "placeProfile",
                    sourceRecordID: artifact.recordID,
                    evidenceSummary: "Moved to place profile: \(toProfile.canonicalName)",
                    createdAt: updatedAt
                )))
            }
        }
    }

    private func rewritePlaceGraphReferences(replacing replacements: [UUID: UUID]) throws {
        try rewriteEntityLinksAndEdges(replacing: replacements, linkSource: "placeProfile")
    }

    private func splitEntityEdges(
        fromEntityID: UUID,
        toEntityID: UUID,
        movingArtifactIDs: Set<UUID>,
        movingRecordIDs: Set<UUID>
    ) throws {
        guard !(movingArtifactIDs.isEmpty && movingRecordIDs.isEmpty) else { return }
        let edgeStores = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>())

        for store in edgeStores {
            let edge = store.domainModel
            guard edge.fromEntityID == fromEntityID || edge.toEntityID == fromEntityID else { continue }
            let movingSourceArtifactIDs = edge.sourceArtifactIDs.filter { movingArtifactIDs.contains($0) }
            let movingSourceRecordIDs = edge.sourceRecordIDs.filter { movingRecordIDs.contains($0) }
            guard !movingSourceArtifactIDs.isEmpty || !movingSourceRecordIDs.isEmpty else { continue }

            let remainingArtifactIDs = edge.sourceArtifactIDs.filter { !movingArtifactIDs.contains($0) }
            let remainingRecordIDs = edge.sourceRecordIDs.filter { !movingRecordIDs.contains($0) }
            var originalEdge = edge
            originalEdge.sourceArtifactIDs = remainingArtifactIDs
            originalEdge.sourceRecordIDs = remainingRecordIDs
            originalEdge.evidenceCount = max(1, remainingArtifactIDs.count + remainingRecordIDs.count)

            var movedEdge = edge
            if movedEdge.fromEntityID == fromEntityID {
                movedEdge.fromEntityID = toEntityID
            }
            if movedEdge.toEntityID == fromEntityID {
                movedEdge.toEntityID = toEntityID
            }
            movedEdge.sourceArtifactIDs = movingSourceArtifactIDs
            movedEdge.sourceRecordIDs = movingSourceRecordIDs
            movedEdge.evidenceCount = max(1, movingSourceArtifactIDs.count + movingSourceRecordIDs.count)

            if remainingArtifactIDs.isEmpty && remainingRecordIDs.isEmpty {
                if movedEdge.fromEntityID == movedEdge.toEntityID {
                    modelContext.delete(store)
                } else {
                    store.apply(domainModel: movedEdge)
                }
            } else {
                store.apply(domainModel: originalEdge)
                if movedEdge.fromEntityID != movedEdge.toEntityID {
                    modelContext.insert(EntityEdgeStore(domainModel: EntityEdge(
                        fromEntityID: movedEdge.fromEntityID,
                        toEntityID: movedEdge.toEntityID,
                        relationKind: movedEdge.relationKind,
                        weight: movedEdge.weight,
                        firstSeenAt: movedEdge.firstSeenAt,
                        lastSeenAt: movedEdge.lastSeenAt,
                        evidenceCount: movedEdge.evidenceCount,
                        sourceArtifactIDs: movedEdge.sourceArtifactIDs,
                        sourceRecordIDs: movedEdge.sourceRecordIDs
                    )))
                }
            }
        }

        try deduplicateEntityEdges()
    }

    private func rewriteEntityLinksAndEdges(
        replacing replacements: [UUID: UUID],
        linkSource: String?
    ) throws {
        guard !replacements.isEmpty else { return }

        let linkStores = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        for store in linkStores {
            guard let replacementID = replacements[store.entityID] else { continue }
            var link = store.domainModel
            link.entityID = replacementID
            if let linkSource {
                link.source = linkSource
            }
            store.apply(domainModel: link)
        }

        let edgeStores = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>())
        for store in edgeStores {
            var edge = store.domainModel
            var changed = false
            if let replacementID = replacements[edge.fromEntityID] {
                edge.fromEntityID = replacementID
                changed = true
            }
            if let replacementID = replacements[edge.toEntityID] {
                edge.toEntityID = replacementID
                changed = true
            }
            guard changed else { continue }
            if edge.fromEntityID == edge.toEntityID {
                modelContext.delete(store)
            } else {
                store.apply(domainModel: edge)
            }
        }

        try deduplicateEntityEdges()
    }

    private func rewriteEntityReferencesForMerge(replacing replacements: [UUID: UUID]) throws {
        guard !replacements.isEmpty else { return }

        let arcStores = try modelContext.fetch(FetchDescriptor<TemporalArcStore>())
        for store in arcStores {
            var arc = store.domainModel
            let remap = remappedUniqueIDs(arc.sourceEntityIDs, replacements: replacements)
            guard remap.changed else { continue }
            arc.sourceEntityIDs = remap.values
            arc.updatedAt = Date.now
            store.apply(domainModel: arc)
        }

        let reflectionStores = try modelContext.fetch(FetchDescriptor<ReflectionSnapshotStore>())
        for store in reflectionStores {
            var reflection = store.domainModel
            let remap = remappedUniqueIDs(reflection.sourceEntityIDs, replacements: replacements)
            guard remap.changed else { continue }
            reflection.sourceEntityIDs = remap.values
            store.apply(domainModel: reflection)
        }

        let questionStores = try modelContext.fetch(FetchDescriptor<ClarificationQuestionStore>())
        for store in questionStores where store.targetTypeRawValue == ClarificationTargetType.entity.rawValue {
            guard let replacementID = replacements[store.targetID] else { continue }
            var question = store.domainModel
            question.targetID = replacementID
            store.apply(domainModel: question)
        }

        let signalStores = try modelContext.fetch(FetchDescriptor<HomeBoardSignalStore>())
        for store in signalStores where store.targetTypeRawValue == ClarificationTargetType.entity.rawValue {
            guard let replacementID = replacements[store.targetID] else { continue }
            var signal = store.domainModel
            signal.targetID = replacementID
            store.apply(domainModel: signal)
        }

        let intentStores = try modelContext.fetch(FetchDescriptor<NotificationIntentStore>())
        for store in intentStores where store.targetTypeRawValue == ClarificationTargetType.entity.rawValue {
            guard let replacementID = replacements[store.targetID] else { continue }
            var intent = store.domainModel
            intent.targetID = replacementID
            store.apply(domainModel: intent)
        }

        let graphDeltaStores = try modelContext.fetch(FetchDescriptor<GraphDeltaStore>())
        for store in graphDeltaStores {
            var delta = store.domainModel
            var changed = false
            delta.operations = delta.operations.map { operation in
                var operation = operation
                if operation.targetType == .entity, let replacementID = replacements[operation.targetID] {
                    operation.targetID = replacementID
                    changed = true
                }
                if let relatedID = operation.relatedID, let replacementID = replacements[relatedID] {
                    operation.relatedID = replacementID
                    changed = true
                }
                return operation
            }
            if changed {
                store.apply(domainModel: delta)
            }
        }

        if let selfProfileStore = try fetchSelfProfileStore(syncKey: SelfProfile.defaultSyncKey) {
            let profile = selfProfileStore.domainModel
            let remap = remappedUniqueIDs(profile.importantRelationshipIDs, replacements: replacements)
            if remap.changed {
                var updated = profile
                updated.importantRelationshipIDs = remap.values
                updated.updatedAt = Date.now
                selfProfileStore.apply(domainModel: updated)
            }
        }

        let correctionStores = try modelContext.fetch(FetchDescriptor<CorrectionEventStore>())
        for store in correctionStores {
            var event = store.domainModel
            let remap = remappedUniqueIDs(event.targetEntityIDs, replacements: replacements)
            guard remap.changed else { continue }
            event.targetEntityIDs = remap.values
            store.apply(domainModel: event)
        }
    }

    private func rewriteEntityReferencesForSplit(
        fromEntityID: UUID,
        toEntityID: UUID,
        movingRecordIDs: Set<UUID>
    ) throws {
        guard !movingRecordIDs.isEmpty else { return }

        let arcStores = try modelContext.fetch(FetchDescriptor<TemporalArcStore>())
        for store in arcStores {
            var arc = store.domainModel
            guard arc.sourceEntityIDs.contains(fromEntityID) else { continue }
            let arcRecordIDs = Set(arc.sourceRecordIDs)
            guard !arcRecordIDs.isDisjoint(with: movingRecordIDs) else { continue }
            if arcRecordIDs.isSubset(of: movingRecordIDs) {
                arc.sourceEntityIDs = remappedUniqueIDs(
                    arc.sourceEntityIDs,
                    replacements: [fromEntityID: toEntityID]
                ).values
            } else if !arc.sourceEntityIDs.contains(toEntityID) {
                arc.sourceEntityIDs.append(toEntityID)
            }
            arc.updatedAt = Date.now
            store.apply(domainModel: arc)
        }

        let reflectionStores = try modelContext.fetch(FetchDescriptor<ReflectionSnapshotStore>())
        for store in reflectionStores {
            var reflection = store.domainModel
            guard reflection.sourceEntityIDs.contains(fromEntityID) else { continue }
            let reflectionRecordIDs = Set(reflection.sourceRecordIDs)
            guard !reflectionRecordIDs.isDisjoint(with: movingRecordIDs) else { continue }
            if reflectionRecordIDs.isSubset(of: movingRecordIDs) {
                reflection.sourceEntityIDs = remappedUniqueIDs(
                    reflection.sourceEntityIDs,
                    replacements: [fromEntityID: toEntityID]
                ).values
            } else if !reflection.sourceEntityIDs.contains(toEntityID) {
                reflection.sourceEntityIDs.append(toEntityID)
            }
            store.apply(domainModel: reflection)
        }

        let questionStores = try modelContext.fetch(FetchDescriptor<ClarificationQuestionStore>())
        for store in questionStores where store.targetTypeRawValue == ClarificationTargetType.entity.rawValue {
            guard store.targetID == fromEntityID else { continue }
            let sourceRecords = Set(store.sourceRecordIDs)
            guard !sourceRecords.isDisjoint(with: movingRecordIDs) else { continue }
            guard sourceRecords.isSubset(of: movingRecordIDs) else { continue }
            var question = store.domainModel
            question.targetID = toEntityID
            store.apply(domainModel: question)
        }

        let signalStores = try modelContext.fetch(FetchDescriptor<HomeBoardSignalStore>())
        for store in signalStores where store.targetTypeRawValue == ClarificationTargetType.entity.rawValue {
            guard store.targetID == fromEntityID else { continue }
            let sourceRecords = Set(store.sourceRecordIDs)
            guard !sourceRecords.isDisjoint(with: movingRecordIDs) else { continue }
            guard sourceRecords.isSubset(of: movingRecordIDs) else { continue }
            var signal = store.domainModel
            signal.targetID = toEntityID
            store.apply(domainModel: signal)
        }
    }

    private func movePersonArtifactLinks(
        fromEntityID: UUID,
        toEntityID: UUID,
        movingRecordIDs: Set<UUID>,
        updatedAt: Date
    ) throws -> Set<UUID> {
        let linkStores = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        var movedArtifactIDs = Set<UUID>()
        for store in linkStores where store.entityID == fromEntityID {
            guard let sourceRecordID = store.sourceRecordID, movingRecordIDs.contains(sourceRecordID) else {
                continue
            }
            var link = store.domainModel
            link.entityID = toEntityID
            link.source = "personProfile"
            if link.createdAt > updatedAt {
                link.createdAt = updatedAt
            }
            store.apply(domainModel: link)
            movedArtifactIDs.insert(link.artifactID)
        }
        return movedArtifactIDs
    }

    private func remappedUniqueIDs(
        _ values: [UUID],
        replacements: [UUID: UUID]
    ) -> (values: [UUID], changed: Bool) {
        var changed = false
        var seen = Set<UUID>()
        var result: [UUID] = []
        for value in values {
            let remapped = replacements[value] ?? value
            if remapped != value {
                changed = true
            }
            if !seen.contains(remapped) {
                seen.insert(remapped)
                result.append(remapped)
            } else if remapped == value {
                changed = true
            }
        }
        return (result, changed)
    }

    private func deduplicateEntityEdges() throws {
        let edgeStores = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>())
        var storesByKey: [EntityEdgeKey: EntityEdgeStore] = [:]

        for store in edgeStores {
            let edge = store.domainModel
            let key = EntityEdgeKey(edge)
            if let existingStore = storesByKey[key] {
                let merged = mergedEntityEdge(existingStore.domainModel, edge)
                existingStore.apply(domainModel: merged)
                modelContext.delete(store)
            } else {
                storesByKey[key] = store
            }
        }
    }

    private func mergedEntityEdge(_ lhs: EntityEdge, _ rhs: EntityEdge) -> EntityEdge {
        EntityEdge(
            id: lhs.id,
            fromEntityID: lhs.fromEntityID,
            toEntityID: lhs.toEntityID,
            relationKind: lhs.relationKind,
            weight: max(lhs.weight, rhs.weight),
            firstSeenAt: min(lhs.firstSeenAt, rhs.firstSeenAt),
            lastSeenAt: max(lhs.lastSeenAt, rhs.lastSeenAt),
            evidenceCount: lhs.evidenceCount + rhs.evidenceCount,
            sourceArtifactIDs: mergeUniqueIDs(lhs.sourceArtifactIDs, rhs.sourceArtifactIDs),
            sourceRecordIDs: mergeUniqueIDs(lhs.sourceRecordIDs, rhs.sourceRecordIDs)
        )
    }

    private func deletePlaceProfilesAndNodes(stores: [PlaceProfileStore]) throws {
        let entityIDs = Set(stores.map(\.entityID))
        for store in stores {
            modelContext.delete(store)
        }
        let nodeStores = try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
        for store in nodeStores where entityIDs.contains(store.id) && store.kindRawValue == EntityKind.place.rawValue {
            modelContext.delete(store)
        }
    }

    private func maxConfidence(_ profiles: [PlaceProfile]) -> Double? {
        profiles.compactMap(\.confidence).max()
    }

    private func mergeStrings(_ lhs: [String], _ rhs: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in lhs + rhs {
            guard let trimmed = value.trimmedOrNil else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }
        return result
    }

    private func mergeUniqueIDs(_ lhs: [UUID], _ rhs: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        var result: [UUID] = []
        for id in lhs + rhs where !seen.contains(id) {
            seen.insert(id)
            result.append(id)
        }
        return result
    }

    private func deleteEntityProfiles(entityIDs: Set<UUID>) throws {
        guard !entityIDs.isEmpty else { return }
        let profileStores = try modelContext.fetch(FetchDescriptor<EntityProfileStore>())
        for store in profileStores where entityIDs.contains(store.entityID) {
            modelContext.delete(store)
        }
    }

    private func deletePersonProfiles(entityIDs: Set<UUID>) throws {
        guard !entityIDs.isEmpty else { return }
        let profileStores = try modelContext.fetch(FetchDescriptor<PersonProfileStore>())
        for store in profileStores where entityIDs.contains(store.entityID) {
            modelContext.delete(store)
        }
    }

    private func mergePersonProfiles(
        primaryID: UUID,
        mergingIDs: Set<UUID>,
        mergedEntityProfile: EntityProfile,
        now: Date
    ) throws {
        let primaryPersonProfile = try fetchPersonProfile(entityID: primaryID)
        let mergingPersonProfiles = try mergingIDs.compactMap { try fetchPersonProfile(entityID: $0) }
        guard primaryPersonProfile != nil || !mergingPersonProfiles.isEmpty else {
            try upsert(personProfile: makePersonProfile(from: mergedEntityProfile, now: now))
            return
        }

        var merged = primaryPersonProfile ?? makePersonProfile(from: mergedEntityProfile, now: now)
        merged.displayName = mergedEntityProfile.displayName
        merged.canonicalName = mergedEntityProfile.canonicalName
        merged.aliases = normalizedPersonAliases(
            [merged.displayName, merged.canonicalName]
                + merged.aliases
                + mergingPersonProfiles.flatMap { [$0.displayName, $0.canonicalName] + $0.aliases }
        )
        merged.roleLabels = mergeStrings(merged.roleLabels, mergingPersonProfiles.flatMap(\.roleLabels))
        merged.relationshipHistory = mergeRelationshipHistory(
            merged.relationshipHistory,
            mergingPersonProfiles.flatMap(\.relationshipHistory)
        )
        if merged.relationshipToUser == nil {
            merged.relationshipToUser = mergingPersonProfiles.compactMap(\.relationshipToUser).first
        }
        merged.commonPlaceIDs = mergeUniqueIDs(merged.commonPlaceIDs, mergingPersonProfiles.flatMap(\.commonPlaceIDs))
        merged.commonThemeIDs = mergeUniqueIDs(merged.commonThemeIDs, mergingPersonProfiles.flatMap(\.commonThemeIDs))
        merged.commonDecisionIDs = mergeUniqueIDs(merged.commonDecisionIDs, mergingPersonProfiles.flatMap(\.commonDecisionIDs))
        merged.commonContextLabels = mergeStrings(merged.commonContextLabels, mergingPersonProfiles.flatMap(\.commonContextLabels))
        merged.sourceRecordIDs = mergeUniqueIDs(mergedEntityProfile.sourceRecordIDs, mergingPersonProfiles.flatMap(\.sourceRecordIDs))
        merged.fieldEvidence = merged.fieldEvidence + mergingPersonProfiles.flatMap(\.fieldEvidence)
        merged.fieldConfidence = fieldConfidence(from: merged.fieldEvidence)
        merged.importanceScore = max(merged.importanceScore ?? 0, mergingPersonProfiles.compactMap(\.importanceScore).max() ?? 0)
        merged.relationshipStrength = max(merged.relationshipStrength ?? 0, mergingPersonProfiles.compactMap(\.relationshipStrength).max() ?? 0)
        merged.updatedAt = now
        try upsert(personProfile: merged)
    }

    private func splitPersonProfiles(
        fromEntityID: UUID,
        toEntityID: UUID,
        newEntityProfile: EntityProfile,
        movingRecordIDs: Set<UUID>,
        now: Date
    ) throws {
        guard var original = try fetchPersonProfile(entityID: fromEntityID) else {
            try upsert(personProfile: makePersonProfile(from: newEntityProfile, now: now))
            return
        }

        let movedEvidence = original.fieldEvidence.filter {
            !Set($0.sourceRecordIDs).isDisjoint(with: movingRecordIDs)
        }
        original.sourceRecordIDs.removeAll { movingRecordIDs.contains($0) }
        original.fieldEvidence.removeAll {
            !$0.sourceRecordIDs.isEmpty && Set($0.sourceRecordIDs).isSubset(of: movingRecordIDs)
        }
        original.updatedAt = now
        try upsert(personProfile: original)

        var newProfile = makePersonProfile(from: newEntityProfile, now: now)
        newProfile.relationshipToUser = original.relationshipToUser
        newProfile.relationshipHistory = original.relationshipHistory
        newProfile.sensitivity = original.sensitivity
        newProfile.fieldEvidence = movedEvidence
        newProfile.fieldConfidence = fieldConfidence(from: movedEvidence)
        newProfile.updatedAt = now
        try upsert(personProfile: newProfile)
    }

    private func makePersonProfile(from entityProfile: EntityProfile, now: Date) -> PersonProfile {
        PersonProfile(
            entityID: entityProfile.entityID,
            displayName: entityProfile.displayName,
            canonicalName: entityProfile.canonicalName,
            aliases: entityProfile.aliases,
            roleLabels: entityProfile.relationshipToUser.map { [$0.rawValue] } ?? [],
            relationshipToUser: entityProfile.relationshipToUser,
            relationshipHistory: entityProfile.relationshipToUser.map {
                [
                    RelationshipChange(
                        relationship: $0,
                        sourceRecordIDs: entityProfile.sourceRecordIDs,
                        status: entityProfile.confirmationState == .userConfirmed ? .userConfirmed : .inferred,
                        changedAt: now
                    )
                ]
            } ?? [],
            interactionFrequency: .unknown,
            commonContextLabels: entityProfile.commonContextLabels,
            sourceRecordIDs: entityProfile.sourceRecordIDs,
            createdAt: entityProfile.createdAt,
            updatedAt: now
        )
    }

    private func mergeRelationshipHistory(
        _ lhs: [RelationshipChange],
        _ rhs: [RelationshipChange]
    ) -> [RelationshipChange] {
        var seen = Set<String>()
        var result: [RelationshipChange] = []
        for change in lhs + rhs {
            let key = [
                change.relationship?.rawValue ?? "nil",
                change.note ?? "",
                change.changedAt.timeIntervalSince1970.description,
            ].joined(separator: "|")
            guard seen.insert(key).inserted else { continue }
            result.append(change)
        }
        return result.sorted { $0.changedAt < $1.changedAt }
    }

    private func deleteEntityNodes(entityIDs: Set<UUID>) throws {
        guard !entityIDs.isEmpty else { return }
        let nodeStores = try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
        for store in nodeStores where entityIDs.contains(store.id) {
            modelContext.delete(store)
        }
    }

    private func enqueueEntityMutationRecomputeJobs(
        affectedRecordIDs: Set<UUID>,
        affectedEntityIDs: Set<UUID>
    ) throws {
        let now = Date.now
        for entityID in affectedEntityIDs {
            try upsert(intelligenceJob: IntelligenceJob(
                kind: .entityEnrichment,
                targetType: .entity,
                targetID: entityID,
                status: .pending,
                priority: 0.76,
                scheduledAt: now,
                updatedAt: now,
                requiresCloudAI: false
            ))
            try upsert(intelligenceJob: IntelligenceJob(
                kind: .personProfileRefresh,
                targetType: .entity,
                targetID: entityID,
                status: .pending,
                priority: 0.73,
                scheduledAt: now,
                updatedAt: now,
                requiresCloudAI: false
            ))
        }
        for recordID in affectedRecordIDs {
            try upsert(intelligenceJob: IntelligenceJob(
                kind: .chapterCandidate,
                targetType: .record,
                targetID: recordID,
                status: .pending,
                priority: 0.42,
                scheduledAt: now,
                updatedAt: now,
                requiresCloudAI: false
            ))
        }
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

    private func makeAffectSnapshots(
        from draft: MemoryCaptureDraft,
        recordID: UUID,
        createdAt: Date
    ) -> [AffectSnapshot] {
        var snapshots = draft.affectSnapshots.map {
            affectSnapshotMapper.snapshot(recordID: recordID, draft: $0, now: createdAt)
        }
        if snapshots.isEmpty,
           let snapshot = affectSnapshotMapper.snapshot(
                recordID: recordID,
                rawMood: draft.mood,
                userIntensity: nil,
                source: .userFreeform,
                now: createdAt
           ) {
            snapshots.append(snapshot)
        }
        return snapshots
    }

    private func replaceUserAffectSnapshot(recordID: UUID, rawMood: String?, now: Date) throws {
        let stores = try modelContext.fetch(
            FetchDescriptor<AffectSnapshotStore>(predicate: #Predicate { $0.recordID == recordID })
        )
        for store in stores {
            let snapshot = store.domainModel
            let onlyUserFreeform = snapshot.sources.allSatisfy { $0 == .userFreeform || $0 == .userSelected }
            if onlyUserFreeform {
                modelContext.delete(store)
            }
        }

        if let snapshot = affectSnapshotMapper.snapshot(
            recordID: recordID,
            rawMood: rawMood,
            userIntensity: nil,
            source: .userFreeform,
            now: now
        ) {
            try upsert(affectSnapshot: snapshot)
        }
    }

    private func updateSelfExpressionPattern(from correction: AffectCorrection, now: Date) throws {
        guard let note = correction.note?.trimmedOrNil else { return }
        var profile = try ensureSelfProfile()
        let interpretation = (correction.toneHints + correction.labels.map { label in
            switch label {
            case .irritated, .stressed, .tense, .overwhelmed:
                return ToneHint.serious
            case .playful, .amused, .mockFrustrated:
                return ToneHint.playful
            default:
                return ToneHint.uncertain
            }
        })
        .map(\.rawValue)
        .joined(separator: ", ")
        let pattern = ExpressionPattern(
            phrase: note,
            interpretation: interpretation.isEmpty ? "affect correction" : interpretation,
            confidence: 1
        )
        profile.expressionPatterns.removeAll {
            $0.phrase.caseInsensitiveCompare(pattern.phrase) == .orderedSame
        }
        profile.expressionPatterns.insert(pattern, at: 0)
        profile.expressionPatterns = Array(profile.expressionPatterns.prefix(20))
        profile.updatedAt = now
        try upsertSelfProfile(profile)
    }

    private func orderedUniqueAffectLabels(_ labels: [AffectLabel]) -> [AffectLabel] {
        var seen = Set<AffectLabel>()
        var result: [AffectLabel] = []
        for label in labels where !seen.contains(label) {
            seen.insert(label)
            result.append(label)
        }
        return result
    }

    private func orderedUniqueToneHints(_ hints: [ToneHint]) -> [ToneHint] {
        var seen = Set<ToneHint>()
        var result: [ToneHint] = []
        for hint in hints where !seen.contains(hint) {
            seen.insert(hint)
            result.append(hint)
        }
        return result
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

    func upsert(homeBoardPreference: HomeBoardItemPreference) throws {
        let syncKey = homeBoardPreference.syncKey
        let descriptor = FetchDescriptor<HomeBoardPreferenceStore>(predicate: #Predicate { $0.syncKey == syncKey })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: homeBoardPreference)
        } else {
            modelContext.insert(HomeBoardPreferenceStore(domainModel: homeBoardPreference))
        }
    }

    func upsert(userSettingsPreference: UserSettingsPreference) throws {
        let syncKey = userSettingsPreference.syncKey
        let descriptor = FetchDescriptor<UserSettingsPreferenceStore>(predicate: #Predicate { $0.syncKey == syncKey })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: userSettingsPreference)
        } else {
            modelContext.insert(UserSettingsPreferenceStore(domainModel: userSettingsPreference))
        }
    }

    private func fetchIntelligencePreferenceStore() throws -> IntelligencePreferenceStore? {
        let syncKey = IntelligencePreferences.defaultSyncKey
        let descriptor = FetchDescriptor<IntelligencePreferenceStore>(
            predicate: #Predicate { $0.syncKey == syncKey },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }

    private func fetchSelfProfileStore(syncKey: String) throws -> SelfProfileStore? {
        let descriptor = FetchDescriptor<SelfProfileStore>(
            predicate: #Predicate { $0.syncKey == syncKey },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }

    func upsert(correctionEvent: CorrectionEvent) throws {
        let descriptor = FetchDescriptor<CorrectionEventStore>(predicate: #Predicate { $0.id == correctionEvent.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: correctionEvent)
        } else {
            modelContext.insert(CorrectionEventStore(domainModel: correctionEvent))
        }
    }

    func upsert(entityTombstone: EntityTombstone) throws {
        let descriptor = FetchDescriptor<EntityTombstoneStore>(
            predicate: #Predicate { $0.oldEntityID == entityTombstone.oldEntityID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: entityTombstone)
        } else {
            modelContext.insert(EntityTombstoneStore(domainModel: entityTombstone))
        }
    }

    func upsert(entityProfile: EntityProfile) throws {
        let descriptor = FetchDescriptor<EntityProfileStore>(predicate: #Predicate { $0.id == entityProfile.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: entityProfile)
        } else if let existingByEntity = try modelContext.fetch(
            FetchDescriptor<EntityProfileStore>(predicate: #Predicate { $0.entityID == entityProfile.entityID })
        ).first {
            existingByEntity.apply(domainModel: entityProfile)
        } else {
            modelContext.insert(EntityProfileStore(domainModel: entityProfile))
        }
    }

    func upsert(personProfile: PersonProfile) throws {
        let descriptor = FetchDescriptor<PersonProfileStore>(predicate: #Predicate { $0.id == personProfile.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: personProfile)
        } else if let existingByEntity = try modelContext.fetch(
            FetchDescriptor<PersonProfileStore>(predicate: #Predicate { $0.entityID == personProfile.entityID })
        ).first {
            existingByEntity.apply(domainModel: personProfile)
        } else {
            modelContext.insert(PersonProfileStore(domainModel: personProfile))
        }
    }

    func upsert(affectSnapshot: AffectSnapshot) throws {
        let descriptor = FetchDescriptor<AffectSnapshotStore>(predicate: #Predicate { $0.id == affectSnapshot.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: affectSnapshot)
        } else {
            modelContext.insert(AffectSnapshotStore(domainModel: affectSnapshot))
        }
    }

    func upsert(placeProfile: PlaceProfile) throws {
        let descriptor = FetchDescriptor<PlaceProfileStore>(predicate: #Predicate { $0.id == placeProfile.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: placeProfile)
        } else if let existingByEntity = try modelContext.fetch(
            FetchDescriptor<PlaceProfileStore>(predicate: #Predicate { $0.entityID == placeProfile.entityID })
        ).first {
            existingByEntity.apply(domainModel: placeProfile)
        } else {
            modelContext.insert(PlaceProfileStore(domainModel: placeProfile))
        }
    }

    func upsert(clarificationQuestion: ClarificationQuestion) throws {
        let descriptor = FetchDescriptor<ClarificationQuestionStore>(predicate: #Predicate { $0.id == clarificationQuestion.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: clarificationQuestion)
        } else {
            modelContext.insert(ClarificationQuestionStore(domainModel: clarificationQuestion))
        }
    }

    func upsert(intelligenceJob: IntelligenceJob) throws {
        let descriptor = FetchDescriptor<IntelligenceJobStore>(predicate: #Predicate { $0.id == intelligenceJob.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: intelligenceJob)
        } else if let existingByDedupeKey = try modelContext.fetch(
            FetchDescriptor<IntelligenceJobStore>(predicate: #Predicate { $0.dedupeKey == intelligenceJob.dedupeKey })
        ).first {
            existingByDedupeKey.apply(domainModel: intelligenceJob)
        } else {
            modelContext.insert(IntelligenceJobStore(domainModel: intelligenceJob))
        }
    }

    func upsert(graphDelta: GraphDelta) throws {
        let descriptor = FetchDescriptor<GraphDeltaStore>(predicate: #Predicate { $0.id == graphDelta.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: graphDelta)
        } else {
            modelContext.insert(GraphDeltaStore(domainModel: graphDelta))
        }
    }

    func upsert(notificationIntent: NotificationIntent) throws {
        let descriptor = FetchDescriptor<NotificationIntentStore>(predicate: #Predicate { $0.id == notificationIntent.id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(domainModel: notificationIntent)
        } else {
            modelContext.insert(NotificationIntentStore(domainModel: notificationIntent))
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
            upsertPlaceProfile: upsert(placeProfile:),
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

    private func isSemanticSearchActive() throws -> Bool {
        try fetchIntelligencePreferences().semanticSearchEnabled && fetchV6FeatureFlags().semanticSearch
    }

    private func indexMemoryIfPossible(_ memory: MemorySummary) async {
        guard (try? isSemanticSearchActive()) == true else { return }
        guard spotlightIndexService.isIndexingAvailable else { return }

        do {
            let item = spotlightItemBuilder.makeMemoryItem(
                memory: memory,
                artifacts: try fetchArtifacts(recordID: memory.id),
                analysis: try fetchRecordAnalysis(recordID: memory.id)
            )
            try await spotlightIndexService.indexItems([item])
        } catch {
            // Indexing should never block capture or analysis completion.
        }
    }

    private func makeMemoryLibraryRow(
        memory: MemorySummary,
        graphContext: MemoryGraphContext
    ) throws -> MemoryLibraryRowSnapshot {
        let artifacts = try fetchArtifacts(recordID: memory.id)
        let artifactKinds = Array(Set(artifacts.map(\.kind))).sorted { $0.rawValue < $1.rawValue }
        let relatedArcs = graphContext.arcs.filter { $0.sourceRecordIDs.contains(memory.id) }
        let relatedArcIDs = Set(relatedArcs.map(\.id))
        let relatedReflections = graphContext.reflections.filter { reflection in
            reflection.sourceRecordIDs.contains(memory.id)
                || reflection.linkedTemporalArcID.map { relatedArcIDs.contains($0) } == true
        }
        let entityIDs = Set(
            graphContext.links
                .filter { $0.sourceRecordID == memory.id || $0.sourceAnalysisRecordID == memory.id }
                .map(\.entityID)
        )

        return MemoryLibraryRowSnapshot(
            memory: memory,
            artifactKinds: artifactKinds,
            hasLocation: artifactKinds.contains(.location),
            hasWeather: artifactKinds.contains(.weather),
            hasMusic: artifactKinds.contains(.music),
            relatedStorylineCount: relatedArcs.count,
            relatedReflectionCount: relatedReflections.count,
            entityCount: entityIDs.count
        )
    }

    private func memoryLibraryRow(
        _ row: MemoryLibraryRowSnapshot,
        matches filter: MemoryLibraryFilter
    ) -> Bool {
        if let dateRange = filter.dateRange, !dateRange.contains(row.memory.record.updatedAt) {
            return false
        }
        if !filter.artifactKinds.isEmpty, filter.artifactKinds.isDisjoint(with: Set(row.artifactKinds)) {
            return false
        }
        if !filter.pipelineStages.isEmpty {
            guard let stage = row.memory.pipelineStatus?.stage, filter.pipelineStages.contains(stage) else {
                return false
            }
        }
        switch filter.context {
        case .any:
            break
        case .hasLocation:
            guard row.hasLocation else { return false }
        case .hasWeather:
            guard row.hasWeather else { return false }
        case .hasMusic:
            guard row.hasMusic else { return false }
        }
        switch filter.insight {
        case .any:
            break
        case .hasStoryline:
            guard row.relatedStorylineCount > 0 else { return false }
        case .hasReflection:
            guard row.relatedReflectionCount > 0 else { return false }
        case .hasEntities:
            guard row.entityCount > 0 else { return false }
        }
        return true
    }

    private func makeReflectionSummary(
        reflection: ReflectionSnapshot,
        graphContext: MemoryGraphContext
    ) -> ReflectionSummarySnapshot {
        let linkedArc = reflection.linkedTemporalArcID.flatMap { arcID in
            graphContext.arcs.first { $0.id == arcID }
        }
        let relatedRecordIDs = linkedArc.map {
            graphContext.mergeUniqueIDs(reflection.sourceRecordIDs, $0.sourceRecordIDs)
        } ?? reflection.sourceRecordIDs
        return ReflectionSummarySnapshot(
            reflection: reflection,
            linkedArc: linkedArc,
            relatedMemories: graphContext.relatedMemories(recordIDs: relatedRecordIDs, limit: 3)
        )
    }

    private func applyLimit<T>(_ limit: Int?, to values: [T]) -> [T] {
        guard let limit else { return values }
        return Array(values.prefix(limit))
    }
}

private struct EntityEdgeKey: Hashable {
    let fromEntityID: UUID
    let toEntityID: UUID
    let relationKind: EntityRelationKind

    init(_ edge: EntityEdge) {
        self.fromEntityID = edge.fromEntityID
        self.toEntityID = edge.toEntityID
        self.relationKind = edge.relationKind
    }
}
