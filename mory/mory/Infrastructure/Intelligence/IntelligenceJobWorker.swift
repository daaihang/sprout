import Foundation

struct IntelligenceJobWorkerReport: Hashable, Sendable {
    var completedJobIDs: [UUID] = []
    var failedJobIDs: [UUID] = []
    var unsupportedJobIDs: [UUID] = []
    var scheduledNotificationCount: Int = 0
    var preparedQuestionCount: Int = 0
}

@MainActor
struct IntelligenceJobWorker {
    private let notificationIntentPreparationService: NotificationIntentPreparationService
    private let notificationScheduler: LocalNotificationScheduler

    init(
        notificationIntentPreparationService: NotificationIntentPreparationService? = nil,
        notificationScheduler: LocalNotificationScheduler? = nil
    ) {
        self.notificationIntentPreparationService = notificationIntentPreparationService ?? NotificationIntentPreparationService()
        self.notificationScheduler = notificationScheduler ?? LocalNotificationScheduler()
    }

    func processDueJobs(
        repository: any MoryMemoryRepositorying,
        cloudIntelligenceService: any CloudIntelligenceServing,
        now: Date = .now,
        limit: Int = 24
    ) async -> IntelligenceJobWorkerReport {
        var report = IntelligenceJobWorkerReport()

        guard let flags = try? repository.fetchV6FeatureFlags(), flags.intelligenceJobs else {
            return report
        }

        guard let allJobs = try? repository.fetchIntelligenceJobs(status: .pending, limit: nil) else {
            return report
        }

        let dueJobs = allJobs
            .filter { $0.scheduledAt <= now }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.scheduledAt < rhs.scheduledAt
            }
            .prefix(max(1, limit))

        for job in dueJobs {
            var running = job
            running.status = .running
            running.startedAt = now
            running.updatedAt = now
            do {
                try repository.upsertIntelligenceJob(running)
                try await execute(
                    running,
                    repository: repository,
                    cloudIntelligenceService: cloudIntelligenceService,
                    now: now,
                    report: &report
                )
            } catch {
                var failed = running
                failed.status = .failed
                failed.attemptCount += 1
                failed.lastError = error.localizedDescription
                failed.completedAt = now
                failed.updatedAt = now
                try? repository.upsertIntelligenceJob(failed)
                report.failedJobIDs.append(job.id)
            }
        }

        return report
    }

    private func execute(
        _ runningJob: IntelligenceJob,
        repository: any MoryMemoryRepositorying,
        cloudIntelligenceService: any CloudIntelligenceServing,
        now: Date,
        report: inout IntelligenceJobWorkerReport
    ) async throws {
        switch runningJob.kind {
        case .postAnalysis:
            guard runningJob.targetType == .record else {
                throw IntelligenceJobWorkerError.unsupportedTargetType
            }
            try await repository.refreshMemoryPipeline(recordID: runningJob.targetID)

        case .dailyQuestion:
            let prepared = try await DailyQuestionSuggestionService(
                cloudIntelligenceService: cloudIntelligenceService
            )
            .prepareIfNeeded(repository: repository, now: now)
            report.preparedQuestionCount += prepared.count

        case .notificationIntent:
            _ = try notificationIntentPreparationService.prepareNextIntentIfNeeded(
                repository: repository,
                now: now
            )
            let scheduleReport = try await notificationScheduler.schedulePendingIntents(
                repository: repository,
                now: now,
                requestAuthorizationIfNeeded: false
            )
            report.scheduledNotificationCount += scheduleReport.scheduledCount

        case .semanticIndex:
            _ = try await repository.rebuildSpotlightIndex()

        case .chapterCandidate, .entityEnrichment, .clarificationQuestionGeneration, .graphDeltaApplication:
            report.unsupportedJobIDs.append(runningJob.id)
            throw IntelligenceJobWorkerError.unsupportedJobKind(runningJob.kind)
        }

        var completed = runningJob
        completed.status = .completed
        completed.completedAt = now
        completed.updatedAt = now
        completed.lastError = nil
        try repository.upsertIntelligenceJob(completed)
        report.completedJobIDs.append(runningJob.id)
    }
}

private enum IntelligenceJobWorkerError: LocalizedError {
    case unsupportedTargetType
    case unsupportedJobKind(IntelligenceJobKind)

    var errorDescription: String? {
        switch self {
        case .unsupportedTargetType:
            return "Unsupported intelligence job target type."
        case let .unsupportedJobKind(kind):
            return "Unsupported intelligence job kind: \(kind.rawValue)"
        }
    }
}
