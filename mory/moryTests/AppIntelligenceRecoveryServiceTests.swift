import SwiftData
import XCTest
@testable import mory

@MainActor
final class AppIntelligenceRecoveryServiceTests: XCTestCase {
    func testRecoveryResumesRunningJobsRetriesFailedJobsAndSchedulesNotifications() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_200_000)
        try enableRecoveryFeatures(on: repository, now: now)
        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Recovery source",
                rawText: "Recovery should re-run this pipeline job.",
                captureSource: .composer,
                artifacts: [.text(title: "Recovery source", body: "Recovery should re-run this pipeline job.")]
            )
        )
        let questionAnchorMemory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Question anchor",
                rawText: "Keep this memory as the source for daily question intent preparation.",
                captureSource: .composer,
                artifacts: [.text(title: "Question anchor", body: "Keep this memory as the source for daily question intent preparation.")]
            )
        )

        let runningJob = IntelligenceJob(
            kind: .postAnalysis,
            targetType: .record,
            targetID: memory.id,
            status: .running,
            priority: 0.9,
            attemptCount: 0,
            scheduledAt: now.addingTimeInterval(-600),
            startedAt: now.addingTimeInterval(-300),
            updatedAt: now.addingTimeInterval(-300)
        )
        let retryableFailedJob = IntelligenceJob(
            kind: .notificationIntent,
            targetType: .notification,
            targetID: UUID(),
            status: .failed,
            priority: 0.5,
            attemptCount: 1,
            lastError: "Network unavailable",
            scheduledAt: now.addingTimeInterval(-300),
            updatedAt: now.addingTimeInterval(-300)
        )
        let exhaustedFailedJob = IntelligenceJob(
            kind: .semanticIndex,
            targetType: .searchIndex,
            targetID: UUID(),
            status: .failed,
            priority: 0.4,
            attemptCount: 3,
            lastError: "Permanent failure",
            scheduledAt: now.addingTimeInterval(-300),
            updatedAt: now.addingTimeInterval(-300)
        )
        try repository.upsertIntelligenceJob(runningJob)
        try repository.upsertIntelligenceJob(retryableFailedJob)
        try repository.upsertIntelligenceJob(exhaustedFailedJob)

        let question = ClarificationQuestion(
            kind: .dailyReflection,
            prompt: "What should Mory ask today?",
            targetType: .record,
            targetID: questionAnchorMemory.id,
            sourceRecordIDs: [questionAnchorMemory.id],
            priority: 0.8,
            reason: "Prepared before app relaunch.",
            createdAt: now
        )
        try repository.upsertClarificationQuestion(question)

        let center = RecoveryMockNotificationCenter(state: .authorized)
        let service = AppIntelligenceRecoveryService(
            maxRetryAttempts: 3,
            baseRetryDelay: 60,
            notificationScheduler: LocalNotificationScheduler(notificationCenter: center)
        )

        let report = await service.recoverAfterLaunch(
            repository: repository,
            cloudIntelligenceService: RecoveryMockCloudIntelligenceService(),
            now: now
        )

        XCTAssertEqual(report.resumedRunningJobIDs, [runningJob.id])
        XCTAssertEqual(report.retriedFailedJobIDs, [retryableFailedJob.id])
        XCTAssertEqual(report.abandonedFailedJobIDs, [exhaustedFailedJob.id])
        XCTAssertTrue(report.workerReport.completedJobIDs.contains(runningJob.id))
        XCTAssertNotNil(report.preparedNotificationIntentID)
        XCTAssertEqual(report.notificationScheduleReport.scheduledCount, 1)
        XCTAssertEqual(center.requests.count, 1)

        let jobs = try repository.fetchIntelligenceJobs(status: nil, limit: nil)
        let resumed = try XCTUnwrap(jobs.first { $0.id == runningJob.id })
        XCTAssertEqual(resumed.status, .completed)
        XCTAssertNotNil(resumed.completedAt)

        let retried = try XCTUnwrap(jobs.first { $0.id == retryableFailedJob.id })
        XCTAssertEqual(retried.status, .pending)
        XCTAssertEqual(retried.scheduledAt, now.addingTimeInterval(60))

        let exhausted = try XCTUnwrap(jobs.first { $0.id == exhaustedFailedJob.id })
        XCTAssertEqual(exhausted.status, .failed)
    }

    private func makeRepositoryFixture() -> RecoveryRepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: RecoveryRecordAnalysisService(),
            cloudIntelligenceService: RecoveryMockCloudIntelligenceService()
        )
        return RecoveryRepositoryFixture(container: container, repository: repository)
    }

    private func enableRecoveryFeatures(on repository: MoryMemoryRepository, now: Date) throws {
        var preferences = IntelligencePreferences.defaults
        preferences.dailyQuestionsEnabled = true
        preferences.notificationPreferences = NotificationPreferences(
            enabled: true,
            dailyQuestionEnabled: true,
            maxPerDay: 2,
            minimumMinutesBetweenNotifications: 0,
            quietHoursStartHour: nil,
            quietHoursEndHour: nil,
            richPreviewsEnabled: false
        )
        preferences.updatedAt = now
        try repository.saveIntelligencePreferences(preferences)

        var flags = V6FeatureFlags.defaults
        flags.intelligenceJobs = true
        flags.dailyQuestions = true
        flags.localNotifications = true
        flags.updatedAt = now
        try repository.saveV6FeatureFlags(flags)
    }
}

