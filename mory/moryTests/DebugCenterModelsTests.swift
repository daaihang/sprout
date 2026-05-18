import XCTest
@testable import mory

final class DebugCenterModelsTests: XCTestCase {
    func testJobQueueSnapshotCountsJobsIntentsAndGraphDeltas() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let pendingDue = IntelligenceJob(
            kind: .dailyQuestion,
            targetType: .board,
            targetID: UUID(),
            status: .pending,
            scheduledAt: now.addingTimeInterval(-60),
            requiresCloudAI: true
        )
        let pendingFuture = IntelligenceJob(
            kind: .semanticIndex,
            targetType: .searchIndex,
            targetID: UUID(),
            status: .pending,
            scheduledAt: now.addingTimeInterval(60),
            requiresCloudAI: false
        )
        let running = IntelligenceJob(
            kind: .notificationIntent,
            targetType: .notification,
            targetID: UUID(),
            status: .running,
            scheduledAt: now,
            requiresCloudAI: false
        )
        let failed = IntelligenceJob(
            kind: .chapterCandidate,
            targetType: .board,
            targetID: UUID(),
            status: .failed,
            scheduledAt: now,
            requiresCloudAI: true
        )
        let pendingIntent = NotificationIntent(
            kind: .debugTest,
            title: "Debug",
            body: "Test",
            targetType: .question,
            targetID: UUID(),
            scheduledAt: now,
            status: .pending
        )
        let deliveredIntent = NotificationIntent(
            kind: .dailyQuestion,
            title: "Question",
            body: "Body",
            targetType: .question,
            targetID: UUID(),
            scheduledAt: now,
            status: .delivered
        )
        let unappliedDelta = GraphDelta(
            source: .cloudAI,
            operations: [],
            appliedAt: nil,
            createdAt: now
        )
        let appliedDelta = GraphDelta(
            source: .localRule,
            operations: [],
            appliedAt: now,
            createdAt: now
        )

        let snapshot = DebugJobQueueSnapshot(
            generatedAt: now,
            jobs: [pendingDue, pendingFuture, running, failed],
            notificationIntents: [pendingIntent, deliveredIntent],
            graphDeltas: [unappliedDelta, appliedDelta]
        )

        XCTAssertEqual(snapshot.totalJobCount, 4)
        XCTAssertEqual(snapshot.pendingJobCount, 2)
        XCTAssertEqual(snapshot.runningJobCount, 1)
        XCTAssertEqual(snapshot.failedJobCount, 1)
        XCTAssertEqual(snapshot.duePendingJobCount, 1)
        XCTAssertEqual(snapshot.cloudRequiredJobCount, 2)
        XCTAssertEqual(snapshot.unappliedGraphDeltaCount, 1)
        XCTAssertEqual(snapshot.jobStatusCounts.first { $0.label == IntelligenceJobStatus.pending.rawValue }?.count, 2)
        XCTAssertEqual(snapshot.notificationStatusCounts.first { $0.label == NotificationIntentStatus.delivered.rawValue }?.count, 1)
        XCTAssertEqual(snapshot.graphDeltaCounts.first { $0.label == "applied" }?.count, 1)
    }

    func testCloudRunSummarySeparatesSuccessAndError() {
        let success = DebugCloudRunSummary(
            operation: "transcript_refine",
            requestID: "request-1",
            provider: "mock",
            model: "debug-model",
            promptVersion: "prompt-v1",
            inputTokens: 10,
            outputTokens: 20,
            result: "ok",
            error: nil
        )
        XCTAssertTrue(success.succeeded)
        XCTAssertEqual(success.headline, "transcript_refine completed")
        XCTAssertTrue(success.metaLines.contains("request_id: request-1"))
        XCTAssertTrue(success.metaLines.contains("prompt_version: prompt-v1"))
        XCTAssertTrue(success.metaLines.contains("input_tokens: 10"))

        let failure = DebugCloudRunSummary(
            operation: "chapter_suggest",
            requestID: nil,
            provider: nil,
            model: nil,
            promptVersion: nil,
            inputTokens: nil,
            outputTokens: nil,
            result: "",
            error: "network offline"
        )
        XCTAssertFalse(failure.succeeded)
        XCTAssertEqual(failure.headline, "chapter_suggest failed: network offline")
        XCTAssertTrue(failure.metaLines.isEmpty)
    }

    func testSemanticAndSpotlightFormatting() {
        XCTAssertEqual(
            DebugCenterFormatting.semanticStatusText(.succeeded(resultCount: 3)),
            "Core Spotlight returned 3 hit(s)"
        )
        XCTAssertEqual(
            DebugCenterFormatting.searchSourceText([.spotlight, .exactFallback]),
            "spotlight + exactFallback"
        )
        XCTAssertEqual(
            DebugCenterFormatting.spotlightReportText(.skipped("disabled")),
            "skipped: disabled"
        )
        XCTAssertEqual(
            DebugCenterFormatting.spotlightReportText(SpotlightIndexReport(indexedItemCount: 2, deletedItemCount: 1, skippedReason: nil)),
            "indexed=2, deleted=1"
        )
    }
}
