import Foundation

struct HomeBoardRuleEngine: Sendable {
    func buildHomeBoard(
        date: Date,
        limit: Int,
        graphContext: MemoryGraphContext,
        memories: [MemorySummary],
        analyses: [UUID: RecordAnalysisSnapshot],
        pipelineStatuses: [PipelineStatusSummary],
        preferences: [HomeBoardItemPreference],
        clarificationQuestions: [ClarificationQuestion],
        entityProfiles: [EntityProfile]
    ) -> HomeBoardSnapshot {
        let now = Date.now
        let boardID = UUID()
        let compositionID = UUID()
        let board = Board(
            id: boardID,
            boardKey: "home-board",
            kind: .homeDay,
            title: "Today",
            subtitle: date.formatted(date: .abbreviated, time: .omitted),
            boardDate: date,
            createdAt: now,
            updatedAt: now
        )
        let composition = Composition(
            id: compositionID,
            boardID: boardID,
            compositionKey: "home-composition",
            title: "Home Grid",
            sortOrder: 0,
            createdAt: now,
            updatedAt: now
        )

        let preferenceIndex = Dictionary(uniqueKeysWithValues: preferences.map { ($0.cardKey, $0) })
        let itemLimit = min(max(limit, 0), 12)
        let candidates = makeCandidates(
            date: date,
            graphContext: graphContext,
            memories: memories,
            analyses: analyses,
            pipelineStatuses: pipelineStatuses,
            boardID: boardID,
            clarificationQuestions: clarificationQuestions,
            entityProfiles: entityProfiles
        )

        let visibleCandidates = candidates.compactMap { candidate -> HomeBoardCandidate? in
            guard let preference = preferenceIndex[candidate.cardKey] else { return candidate }
            guard !preference.isHidden, preference.dismissedAt == nil else { return nil }
            var updated = candidate
            updated.isPinned = preference.isPinned
            updated.widthColumns = preference.widthColumns ?? updated.widthColumns
            updated.heightUnits = preference.heightUnits ?? updated.heightUnits
            updated.userSortIndex = preference.userSortIndex
            updated.acceptedAt = preference.acceptedAt
            updated.dismissedAt = preference.dismissedAt
            updated.preferenceUpdatedAt = preference.updatedAt
            return updated
        }
        let userCandidates = visibleCandidates
            .filter { $0.layoutLayer == .userBoard }
            .sorted(by: sortUserBoardCandidates)
        let suggestionCandidates = visibleCandidates
            .filter { $0.layoutLayer == .suggestion }
            .sorted(by: sortSuggestionCandidates)
            .prefix(max(0, itemLimit - userCandidates.count))
        let selectedCandidates = userCandidates + Array(suggestionCandidates)

        let items = selectedCandidates.enumerated().map { index, candidate in
            let span = HomeBoardSpan(widthColumns: candidate.widthColumns, heightUnits: candidate.heightUnits)
            return HomeBoardItemSnapshot(
                compositionItem: CompositionItem(
                    id: UUID(),
                    boardID: boardID,
                    boardKey: board.boardKey,
                    compositionID: compositionID,
                    compositionKey: composition.compositionKey,
                    itemKey: candidate.cardKey,
                    targetType: candidate.targetType,
                    targetID: candidate.targetID,
                    widthColumns: span.widthColumns,
                    heightUnits: span.heightUnits,
                    zIndex: index,
                    rotationDegrees: rotationForPosition(index),
                    scale: candidate.isPinned ? 1.02 : 1,
                    isHidden: false,
                    updatedAt: candidate.updatedAt
                ),
                renderValue: candidate.renderValue,
                cardKind: candidate.cardKind,
                priority: candidate.priority,
                reason: candidate.reason,
                sourceRecordIDs: candidate.sourceRecordIDs,
                layout: HomeBoardItemLayout(
                    span: span,
                    layer: candidate.layoutLayer,
                    userSortIndex: candidate.userSortIndex,
                    acceptedAt: candidate.acceptedAt
                ),
                isPinned: candidate.isPinned,
                isHidden: false,
                dismissedAt: candidate.dismissedAt,
                createdAt: candidate.createdAt,
                updatedAt: candidate.preferenceUpdatedAt ?? candidate.updatedAt
            )
        }

        return HomeBoardSnapshot(board: board, composition: composition, items: items)
    }

