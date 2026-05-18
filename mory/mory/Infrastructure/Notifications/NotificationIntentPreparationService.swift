import Foundation

@MainActor
struct NotificationIntentPreparationService {
    private let policy: NotificationPolicy

    init(policy: NotificationPolicy = NotificationPolicy()) {
        self.policy = policy
    }

    @discardableResult
    func prepareDailyQuestionIntentIfNeeded(
        repository: any MoryMemoryRepositorying,
        now: Date = .now
    ) throws -> NotificationIntent? {
        let preferences = try repository.fetchIntelligencePreferences()
        let flags = try repository.fetchV6FeatureFlags()
        guard preferences.dailyQuestionsEnabled, flags.dailyQuestions else {
            return nil
        }

        let existingIntents = try repository.fetchNotificationIntents(status: nil, limit: nil)
        let candidate = nextDailyQuestion(
            from: try repository.fetchClarificationQuestions(status: .pending, limit: nil),
            now: now
        )
        guard let candidate else {
            return nil
        }

        guard !hasActiveIntent(for: candidate.id, existingIntents: existingIntents) else {
            return nil
        }

        let intent = NotificationIntent(
            kind: .dailyQuestion,
            title: "Mory",
            body: candidate.prompt,
            privacyLevel: .contextual,
            targetType: .question,
            targetID: candidate.id,
            scheduledAt: now,
            status: .pending,
            deliveryChannel: .local,
            createdAt: now
        )
        let decision = policy.evaluate(
            intent: intent,
            existingIntents: existingIntents,
            preferences: preferences,
            flags: flags,
            questionSensitivity: candidate.sensitivity,
            now: now
        )

        guard let approvedIntent = decision.approvedIntent else {
            return nil
        }

        try repository.upsertNotificationIntent(approvedIntent)
        return approvedIntent
    }

    private func nextDailyQuestion(
        from questions: [ClarificationQuestion],
        now: Date
    ) -> ClarificationQuestion? {
        questions
            .filter { question in
                question.kind == .dailyReflection
                    && question.status == .pending
                    && !isExpired(question, now: now)
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.createdAt > rhs.createdAt
            }
            .first
    }

    private func isExpired(_ question: ClarificationQuestion, now: Date) -> Bool {
        guard let expiresAt = question.expiresAt else {
            return false
        }
        return expiresAt <= now
    }

    private func hasActiveIntent(
        for questionID: UUID,
        existingIntents: [NotificationIntent]
    ) -> Bool {
        existingIntents.contains { intent in
            intent.kind == .dailyQuestion
                && intent.targetType == .question
                && intent.targetID == questionID
                && intent.status != .dismissed
                && intent.status != .blocked
        }
    }
}
