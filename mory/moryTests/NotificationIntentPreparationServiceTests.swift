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

    func testPrepareNextIntentUsesBackgroundDoneArtifactTargetWhenPipelineCompletes() throws {
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

        let prepared = try XCTUnwrap(
            NotificationIntentPreparationService(policy: NotificationPolicy(calendar: utcCalendar()))
                .prepareNextIntentIfNeeded(repository: repository, now: now)
        )

        XCTAssertEqual(prepared.kind, .backgroundDone)
        XCTAssertEqual(prepared.targetType, .artifact)
        XCTAssertEqual(prepared.targetID, seededMemory.artifact.id)
        XCTAssertEqual(prepared.privacyLevel, .generic)
        XCTAssertEqual(prepared.body, "Your memories are ready to review.")
    }

    func testPrepareNextIntentCreatesStageFormingIntentForRecentArcCandidate() throws {
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
        let arc = TemporalArc(
            title: "Career reset",
            summary: "A career transition thread is forming.",
            status: .candidate,
            dominantTheme: "career reset",
            dominantEntityName: nil,
            themeLabels: ["career", "change"],
            entityNames: [],
            linkedReflectionID: nil,
            mergedFromArcIDs: [],
            mergedIntoArcID: nil,
            lastMergedAt: nil,
            sourceRecordIDs: [seededMemory.record.id],
            sourceArtifactIDs: [seededMemory.artifact.id],
            sourceEntityIDs: [],
            startDate: seededMemory.record.createdAt,
            endDate: seededMemory.record.updatedAt,
            intensityScore: 0.82,
            clusterStrength: 0.91,
            createdAt: now.addingTimeInterval(-300),
            updatedAt: now.addingTimeInterval(-120)
        )
        try repository.upsert(temporalArc: arc)
        try repository.save()

        let prepared = try XCTUnwrap(
            NotificationIntentPreparationService(policy: NotificationPolicy(calendar: utcCalendar()))
                .prepareNextIntentIfNeeded(repository: repository, now: now)
        )

        XCTAssertEqual(prepared.kind, .stageForming)
        XCTAssertEqual(prepared.targetType, .chapter)
        XCTAssertEqual(prepared.targetID, arc.id)
        XCTAssertEqual(prepared.privacyLevel, .generic)
        XCTAssertEqual(prepared.body, "A memory chapter may be forming.")
    }

    func testPrepareNextIntentFallsBackToRevisitForOlderArtifactMemory() throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try enableNotificationLoop(on: repository, now: now)

        let seededMemory = try seedMemory(
            in: repository,
            title: "Old train ride",
            body: "A quiet train ride I might want to revisit.",
            createdAt: now.addingTimeInterval(-(10 * 24 * 60 * 60)),
            artifactKind: .photo
        )

        let prepared = try XCTUnwrap(
            NotificationIntentPreparationService(policy: NotificationPolicy(calendar: utcCalendar()))
                .prepareNextIntentIfNeeded(repository: repository, now: now)
        )

        XCTAssertEqual(prepared.kind, .revisit)
        XCTAssertEqual(prepared.targetType, .artifact)
        XCTAssertEqual(prepared.targetID, seededMemory.artifact.id)
        XCTAssertEqual(prepared.privacyLevel, .generic)
        XCTAssertEqual(prepared.body, "A meaningful memory is ready to revisit.")
    }

    func testNotificationPolicyBlocksWhenDisabledOrLocalFlagOff() throws {
        let policy = NotificationPolicy(calendar: utcCalendar())
        let intent = makeIntent(scheduledAt: Date(timeIntervalSince1970: 1_800_000_000))
        var preferences = IntelligencePreferences.defaults
        preferences.notificationPreferences.enabled = false
        preferences.notificationPreferences.dailyQuestionEnabled = false
        var flags = V6FeatureFlags.defaults
        flags.localNotifications = false

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

    func testNotificationPolicyBlocksMinimumInterval() throws {
        let calendar = utcCalendar()
        let now = date(year: 2026, month: 5, day: 19, hour: 12, minute: 0, calendar: calendar)
        let policy = NotificationPolicy(calendar: calendar)
        var preferences = enabledPreferences(now: now)
        preferences.notificationPreferences.minimumMinutesBetweenNotifications = 120
        let flags = enabledFlags(now: now)
        let existing = makeIntent(scheduledAt: date(year: 2026, month: 5, day: 19, hour: 10, minute: 45, calendar: calendar))
        let candidate = makeIntent(scheduledAt: now)

        let decision = policy.evaluate(
            intent: candidate,
            existingIntents: [existing],
            preferences: preferences,
            flags: flags
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.blockReasons.contains(.minimumInterval))
    }

    func testNotificationPolicyUsesMinutePreciseQuietHours() throws {
        let calendar = utcCalendar()
        let policy = NotificationPolicy(calendar: calendar)
        let now = date(year: 2026, month: 5, day: 19, hour: 22, minute: 45, calendar: calendar)
        var preferences = enabledPreferences(now: now)
        preferences.notificationPreferences.quietHoursStartHour = 22
        preferences.notificationPreferences.quietHoursStartMinute = 30
        preferences.notificationPreferences.quietHoursEndHour = 7
        preferences.notificationPreferences.quietHoursEndMinute = 15
        let flags = enabledFlags(now: now)
        let candidate = makeIntent(scheduledAt: now)

        let decision = policy.evaluate(
            intent: candidate,
            existingIntents: [],
            preferences: preferences,
            flags: flags
        )

        XCTAssertFalse(decision.isAllowed)
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
        minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
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
