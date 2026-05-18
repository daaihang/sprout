import SwiftData
import XCTest
@testable import mory

@MainActor
final class DailyQuestionSuggestionServiceTests: XCTestCase {
    func testCloudDailyQuestionSuggestionPersistsAndAppearsOnHomeBoard() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        try enableDailyQuestionLoop(on: repository)

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Late work note",
                rawText: "I stayed late again because the beta launch checklist kept expanding.",
                mood: "tired",
                inputContext: "typed in test",
                captureSource: .composer,
                artifacts: [
                    .text(
                        title: "Late work note",
                        body: "I stayed late again because the beta launch checklist kept expanding."
                    )
                ]
            )
        )

        let cloud = MockDailyQuestionCloudService(
            response: MoryAPIClient.QuestionSuggestionResponse(
                schemaVersion: 1,
                questions: [
                    MoryAPIClient.QuestionCandidateResponse(
                        kind: ClarificationQuestionKind.dailyReflection.rawValue,
                        prompt: "What part of the beta checklist felt most stuck tonight?",
                        reason: "The recent memory mentions late work and an expanding checklist.",
                        candidateAnswers: ["Scope", "Timing", "Ownership"],
                        confidence: 0.78,
                        sensitivity: QuestionSensitivity.personal.rawValue
                    )
                ],
                meta: MoryAPIClient.CloudIntelligenceMeta(
                    provider: "mock",
                    model: "mock-v6-question-v1",
                    usage: nil,
                    requestID: "req-daily-question",
                    promptVersion: "prompt-v1"
                )
            )
        )
        let service = DailyQuestionSuggestionService(cloudIntelligenceService: cloud)

        let prepared = try await service.prepareIfNeeded(
            repository: repository,
            now: Date(timeIntervalSince1970: 1_800_000_000),
            localeIdentifier: "en-US"
        )

        XCTAssertEqual(prepared.count, 1)
        XCTAssertEqual(prepared.first?.kind, .dailyReflection)
        XCTAssertEqual(prepared.first?.targetID, memory.id)
        XCTAssertEqual(prepared.first?.candidateAnswers.map(\.value), ["Scope", "Timing", "Ownership"])

        let stored = try XCTUnwrap(repository.fetchClarificationQuestions(status: .pending, limit: nil).first)
        XCTAssertEqual(stored.prompt, "What part of the beta checklist felt most stuck tonight?")
        XCTAssertEqual(stored.sourceRecordIDs, [memory.id])

        let payloads = await cloud.questionPayloads()
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads.first?.target.id, memory.id.uuidString)
        XCTAssertEqual(payloads.first?.target.kind, ClarificationQuestionKind.dailyReflection.rawValue)
        XCTAssertEqual(payloads.first?.userPreferences?.questionTone, "evidence_based")
        XCTAssertEqual(payloads.first?.evidence.first?.recordID, memory.id.uuidString)

        let board = try repository.fetchHomeBoard(for: Date(timeIntervalSince1970: 1_800_000_000), limit: 8)
        XCTAssertTrue(board.items.contains { item in
            if case let .clarificationQuestion(question, profile) = item.renderValue {
                return question.id == stored.id && profile == nil
            }
            return false
        })
    }

    func testSkipsDailyQuestionSuggestionWhenPreferencesOrFlagsDisableIt() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Quiet default",
                rawText: "A memory exists, but daily questions are not enabled by default.",
                captureSource: .composer,
                artifacts: [.text(title: "Quiet default", body: "A memory exists.")]
            )
        )

        let cloud = MockDailyQuestionCloudService()
        let service = DailyQuestionSuggestionService(cloudIntelligenceService: cloud)

        let prepared = try await service.prepareIfNeeded(repository: repository)

        XCTAssertTrue(prepared.isEmpty)
        let payloads = await cloud.questionPayloads()
        XCTAssertTrue(payloads.isEmpty)
        XCTAssertTrue(try repository.fetchClarificationQuestions(status: nil, limit: nil).isEmpty)
    }

    func testSkipsDailyQuestionSuggestionWhenTodayAlreadyHasQuestion() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        try enableDailyQuestionLoop(on: repository)

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Existing daily",
                rawText: "This memory already has a daily question for today.",
                captureSource: .composer,
                artifacts: [.text(title: "Existing daily", body: "This memory already has a daily question.")]
            )
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try repository.upsertClarificationQuestion(
            ClarificationQuestion(
                kind: .dailyReflection,
                prompt: "Existing question?",
                targetType: .record,
                targetID: memory.id,
                sourceRecordIDs: [memory.id],
                priority: 0.7,
                reason: "Already prepared today.",
                createdAt: now
            )
        )

        let cloud = MockDailyQuestionCloudService()
        let service = DailyQuestionSuggestionService(cloudIntelligenceService: cloud)

        let prepared = try await service.prepareIfNeeded(repository: repository, now: now)

        XCTAssertTrue(prepared.isEmpty)
        let payloads = await cloud.questionPayloads()
        XCTAssertTrue(payloads.isEmpty)
        XCTAssertEqual(try repository.fetchClarificationQuestions(status: .pending, limit: nil).count, 1)
    }

    private func makeRepositoryFixture() -> DailyQuestionRepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: DailyQuestionTestRecordAnalysisService()
        )
        return DailyQuestionRepositoryFixture(container: container, repository: repository)
    }

    private func enableDailyQuestionLoop(on repository: MoryMemoryRepository) throws {
        var preferences = try repository.fetchIntelligencePreferences()
        preferences.localIntelligenceEnabled = true
        preferences.cloudIntelligenceEnabled = true
        preferences.homeSuggestionsEnabled = true
        preferences.dailyQuestionsEnabled = true
        preferences.questionTone = .evidenceBased
        preferences.updatedAt = .now
        try repository.saveIntelligencePreferences(preferences)

        var flags = try repository.fetchV6FeatureFlags()
        flags.clarificationQuestions = true
        flags.dailyQuestions = true
        flags.cloudQuestionSuggestions = true
        flags.updatedAt = .now
        try repository.saveV6FeatureFlags(flags)
    }
}

