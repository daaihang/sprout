import Foundation
import SwiftData

extension MoryMemoryRepository {
    // MARK: - Home Board & Composition

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

    func applyHomeBoardItemPreference(
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

}
