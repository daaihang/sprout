import Foundation

struct AppIntelligenceRecoveryReport: Hashable, Sendable {
    var resumedRunningJobIDs: [UUID] = []
    var retriedFailedJobIDs: [UUID] = []
    var abandonedFailedJobIDs: [UUID] = []
    var preparedQuestionCount: Int = 0
    var notificationReport: NotificationOrchestrationReport = .empty
    var workerReport: IntelligenceJobWorkerReport = .init()
    var errors: [String] = []

    var recoveredJobCount: Int {
        resumedRunningJobIDs.count + retriedFailedJobIDs.count
    }
}

@MainActor
struct AppIntelligenceRecoveryService {
    private let maxRetryAttempts: Int
    private let baseRetryDelay: TimeInterval
    private let intelligenceJobWorker: IntelligenceJobWorker

    init(
        maxRetryAttempts: Int = 3,
        baseRetryDelay: TimeInterval = 15 * 60,
        intelligenceJobWorker: IntelligenceJobWorker? = nil
    ) {
        self.maxRetryAttempts = max(1, maxRetryAttempts)
        self.baseRetryDelay = max(60, baseRetryDelay)
        self.intelligenceJobWorker = intelligenceJobWorker ?? IntelligenceJobWorker()
    }

    func recoverAfterLaunch(
        repository: any AppIntelligenceRecoveryRepositorying,
        cloudIntelligenceService: any CloudIntelligenceServing,
        remotePushSyncService: (any RemotePushSyncing)? = nil,
        notificationOrchestrator: NotificationOrchestrator? = nil,
        now: Date = .now
    ) async -> AppIntelligenceRecoveryReport {
        var report = AppIntelligenceRecoveryReport()
        let resolvedOrchestrator = notificationOrchestrator ?? .localDelivery

        do {
            report = try recoverUnfinishedJobs(
                repository: repository,
                now: now,
                report: report
            )
        } catch {
            report.errors.append(error.localizedDescription)
        }

        report.workerReport = await intelligenceJobWorker.processDueJobs(
            repository: repository,
            cloudIntelligenceService: cloudIntelligenceService,
            remotePushSyncService: remotePushSyncService,
            notificationOrchestrator: resolvedOrchestrator,
            now: now
        )

        do {
            let preparedQuestions = try await DailyQuestionSuggestionService(
                cloudIntelligenceService: cloudIntelligenceService
            )
            .prepareIfNeeded(repository: repository, now: now)
            report.preparedQuestionCount = preparedQuestions.count
        } catch {
            report.errors.append(error.localizedDescription)
        }

        do {
            report.notificationReport = try await resolvedOrchestrator.orchestrate(
                trigger: .appLaunchRecovery,
                repository: repository,
                now: now
            )
        } catch {
            report.errors.append(error.localizedDescription)
        }

        return report
    }

    private func recoverUnfinishedJobs(
        repository: any IntelligenceRecoveryRepositorying,
        now: Date,
        report initialReport: AppIntelligenceRecoveryReport
    ) throws -> AppIntelligenceRecoveryReport {
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