    private func makeCandidates(
        date: Date,
        graphContext: MemoryGraphContext,
        memories: [MemorySummary],
        analyses: [UUID: RecordAnalysisSnapshot],
        pipelineStatuses: [PipelineStatusSummary],
        boardID: UUID,
        clarificationQuestions: [ClarificationQuestion],
        entityProfiles: [EntityProfile]
    ) -> [HomeBoardCandidate] {
        var candidates: [HomeBoardCandidate] = []
        let calendar = Calendar.current
        let recentCutoff = date.addingTimeInterval(-24 * 60 * 60)
        let linksByRecordID = Dictionary(grouping: graphContext.links.compactMap { link -> (UUID, ArtifactEntityLink)? in
            guard let recordID = link.sourceRecordID else { return nil }
            return (recordID, link)
        }, by: \.0)
        let memoryIndex = Dictionary(uniqueKeysWithValues: memories.map { ($0.id, $0) })

        for memory in memories.prefix(10) {
            let analysis = analyses[memory.id]
            let updatedAt = memory.record.updatedAt
            let isToday = calendar.isDate(updatedAt, inSameDayAs: date)
            let isRecent = updatedAt >= recentCutoff
            let salience = analysis?.salienceScore ?? 0.35
            let contextBoost = min(Double(memory.contextArtifacts.count) * 3.0, 9.0)
            let graphBoost = min(Double(linksByRecordID[memory.id]?.count ?? 0) * 2.0, 8.0)
            let recencyBoost: Double = isToday ? 18.0 : (isRecent ? 12.0 : 0.0)
            let priority = 38.0 + recencyBoost + (salience * 20.0) + contextBoost + graphBoost
            candidates.append(
                HomeBoardCandidate(
                    cardKey: "memory-\(memory.id.uuidString)",
                    cardKind: .memory,
                    targetType: .record,
                    targetID: memory.id,
                    sourceRecordIDs: [memory.id],
                    renderValue: .memory(memory),
                    priority: priority,
                    reason: reason([
                        isToday ? "today" : nil,
                        isRecent ? "recent" : nil,
                        salience >= 0.65 ? "high salience" : nil,
                        memory.contextArtifacts.isEmpty ? nil : "context",
                        linksByRecordID[memory.id]?.isEmpty == false ? "graph linked" : nil
                    ]),
                    createdAt: memory.record.createdAt,
                    updatedAt: updatedAt,
                    widthColumns: 2,
                    heightUnits: memory.contextArtifacts.isEmpty ? 1 : 2,
                    defaultLayer: .userBoard
                )
            )
        }

        if let yesterdayPanel = makeYesterdayPanelCandidate(memories: memories, boardID: boardID, date: date) {
            candidates.append(yesterdayPanel)
        }

        let activeArcs = graphContext.arcs
            .filter { $0.status == .accepted }
            .filter { arc in
                arc.updatedAt >= date.addingTimeInterval(-7 * 24 * 60 * 60)
                    || arc.sourceRecordIDs.contains { memoryIndex[$0]?.record.updatedAt ?? .distantPast >= recentCutoff }
            }
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                return lhs.clusterStrength > rhs.clusterStrength
            }
            .prefix(3)
        for arc in activeArcs {
            candidates.append(
                HomeBoardCandidate(
                    cardKey: "arc-\(arc.id.uuidString)",
                    cardKind: .arc,
                    targetType: .arc,
                    targetID: arc.id,
                    sourceRecordIDs: arc.sourceRecordIDs,
                    renderValue: .arc(arc),
                    priority: 70 + arc.clusterStrength * 12 + min(Double(arc.sourceRecordIDs.count), 5),
                    reason: "active storyline",
                    createdAt: arc.createdAt,
                    updatedAt: arc.updatedAt,
                    widthColumns: 2,
                    heightUnits: 2,
                    defaultLayer: .suggestion
                )
            )
        }

        let suggestedReflections = graphContext.reflections
            .filter { $0.status == .suggested }
            .sorted { lhs, rhs in
                if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
                return lhs.createdAt > rhs.createdAt
            }
            .prefix(2)
        for reflection in suggestedReflections {
            candidates.append(
                HomeBoardCandidate(
                    cardKey: "reflection-\(reflection.id.uuidString)",
                    cardKind: .reflection,
                    targetType: .reflection,
                    targetID: reflection.id,
                    sourceRecordIDs: reflection.sourceRecordIDs,
                    renderValue: .reflection(reflection),
                    priority: 66 + reflection.confidence * 14,
                    reason: "suggested reflection",
                    createdAt: reflection.createdAt,
                    updatedAt: reflection.createdAt,
                    widthColumns: 2,
                    heightUnits: 2,
                    defaultLayer: .suggestion
                )
            )
        }

