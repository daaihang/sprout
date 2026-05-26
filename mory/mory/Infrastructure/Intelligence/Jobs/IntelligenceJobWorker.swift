import Foundation
import OSLog

private let log = Logger(subsystem: "com.mory", category: "intelligence.jobs")

struct IntelligenceJobWorkerReport: Hashable, Sendable {
    var completedJobIDs: [UUID] = []
    var failedJobIDs: [UUID] = []
    var unsupportedJobIDs: [UUID] = []
    var scheduledNotificationCount: Int = 0
    var preparedQuestionCount: Int = 0
}

@MainActor
struct IntelligenceJobWorker {
    let clarificationQuestionBuilder: ClarificationQuestionBuilder
    let graphDeltaApplier: GraphDeltaApplier
    private let cloudIntelligenceService: (any CloudIntelligenceServing)?
    private let notificationRouting: (any IntelligenceNotificationRouting)?

    init(
        clarificationQuestionBuilder: ClarificationQuestionBuilder? = nil,
        graphDeltaApplier: GraphDeltaApplier? = nil,
        cloudIntelligenceService: (any CloudIntelligenceServing)? = nil,
        notificationRouting: (any IntelligenceNotificationRouting)? = nil
    ) {
        self.clarificationQuestionBuilder = clarificationQuestionBuilder ?? ClarificationQuestionBuilder()
        self.graphDeltaApplier = graphDeltaApplier ?? GraphDeltaApplier()
        self.cloudIntelligenceService = cloudIntelligenceService
        self.notificationRouting = notificationRouting
    }

    func processDueJobs(
        repository: any IntelligenceJobRepositorying,
        cloudIntelligenceService: any CloudIntelligenceServing,
        notificationRouting: (any IntelligenceNotificationRouting)? = nil,
        now: Date = .now,
        limit: Int = 24
    ) async -> IntelligenceJobWorkerReport {
        var report = IntelligenceJobWorkerReport()
        let resolvedNotificationRouting = notificationRouting ?? self.notificationRouting

        let flags: V6FeatureFlags
        do {
            flags = try repository.fetchV6FeatureFlags()
        } catch {
            log.error("fetchV6FeatureFlags failed, skipping job processing: \(error)")
            return report
        }
        guard flags.intelligenceJobs else { return report }

        let allJobs: [IntelligenceJob]
        do {
            allJobs = try repository.fetchIntelligenceJobs(status: .pending, limit: nil)
        } catch {
            log.error("fetchIntelligenceJobs failed, skipping job processing: \(error)")
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
                    notificationRouting: resolvedNotificationRouting,
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
                do {
                    try repository.upsertIntelligenceJob(failed)
                } catch let persistError {
                    log.error("Failed to persist failed state for job \(job.id): \(persistError)")
                }
                report.failedJobIDs.append(job.id)
            }
        }

        return report
    }

    private func execute(
        _ runningJob: IntelligenceJob,
        repository: any IntelligenceJobRepositorying,
        cloudIntelligenceService: any CloudIntelligenceServing,
        notificationRouting: (any IntelligenceNotificationRouting)?,
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
            guard let notificationRouting else {
                throw IntelligenceJobWorkerError.notificationRoutingUnavailable
            }
            let notificationReport = try await notificationRouting.routeIntelligenceNotification(
                trigger: .backgroundRefresh,
                repository: repository,
                now: now,
            )
            report.scheduledNotificationCount += notificationReport.scheduledIntentIDs.count

        case .semanticIndex:
            _ = try await repository.rebuildSpotlightIndex()

        case .entityEnrichment:
            try executeEntityEnrichment(
                runningJob,
                repository: repository,
                now: now
            )

        case .personProfileRefresh:
            try executePersonProfileRefresh(
                runningJob,
                repository: repository,
                now: now
            )

        case .clarificationQuestionGeneration:
            try executeClarificationQuestionGeneration(
                runningJob,
                repository: repository,
                now: now
            )

        case .graphDeltaApplication:
            try executeGraphDeltaApplication(
                runningJob,
                repository: repository,
                now: now
            )

        case .chapterCandidate:
            try await executeChapterCandidate(
                runningJob,
                repository: repository,
                cloudIntelligenceService: cloudIntelligenceService,
                now: now
            )
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


extension IntelligenceJobWorker: BackgroundJobProcessing {
    func processBackgroundJobs(
        repository: any IntelligenceJobRepositorying,
        now: Date,
        limit: Int
    ) async -> BackgroundOperationOutcome {
        guard let cloudIntelligenceService else {
            return .skipped(message: "Cloud intelligence service unavailable.")
        }

        let report = await processDueJobs(
            repository: repository,
            cloudIntelligenceService: cloudIntelligenceService,
            now: now,
            limit: limit
        )
        let counts = [
            "completed": report.completedJobIDs.count,
            "failed": report.failedJobIDs.count,
            "unsupported": report.unsupportedJobIDs.count,
            "questions": report.preparedQuestionCount,
            "notifications": report.scheduledNotificationCount,
        ]
        guard report.failedJobIDs.isEmpty else {
            return .failed(error: "Failed jobs: \(report.failedJobIDs.count)", resultCounts: counts)
        }
        return .completed(resultCounts: counts)
    }
}

enum IntelligenceJobWorkerError: LocalizedError {
    case notificationRoutingUnavailable
    case unsupportedTargetType
    case unsupportedJobKind(IntelligenceJobKind)

    var errorDescription: String? {
        switch self {
        case .notificationRoutingUnavailable:
            return "Notification routing is unavailable for intelligence job execution."
        case .unsupportedTargetType:
            return "Unsupported intelligence job target type."
        case let .unsupportedJobKind(kind):
            return "Unsupported intelligence job kind: \(kind.rawValue)"
        }
    }
}
