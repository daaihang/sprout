import Foundation

@MainActor
struct DailyQuestionSuggestionService {
    private let cloudIntelligenceService: any CloudIntelligenceServing
    private let isoFormatter: ISO8601DateFormatter

    init(
        cloudIntelligenceService: any CloudIntelligenceServing,
        isoFormatter: ISO8601DateFormatter = ISO8601DateFormatter()
    ) {
        self.cloudIntelligenceService = cloudIntelligenceService
        self.isoFormatter = isoFormatter
    }

    func prepareIfNeeded(
        repository: any MoryMemoryRepositorying,
        now: Date = .now,
        localeIdentifier: String = Locale.autoupdatingCurrent.identifier,
        evidenceLimit: Int = 6
    ) async throws -> [ClarificationQuestion] {
        let preferences = try repository.fetchIntelligencePreferences()
        let flags = try repository.fetchV6FeatureFlags()
        guard shouldPrepare(preferences: preferences, flags: flags) else { return [] }

        let existingQuestions = try repository.fetchClarificationQuestions(status: nil, limit: nil)
        guard shouldAskDailyQuestion(existingQuestions: existingQuestions, now: now) else { return [] }

        let memories = try repository.fetchRecentMemories(limit: evidenceLimit)
        guard let targetMemory = memories.first else { return [] }

        let response = try await cloudIntelligenceService.suggestQuestions(
            makePayload(
                targetMemory: targetMemory,
                memories: memories,
                preferences: preferences,
                localeIdentifier: localeIdentifier
            )
        )
        let questions = response.questions
            .prefix(2)
            .map { candidate in
                makeClarificationQuestion(
                    from: candidate,
                    targetMemory: targetMemory,
                    memories: memories,
                    now: now
                )
            }

        for question in questions {
            try repository.upsertClarificationQuestion(question)
        }

        return Array(questions)
    }

    private func shouldPrepare(preferences: IntelligencePreferences, flags: V6FeatureFlags) -> Bool {
        preferences.localIntelligenceEnabled
            && preferences.cloudIntelligenceEnabled
            && preferences.homeSuggestionsEnabled
            && preferences.dailyQuestionsEnabled
            && flags.dailyQuestions
            && flags.cloudQuestionSuggestions
    }

    private func shouldAskDailyQuestion(
        existingQuestions: [ClarificationQuestion],
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        !existingQuestions.contains { question in
            guard question.kind == .dailyReflection else { return false }
            if question.status == .pending {
                return true
            }
            guard question.status != .expired, question.status != .stale else {
                return false
            }
            return calendar.isDate(question.createdAt, inSameDayAs: now)
        }
    }

    private func makePayload(
        targetMemory: MemorySummary,
        memories: [MemorySummary],
        preferences: IntelligencePreferences,
        localeIdentifier: String
    ) -> MoryAPIClient.QuestionSuggestionPayload {
        MoryAPIClient.QuestionSuggestionPayload(
            locale: localeIdentifier,
            target: .init(
                type: ClarificationTargetType.record.rawValue,
                id: targetMemory.id.uuidString,
                kind: ClarificationQuestionKind.dailyReflection.rawValue
            ),
            evidence: memories.map(makeEvidenceSnippet),
            knownProfile: nil,
            userPreferences: .init(
                allowSensitiveQuestions: preferences.sensitiveTopicPolicy == .allow,
                questionTone: preferences.questionTone.cloudPayloadValue
            )
        )
    }

    private func makeEvidenceSnippet(from memory: MemorySummary) -> MoryAPIClient.EvidenceSnippetPayload {
        let snippet = [
            memory.title.trimmedOrNil,
            memory.summaryText.trimmedOrNil,
            memory.record.userMood?.trimmedOrNil,
            memory.record.inputContext?.trimmedOrNil,
        ]
            .compactMap { $0 }
            .joined(separator: " | ")
            .prefixString(maxLength: 600)

        return MoryAPIClient.EvidenceSnippetPayload(
            recordID: memory.id.uuidString,
            artifactID: memory.primaryArtifact?.id.uuidString,
            snippet: snippet,
            createdAt: isoFormatter.string(from: memory.record.createdAt)
        )
    }

    private func makeClarificationQuestion(
        from candidate: MoryAPIClient.QuestionCandidateResponse,
        targetMemory: MemorySummary,
        memories: [MemorySummary],
        now: Date
    ) -> ClarificationQuestion {
        let sourceRecordIDs = memories.map(\.id)
        let sourceArtifactIDs = memories.compactMap { $0.primaryArtifact?.id }
        let prompt = candidate.prompt.trimmedOrNil ?? "What should Mory remember from today?"
        let reason = candidate.reason.trimmedOrNil ?? "Mory found enough recent context to ask one focused question."
        let kind = ClarificationQuestionKind(rawValue: candidate.kind) ?? .dailyReflection
        let sensitivity = QuestionSensitivity(rawValue: candidate.sensitivity) ?? .normal

        return ClarificationQuestion(
            kind: kind,
            prompt: prompt,
            targetType: .record,
            targetID: targetMemory.id,
            sourceRecordIDs: sourceRecordIDs,
            sourceArtifactIDs: sourceArtifactIDs,
            candidateAnswers: candidate.candidateAnswers.map { answer in
                ClarificationAnswerOption(label: answer, value: answer)
            },
            priority: min(max(candidate.confidence, 0.1), 0.98),
            reason: reason,
            sensitivity: sensitivity,
            createdAt: now,
            expiresAt: Calendar.autoupdatingCurrent.date(byAdding: .day, value: 2, to: now)
        )
    }
}

private extension DailyQuestionTone {
    var cloudPayloadValue: String {
        switch self {
        case .journalPrompt: return "journal_prompt"
        case .memoryRevisit: return "memory_revisit"
        case .lifeOrganization: return "life_organization"
        case .evidenceBased: return "evidence_based"
        case .reflective: return "reflective"
        }
    }
}

private extension String {
    func prefixString(maxLength: Int) -> String {
        guard count > maxLength else { return self }
        return String(prefix(maxLength))
    }
}
