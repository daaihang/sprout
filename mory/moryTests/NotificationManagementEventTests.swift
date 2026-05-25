import SwiftData
import XCTest
@testable import mory

@MainActor
final class NotificationManagementEventTests: XCTestCase {
    func testFetchNotificationManagementEventsAppliesKindLimitAndReverseTimeOrder() throws {
        let fixture = makeRepositoryFixture()
        let first = makeEvent(kind: .generated, createdAt: Date(timeIntervalSince1970: 10))
        let second = makeEvent(kind: .deduped, createdAt: Date(timeIntervalSince1970: 20))
        let third = makeEvent(kind: .deduped, createdAt: Date(timeIntervalSince1970: 30))

        try fixture.repository.upsertNotificationManagementEvent(first)
        try fixture.repository.upsertNotificationManagementEvent(second)
        try fixture.repository.upsertNotificationManagementEvent(third)

        let all = try fixture.repository.fetchNotificationManagementEvents(kind: nil, limit: nil)
        XCTAssertEqual(all.map(\.id), [third.id, second.id, first.id])

        let dedupeLimited = try fixture.repository.fetchNotificationManagementEvents(kind: .deduped, limit: 1)
        XCTAssertEqual(dedupeLimited.map(\.id), [third.id])
    }

    func testNotificationManagementSnapshotBucketsQueueHistoryDedupeAndErrors() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let pending = makeIntent(status: .pending, scheduledAt: now.addingTimeInterval(10))
        let scheduled = makeIntent(status: .scheduled, scheduledAt: now.addingTimeInterval(20))
        let blocked = makeIntent(status: .blocked, scheduledAt: now.addingTimeInterval(30))
        let delivered = makeIntent(status: .delivered, scheduledAt: now.addingTimeInterval(40))
        let events = [
            makeEvent(kind: .opened, createdAt: now.addingTimeInterval(4)),
            makeEvent(kind: .deduped, createdAt: now.addingTimeInterval(3)),
            makeEvent(kind: .policyBlocked, createdAt: now.addingTimeInterval(2)),
            makeEvent(kind: .generated, createdAt: now.addingTimeInterval(1)),
        ]

        let snapshot = NotificationManagementSnapshot.build(
            intents: [delivered, blocked, scheduled, pending],
            events: events
        )

        XCTAssertEqual(snapshot.queueIntents.map(\.status), [.pending, .scheduled, .blocked])
        XCTAssertEqual(snapshot.historyEvents.map(\.eventKind), [.opened])
        XCTAssertEqual(snapshot.dedupeEvents.map(\.eventKind), [.deduped])
        XCTAssertEqual(snapshot.errorEvents.map(\.eventKind), [.policyBlocked])
    }

    private func makeRepositoryFixture() -> NotificationManagementRepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: NotificationManagementTestRecordAnalysisService()
        )
        return NotificationManagementRepositoryFixture(container: container, repository: repository)
    }

    private func makeEvent(
        kind: NotificationManagementEventKind,
        createdAt: Date
    ) -> NotificationManagementEvent {
        let targetID = UUID()
        return NotificationManagementEvent(
            eventKind: kind,
            intentID: UUID(),
            dedupeKey: "debugTest|record|\(targetID.uuidString)",
            trigger: .debugManual,
            kind: .debugTest,
            targetType: .record,
            targetID: targetID,
            message: "\(kind.rawValue) event",
            createdAt: createdAt
        )
    }

    private func makeIntent(
        status: NotificationIntentStatus,
        scheduledAt: Date
    ) -> NotificationIntent {
        NotificationIntent(
            kind: .debugTest,
            title: "Mory",
            body: "Debug notification",
            targetType: .record,
            targetID: UUID(),
            scheduledAt: scheduledAt,
            status: status,
            deliveryChannel: .local,
            deepLink: "mory://home",
            reason: "Snapshot test",
            sourceTrigger: .debugManual,
            createdBy: .debug,
            createdAt: scheduledAt
        )
    }
}

private struct NotificationManagementRepositoryFixture {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

private enum NotificationManagementTestError: Error {
    case unsupported
}

private struct NotificationManagementTestRecordAnalysisService: RecordAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: record.rawText,
            themes: ["notification-management"],
            emotionInterpretation: "",
            salienceScore: 0.5,
            retrievalTerms: ["notification-management"],
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
        throw NotificationManagementTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw NotificationManagementTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}
