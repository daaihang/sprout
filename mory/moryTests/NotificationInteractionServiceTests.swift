import SwiftData
import XCTest
@testable import mory

@MainActor
final class NotificationInteractionServiceTests: XCTestCase {
    func testPayloadParsesLocalNotificationMetadata() throws {
        let intent = makeIntent(kind: .dailyQuestion, targetType: .question)
        let payload = try XCTUnwrap(LocalNotificationPayload(userInfo: anyUserInfo(for: intent)))

        XCTAssertEqual(payload.intentID, intent.id)
        XCTAssertEqual(payload.kind, .dailyQuestion)
        XCTAssertEqual(payload.targetType, .question)
        XCTAssertEqual(payload.targetID, intent.targetID)
    }

    func testDeliveredInteractionMarksScheduledIntentDelivered() throws {
        let fixture = makeRepositoryFixture()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let intent = makeIntent(kind: .dailyQuestion, targetType: .question, status: .scheduled)
        try fixture.repository.upsertNotificationIntent(intent)
        let service = NotificationInteractionService()
        let event = try XCTUnwrap(NotificationInteractionEvent(
            action: .delivered,
            userInfo: anyUserInfo(for: intent),
            receivedAt: now
        ))

        let result = try service.handle(event: event, repository: fixture.repository, now: now)

        XCTAssertNil(result.route)
        let stored = try XCTUnwrap(fixture.repository.fetchNotificationIntents(status: nil, limit: nil).first)
        XCTAssertEqual(stored.status, .delivered)
        XCTAssertEqual(stored.deliveredAt, now)
        XCTAssertNil(stored.dismissedAt)
    }

    func testOpenedInteractionReturnsRouteAndMarksIntentDelivered() throws {
        let fixture = makeRepositoryFixture()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let intent = makeIntent(kind: .revisit, targetType: .record, status: .scheduled)
        try fixture.repository.upsertNotificationIntent(intent)
        let service = NotificationInteractionService()
        let event = try XCTUnwrap(NotificationInteractionEvent(
            action: .opened,
            userInfo: anyUserInfo(for: intent),
            receivedAt: now
        ))

        let result = try service.handle(event: event, repository: fixture.repository, now: now)

        XCTAssertEqual(result.route?.destination, .memories)
        XCTAssertEqual(result.route?.targetID, intent.targetID)
        XCTAssertEqual(result.route?.deepLink, .memories(.memory(intent.targetID)))
        let stored = try XCTUnwrap(fixture.repository.fetchNotificationIntents(status: nil, limit: nil).first)
        XCTAssertEqual(stored.status, .delivered)
        XCTAssertEqual(stored.deliveredAt, now)
    }

    func testDismissedInteractionMarksIntentDismissed() throws {
        let fixture = makeRepositoryFixture()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let intent = makeIntent(kind: .dailyQuestion, targetType: .question, status: .scheduled)
        try fixture.repository.upsertNotificationIntent(intent)
        let service = NotificationInteractionService()
        let event = try XCTUnwrap(NotificationInteractionEvent(
            action: .dismissed,
            userInfo: anyUserInfo(for: intent),
            receivedAt: now
        ))

        let result = try service.handle(event: event, repository: fixture.repository, now: now)

        XCTAssertNil(result.route)
        let stored = try XCTUnwrap(fixture.repository.fetchNotificationIntents(status: nil, limit: nil).first)
        XCTAssertEqual(stored.status, .dismissed)
        XCTAssertEqual(stored.deliveredAt, now)
        XCTAssertEqual(stored.dismissedAt, now)
    }

    func testOpenedInteractionCanRouteEvenWhenIntentIsMissing() throws {
        let fixture = makeRepositoryFixture()
        let intent = makeIntent(kind: .repeatedTheme, targetType: .theme, status: .scheduled)
        let service = NotificationInteractionService()
        let event = try XCTUnwrap(NotificationInteractionEvent(
            action: .opened,
            userInfo: anyUserInfo(for: intent)
        ))

        let result = try service.handle(event: event, repository: fixture.repository)

        XCTAssertEqual(result.route?.destination, .insights)
        XCTAssertNil(result.updatedIntent)
        XCTAssertTrue(try fixture.repository.fetchNotificationIntents(status: nil, limit: nil).isEmpty)
    }

    func testOpenedDailyQuestionDeepLinksToQuestionCard() throws {
        let fixture = makeRepositoryFixture()
        let intent = makeIntent(kind: .dailyQuestion, targetType: .question, status: .scheduled)
        try fixture.repository.upsertNotificationIntent(intent)
        let service = NotificationInteractionService()
        let event = try XCTUnwrap(NotificationInteractionEvent(
            action: .opened,
            userInfo: anyUserInfo(for: intent)
        ))

        let result = try service.handle(event: event, repository: fixture.repository)

        XCTAssertEqual(result.route?.destination, .home)
        XCTAssertEqual(result.route?.deepLink, .home(.question(intent.targetID)))
    }

    func testOpenedStageFormingChapterDeepLinksToArcCandidate() throws {
        let fixture = makeRepositoryFixture()
        let intent = makeIntent(kind: .stageForming, targetType: .chapter, status: .scheduled)
        try fixture.repository.upsertNotificationIntent(intent)
        let service = NotificationInteractionService()
        let event = try XCTUnwrap(NotificationInteractionEvent(
            action: .opened,
            userInfo: anyUserInfo(for: intent)
        ))

        let result = try service.handle(event: event, repository: fixture.repository)

        XCTAssertEqual(result.route?.destination, .insights)
        XCTAssertEqual(result.route?.deepLink, .insights(.arc(intent.targetID)))
    }

    private func makeRepositoryFixture() -> NotificationInteractionRepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: NotificationInteractionTestRecordAnalysisService()
        )
        return NotificationInteractionRepositoryFixture(container: container, repository: repository)
    }

    private func makeIntent(
        kind: NotificationIntentKind,
        targetType: ClarificationTargetType,
        status: NotificationIntentStatus = .pending
    ) -> NotificationIntent {
        NotificationIntent(
            kind: kind,
            title: "Mory",
            body: "A memory prompt is ready.",
            targetType: targetType,
            targetID: UUID(),
            scheduledAt: Date(timeIntervalSince1970: 1_800_000_000),
            status: status,
            deliveryChannel: .local,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private func anyUserInfo(for intent: NotificationIntent) -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [:]
        for (key, value) in LocalNotificationMetadata.userInfo(for: intent) {
            userInfo[key] = value
        }
        return userInfo
    }
}

private struct NotificationInteractionRepositoryFixture {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

private enum NotificationInteractionTestError: Error {
    case unsupported
}

private struct NotificationInteractionTestRecordAnalysisService: RecordAnalysisServing {
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
        throw NotificationInteractionTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw NotificationInteractionTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}
