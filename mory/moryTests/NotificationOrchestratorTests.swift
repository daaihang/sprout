import SwiftData
import XCTest
@testable import mory

@MainActor
final class NotificationOrchestratorTests: XCTestCase {
    func testRepositoryPersistsNotificationIntentRoundTrip() throws {
        let fixture = makeRepositoryFixture()
        let targetID = UUID()
        let scheduledAt = Date(timeIntervalSince1970: 1_800_000_000)

        let intent = NotificationIntent(
            kind: .dailyQuestion,
            title: "Mory",
            body: "What should Mory remember today?",
            privacyLevel: .contextual,
            targetType: .question,
            targetID: targetID,
            scheduledAt: scheduledAt,
            deepLink: "mory://home/question/\(targetID.uuidString)",
            reason: "Daily question is ready.",
            sourceTrigger: .homeForegroundRefresh,
            createdBy: .orchestrator,
            lastEvaluatedAt: scheduledAt
        )

        try fixture.repository.upsertNotificationIntent(intent)

        let stored = try XCTUnwrap(fixture.repository.fetchNotificationIntents(status: .pending, limit: nil).first)
        XCTAssertEqual(stored.id, intent.id)
        XCTAssertEqual(stored.kind, .dailyQuestion)
        XCTAssertEqual(stored.targetType, .question)
        XCTAssertEqual(stored.targetID, targetID)
        XCTAssertEqual(stored.deepLink, intent.deepLink)
        XCTAssertEqual(stored.reason, intent.reason)
        XCTAssertEqual(stored.sourceTrigger, .homeForegroundRefresh)
    }

    func testRepositoryPersistsNotificationManagementEventRoundTrip() throws {
        let fixture = makeRepositoryFixture()
        let targetID = UUID()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let event = NotificationManagementEvent(
            eventKind: .deduped,
            intentID: UUID(),
            dedupeKey: "dailyQuestion|question|\(targetID.uuidString)",
            trigger: .homeForegroundRefresh,
            kind: .dailyQuestion,
            targetType: .question,
            targetID: targetID,
            message: "Skipped duplicate candidate.",
            createdAt: now
        )

        try fixture.repository.upsertNotificationManagementEvent(event)

        let stored = try XCTUnwrap(fixture.repository.fetchNotificationManagementEvents(kind: .deduped, limit: nil).first)
        XCTAssertEqual(stored.id, event.id)
        XCTAssertEqual(stored.eventKind, .deduped)
        XCTAssertEqual(stored.dedupeKey, event.dedupeKey)
        XCTAssertEqual(stored.trigger, .homeForegroundRefresh)
        XCTAssertEqual(stored.kind, .dailyQuestion)
        XCTAssertEqual(stored.targetID, targetID)
        XCTAssertEqual(stored.message, event.message)
        XCTAssertEqual(stored.createdAt, now)
    }

    func testAppLaunchRecoveryRecordsDailyQuestionAsInAppOnly() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try enableNotificationLoop(on: repository, now: now)

        let question = ClarificationQuestion(
            kind: .dailyReflection,
            prompt: "What part of today should Mory keep close?",
            targetType: .record,
            targetID: UUID(),
            priority: 0.8,
            reason: "Daily question prepared from recent memories.",
            sensitivity: .normal,
            createdAt: now
        )
        try repository.upsertClarificationQuestion(question)

        let report = try await NotificationOrchestrator().orchestrate(
            trigger: .appLaunchRecovery,
            repository: repository,
            now: now
        )

