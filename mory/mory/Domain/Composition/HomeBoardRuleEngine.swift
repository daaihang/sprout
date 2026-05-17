import Foundation

struct HomeBoardRuleEngine: Sendable {
    func buildHomeBoard(
        date: Date,
        limit: Int,
        graphContext: MemoryGraphContext,
        memories: [MemorySummary],
        analyses: [UUID: RecordAnalysisSnapshot],
        pipelineStatuses: [PipelineStatusSummary],
        preferences: [HomeBoardItemPreference]
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
            boardID: boardID
        )

        let visibleCandidates = candidates.compactMap { candidate -> HomeBoardCandidate? in
            guard let preference = preferenceIndex[candidate.cardKey] else { return candidate }
            guard !preference.isHidden, preference.dismissedAt == nil else { return nil }
            var updated = candidate
            updated.isPinned = preference.isPinned
            updated.dismissedAt = preference.dismissedAt
            updated.preferenceUpdatedAt = preference.updatedAt
            return updated
        }
        .sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.updatedAt > rhs.updatedAt
        }
        .prefix(itemLimit)

        let items = visibleCandidates.enumerated().map { index, candidate in
            HomeBoardItemSnapshot(
                compositionItem: CompositionItem(
                    id: UUID(),
                    boardID: boardID,
                    boardKey: board.boardKey,
                    compositionID: compositionID,
                    compositionKey: composition.compositionKey,
                    itemKey: candidate.cardKey,
                    targetType: candidate.targetType,
                    targetID: candidate.targetID,
                    widthColumns: candidate.widthColumns,
                    heightUnits: candidate.heightUnits,
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
        boardID: UUID
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
                    heightUnits: memory.contextArtifacts.isEmpty ? 1 : 2
                )
            )
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
                    heightUnits: 2
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
                    heightUnits: 2
                )
            )
        }

        candidates.append(contentsOf: makeContextClusterCandidates(memories: memories, boardID: boardID, date: date))
        candidates.append(contentsOf: makePendingActionCandidates(pipelineStatuses: pipelineStatuses))

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
                heightUnits: 1
            )
        ]
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
                    heightUnits: 1
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
            heightUnits: 1
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
    var isPinned = false
    var dismissedAt: Date?
    var preferenceUpdatedAt: Date?
}
