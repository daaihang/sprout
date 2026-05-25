import SwiftData
import XCTest
@testable import mory

@MainActor
final class NotificationSettingsServiceTests: XCTestCase {
    func testEnablingNotificationsStoresPreferenceRequestsAuthorizationAndEnablesDailyQuestionDefaults() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        try enableNotificationRolloutFlags(on: repository)
        let center = NotificationSettingsMockCenter(state: .notDetermined, requestAuthorizationResult: true)
        let service = NotificationSettingsService(notificationCenter: center)

        let result = try await service.setNotificationsEnabled(
            true,
            repository: repository,
            notificationOrchestrator: .localDelivery,
            requestSystemAuthorization: true
        )

        let stored = try repository.fetchIntelligencePreferences()
        XCTAssertTrue(stored.notificationPreferences.enabled)
        XCTAssertTrue(stored.dailyQuestionsEnabled)
        XCTAssertTrue(stored.notificationPreferences.dailyQuestionEnabled)
        XCTAssertEqual(center.requestAuthorizationCallCount, 1)
        XCTAssertTrue(result.systemAuthorizationRequested)
        XCTAssertTrue(result.systemAuthorizationGranted)
        XCTAssertEqual(result.snapshot.authorizationState, LocalNotificationAuthorizationState.authorized)
        XCTAssertTrue(result.notificationReport.generatedIntentIDs.isEmpty)
    }

    func testUpdatingNotificationPreferencesDoesNotRequestSystemAuthorizationByDefault() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let center = NotificationSettingsMockCenter(state: .notDetermined)
        let service = NotificationSettingsService(notificationCenter: center)

        _ = try await service.updatePreferences(
            repository: repository,
            notificationOrchestrator: .localDelivery
        ) { preferences in
            preferences.notificationPreferences.dailyQuestionEnabled = false
            preferences.notificationPreferences.maxPerDay = 4
        }

        let stored = try repository.fetchIntelligencePreferences()
        XCTAssertFalse(stored.notificationPreferences.dailyQuestionEnabled)
        XCTAssertEqual(stored.notificationPreferences.maxPerDay, 4)
        XCTAssertEqual(center.requestAuthorizationCallCount, 0)
    }

    func testDisablingNotificationsCancelsPendingAndScheduledLocalIntents() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_100_000)
        try enableNotificationPreferences(on: repository, now: now)
        let pendingIntent = try insertIntent(on: repository, status: .pending, now: now)
        let scheduledIntent = try insertIntent(on: repository, status: .scheduled, now: now)
        let center = NotificationSettingsMockCenter(state: .authorized)
        let service = NotificationSettingsService(notificationCenter: center)

        let result = try await service.setNotificationsEnabled(
            false,
            repository: repository,
            notificationOrchestrator: .localDelivery,
            requestSystemAuthorization: false,
            now: now
        )

        XCTAssertFalse(result.snapshot.preferences.notificationPreferences.enabled)
        XCTAssertEqual(result.cancellationReport.cancelledCount, 2)
        XCTAssertEqual(
            Set(center.removedIdentifiers),
            [
                "mory.notification.\(pendingIntent.id.uuidString)",
                "mory.notification.\(scheduledIntent.id.uuidString)",
            ]
        )

        let storedIntents = try repository.fetchNotificationIntents(status: nil, limit: nil)
        XCTAssertEqual(storedIntents.first { $0.id == pendingIntent.id }?.status, .dismissed)
        XCTAssertEqual(storedIntents.first { $0.id == scheduledIntent.id }?.status, .dismissed)
        XCTAssertEqual(storedIntents.first { $0.id == scheduledIntent.id }?.dismissedAt, now)
        XCTAssertTrue(result.notificationReport.generatedIntentIDs.isEmpty)
    }

    func testLoadSnapshotReportsFeatureFlagsAndAuthorizationState() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        try enableNotificationRolloutFlags(on: repository)
        let center = NotificationSettingsMockCenter(state: .provisional)
        let service = NotificationSettingsService(notificationCenter: center)

        let snapshot = try await service.loadSnapshot(repository: repository)

        XCTAssertTrue(snapshot.featureFlags.localNotifications)
        XCTAssertTrue(snapshot.featureFlags.dailyQuestions)
        XCTAssertEqual(snapshot.authorizationState, .provisional)
        XCTAssertTrue(snapshot.systemNotificationsAllowed)
    }

    private func makeRepositoryFixture() -> NotificationSettingsRepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: NotificationSettingsTestRecordAnalysisService()
        )
        return NotificationSettingsRepositoryFixture(container: container, repository: repository)
    }

    private func enableNotificationRolloutFlags(on repository: MoryMemoryRepository) throws {
        var flags = V6FeatureFlags.defaults
        flags.localNotifications = true
        flags.dailyQuestions = true
        try repository.saveV6FeatureFlags(flags)
    }

    private func enableNotificationPreferences(
        on repository: MoryMemoryRepository,
        now: Date
    ) throws {
        try enableNotificationRolloutFlags(on: repository)
        var preferences = IntelligencePreferences.defaults
        preferences.dailyQuestionsEnabled = true
        preferences.notificationPreferences = NotificationPreferences(
            enabled: true,
            dailyQuestionEnabled: true,
            maxPerDay: 3,
            quietHoursStartHour: nil,
            quietHoursEndHour: nil
        )
        preferences.updatedAt = now
        try repository.saveIntelligencePreferences(preferences)
    }

    private func insertIntent(
        on repository: MoryMemoryRepository,
        status: NotificationIntentStatus,
        now: Date
    ) throws -> NotificationIntent {
        let intent = NotificationIntent(
            kind: .dailyQuestion,
            title: "Mory",
            body: "A question is ready.",
            targetType: .question,
            targetID: UUID(),
            scheduledAt: now.addingTimeInterval(600),
            status: status,
            deliveryChannel: .local,
            createdAt: now
        )
        try repository.upsertNotificationIntent(intent)
        return intent
    }
}

private struct NotificationSettingsRepositoryFixture {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

@MainActor
private final class NotificationSettingsMockCenter: LocalNotificationSchedulingCenter {
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

private enum NotificationSettingsTestError: Error {
    case unsupported
}

private struct NotificationSettingsTestRecordAnalysisService: ReflectionAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: record.rawText,
            themes: ["notification-settings"],
            emotionInterpretation: "",
            salienceScore: 0.5,
            retrievalTerms: ["notification-settings"],
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
        throw NotificationSettingsTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw NotificationSettingsTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}
