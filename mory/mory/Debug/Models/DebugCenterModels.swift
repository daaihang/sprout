import Foundation

struct DebugStatusCount: Identifiable, Hashable, Sendable {
    var id: String { label }
    let label: String
    let count: Int
}

struct DebugJobQueueSnapshot: Hashable, Sendable {
    let generatedAt: Date
    let jobs: [IntelligenceJob]
    let graphDeltas: [GraphDelta]

    var totalJobCount: Int { jobs.count }
    var pendingJobCount: Int { countJobs(status: .pending) }
    var runningJobCount: Int { countJobs(status: .running) }
    var failedJobCount: Int { countJobs(status: .failed) }
    var duePendingJobCount: Int { jobs.filter { $0.status == .pending && $0.scheduledAt <= generatedAt }.count }
    var cloudRequiredJobCount: Int { jobs.filter(\.requiresCloudAI).count }
    var unappliedGraphDeltaCount: Int { graphDeltas.filter { $0.appliedAt == nil }.count }

    var jobStatusCounts: [DebugStatusCount] {
        IntelligenceJobStatus.allCases.map { status in
            DebugStatusCount(label: status.rawValue, count: countJobs(status: status))
        }
    }

    var jobKindCounts: [DebugStatusCount] {
        IntelligenceJobKind.allCases.map { kind in
            DebugStatusCount(label: kind.rawValue, count: jobs.filter { $0.kind == kind }.count)
        }
    }

    var graphDeltaCounts: [DebugStatusCount] {
        [
            DebugStatusCount(label: "unapplied", count: graphDeltas.filter { $0.appliedAt == nil }.count),
            DebugStatusCount(label: "applied", count: graphDeltas.filter { $0.appliedAt != nil }.count),
        ]
    }

    private func countJobs(status: IntelligenceJobStatus) -> Int {
        jobs.filter { $0.status == status }.count
    }
}

struct DebugCloudRunSummary: Hashable, Sendable {
    let operation: String
    let requestID: String?
    let provider: String?
    let model: String?
    let promptVersion: String?
    let inputTokens: Int?
    let outputTokens: Int?
    let result: String
    let error: String?

    var succeeded: Bool { error == nil }

    var headline: String {
        if let error {
            return "\(operation) failed: \(error)"
        }
        return "\(operation) completed"
    }

    var metaLines: [String] {
        [
            ("request_id", requestID),
            ("provider", provider),
            ("model", model),
            ("prompt_version", promptVersion),
            ("input_tokens", inputTokens.map(String.init)),
            ("output_tokens", outputTokens.map(String.init)),
        ]
        .compactMap { key, value in
            guard let value, !value.isEmpty else { return nil }
            return "\(key): \(value)"
        }
    }
}

struct V6GateDiagnostic: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let isEnabled: Bool
    let blockedReasons: [String]

    var statusText: String {
        isEnabled ? "enabled" : "blocked"
    }

    var reasonText: String {
        blockedReasons.isEmpty ? "none" : blockedReasons.joined(separator: "\n")
    }
}

enum V6DebugControls {
    static func gateDiagnostics(
        preferences: IntelligencePreferences,
        flags: V6FeatureFlags
    ) -> [V6GateDiagnostic] {
        [
            semanticSearchGate(preferences: preferences, flags: flags),
            voiceRefinementGate(preferences: preferences),
            dailyQuestionsGate(preferences: preferences, flags: flags),
            jobWorkerGate(flags: flags),
            homeBoardGate(preferences: preferences, flags: flags),
            notificationsGate(preferences: preferences, flags: flags),
        ]
    }

    static func semanticSearchGate(
        preferences: IntelligencePreferences,
        flags: V6FeatureFlags
    ) -> V6GateDiagnostic {
        gate(
            id: "semantic_search",
            title: "Semantic Search",
            checks: [
                ("semanticSearchEnabled", preferences.semanticSearchEnabled),
                ("v6.semanticSearch", flags.semanticSearch),
            ]
        )
    }

    static func voiceRefinementGate(preferences: IntelligencePreferences) -> V6GateDiagnostic {
        gate(
            id: "voice_refinement",
            title: "Voice Refinement",
            checks: [
                ("cloudIntelligenceEnabled", preferences.cloudIntelligenceEnabled),
                ("voiceRefinementEnabled", preferences.voiceRefinementEnabled),
            ]
        )
    }

