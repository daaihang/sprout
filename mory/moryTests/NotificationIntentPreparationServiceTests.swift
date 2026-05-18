import SwiftData
import XCTest
@testable import mory

@MainActor
final class NotificationIntentPreparationServiceTests: XCTestCase {
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
            scheduledAt: scheduledAt
        )

        try fixture.repository.upsertNotificationIntent(intent)

        let stored = try XCTUnwrap(fixture.repository.fetchNotificationIntents(status: .pending, limit: nil).first)
        XCTAssertEqual(stored.id, intent.id)
        XCTAssertEqual(stored.kind, .dailyQuestion)
        XCTAssertEqual(stored.targetType, .question)
        XCTAssertEqual(stored.targetID, targetID)
        XCTAssertEqual(stored.body, "What should Mory remember today?")
    }

    func testDailyQuestionPreparationCreatesGenericIntentWhenAllowed() throws {
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

        let service = NotificationIntentPreparationService(policy: NotificationPolicy(calendar: utcCalendar()))
        let prepared = try XCTUnwrap(service.prepareDailyQuestionIntentIfNeeded(repository: repository, now: now))

        XCTAssertEqual(prepared.kind, .dailyQuestion)
        XCTAssertEqual(prepared.targetType, .question)
        XCTAssertEqual(prepared.targetID, question.id)
        XCTAssertEqual(prepared.privacyLevel, .generic)
        XCTAssertEqual(prepared.body, "A question is ready for today.")
        XCTAssertEqual(try repository.fetchNotificationIntents(status: .pending, limit: nil).count, 1)
    }

    func testDailyQuestionPreparationDoesNotDuplicateActiveIntent() throws {
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
        try repository.upsertNotificationIntent(
            NotificationIntent(
                kind: .dailyQuestion,
                title: "Mory",
                body: "Existing intent",
                targetType: .question,
                targetID: question.id,
                scheduledAt: now
            )
        )

        let service = NotificationIntentPreparationService(policy: NotificationPolicy(calendar: utcCalendar()))
        let prepared = try service.prepareDailyQuestionIntentIfNeeded(repository: repository, now: now)

        XCTAssertNil(prepared)
        XCTAssertEqual(try repository.fetchNotificationIntents(status: nil, limit: nil).count, 1)
    }

    func testNotificationPolicyBlocksWhenDisabledOrLocalFlagOff() throws {
        let policy = NotificationPolicy(calendar: utcCalendar())
        let intent = makeIntent(scheduledAt: Date(timeIntervalSince1970: 1_800_000_000))
        let preferences = IntelligencePreferences.defaults
        let flags = V6FeatureFlags.defaults

        let decision = policy.evaluate(
            intent: intent,
            existingIntents: [],
            preferences: preferences,
            flags: flags
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.blockReasons.contains(.notificationsDisabled))
        XCTAssertTrue(decision.blockReasons.contains(.localNotificationFlagDisabled))
        XCTAssertTrue(decision.blockReasons.contains(.notificationTypeDisabled))
    }

    func testNotificationPolicyBlocksMaxPerDayAndQuietHours() throws {
        let calendar = utcCalendar()
        let now = date(year: 2026, month: 5, day: 19, hour: 23, calendar: calendar)
        let policy = NotificationPolicy(calendar: calendar)
        var preferences = enabledPreferences(now: now)
        preferences.notificationPreferences.maxPerDay = 1
        preferences.notificationPreferences.quietHoursStartHour = 22
        preferences.notificationPreferences.quietHoursEndHour = 8
        let flags = enabledFlags(now: now)
        let existing = makeIntent(scheduledAt: date(year: 2026, month: 5, day: 19, hour: 10, calendar: calendar))
        let candidate = makeIntent(scheduledAt: now)

        let decision = policy.evaluate(
            intent: candidate,
            existingIntents: [existing],
            preferences: preferences,
            flags: flags
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.blockReasons.contains(.maxPerDayReached))
        XCTAssertTrue(decision.blockReasons.contains(.quietHours))
    }

    func testSensitiveDailyQuestionIsSuppressedBeforeNotificationIntentIsStored() throws {
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

        let service = NotificationIntentPreparationService(policy: NotificationPolicy(calendar: utcCalendar()))
        let prepared = try service.prepareDailyQuestionIntentIfNeeded(repository: repository, now: now)

        XCTAssertNil(prepared)
        XCTAssertTrue(try repository.fetchNotificationIntents(status: nil, limit: nil).isEmpty)
    }

    private func makeRepositoryFixture() -> NotificationIntentRepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: NotificationIntentTestRecordAnalysisService()
        )
        return NotificationIntentRepositoryFixture(container: container, repository: repository)
    }

    private func enableNotificationLoop(on repository: MoryMemoryRepository, now: Date) throws {
        try repository.saveIntelligencePreferences(enabledPreferences(now: now))
        try repository.saveV6FeatureFlags(enabledFlags(now: now))
    }

    private func enabledPreferences(now: Date) -> IntelligencePreferences {
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
        return preferences
    }

    private func enabledFlags(now: Date) -> V6FeatureFlags {
        var flags = V6FeatureFlags.defaults
        flags.dailyQuestions = true
        flags.localNotifications = true
        flags.updatedAt = now
        return flags
    }

    private func makeIntent(scheduledAt: Date) -> NotificationIntent {
        NotificationIntent(
            kind: .dailyQuestion,
            title: "Mory",
            body: "What should Mory remember today?",
            privacyLevel: .contextual,
            targetType: .question,
            targetID: UUID(),
            scheduledAt: scheduledAt
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date!
    }
}

private struct NotificationIntentRepositoryFixture {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

private enum NotificationIntentTestError: Error {
    case unsupported
}

private struct NotificationIntentTestRecordAnalysisService: RecordAnalysisServing {
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
        throw NotificationIntentTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw NotificationIntentTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}