private struct RecoveryRepositoryFixture {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

@MainActor
private final class RecoveryMockNotificationCenter: LocalNotificationSchedulingCenter {
    var state: LocalNotificationAuthorizationState
    var requests: [LocalNotificationScheduleRequest] = []

    init(state: LocalNotificationAuthorizationState) {
        self.state = state
    }

    func authorizationState() async -> LocalNotificationAuthorizationState {
        state
    }

    func requestAuthorization() async throws -> Bool {
        state = .authorized
        return true
    }

    func add(_ request: LocalNotificationScheduleRequest) async throws {
        requests.append(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) async {}
}

private enum RecoveryTestError: Error {
    case unsupported
}

private struct RecoveryMockCloudIntelligenceService: CloudIntelligenceServing {
    func analyzeV7(_ payload: AnalyzeV7RequestPayload) async throws -> AnalyzeV7ResponseEnvelope {
        AnalyzeV7ResponseEnvelope(
            analysis: AnalyzeResponseEnvelope(
                tags: ["recovery"],
                retrievalTerms: ["recovery"],
                emotion: .init(label: "neutral", intensity: 0.2, confidence: 0.6, interpretation: nil),
                entities: [],
                candidateEdges: [],
                insight: payload.recordShell.rawText,
                summary: payload.recordShell.rawText,
                salienceScore: 0.5,
                followUp: nil,
                reflectionHint: nil
            ),
            affectProposals: [],
            graphDeltaProposals: [],
            profileUpdateProposals: [],
            mergeSplitCandidates: [],
            arcCandidates: [],
            reflectionCandidates: [],
            questionCandidates: [],
            quality: .init(confidence: 0.6, uncertaintyReasons: [], needsUserCheck: [])
        )
    }

    func refineTranscript(_ payload: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse {
        throw RecoveryTestError.unsupported
    }

    func suggestQuestions(_ payload: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse {
        throw RecoveryTestError.unsupported
    }

    func suggestChapters(_ payload: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse {
        throw RecoveryTestError.unsupported
    }

    func analyzePhotoSemantics(_ payload: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse {
        throw RecoveryTestError.unsupported
    }

    func suggestNotificationIntent(_ payload: MoryAPIClient.NotificationIntentSuggestionPayload) async throws -> MoryAPIClient.NotificationIntentSuggestionResponse {
        throw RecoveryTestError.unsupported
    }

    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse {
        throw RecoveryTestError.unsupported
    }
}

private struct RecoveryRecordAnalysisService: RecordAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: record.rawText,
            themes: ["recovery"],
            emotionInterpretation: "",
            salienceScore: 0.5,
            retrievalTerms: ["recovery"],
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
        throw RecoveryTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw RecoveryTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}