        XCTAssertEqual(report.inAppOnlyIntentIDs.count, 1)
        let stored = try XCTUnwrap(repository.fetchNotificationIntents(status: .inAppOnly, limit: nil).first)
        XCTAssertEqual(stored.kind, .dailyQuestion)
        XCTAssertEqual(stored.targetType, .question)
        XCTAssertEqual(stored.targetID, question.id)
        XCTAssertEqual(stored.deepLink, "mory://home/question/\(question.id.uuidString)")
        let events = try repository.fetchNotificationManagementEvents(kind: nil, limit: nil)
        XCTAssertTrue(events.contains { $0.eventKind == .generated && $0.intentID == stored.id })
        XCTAssertTrue(events.contains { $0.eventKind == .inAppOnly && $0.intentID == stored.id })
    }

    func testBackgroundRefreshSchedulesAnalysisReadyForCompletedPipeline() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try enableNotificationLoop(on: repository, now: now)

        let seededMemory = try seedMemory(
            in: repository,
            title: "Morning walk",
            body: "Captured a short photo memory.",
            createdAt: now.addingTimeInterval(-2_000),
            artifactKind: .photo
        )
        try repository.upsertPipelineStatus(
            MemoryPipelineStatusSnapshot(
                recordID: seededMemory.record.id,
                stage: .completed,
                requestID: "request-1",
                lastError: nil,
                requestBody: nil,
                responseBody: nil,
                rawErrorBody: nil,
                lastHTTPStatusCode: 200,
                failedStage: nil,
                lastAttemptAt: now.addingTimeInterval(-120),
                completedAt: now.addingTimeInterval(-60),
                updatedAt: now.addingTimeInterval(-60)
            )
        )
        try repository.save()

        let center = MockLocalNotificationCenter(state: .authorized)
        let orchestrator = NotificationOrchestrator(
            localScheduler: LocalNotificationScheduler(
                notificationCenter: center
            )
        )

        let report = try await orchestrator.orchestrate(
            trigger: .backgroundRefresh,
            repository: repository,
            now: now
        )

        XCTAssertEqual(report.scheduledIntentIDs.count, 1)
        XCTAssertTrue(report.remoteEnqueuedIntentIDs.isEmpty)
        XCTAssertEqual(center.requests.count, 1)

        let stored = try XCTUnwrap(repository.fetchNotificationIntents(status: .scheduled, limit: nil).first)
        XCTAssertEqual(stored.kind, .analysisReady)
        XCTAssertEqual(stored.targetType, .record)
        XCTAssertEqual(stored.targetID, seededMemory.record.id)
        XCTAssertEqual(stored.deepLink, "mory://memories/record/\(seededMemory.record.id.uuidString)")
    }

    func testPipelineCompletedPrefersReflectionReadyForMatchingRecord() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try enableNotificationLoop(on: repository, now: now)

        let seededMemory = try seedMemory(
            in: repository,
            title: "Career reset",
            body: "I keep thinking about what work should look like next.",
            createdAt: now.addingTimeInterval(-8_000),
            artifactKind: .text
        )
        try repository.upsert(reflection: ReflectionSnapshot(
            type: .phase,
            title: "Career Transition",
            body: "A work transition reflection is ready.",
            evidenceSummary: "Several recent memories point to the same change.",
            confidence: 0.88,
            status: .suggested,
            linkedTemporalArcID: nil,
            sourceRecordIDs: [seededMemory.record.id],
            sourceArtifactIDs: [seededMemory.artifact.id],
            createdAt: now.addingTimeInterval(-120)
        ))
        try repository.save()

        let report = try await NotificationOrchestrator().orchestrate(
            trigger: .pipelineCompleted(recordID: seededMemory.record.id),
            repository: repository,
            now: now
        )

        XCTAssertEqual(report.inAppOnlyIntentIDs.count, 1)
        let stored = try XCTUnwrap(repository.fetchNotificationIntents(status: .inAppOnly, limit: nil).first)
        XCTAssertEqual(stored.kind, .reflectionReady)
        XCTAssertEqual(stored.targetType, .reflection)
        XCTAssertEqual(stored.reason, "A suggested reflection is ready to review.")
    }

    func testDedupePreventsSecondIntentForSameQuestion() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try enableNotificationLoop(on: repository, now: now)

        let question = ClarificationQuestion(
            kind: .dailyReflection,
            prompt: "What changed today?",
            targetType: .record,
            targetID: UUID(),
            priority: 0.9,
            reason: "Daily question prepared.",
            createdAt: now
        )
        try repository.upsertClarificationQuestion(question)

        _ = try await NotificationOrchestrator().orchestrate(
            trigger: .appLaunchRecovery,
            repository: repository,
            now: now
        )
        let report = try await NotificationOrchestrator().orchestrate(
            trigger: .homeForegroundRefresh,
            repository: repository,
            now: now.addingTimeInterval(30)
        )

        XCTAssertEqual(report.dedupedIntentIDs.count, 1)
        XCTAssertEqual(try repository.fetchNotificationIntents(status: nil, limit: nil).count, 1)
        let dedupeEvent = try XCTUnwrap(repository.fetchNotificationManagementEvents(kind: .deduped, limit: nil).first)
        XCTAssertEqual(dedupeEvent.trigger, .homeForegroundRefresh)
        XCTAssertEqual(dedupeEvent.kind, .dailyQuestion)
        XCTAssertEqual(dedupeEvent.targetID, question.id)
    }

    func testSensitiveDailyQuestionIsBlockedBeforeScheduling() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try enableNotificationLoop(on: repository, now: now)

        try repository.upsertClarificationQuestion(
            ClarificationQuestion(
                kind: .dailyReflection,
                prompt: "A sensitive prompt should stay in-app.",
                targetType: .record,
                targetID: UUID(),
                priority: 0.95,
                reason: "Sensitive daily question.",
                sensitivity: .sensitive,
                createdAt: now
            )
        )

        let center = MockLocalNotificationCenter(state: .authorized)
        let report = try await NotificationOrchestrator(
            localScheduler: LocalNotificationScheduler(
                notificationCenter: center
            )
        ).orchestrate(
            trigger: .backgroundRefresh,
            repository: repository,
            now: now
        )

        XCTAssertEqual(report.blockedIntentIDs.count, 1)
        XCTAssertTrue(center.requests.isEmpty)
        let stored = try XCTUnwrap(repository.fetchNotificationIntents(status: .blocked, limit: nil).first)
        XCTAssertTrue(stored.blockedReasons.contains(NotificationPolicyBlockReason.sensitiveTopicSuppressed.rawValue))
        let blockEvent = try XCTUnwrap(repository.fetchNotificationManagementEvents(kind: .policyBlocked, limit: nil).first)
        XCTAssertEqual(blockEvent.intentID, stored.id)
        XCTAssertEqual(blockEvent.kind, .dailyQuestion)
    }

    func testDebugIntentWithoutResolvableDeepLinkIsBlockedAndLogged() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try enableNotificationLoop(on: repository, now: now)

        var intent = NotificationIntent(
            kind: .debugTest,
            title: "Mory",
            body: "A broken debug notification.",
            targetType: .record,
            targetID: UUID(),
            scheduledAt: now,
            deliveryChannel: .local,
            deepLink: "mory://unknown",
            createdAt: now
        )
        intent.sourceTrigger = .debugManual

        let report = try await NotificationOrchestrator().orchestrate(
            trigger: .debugManual(intent: intent),
            repository: repository,
            now: now
        )

        XCTAssertEqual(report.blockedIntentIDs.count, 1)
        let stored = try XCTUnwrap(repository.fetchNotificationIntents(status: .blocked, limit: nil).first)
        XCTAssertEqual(stored.blockedReasons, [NotificationPolicyBlockReason.noResolvableRoute.rawValue])
        let routeEvent = try XCTUnwrap(repository.fetchNotificationManagementEvents(kind: .routeError, limit: nil).first)
        XCTAssertEqual(routeEvent.intentID, stored.id)
        XCTAssertEqual(routeEvent.trigger, .debugManual)
    }

    private func makeRepositoryFixture() -> NotificationOrchestratorRepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: NotificationOrchestratorTestRecordAnalysisService()
        )
        return NotificationOrchestratorRepositoryFixture(container: container, repository: repository)
    }

    private func enableNotificationLoop(on repository: MoryMemoryRepository, now: Date) throws {
        var preferences = IntelligencePreferences.defaults
        preferences.dailyQuestionsEnabled = true
        preferences.notificationPreferences = NotificationPreferences(
            enabled: true,
            dailyQuestionEnabled: true,
            maxPerDay: 2,
            quietHoursStartHour: nil,
            quietHoursEndHour: nil,
            richPreviewsEnabled: false
        )
        preferences.sensitiveTopicPolicy = .askBeforeShowing
        preferences.updatedAt = now
        try repository.saveIntelligencePreferences(preferences)

        var flags = V6FeatureFlags.defaults
        flags.dailyQuestions = true
        flags.localNotifications = true
        flags.updatedAt = now
        try repository.saveV6FeatureFlags(flags)
    }

    private func seedMemory(
        in repository: MoryMemoryRepository,
        title: String,
        body: String,
        createdAt: Date,
        artifactKind: ArtifactKind
    ) throws -> (record: RecordShell, artifact: Artifact) {
        let artifact = Artifact(
            recordID: UUID(),
            kind: artifactKind,
            title: title,
            summary: body,
            textContent: body,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let record = RecordShell(
            id: artifact.recordID,
            createdAt: createdAt,
            updatedAt: createdAt,
            captureSource: .composer,
            rawText: body,
            artifactIDs: [artifact.id]
        )
        try repository.upsert(recordShell: record)
        try repository.upsert(artifact: artifact)
        try repository.save()
        return (record, artifact)
    }
}

