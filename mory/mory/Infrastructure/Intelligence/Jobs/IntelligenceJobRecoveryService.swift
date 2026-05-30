import Foundation

struct IntelligenceJobRecoveryReport: Hashable, Sendable {
    var resumedRunningJobIDs: [UUID] = []
    var retriedFailedJobIDs: [UUID] = []
    var abandonedFailedJobIDs: [UUID] = []
    var errors: [String] = []

    var recoveredJobCount: Int {
        resumedRunningJobIDs.count + retriedFailedJobIDs.count
    }
}

@MainActor
struct IntelligenceJobRecoveryService {
    private let maxRetryAttempts: Int
    private let baseRetryDelay: TimeInterval

    init(
        maxRetryAttempts: Int = 3,
        baseRetryDelay: TimeInterval = 15 * 60
    ) {
        self.maxRetryAttempts = max(1, maxRetryAttempts)
        self.baseRetryDelay = max(60, baseRetryDelay)
    }

    func recoverUnfinishedJobs(
        repository: any IntelligenceRecoveryRepositorying,
        now: Date = .now
    ) throws -> IntelligenceJobRecoveryReport {
        try recoverUnfinishedJobs(repository: repository, now: now, report: .init())
    }

    private func recoverUnfinishedJobs(
        repository: any IntelligenceRecoveryRepositorying,
        now: Date,
        report initialReport: IntelligenceJobRecoveryReport
    ) throws -> IntelligenceJobRecoveryReport {
        let flags = try repository.fetchV6FeatureFlags()
        guard flags.intelligenceJobs else {
            return initialReport
        }

        var report = initialReport
        let jobs = try repository.fetchIntelligenceJobs(status: nil, limit: nil)

        for job in jobs {
            switch job.status {
            case .running:
                var resumed = job
                resumed.status = .pending
                resumed.startedAt = nil
                resumed.completedAt = nil
                resumed.updatedAt = now
                if resumed.scheduledAt > now {
                    resumed.scheduledAt = now
                }
                try repository.upsertIntelligenceJob(resumed)
                report.resumedRunningJobIDs.append(job.id)

            case .failed where job.attemptCount < maxRetryAttempts:
                var retry = job
                retry.status = .pending
                retry.startedAt = nil
                retry.completedAt = nil
                retry.updatedAt = now
                retry.scheduledAt = now.addingTimeInterval(retryDelay(forAttemptCount: job.attemptCount))
                try repository.upsertIntelligenceJob(retry)
                report.retriedFailedJobIDs.append(job.id)

            case .failed:
                report.abandonedFailedJobIDs.append(job.id)

            case .pending, .completed, .cancelled:
                continue
            }
        }

        return report
    }

    private func retryDelay(forAttemptCount attemptCount: Int) -> TimeInterval {
        let multiplier = pow(2.0, Double(max(0, attemptCount - 1)))
        return min(baseRetryDelay * multiplier, 6 * 60 * 60)
    }
}

extension IntelligenceJobRecoveryService: BackgroundJobRecovering {
    func recoverBackgroundJobs(
        repository: any IntelligenceRecoveryRepositorying,
        now: Date
    ) throws -> BackgroundOperationOutcome {
        let report = try recoverUnfinishedJobs(repository: repository, now: now)
        return .completed(resultCounts: [
            "resumed": report.resumedRunningJobIDs.count,
            "retried": report.retriedFailedJobIDs.count,
            "abandoned": report.abandonedFailedJobIDs.count,
        ])
    }
}
