import SwiftData
import XCTest
@testable import mory

@MainActor
final class LocalNotificationSchedulerTests: XCTestCase {
    func testSchedulesPendingIntentAndMarksItScheduled() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try enableNotifications(on: repository, now: now)
        let intent = try insertPendingDailyQuestionIntent(on: repository, scheduledAt: now)
        let center = MockLocalNotificationCenter(state: .authorized)
        let scheduler = LocalNotificationScheduler(notificationCenter: center)

        let report = try await scheduler.schedulePendingIntents(repository: repository, now: now)

        XCTAssertEqual(report.scheduledCount, 1)
        XCTAssertEqual(report.skippedCount, 0)
        XCTAssertEqual(center.requests.count, 1)
        XCTAssertEqual(center.requests.first?.identifier, "mory.notification.\(intent.id.uuidString)")
        XCTAssertEqual(center.requests.first?.userInfo["mory_notification_target_type"], ClarificationTargetType.question.rawValue)
        let stored = try XCTUnwrap(repository.fetchNotificationIntents(status: nil, limit: nil).first { $0.id == intent.id })
        XCTAssertEqual(stored.status, .scheduled)
    }

    func testDoesNotRequestAuthorizationByDefault() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try enableNotifications(on: repository, now: now)
        let intent = try insertPendingDailyQuestionIntent(on: repository, scheduledAt: now)
        let center = MockLocalNotificationCenter(state: .notDetermined)
        let scheduler = LocalNotificationScheduler(notificationCenter: center)

        let report = try await scheduler.schedulePendingIntents(
            repository: repository,
            now: now,
            requestAuthorizationIfNeeded: false
        )

        XCTAssertEqual(report.scheduledCount, 0)
        XCTAssertEqual(report.results.first?.intentID, intent.id)
        XCTAssertEqual(report.results.first?.skipReason, .authorizationRequired)
        XCTAssertEqual(center.requestAuthorizationCallCount, 0)
        XCTAssertTrue(center.requests.isEmpty)
        let stored = try XCTUnwrap(repository.fetchNotificationIntents(status: nil, limit: nil).first { $0.id == intent.id })
        XCTAssertEqual(stored.status, .pending)
    }

    func testCanRequestAuthorizationAndScheduleWhenGranted() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try enableNotifications(on: repository, now: now)
        _ = try insertPendingDailyQuestionIntent(on: repository, scheduledAt: now)
        let center = MockLocalNotificationCenter(state: .notDetermined, requestAuthorizationResult: true)
        let scheduler = LocalNotificationScheduler(notificationCenter: center)

        let report = try await scheduler.schedulePendingIntents(
            repository: repository,
            now: now,
            requestAuthorizationIfNeeded: true
        )

        XCTAssertEqual(center.requestAuthorizationCallCount, 1)
        XCTAssertEqual(report.scheduledCount, 1)
        XCTAssertEqual(center.requests.count, 1)
    }

    func testAuthorizationRequestDeniedIsReportedSeparately() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try enableNotifications(on: repository, now: now)
        _ = try insertPendingDailyQuestionIntent(on: repository, scheduledAt: now)
        let center = MockLocalNotificationCenter(state: .notDetermined, requestAuthorizationResult: false)
        let scheduler = LocalNotificationScheduler(notificationCenter: center)

        let report = try await scheduler.schedulePendingIntents(
            repository: repository,
            now: now,
            requestAuthorizationIfNeeded: true
        )

        XCTAssertEqual(center.requestAuthorizationCallCount, 1)
        XCTAssertEqual(report.scheduledCount, 0)
        XCTAssertEqual(report.results.first?.skipReason, .authorizationRequestDenied)
        XCTAssertTrue(center.requests.isEmpty)
    }

    func testDeniedAuthorizationSkipsPendingIntent() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try enableNotifications(on: repository, now: now)
        _ = try insertPendingDailyQuestionIntent(on: repository, scheduledAt: now)
        let center = MockLocalNotificationCenter(state: .denied)
        let scheduler = LocalNotificationScheduler(notificationCenter: center)

        let report = try await scheduler.schedulePendingIntents(repository: repository, now: now)

        XCTAssertEqual(report.scheduledCount, 0)
        XCTAssertEqual(report.results.first?.skipReason, .authorizationDenied)
        XCTAssertTrue(center.requests.isEmpty)
    }

    func testRemoteChannelIntentIsSkippedByDeliveryScheduler() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try insertPendingDailyQuestionIntent(
            on: repository,
            scheduledAt: now,
            deliveryChannel: .remote
        )
        let center = MockLocalNotificationCenter(state: .authorized)
        let scheduler = LocalNotificationScheduler(notificationCenter: center)

        let report = try await scheduler.schedulePendingIntents(repository: repository, now: now)

        XCTAssertEqual(report.scheduledCount, 0)
        XCTAssertEqual(report.results.first?.skipReason, .unsupportedChannel)
        XCTAssertTrue(center.requests.isEmpty)
    }

    private func makeRepositoryFixture() -> LocalNotificationRepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: LocalNotificationTestRecordAnalysisService()
        )
        return LocalNotificationRepositoryFixture(container: container, repository: repository)
    }

    private func enableNotifications(on repository: MoryMemoryRepository, now: Date) throws {
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
        preferences.updatedAt = now
        try repository.saveIntelligencePreferences(preferences)

        var flags = V6FeatureFlags.defaults
        flags.dailyQuestions = true
        flags.localNotifications = true
        flags.updatedAt = now
        try repository.saveV6FeatureFlags(flags)
    }

    private func insertPendingDailyQuestionIntent(
        on repository: MoryMemoryRepository,
        scheduledAt: Date,
        deliveryChannel: NotificationDeliveryChannel = .local
    ) throws -> NotificationIntent {
        let intent = NotificationIntent(
            kind: .dailyQuestion,
            title: "Mory",
            body: "A question is ready for today.",
            privacyLevel: .generic,
            targetType: .question,
            targetID: UUID(),
            scheduledAt: scheduledAt,
            status: .pending,
            deliveryChannel: deliveryChannel,
            createdAt: scheduledAt
        )
        try repository.upsertNotificationIntent(intent)
        return intent
    }
}

private struct LocalNotificationRepositoryFixture {
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

private enum LocalNotificationTestError: Error {
    case unsupported
}

private struct LocalNotificationTestRecordAnalysisService: RecordAnalysisServing {
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
        throw LocalNotificationTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw LocalNotificationTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}
