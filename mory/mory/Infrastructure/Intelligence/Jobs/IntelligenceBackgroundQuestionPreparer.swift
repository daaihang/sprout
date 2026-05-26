import Foundation

@MainActor
struct IntelligenceBackgroundQuestionPreparer: BackgroundQuestionPreparing {
    private let cloudIntelligenceService: (any CloudIntelligenceServing)?

    init(cloudIntelligenceService: (any CloudIntelligenceServing)?) {
        self.cloudIntelligenceService = cloudIntelligenceService
    }

    func prepareBackgroundQuestion(
        repository: any DailyQuestionRepositorying,
        now: Date
    ) async throws -> BackgroundOperationOutcome {
        guard let cloudIntelligenceService else {
            return .skipped(message: "Cloud intelligence service unavailable.")
        }

        let questions = try await DailyQuestionSuggestionService(
            cloudIntelligenceService: cloudIntelligenceService
        )
        .prepareIfNeeded(repository: repository, now: now)

        return .completed(resultCounts: ["questions": questions.count])
    }
}