private struct NotificationOrchestratorRepositoryFixture {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

@MainActor
private final class MockLocalNotificationCenter: LocalNotificationSchedulingCenter {
    var state: LocalNotificationAuthorizationState
    var requestAuthorizationResult: Bool
    var requestAuthorizationCallCount = 0
    var requests: [LocalNotificationScheduleRequest] = []
    var removedIdentifiers: [String] = []

    init(
        state: LocalNotificationAuthorizationState,
        requestAuthorizationResult: Bool = false
    ) {
        self.state = state
        self.requestAuthorizationResult = requestAuthorizationResult
    }

    func authorizationState() async -> LocalNotificationAuthorizationState {
        state
    }

    func requestAuthorization() async throws -> Bool {
        requestAuthorizationCallCount += 1
        if requestAuthorizationResult {
            state = .authorized
        }
        return requestAuthorizationResult
    }

    func add(_ request: LocalNotificationScheduleRequest) async throws {
        requests.append(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) async {
        removedIdentifiers.append(contentsOf: identifiers)
    }
}

private enum NotificationOrchestratorTestError: Error {
    case unsupported
}

private struct NotificationOrchestratorTestRecordAnalysisService: ReflectionAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: record.rawText,
            themes: ["notification"],
            emotionInterpretation: "",
            salienceScore: 0.5,
            retrievalTerms: ["notification"],
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
        throw NotificationOrchestratorTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw NotificationOrchestratorTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}