private struct DailyQuestionRepositoryFixture {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

private enum DailyQuestionTestError: Error {
    case unsupported
}

private actor MockDailyQuestionCloudService: CloudIntelligenceServing {
    private var response: MoryAPIClient.QuestionSuggestionResponse
    private var payloads: [MoryAPIClient.QuestionSuggestionPayload] = []

    init(
        response: MoryAPIClient.QuestionSuggestionResponse = MoryAPIClient.QuestionSuggestionResponse(
            schemaVersion: 1,
            questions: [
                MoryAPIClient.QuestionCandidateResponse(
                    kind: ClarificationQuestionKind.dailyReflection.rawValue,
                    prompt: "What should Mory remember from today?",
                    reason: "A daily question was requested.",
                    candidateAnswers: [],
                    confidence: 0.6,
                    sensitivity: QuestionSensitivity.normal.rawValue
                )
            ],
            meta: nil
        )
    ) {
        self.response = response
    }

    func questionPayloads() -> [MoryAPIClient.QuestionSuggestionPayload] {
        payloads
    }

    func suggestQuestions(_ payload: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse {
        payloads.append(payload)
        return response
    }

    func refineTranscript(_ payload: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse {
        throw DailyQuestionTestError.unsupported
    }

    func suggestChapters(_ payload: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse {
        throw DailyQuestionTestError.unsupported
    }

    func analyzePhotoSemantics(_ payload: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse {
        throw DailyQuestionTestError.unsupported
    }

    func suggestNotificationIntent(_ payload: MoryAPIClient.NotificationIntentSuggestionPayload) async throws -> MoryAPIClient.NotificationIntentSuggestionResponse {
        throw DailyQuestionTestError.unsupported
    }

    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse {
        throw DailyQuestionTestError.unsupported
    }
}

private struct DailyQuestionTestRecordAnalysisService: RecordAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: record.rawText,
            themes: ["daily"],
            emotionInterpretation: "",
            salienceScore: 0.6,
            retrievalTerms: ["daily"],
            entityMentions: [],
            candidateEdges: [],
            followUpCandidates: [],
            reflectionHint: nil,
            createdAt: record.updatedAt
        )
    }

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw DailyQuestionTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw DailyQuestionTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}