    static func dailyQuestionsGate(
        preferences: IntelligencePreferences,
        flags: V6FeatureFlags
    ) -> V6GateDiagnostic {
        gate(
            id: "daily_questions",
            title: "Daily Questions",
            checks: [
                ("localIntelligenceEnabled", preferences.localIntelligenceEnabled),
                ("cloudIntelligenceEnabled", preferences.cloudIntelligenceEnabled),
                ("homeSuggestionsEnabled", preferences.homeSuggestionsEnabled),
                ("dailyQuestionsEnabled", preferences.dailyQuestionsEnabled),
                ("v6.dailyQuestions", flags.dailyQuestions),
                ("v6.cloudQuestionSuggestions", flags.cloudQuestionSuggestions),
            ]
        )
    }

    static func jobWorkerGate(flags: V6FeatureFlags) -> V6GateDiagnostic {
        gate(
            id: "job_worker",
            title: "Job Worker",
            checks: [
                ("v6.intelligenceJobs", flags.intelligenceJobs),
            ]
        )
    }

    static func homeBoardGate(
        preferences: IntelligencePreferences,
        flags: V6FeatureFlags
    ) -> V6GateDiagnostic {
        gate(
            id: "home_board",
            title: "Home Board Intelligence",
            checks: [
                ("homeSuggestionsEnabled", preferences.homeSuggestionsEnabled),
                ("v6.homeBoard", flags.homeBoard),
                ("v6.entityProfiles", flags.entityProfiles),
                ("v6.clarificationQuestions", flags.clarificationQuestions),
            ]
        )
    }

    static func notificationsGate(
        preferences: IntelligencePreferences,
        flags: V6FeatureFlags
    ) -> V6GateDiagnostic {
        gate(
            id: "notifications",
            title: "Notifications",
            checks: [
                ("notificationPreferences.enabled", preferences.notificationPreferences.enabled),
                ("v6.localNotifications", flags.localNotifications),
            ]
        )
    }

    static func cloudFirstStrongestPolicy(
        from preferences: IntelligencePreferences,
        now: Date = .now
    ) -> IntelligencePreferences {
        var updated = preferences
        updated.localIntelligenceEnabled = true
        updated.cloudIntelligenceEnabled = true
        updated.voiceRefinementEnabled = true
        updated.semanticSearchEnabled = true
        updated.homeSuggestionsEnabled = true
        updated.dailyQuestionsEnabled = true
        updated.updatedAt = now
        return updated
    }

    static func allFlagsEnabled(
        from flags: V6FeatureFlags,
        now: Date = .now
    ) -> V6FeatureFlags {
        var updated = flags
        updated.intelligenceJobs = true
        updated.entityProfiles = true
        updated.clarificationQuestions = true
        updated.homeBoard = true
        updated.semanticSearch = true
        updated.dailyQuestions = true
        updated.localNotifications = true
        updated.cloudQuestionSuggestions = true
        updated.cloudChapterSuggestions = true
        updated.multimediaViews = true
        updated.updatedAt = now
        return updated
    }

    static func semanticSearchEnabled(
        preferences: IntelligencePreferences,
        flags: V6FeatureFlags,
        now: Date = .now
    ) -> (preferences: IntelligencePreferences, flags: V6FeatureFlags) {
        var updatedPreferences = preferences
        var updatedFlags = flags
        updatedPreferences.semanticSearchEnabled = true
        updatedPreferences.updatedAt = now
        updatedFlags.semanticSearch = true
        updatedFlags.updatedAt = now
        return (updatedPreferences, updatedFlags)
    }

    private static func gate(
        id: String,
        title: String,
        checks: [(String, Bool)]
    ) -> V6GateDiagnostic {
        let blockedReasons = checks.compactMap { name, enabled in
            enabled ? nil : "\(name)=false"
        }
        return V6GateDiagnostic(
            id: id,
            title: title,
            isEnabled: blockedReasons.isEmpty,
            blockedReasons: blockedReasons
        )
    }
}

enum DebugCenterFormatting {
    static func semanticStatusText(_ status: SemanticSearchStatus) -> String {
        switch status {
        case .notRequested:
            return "not requested"
        case .disabled:
            return "disabled"
        case .unavailable:
            return "Core Spotlight unavailable"
        case let .succeeded(resultCount):
            return "Core Spotlight returned \(resultCount) hit(s)"
        case let .failed(message):
            return "Core Spotlight failed: \(message)"
        }
    }

    static func searchSourceText(_ sources: [SearchRetrievalSource]) -> String {
        sources.isEmpty ? "none" : sources.map(\.rawValue).joined(separator: " + ")
    }

    static func spotlightReportText(_ report: SpotlightIndexReport) -> String {
        if let skippedReason = report.skippedReason {
            return "skipped: \(skippedReason)"
        }
        return "indexed=\(report.indexedItemCount), deleted=\(report.deletedItemCount)"
    }

    static func boolText(_ value: Bool) -> String {
        value ? "yes" : "no"
    }
}
