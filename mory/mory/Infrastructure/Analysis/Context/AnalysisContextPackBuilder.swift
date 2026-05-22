import Foundation

enum ContextPackBuilderError: LocalizedError {
    case targetMemoryNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case let .targetMemoryNotFound(id):
            "No memory found for context pack target \(id.uuidString)."
        }
    }
}

struct ContextRanker {
    func score(
        memory: MemorySummary,
        target: MemoryDetailSnapshot,
        query: String,
        semanticMemoryIDs: Set<UUID>,
        profiles: [EntityProfile],
        selfProfile: SelfProfile,
        now: Date
    ) -> ContextScoreBreakdown {
        let text = [memory.title, memory.summaryText, memory.record.rawText, memory.record.inputContext ?? ""].joined(separator: " ")
        let queryTokens = tokenize(query)
        let textTokens = tokenize(text)
        let overlapCount = queryTokens.intersection(textTokens).count
        let entityMatches = profiles.filter { profile in
            let names = [profile.displayName, profile.canonicalName] + profile.aliases
            return names.contains { !($0.isEmpty) && text.localizedCaseInsensitiveContains($0) }
        }
        let confirmedMatches = entityMatches.filter { $0.confirmationState == .userConfirmed }.count
        let age = max(0, now.timeIntervalSince(memory.record.createdAt))
        let recency = max(0, 1 - min(age / (60 * 60 * 24 * 30), 1))
        let targetMood = target.record.userMood?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let memoryMood = memory.record.userMood?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let affectMatch = targetMood != nil && targetMood == memoryMood
        let hasDecisionSignal = ["decide", "decision", "choose", "move", "job", "relationship", "决定", "选择", "换工作", "搬家"]
            .contains { text.localizedCaseInsensitiveContains($0) }
        let sensitivityPenalty = selfProfile.sensitiveBoundaries.contains { boundary in
            ([boundary.label] + boundary.keywords).contains { keyword in
                !keyword.isEmpty && text.localizedCaseInsensitiveContains(keyword)
            }
        } ? 0.6 : 0

        return ContextScoreBreakdown(
            semanticSimilarity: semanticMemoryIDs.contains(memory.id) ? 0.45 : 0,
            entityOverlap: queryTokens.isEmpty ? 0 : min(Double(overlapCount) / Double(queryTokens.count), 1) * 0.25
                + min(Double(entityMatches.count) * 0.12, 0.36),
            recencyWeight: recency * 0.15,
            salienceWeight: min(Double(memory.artifactCount) * 0.03, 0.12),
            userConfirmedWeight: min(Double(confirmedMatches) * 0.12, 0.24),
            openDecisionWeight: hasDecisionSignal ? 0.12 : 0,
            affectSimilarityWeight: affectMatch ? 0.08 : 0,
            sensitivityPenalty: sensitivityPenalty,
            repeatedRejectedSignalPenalty: 0
        )
    }

    func inclusionReasons(for breakdown: ContextScoreBreakdown) -> [String] {
        var reasons: [String] = []
        if breakdown.semanticSimilarity > 0 { reasons.append("semantic-search") }
        if breakdown.entityOverlap > 0 { reasons.append("text-or-entity-overlap") }
        if breakdown.recencyWeight > 0.08 { reasons.append("recent") }
        if breakdown.userConfirmedWeight > 0 { reasons.append("user-confirmed-profile") }
        if breakdown.openDecisionWeight > 0 { reasons.append("decision-signal") }
        if breakdown.affectSimilarityWeight > 0 { reasons.append("affect-match") }
        if reasons.isEmpty { reasons.append("fallback-continuity") }
        return reasons
    }

    private func tokenize(_ text: String) -> Set<String> {
        let parts = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 2 }
        return Set(parts)
    }
}

struct ContextBudgeter {
    var limits: ContextBudgetLimits = .phase1Default

    func memorySnippet(from memory: MemorySummary) -> String {
        bounded([memory.summaryText, memory.record.rawText].joined(separator: "\n"), maxCharacters: limits.maxMemorySnippetCharacters)
    }