        candidates.append(contentsOf: makeContextClusterCandidates(memories: memories, boardID: boardID, date: date))
        candidates.append(contentsOf: makePendingActionCandidates(pipelineStatuses: pipelineStatuses))
        candidates.append(contentsOf: makeClarificationQuestionCandidates(
            questions: clarificationQuestions,
            entityProfiles: entityProfiles
        ))

        if memories.isEmpty {
            candidates.append(systemPromptCandidate(
                boardID: boardID,
                cardKey: "system-empty-home",
                title: String(localized: "home.board.system.empty.title"),
                subtitle: String(localized: "home.board.system.empty.subtitle"),
                actionTitle: String(localized: "home.capture.button"),
                priority: 95,
                reason: "empty board"
            ))
        } else if memories.count < 3 {
            candidates.append(systemPromptCandidate(
                boardID: boardID,
                cardKey: "system-onboarding",
                title: String(localized: "home.board.system.onboarding.title"),
                subtitle: String(localized: "home.board.system.onboarding.subtitle"),
                actionTitle: nil,
                priority: 58,
                reason: "early usage guidance"
            ))
        }

        return candidates
    }

    private func makeContextClusterCandidates(memories: [MemorySummary], boardID: UUID, date: Date) -> [HomeBoardCandidate] {
        let recentCutoff = date.addingTimeInterval(-7 * 24 * 60 * 60)
        let recent = memories.filter { $0.record.updatedAt >= recentCutoff }
        let contextEntries = recent.flatMap { memory in
            memory.contextArtifacts.compactMap { artifact -> (String, MemorySummary)? in
                guard artifact.kind == .location || artifact.kind == .music else { return nil }
                let key = "\(artifact.kind.rawValue)-\(artifact.title.lowercased())"
                return (key, memory)
            }
        }
        let grouped = Dictionary(grouping: contextEntries, by: \.0)
        guard let cluster = grouped.values
            .filter({ Set($0.map(\.1.id)).count >= 2 })
            .max(by: { lhs, rhs in Set(lhs.map(\.1.id)).count < Set(rhs.map(\.1.id)).count })
        else {
            return []
        }
        let sourceMemories = Array(Dictionary(uniqueKeysWithValues: cluster.map { ($0.1.id, $0.1) }).values)
            .sorted { $0.record.updatedAt > $1.record.updatedAt }
        let title = sourceMemories.first?.contextArtifacts.first?.title ?? String(localized: "home.board.cluster.title")
        return [
            HomeBoardCandidate(
                cardKey: "context-cluster-\(cluster[0].0)",
                cardKind: .contextCluster,
                targetType: .system,
                targetID: boardID,
                sourceRecordIDs: sourceMemories.map(\.id),
                renderValue: .contextCluster(
                    title: title,
                    subtitle: String(localized: "home.board.cluster.subtitle \(sourceMemories.count)"),
                    sourceRecordIDs: sourceMemories.map(\.id)
                ),
                priority: 56 + Double(sourceMemories.count),
                reason: "repeated context",
                createdAt: sourceMemories.last?.record.createdAt ?? .now,
                updatedAt: sourceMemories.first?.record.updatedAt ?? .now,
                widthColumns: 2,
                heightUnits: 1,
                defaultLayer: .suggestion
            )
        ]
    }

    private func makeYesterdayPanelCandidate(memories: [MemorySummary], boardID: UUID, date: Date) -> HomeBoardCandidate? {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) else {
            return nil
        }
        let sourceMemories = memories
            .filter { calendar.isDate($0.record.updatedAt, inSameDayAs: yesterday) }
            .sorted { $0.record.updatedAt > $1.record.updatedAt }
        guard !sourceMemories.isEmpty else { return nil }

        return HomeBoardCandidate(
            cardKey: "yesterday-\(calendar.startOfDay(for: yesterday).timeIntervalSince1970)",
            cardKind: .yesterdayPanel,
            targetType: .system,
            targetID: boardID,
            sourceRecordIDs: sourceMemories.map(\.id),
            renderValue: .yesterdayPanel(
                title: "Yesterday organized",
                subtitle: "\(sourceMemories.count) memories are ready to revisit.",
                sourceRecordIDs: sourceMemories.map(\.id)
            ),
            priority: 64 + min(Double(sourceMemories.count), 8),
            reason: "yesterday ready",
            createdAt: sourceMemories.last?.record.createdAt ?? yesterday,
            updatedAt: sourceMemories.first?.record.updatedAt ?? yesterday,
            widthColumns: 4,
            heightUnits: 2,
            defaultLayer: .suggestion
        )
    }

    private func makePendingActionCandidates(pipelineStatuses: [PipelineStatusSummary]) -> [HomeBoardCandidate] {
        pipelineStatuses
            .filter { $0.status.stage == .failed || $0.status.stage == .running }
            .prefix(2)
            .map { status in
                let isFailed = status.status.stage == .failed
                return HomeBoardCandidate(
                    cardKey: "pipeline-\(status.recordID.uuidString)",
                    cardKind: .pendingAction,
                    targetType: .record,
                    targetID: status.recordID,
                    sourceRecordIDs: [status.recordID],
                    renderValue: .pendingAction(
                        title: status.title,
                        subtitle: isFailed ? String(localized: "home.board.pending.failed") : String(localized: "home.board.pending.running"),
                        targetRecordID: status.recordID
                    ),
                    priority: isFailed ? 82 : 52,
                    reason: isFailed ? "pipeline failed" : "pipeline running",
                    createdAt: status.status.lastAttemptAt ?? status.status.updatedAt,
                    updatedAt: status.status.updatedAt,
                    widthColumns: 2,
                    heightUnits: 1,
                    defaultLayer: .suggestion
                )
            }
    }

    private func makeClarificationQuestionCandidates(
        questions: [ClarificationQuestion],
        entityProfiles: [EntityProfile]
    ) -> [HomeBoardCandidate] {
        let profileIndex = Dictionary(uniqueKeysWithValues: entityProfiles.map { ($0.entityID, $0) })

        return questions
            .filter { $0.status == .pending && $0.targetType == .entity }
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.createdAt > $1.createdAt
            }
            .prefix(2)
            .map { question in
                let profile = profileIndex[question.targetID]
                return HomeBoardCandidate(
                    cardKey: "question-\(question.id.uuidString)",
                    cardKind: .clarificationQuestion,
                    targetType: .entity,
                    targetID: question.targetID,
                    sourceRecordIDs: question.sourceRecordIDs,
                    renderValue: .clarificationQuestion(question: question, profile: profile),
                    priority: 74 + question.priority * 18,
                    reason: question.reason.ifEmpty("clarification needed"),
                    createdAt: question.createdAt,
                    updatedAt: profile?.updatedAt ?? question.createdAt,
                    widthColumns: 2,
                    heightUnits: question.kind == .entityAlias ? 2 : 1,
                    defaultLayer: .suggestion
                )
            }
    }

    private func systemPromptCandidate(
        boardID: UUID,
        cardKey: String,
        title: String,
        subtitle: String,
        actionTitle: String?,
        priority: Double,
        reason: String
    ) -> HomeBoardCandidate {
        HomeBoardCandidate(
            cardKey: cardKey,
            cardKind: .systemPrompt,
            targetType: .system,
            targetID: boardID,
            sourceRecordIDs: [],
            renderValue: .systemPrompt(title: title, subtitle: subtitle, actionTitle: actionTitle),
            priority: priority,
            reason: reason,
            createdAt: .now,
            updatedAt: .now,
            widthColumns: 2,
            heightUnits: 1,
            defaultLayer: .suggestion
        )
    }

    private func reason(_ parts: [String?]) -> String {
        let value = parts.compactMap(\.self).joined(separator: " · ")
        return value.isEmpty ? "recent activity" : value
    }

    private func rotationForPosition(_ index: Int) -> Double {
        let rotations: [Double] = [0, -0.8, 0.6, 0, 0.5, -0.4, 0, 0.3]
        return rotations[index % rotations.count]
    }

    private func sortUserBoardCandidates(_ lhs: HomeBoardCandidate, _ rhs: HomeBoardCandidate) -> Bool {
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
        switch (lhs.userSortIndex, rhs.userSortIndex) {
        case let (lhsOrder?, rhsOrder?) where lhsOrder != rhsOrder:
            return lhsOrder < rhsOrder
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private func sortSuggestionCandidates(_ lhs: HomeBoardCandidate, _ rhs: HomeBoardCandidate) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        return lhs.updatedAt > rhs.updatedAt
    }
}

private struct HomeBoardCandidate {
    var cardKey: String
    var cardKind: HomeBoardCardKind
    var targetType: CompositionTargetType
    var targetID: UUID
    var sourceRecordIDs: [UUID]
    var renderValue: CompositionRenderValue
    var priority: Double
    var reason: String
    var createdAt: Date
    var updatedAt: Date
    var widthColumns: Int
    var heightUnits: Int
    var defaultLayer: HomeBoardItemLayer
    var isPinned = false
    var acceptedAt: Date?
    var userSortIndex: Double?
    var dismissedAt: Date?
    var preferenceUpdatedAt: Date?

    var layoutLayer: HomeBoardItemLayer {
        isPinned || acceptedAt != nil || userSortIndex != nil ? .userBoard : defaultLayer
    }
}
