import XCTest
@testable import mory

@MainActor
final class BackgroundOperationOrchestratorTests: XCTestCase {
    func testPipelineCompletedPersistsRunAndNotificationEvent() async throws {
        let repository = makeRepository()
        let notification = BackgroundNotificationSpy()
        let recordID = UUID()

        let report = await makeOrchestrator(reminderRouting: notification).handle(
            trigger: BackgroundTrigger(kind: .pipelineCompleted, targetID: recordID, source: "test"),
            repository: repository
        )

        XCTAssertEqual(report.triggerKind, .pipelineCompleted)
        XCTAssertEqual(notification.triggers.map(\.kind), [.pipelineCompleted])
        let runs = try repository.fetchBackgroundOperationRuns(status: nil, limit: nil)
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs.first?.triggerKind, .pipelineCompleted)
        XCTAssertEqual(runs.first?.triggerTargetID, recordID)
        XCTAssertEqual(runs.first?.status, .completed)

        let events = try repository.fetchBackgroundOperationEvents(runID: runs.first?.id, limit: nil)
        XCTAssertEqual(events.map(\.operationKind), [.orchestrateNotifications])
    }

    func testAPNSTokenUpdatedRunsRemotePushSync() async throws {
        let repository = makeRepository()
        let push = BackgroundPushSpy()

        let report = await makeOrchestrator(pushSyncing: push).handle(
            trigger: BackgroundTrigger(kind: .apnsTokenUpdated, source: "test"),
            repository: repository
        )

        XCTAssertEqual(report.status, .completed)
        XCTAssertEqual(push.forceValues, [true])
        let events = try repository.fetchBackgroundOperationEvents(runID: report.runID, limit: nil)
        XCTAssertEqual(events.first?.operationKind, .syncRemotePushRegistration)
        XCTAssertEqual(events.first?.status, .completed)
    }

    func testBackgroundURLSessionCompletedRecordsEventOnly() async throws {
        let repository = makeRepository()

        let report = await makeOrchestrator().handle(
            trigger: BackgroundTrigger(
                kind: .backgroundURLSessionCompleted,
                source: "test",
                metadata: ["identifier": MoryAPIClient.backgroundSessionID]
            ),
            repository: repository
        )

        XCTAssertEqual(report.status, .completed)
        let events = try repository.fetchBackgroundOperationEvents(runID: report.runID, limit: nil)
        XCTAssertEqual(events.first?.operationKind, .recordBackgroundURLSession)
        XCTAssertTrue(events.first?.message?.contains(MoryAPIClient.backgroundSessionID) == true)
    }

    private func makeOrchestrator(
        jobRecoverer: (any BackgroundJobRecovering)? = nil,
        jobProcessor: (any BackgroundJobProcessing)? = nil,
        questionPreparer: (any BackgroundQuestionPreparing)? = nil,
        reminderRouting: (any BackgroundReminderRouting)? = nil,
        pushSyncing: (any BackgroundPushRegistrationSyncing)? = nil
    ) -> BackgroundOperationOrchestrator {
        BackgroundOperationOrchestrator(
            jobRecoverer: jobRecoverer ?? BackgroundRecovererSpy(),
            jobProcessor: jobProcessor ?? BackgroundJobProcessorSpy(),
            questionPreparer: questionPreparer ?? BackgroundQuestionSpy(),
            reminderRouting: reminderRouting ?? BackgroundNotificationSpy(),
            pushSyncing: pushSyncing ?? BackgroundPushSpy()
        )
    }

    private func makeRepository() -> MoryMemoryRepository {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        return MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: BackgroundAnalysisService()
        )
    }
}

private enum BackgroundTestError: Error {
    case unsupported
}

@MainActor
private final class BackgroundRecovererSpy: BackgroundJobRecovering {
    func recoverBackgroundJobs(
        repository _: any IntelligenceRecoveryRepositorying,
        now _: Date
    ) throws -> BackgroundOperationOutcome {
        .completed(resultCounts: ["recovered": 1])
    }
}

@MainActor
private final class BackgroundJobProcessorSpy: BackgroundJobProcessing {
    func processBackgroundJobs(
        repository _: any IntelligenceJobRepositorying,
        now _: Date,
        limit _: Int
    ) async -> BackgroundOperationOutcome {
        .completed(resultCounts: ["completed": 1])
    }
}

@MainActor
private final class BackgroundQuestionSpy: BackgroundQuestionPreparing {
    func prepareBackgroundQuestion(
        repository _: any DailyQuestionRepositorying,
        now _: Date
    ) async throws -> BackgroundOperationOutcome {
        .completed(resultCounts: ["questions": 1])
    }
}

@MainActor
private final class BackgroundNotificationSpy: BackgroundReminderRouting {
    private(set) var triggers: [BackgroundTrigger] = []

    func routeBackgroundReminder(
        for trigger: BackgroundTrigger,
        repository _: any NotificationPreparationRepositorying,
        now _: Date
    ) async throws -> BackgroundOperationOutcome {
        triggers.append(trigger)
        return .completed(resultCounts: ["scheduled": 1])
    }
}

@MainActor
private final class BackgroundPushSpy: BackgroundPushRegistrationSyncing {
    private(set) var forceValues: [Bool] = []

    func syncBackgroundPushRegistration(
        repository _: any MoryMemoryRepositorying,
        force: Bool
    ) async -> BackgroundOperationOutcome {
        forceValues.append(force)
        return .completed(resultCounts: ["attempted": 1])
    }
}

private struct BackgroundAnalysisService: ReflectionAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        await RecordAnalysisSnapshot(recordID: record.id, summary: record.rawText, createdAt: .now)
    }

    func generateReflection(
        record _: RecordShell,
        artifacts _: [Artifact],
        linkedArcID _: UUID?,
        knownEntities _: [EntityReference],
        prompt _: String?
    ) async throws -> ReflectionServiceResult {
        throw BackgroundTestError.unsupported
    }

    func replayReflection(
        reflection _: ReflectionSnapshot,
        linkedArc _: TemporalArc?,
        record _: RecordShell?,
        artifacts _: [Artifact],
        knownEntities _: [EntityReference],
        prompt _: String?
    ) async throws -> ReflectionServiceResult {
        throw BackgroundTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? { nil }
}
