import Foundation

struct DebugStatusCount: Identifiable, Hashable, Sendable {
    var id: String { label }
    let label: String
    let count: Int
}

struct DebugJobQueueSnapshot: Hashable, Sendable {
    let generatedAt: Date
    let jobs: [IntelligenceJob]
    let notificationIntents: [NotificationIntent]
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

    var notificationStatusCounts: [DebugStatusCount] {
        NotificationIntentStatus.allCases.map { status in
            DebugStatusCount(label: status.rawValue, count: notificationIntents.filter { $0.status == status }.count)
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
