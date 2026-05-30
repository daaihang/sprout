import Foundation
import OSLog

private let backgroundLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mory", category: "background")

@MainActor
struct BackgroundOperationOrchestrator: BackgroundTriggerDispatching {
    private let jobRecoverer: any BackgroundJobRecovering
    private let jobProcessor: any BackgroundJobProcessing
    private let questionPreparer: any BackgroundQuestionPreparing
    private let reminderRouting: any BackgroundReminderRouting
    private let pushSyncing: any BackgroundPushRegistrationSyncing

    init(
        jobRecoverer: any BackgroundJobRecovering,
        jobProcessor: any BackgroundJobProcessing,
        questionPreparer: any BackgroundQuestionPreparing,
        reminderRouting: any BackgroundReminderRouting,
        pushSyncing: any BackgroundPushRegistrationSyncing
    ) {
        self.jobRecoverer = jobRecoverer
        self.jobProcessor = jobProcessor
        self.questionPreparer = questionPreparer
        self.reminderRouting = reminderRouting
        self.pushSyncing = pushSyncing
    }

    func handle(
        trigger: BackgroundTrigger,
        repository: any MoryMemoryRepositorying,
        now: Date = .now
    ) async -> BackgroundOperationReport {
        var run = BackgroundOperationRun(
            triggerKind: trigger.kind,
            triggerTargetID: trigger.targetID,
            startedAt: now,
            source: trigger.source,
            metadata: trigger.metadata
        )
        persistRunStart(run, repository: repository)

        var report = BackgroundOperationReport(runID: run.id, triggerKind: trigger.kind)

        switch trigger.kind {
        case .appLaunch:
            await append(
                operation: .recoverUnfinishedJobs,
                runID: run.id,
                repository: repository,
                now: now,
                to: &report
            ) {
                try jobRecoverer.recoverBackgroundJobs(repository: repository, now: now)
            }
            await appendProcessDueJobs(runID: run.id, repository: repository, now: now, to: &report)
            await appendPrepareQuestion(runID: run.id, repository: repository, now: now, to: &report)
            await appendNotification(trigger: trigger, runID: run.id, repository: repository, now: now, to: &report)
            await appendPushSync(runID: run.id, repository: repository, force: false, now: now, to: &report)

        case .bgProcessingTask:
            await appendProcessDueJobs(runID: run.id, repository: repository, now: now, to: &report)

        case .bgAppRefreshTask:
            await appendPrepareQuestion(runID: run.id, repository: repository, now: now, to: &report)
            await appendNotification(trigger: trigger, runID: run.id, repository: repository, now: now, to: &report)
            await appendPushSync(runID: run.id, repository: repository, force: false, now: now, to: &report)

        case .silentPush:
            await appendNotification(trigger: trigger, runID: run.id, repository: repository, now: now, to: &report)
            await appendPushSync(runID: run.id, repository: repository, force: false, now: now, to: &report)

        case .homeForegroundRefresh, .sceneForeground:
            await appendPrepareQuestion(runID: run.id, repository: repository, now: now, to: &report)
            await appendNotification(trigger: trigger, runID: run.id, repository: repository, now: now, to: &report)

        case .pipelineCompleted:
            await appendNotification(trigger: trigger, runID: run.id, repository: repository, now: now, to: &report)

        case .apnsTokenUpdated:
            await appendPushSync(runID: run.id, repository: repository, force: true, now: now, to: &report)

        case .notificationPreferencesChanged:
            await appendPushSync(runID: run.id, repository: repository, force: true, now: now, to: &report)
            await appendNotification(trigger: trigger, runID: run.id, repository: repository, now: now, to: &report)

        case .backgroundURLSessionCompleted:
            let message = trigger.metadata["identifier"].map {
                "Completed background URLSession \($0)."
            } ?? "Completed background URLSession callback."
            await appendStatic(
                operation: .recordBackgroundURLSession,
                outcome: .completed(message: message),
                runID: run.id,
                repository: repository,
                now: now,
                to: &report
            )

        case .debugManual:
            await appendStatic(
                operation: .scheduleBGTasks,
                outcome: .completed(message: "Debug manual trigger recorded."),
                runID: run.id,
                repository: repository,
                now: now,
                to: &report
            )
        }

        let completedAt = Date.now
        run.completedAt = completedAt
        run.status = report.status
        run.errors = report.errors
        run.summary = summarize(report)
        persistRunCompletion(run, repository: repository)
        return report
    }

    private func appendProcessDueJobs(
        runID: UUID,
        repository: any MoryMemoryRepositorying,
        now: Date,
        to report: inout BackgroundOperationReport
    ) async {
        await append(
            operation: .processDueJobs,
            runID: runID,
            repository: repository,
            now: now,
            to: &report
        ) {
            await jobProcessor.processBackgroundJobs(repository: repository, now: now, limit: 24)
        }
    }

    private func appendPrepareQuestion(
        runID: UUID,
        repository: any MoryMemoryRepositorying,
        now: Date,
        to report: inout BackgroundOperationReport
    ) async {
        await append(
            operation: .prepareDailyQuestion,
            runID: runID,
            repository: repository,
            now: now,
            to: &report
        ) {
            try await questionPreparer.prepareBackgroundQuestion(repository: repository, now: now)
        }
    }

    private func appendNotification(
        trigger: BackgroundTrigger,
        runID: UUID,
        repository: any MoryMemoryRepositorying,
        now: Date,
        to report: inout BackgroundOperationReport
    ) async {
        await append(
            operation: .orchestrateNotifications,
            runID: runID,
            repository: repository,
            now: now,
            to: &report
        ) {
            try await reminderRouting.routeBackgroundReminder(
                for: trigger,
                repository: repository,
                now: now
            )
        }
    }

