import XCTest
@testable import mory

final class DebugCenterModelsTests: XCTestCase {
    func testV6GateDiagnosticsExposeBlockedReasons() {
        var preferences = IntelligencePreferences.defaults
        preferences.semanticSearchEnabled = false
        preferences.voiceRefinementEnabled = false
        preferences.dailyQuestionsEnabled = false
        preferences.notificationPreferences.enabled = false

        var flags = V6FeatureFlags.defaults
        flags.semanticSearch = false
        flags.intelligenceJobs = false
        flags.localNotifications = false

        let diagnostics = V6DebugControls.gateDiagnostics(preferences: preferences, flags: flags)

        let semantic = diagnostics.first { $0.id == "semantic_search" }
        XCTAssertEqual(semantic?.isEnabled, false)
        XCTAssertEqual(semantic?.blockedReasons, ["semanticSearchEnabled=false", "v6.semanticSearch=false"])

        let voice = diagnostics.first { $0.id == "voice_refinement" }
        XCTAssertEqual(voice?.isEnabled, false)
        XCTAssertEqual(voice?.blockedReasons, ["voiceRefinementEnabled=false"])

        let job = diagnostics.first { $0.id == "job_worker" }
        XCTAssertEqual(job?.isEnabled, false)
        XCTAssertEqual(job?.blockedReasons, ["v6.intelligenceJobs=false"])

        let notifications = diagnostics.first { $0.id == "notifications" }
        XCTAssertEqual(notifications?.isEnabled, false)
        XCTAssertEqual(notifications?.blockedReasons, ["notificationPreferences.enabled=false", "v6.localNotifications=false"])
    }

    func testV6BulkControlsEnableFlagsAndCloudFirstPreferences() {
        let now = Date(timeIntervalSince1970: 1_800_000_123)
        var flags = V6FeatureFlags.defaults
        flags.intelligenceJobs = false
        flags.entityProfiles = false
        flags.clarificationQuestions = false
        flags.homeGrid = false
        flags.semanticSearch = false
        flags.dailyQuestions = false
        flags.localNotifications = false
        flags.cloudQuestionSuggestions = false
        flags.cloudChapterSuggestions = false
        flags.multimediaViews = false

        let enabledFlags = V6DebugControls.allFlagsEnabled(from: flags, now: now)
        XCTAssertTrue(enabledFlags.intelligenceJobs)
        XCTAssertTrue(enabledFlags.entityProfiles)
        XCTAssertTrue(enabledFlags.clarificationQuestions)
        XCTAssertTrue(enabledFlags.homeGrid)
        XCTAssertTrue(enabledFlags.semanticSearch)
        XCTAssertTrue(enabledFlags.dailyQuestions)
        XCTAssertTrue(enabledFlags.localNotifications)
        XCTAssertTrue(enabledFlags.cloudQuestionSuggestions)
        XCTAssertTrue(enabledFlags.cloudChapterSuggestions)
        XCTAssertTrue(enabledFlags.multimediaViews)
        XCTAssertEqual(enabledFlags.updatedAt, now)

        var preferences = IntelligencePreferences.defaults
        preferences.localIntelligenceEnabled = false
        preferences.cloudIntelligenceEnabled = false
        preferences.voiceRefinementEnabled = false
        preferences.semanticSearchEnabled = false
        preferences.homeSuggestionsEnabled = false
        preferences.dailyQuestionsEnabled = false
        preferences.notificationPreferences.enabled = false
        preferences.questionTone = .journalPrompt

        let enabledPreferences = V6DebugControls.cloudFirstStrongestPolicy(from: preferences, now: now)
        XCTAssertTrue(enabledPreferences.localIntelligenceEnabled)
        XCTAssertTrue(enabledPreferences.cloudIntelligenceEnabled)
        XCTAssertTrue(enabledPreferences.voiceRefinementEnabled)
        XCTAssertTrue(enabledPreferences.semanticSearchEnabled)
        XCTAssertTrue(enabledPreferences.homeSuggestionsEnabled)
        XCTAssertTrue(enabledPreferences.dailyQuestionsEnabled)
        XCTAssertFalse(enabledPreferences.notificationPreferences.enabled)
        XCTAssertEqual(enabledPreferences.questionTone, .journalPrompt)
        XCTAssertEqual(enabledPreferences.updatedAt, now)
    }

    func testEnableSemanticSearchUpdatesPreferenceAndFeatureFlagOnly() {
        let now = Date(timeIntervalSince1970: 1_800_000_456)
        var preferences = IntelligencePreferences.defaults
        preferences.semanticSearchEnabled = false
        preferences.cloudIntelligenceEnabled = false
        var flags = V6FeatureFlags.defaults
        flags.semanticSearch = false
        flags.dailyQuestions = false

        let updated = V6DebugControls.semanticSearchEnabled(
            preferences: preferences,
            flags: flags,
            now: now
        )

        XCTAssertTrue(updated.preferences.semanticSearchEnabled)
        XCTAssertFalse(updated.preferences.cloudIntelligenceEnabled)
        XCTAssertEqual(updated.preferences.updatedAt, now)
        XCTAssertTrue(updated.flags.semanticSearch)
        XCTAssertFalse(updated.flags.dailyQuestions)
        XCTAssertEqual(updated.flags.updatedAt, now)
    }

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