    func bounded(_ text: String, maxCharacters: Int) -> String {
        guard text.count > maxCharacters else { return text }
        let index = text.index(text.startIndex, offsetBy: maxCharacters)
        return String(text[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func report(
        profiles: Int,
        memories: Int,
        arcs: Int,
        reflections: Int,
        corrections: Int,
        affectHistory: Int,
        droppedByBudget: Int,
        droppedByPrivacy: Int
    ) -> ContextBudgetReport {
        ContextBudgetReport(
            limits: limits,
            selectedProfiles: profiles,
            selectedRelatedMemories: memories,
            selectedArcs: arcs,
            selectedReflections: reflections,
            selectedCorrections: corrections,
            selectedAffectHistory: affectHistory,
            droppedByBudget: droppedByBudget,
            droppedByPrivacy: droppedByPrivacy
        )
    }
}

struct PrivacyGate {
    func decision(for memory: MemorySummary, selfProfile: SelfProfile) -> ContextPrivacyDecision {
        if selfProfile.privacyMode == .localOnly {
            return ContextPrivacyDecision(
                sourceType: "memory",
                sourceID: memory.id,
                action: .localOnly,
                reason: "SelfProfile privacyMode is localOnly."
            )
        }

        let text = [memory.title, memory.summaryText, memory.record.rawText, memory.record.inputContext ?? ""].joined(separator: " ")
        for boundary in selfProfile.sensitiveBoundaries {
            let keywords = [boundary.label] + boundary.keywords
            if let matched = keywords.first(where: { !$0.isEmpty && text.localizedCaseInsensitiveContains($0) }) {
                return ContextPrivacyDecision(
                    sourceType: "memory",
                    sourceID: memory.id,
                    action: .drop,
                    reason: "Matched sensitive boundary: \(matched)."
                )
            }
        }

        return ContextPrivacyDecision(
            sourceType: "memory",
            sourceID: memory.id,
            action: .include,
            reason: "No Phase 1 privacy rule blocked this memory."
        )
    }

    func allowsCloudEvidence(_ decision: ContextPrivacyDecision) -> Bool {
        switch decision.action {
        case .include, .redact, .summarize, .idOnly:
            return true
        case .drop, .localOnly, .blockCloud:
            return false
        }
    }
}

@MainActor
struct ContextPackBuilder {
    private let repository: any MoryMemoryRepositorying
    private let ranker: ContextRanker
    private let budgeter: ContextBudgeter
    private let privacyGate: PrivacyGate

    init(repository: any MoryMemoryRepositorying) {
        self.repository = repository
        self.ranker = ContextRanker()
        self.budgeter = ContextBudgeter()
        self.privacyGate = PrivacyGate()
    }

    init(
        repository: any MoryMemoryRepositorying,
        ranker: ContextRanker,
        budgeter: ContextBudgeter,
        privacyGate: PrivacyGate
    ) {
        self.repository = repository
        self.ranker = ranker
        self.budgeter = budgeter
        self.privacyGate = privacyGate
    }

    func build(targetRecordID: UUID, builtAt: Date = .now) async throws -> AnalysisContextPack {
        guard let target = try repository.fetchMemoryDetail(recordID: targetRecordID) else {
            throw ContextPackBuilderError.targetMemoryNotFound(targetRecordID)
        }

        let selfProfile = try repository.ensureSelfProfile()
        let profiles = try repository.fetchEntityProfiles(kind: nil, limit: budgeter.limits.maxProfiles * 3)
        let query = Self.queryText(for: target)
        let semanticResult = await semanticSearchIfAvailable(query: query)
        let semanticMemoryIDs = Set(semanticResult.snapshot?.semanticMemoryIDs ?? [])
        let recentMemories = try repository.fetchRecentMemories(limit: max(24, budgeter.limits.maxRelatedMemories * 4))
        let memoryCandidates = mergeMemoryCandidates(
            semantic: semanticResult.snapshot?.memories.map(\.memory) ?? [],
            recent: recentMemories,
            targetRecordID: targetRecordID
        )
        let rankedMemories = memoryCandidates
            .map { memory -> (memory: MemorySummary, score: ContextScoreBreakdown, decision: ContextPrivacyDecision) in
                let score = ranker.score(
                    memory: memory,
                    target: target,
                    query: query,
                    semanticMemoryIDs: semanticMemoryIDs,
                    profiles: profiles,
                    selfProfile: selfProfile,
                    now: builtAt
                )
                let decision = privacyGate.decision(for: memory, selfProfile: selfProfile)
                return (memory, score, decision)
            }
            .sorted { $0.score.total > $1.score.total }

        let includedMemoryTuples = rankedMemories
            .filter { privacyGate.allowsCloudEvidence($0.decision) }
            .prefix(budgeter.limits.maxRelatedMemories)
        let relatedMemories = includedMemoryTuples.map { item in
            RelatedMemoryBrief(
                recordID: item.memory.id,
                title: item.memory.title,
                snippet: budgeter.memorySnippet(from: item.memory),
                createdAt: item.memory.record.createdAt,
                userMood: item.memory.record.userMood,
                scoreBreakdown: item.score,
                inclusionReasons: ranker.inclusionReasons(for: item.score)
            )
        }
        let privacyDecisions = rankedMemories.map(\.decision)
        let droppedByPrivacy = privacyDecisions.filter { !privacyGate.allowsCloudEvidence($0) }.count
        let droppedByBudget = max(0, rankedMemories.count - droppedByPrivacy - relatedMemories.count)
        let relatedProfiles = makeProfileBriefs(from: profiles, relatedMemories: Array(relatedMemories))
        let relatedArcs = try repository.fetchTemporalArcSummaries(limit: budgeter.limits.maxArcs * 3)
            .prefix(budgeter.limits.maxArcs)
            .map { summary in
                RelatedArcBrief(
                    arcID: summary.arc.id,
                    title: summary.arc.title,
                    summary: summary.arc.summary,
                    status: summary.arc.status,
                    sourceRecordIDs: summary.arc.sourceRecordIDs,
                    score: summary.arc.clusterStrength
                )
            }
        let reflections = try repository.fetchReflectionSummaries(limit: budgeter.limits.maxReflections * 3)
            .prefix(budgeter.limits.maxReflections)
            .map { summary in
                PriorReflectionBrief(
                    reflectionID: summary.reflection.id,
                    title: summary.reflection.title,
                    evidenceSummary: summary.reflection.evidenceSummary,
                    status: summary.reflection.status,
                    sourceRecordIDs: summary.reflection.sourceRecordIDs,
                    confidence: summary.reflection.confidence
                )
            }
        let corrections = try repository.fetchClarificationQuestions(status: nil, limit: budgeter.limits.maxCorrections * 3)
            .filter { $0.status == .pending || $0.status == .answered || $0.status == .dismissed }
            .prefix(budgeter.limits.maxCorrections)
            .map { question in
                CorrectionSignalBrief(
                    id: question.id,
                    kind: question.kind,
                    targetType: question.targetType,
                    targetID: question.targetID,
                    status: question.status,
                    summary: question.answer?.freeformText ?? question.answer?.value ?? question.prompt,
                    answeredAt: question.answeredAt
                )
            }
        let affectSnapshots = try repository.fetchAffectSnapshots(recordID: nil, limit: max(48, budgeter.limits.maxAffectHistory * 8))
        let affectHistory = makeAffectHistory(from: recentMemories, snapshots: affectSnapshots, excluding: targetRecordID)

        let budget = budgeter.report(
            profiles: relatedProfiles.count,
            memories: relatedMemories.count,
            arcs: relatedArcs.count,
            reflections: reflections.count,
            corrections: corrections.count,
            affectHistory: affectHistory.count,
            droppedByBudget: droppedByBudget,
            droppedByPrivacy: droppedByPrivacy
        )

        return AnalysisContextPack(
            packID: UUID(),
            targetRecordID: targetRecordID,
            selfBrief: SelfContextBrief(profile: selfProfile, maxCharacters: budgeter.limits.maxSelfBriefCharacters),
            relatedProfiles: relatedProfiles,
            relatedMemories: Array(relatedMemories),
            relatedArcs: Array(relatedArcs),
            priorReflections: Array(reflections),
            correctionSignals: Array(corrections),
            affectHistory: affectHistory,
            privacyDecisions: privacyDecisions,
            budget: budget,
            retrieval: ContextPackRetrievalReport(
                semanticSearchStatus: semanticResult.statusDescription,
                retrievalSources: semanticResult.sources,
                candidateMemoryCount: memoryCandidates.count,
                fallbackReason: semanticResult.fallbackReason
            ),
            builtAt: builtAt
        )
    }

    private func semanticSearchIfAvailable(query: String) async -> SemanticContextResult {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SemanticContextResult(snapshot: nil, statusDescription: "disabled", sources: ["exactFallback"], fallbackReason: "Empty query.")
        }

        do {
            let preferences = try repository.fetchIntelligencePreferences()
            let flags = try repository.fetchV6FeatureFlags()
            guard preferences.semanticSearchEnabled && flags.semanticSearch else {
                return SemanticContextResult(snapshot: nil, statusDescription: "disabled", sources: ["exactFallback"], fallbackReason: "Semantic search gate is disabled.")
            }
            let snapshot = try await repository.searchSemanticFirst(query: query, limit: budgeter.limits.maxRelatedMemories * 2)
            return SemanticContextResult(
                snapshot: snapshot,
                statusDescription: Self.semanticStatusDescription(snapshot.semanticSearchStatus),
                sources: snapshot.retrievalSources.map(\.rawValue),
                fallbackReason: nil
            )
        } catch {
            return SemanticContextResult(snapshot: nil, statusDescription: "failed: \(error.localizedDescription)", sources: ["exactFallback"], fallbackReason: error.localizedDescription)
        }
    }

    private func mergeMemoryCandidates(
        semantic: [MemorySummary],
        recent: [MemorySummary],
        targetRecordID: UUID
    ) -> [MemorySummary] {
        var seen: Set<UUID> = [targetRecordID]
        var result: [MemorySummary] = []
        for memory in semantic + recent where !seen.contains(memory.id) {
            seen.insert(memory.id)
            result.append(memory)
        }
        return result
    }

    private func makeProfileBriefs(
        from profiles: [EntityProfile],
        relatedMemories: [RelatedMemoryBrief]
    ) -> [KnownProfileBrief] {
        let evidenceText = relatedMemories.map { "\($0.title) \($0.snippet)" }.joined(separator: " ")
        let sorted = profiles.sorted { lhs, rhs in
            let lhsMatched = evidenceText.localizedCaseInsensitiveContains(lhs.displayName)
            let rhsMatched = evidenceText.localizedCaseInsensitiveContains(rhs.displayName)
            if lhsMatched != rhsMatched { return lhsMatched && !rhsMatched }
            return lhs.mentionCount > rhs.mentionCount
        }
        return sorted.prefix(budgeter.limits.maxProfiles).map { profile in
            KnownProfileBrief(
                entityID: profile.entityID,
                kind: profile.kind,
                displayName: profile.displayName,
                relationshipToUser: profile.relationshipToUser,
                mentionCount: profile.mentionCount,
                commonContextLabels: Array(profile.commonContextLabels.prefix(6)),
                confidence: profile.confidence,
                inclusionReason: evidenceText.localizedCaseInsensitiveContains(profile.displayName) ? "mentioned in related memories" : "high profile recency/mention count"
            )
        }
    }

    private func makeAffectHistory(
        from memories: [MemorySummary],
        snapshots: [AffectSnapshot],
        excluding targetRecordID: UUID
    ) -> [AffectHistoryBrief] {
        let memoryByID = Dictionary(uniqueKeysWithValues: memories.map { ($0.id, $0) })
        let snapshotGroups = Dictionary(grouping: snapshots.filter { $0.recordID != targetRecordID }, by: { snapshot in
            snapshot.primaryMoodText.lowercased()
        })

        if !snapshotGroups.isEmpty {
            return snapshotGroups.map { key, values in
                let latest = values.max { $0.updatedAt < $1.updatedAt }
                return AffectHistoryBrief(
                    mood: key,
                    count: values.count,
                    latestRecordID: latest?.recordID ?? values[0].recordID,
                    averageValence: average(values.compactMap(\.valence)),
                    averageArousal: average(values.compactMap(\.arousal)),
                    averageDominance: average(values.compactMap(\.dominance)),
                    toneHints: orderedUnique(values.flatMap(\.toneHints)),
                    sources: orderedUnique(values.flatMap(\.sources))
                )
            }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                let lhsDate = memoryByID[lhs.latestRecordID]?.record.createdAt ?? .distantPast
                let rhsDate = memoryByID[rhs.latestRecordID]?.record.createdAt ?? .distantPast
                return lhsDate > rhsDate
            }
            .prefix(budgeter.limits.maxAffectHistory)
            .map { $0 }
        }

        var counts: [String: (count: Int, latest: MemorySummary)] = [:]
        for memory in memories where memory.id != targetRecordID {
            guard let mood = memory.record.userMood?.trimmingCharacters(in: .whitespacesAndNewlines), !mood.isEmpty else { continue }
            let key = mood.lowercased()
            let existing = counts[key]
            if let existing {
                let latest = existing.latest.record.createdAt > memory.record.createdAt ? existing.latest : memory
                counts[key] = (existing.count + 1, latest)
            } else {
                counts[key] = (1, memory)
            }
        }
        return counts
            .map { key, value in AffectHistoryBrief(mood: key, count: value.count, latestRecordID: value.latest.id) }
            .sorted { $0.count > $1.count }
            .prefix(budgeter.limits.maxAffectHistory)
            .map { $0 }
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func orderedUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }

    private static func queryText(for target: MemoryDetailSnapshot) -> String {
        ([target.record.rawText, target.record.inputContext ?? ""] + target.artifacts.map { "\($0.title) \($0.summary) \($0.textContent)" })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func semanticStatusDescription(_ status: SemanticSearchStatus) -> String {
        switch status {
        case .notRequested:
            return "notRequested"
        case .disabled:
            return "disabled"
        case .unavailable:
            return "unavailable"
        case let .succeeded(resultCount):
            return "succeeded(\(resultCount))"
        case let .failed(message):
            return "failed: \(message)"
        }
    }
}

private struct SemanticContextResult {
    var snapshot: SearchSnapshot?
    var statusDescription: String
    var sources: [String]
    var fallbackReason: String?
}