    private func appendPushSync(
        runID: UUID,
        repository: any MoryMemoryRepositorying,
        force: Bool,
        now: Date,
        to report: inout BackgroundOperationReport
    ) async {
        await append(
            operation: .syncRemotePushRegistration,
            runID: runID,
            repository: repository,
            now: now,
            to: &report
        ) {
            await pushSyncing.syncBackgroundPushRegistration(repository: repository, force: force)
        }
    }

    private func appendStatic(
        operation: BackgroundOperationKind,
        outcome: BackgroundOperationOutcome,
        runID: UUID,
        repository: any BackgroundOperationRepositorying,
        now: Date,
        to report: inout BackgroundOperationReport
    ) async {
        let event = await persistOutcome(
            operation: operation,
            outcome: outcome,
            runID: runID,
            repository: repository,
            now: now,
            startedAt: now
        )
        append(event, to: &report)
    }

    private func append(
        operation: BackgroundOperationKind,
        runID: UUID,
        repository: any BackgroundOperationRepositorying,
        now: Date,
        to report: inout BackgroundOperationReport,
        body: () async throws -> BackgroundOperationOutcome
    ) async {
        let startedAt = Date.now
        var running = BackgroundOperationEvent(
            runID: runID,
            operationKind: operation,
            status: .running,
            startedAt: startedAt
        )
        try? repository.upsertBackgroundOperationEvent(running)

        let outcome: BackgroundOperationOutcome
        do {
            outcome = try await body()
        } catch {
            outcome = .failed(error: error.localizedDescription)
        }
        running = await persistOutcome(
            operation: operation,
            outcome: outcome,
            runID: runID,
            repository: repository,
            now: now,
            startedAt: startedAt,
            existingID: running.id
        )
        append(running, to: &report)
    }

    private func persistOutcome(
        operation: BackgroundOperationKind,
        outcome: BackgroundOperationOutcome,
        runID: UUID,
        repository: any BackgroundOperationRepositorying,
        now _: Date,
        startedAt: Date,
        existingID: UUID? = nil
    ) async -> BackgroundOperationEvent {
        let event = BackgroundOperationEvent(
            id: existingID ?? UUID(),
            runID: runID,
            operationKind: operation,
            status: outcome.status,
            startedAt: startedAt,
            completedAt: Date.now,
            message: outcome.message,
            error: outcome.error,
            resultCounts: outcome.resultCounts
        )
        try? repository.upsertBackgroundOperationEvent(event)
        return event
    }

    private func append(_ event: BackgroundOperationEvent, to report: inout BackgroundOperationReport) {
        report.operationEvents.append(event)
        if event.status == .failed {
            report.errors.append(event.error ?? "\(event.operationKind.rawValue) failed.")
        }
    }

    private func persistRunStart(
        _ run: BackgroundOperationRun,
        repository: any BackgroundOperationRepositorying
    ) {
        do {
            try repository.upsertBackgroundOperationRun(run)
        } catch {
            backgroundLog.error("Failed to persist background run start: \(error.localizedDescription)")
        }
    }

    private func persistRunCompletion(
        _ run: BackgroundOperationRun,
        repository: any BackgroundOperationRepositorying
    ) {
        do {
            try repository.upsertBackgroundOperationRun(run)
        } catch {
            backgroundLog.error("Failed to persist background run completion: \(error.localizedDescription)")
        }
    }

    private func summarize(_ report: BackgroundOperationReport) -> String {
        [
            "trigger=\(report.triggerKind.rawValue)",
            "events=\(report.operationEvents.count)",
            "errors=\(report.errors.count)",
        ].joined(separator: ", ")
    }
}

@MainActor
struct NoopBackgroundJobRecoverer: BackgroundJobRecovering {
    func recoverBackgroundJobs(
        repository _: any IntelligenceRecoveryRepositorying,
        now _: Date
    ) throws -> BackgroundOperationOutcome {
        .skipped(message: "No background job recoverer configured.")
    }
}

@MainActor
struct NoopBackgroundJobProcessor: BackgroundJobProcessing {
    func processBackgroundJobs(
        repository _: any IntelligenceJobRepositorying,
        now _: Date,
        limit _: Int
    ) async -> BackgroundOperationOutcome {
        .skipped(message: "No background job processor configured.")
    }
}

@MainActor
struct NoopBackgroundQuestionPreparer: BackgroundQuestionPreparing {
    func prepareBackgroundQuestion(
        repository _: any DailyQuestionRepositorying,
        now _: Date
    ) async throws -> BackgroundOperationOutcome {
        .skipped(message: "No background question preparer configured.")
    }
}

@MainActor
struct NoopBackgroundReminderRouter: BackgroundReminderRouting {
    func routeBackgroundReminder(
        for _: BackgroundTrigger,
        repository _: any NotificationPreparationRepositorying,
        now _: Date
    ) async throws -> BackgroundOperationOutcome {
        .skipped(message: "No background notification trigger configured.")
    }
}

@MainActor
struct NoopBackgroundPushSyncer: BackgroundPushRegistrationSyncing {
    func syncBackgroundPushRegistration(
        repository _: any MoryMemoryRepositorying,
        force _: Bool
    ) async -> BackgroundOperationOutcome {
        .skipped(message: "No background push syncer configured.")
    }
}

extension BackgroundOperationOrchestrator {
    static var noop: BackgroundOperationOrchestrator {
        BackgroundOperationOrchestrator(
            jobRecoverer: NoopBackgroundJobRecoverer(),
            jobProcessor: NoopBackgroundJobProcessor(),
            questionPreparer: NoopBackgroundQuestionPreparer(),
            reminderRouting: NoopBackgroundReminderRouter(),
            pushSyncing: NoopBackgroundPushSyncer()
        )
    }
}
