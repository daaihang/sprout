import Foundation

@MainActor
protocol BackgroundJobRecovering {
    func recoverBackgroundJobs(
        repository: any IntelligenceRecoveryRepositorying,
        now: Date
    ) throws -> BackgroundOperationOutcome
}

@MainActor
protocol BackgroundJobProcessing {
    func processBackgroundJobs(
        repository: any IntelligenceJobRepositorying,
        now: Date,
        limit: Int
    ) async -> BackgroundOperationOutcome
}

@MainActor
protocol BackgroundQuestionPreparing {
    func prepareBackgroundQuestion(
        repository: any DailyQuestionRepositorying,
        now: Date
    ) async throws -> BackgroundOperationOutcome
}

@MainActor
protocol BackgroundReminderRouting {
    func routeBackgroundReminder(
        for trigger: BackgroundTrigger,
        repository: any NotificationPreparationRepositorying,
        now: Date
    ) async throws -> BackgroundOperationOutcome
}

@MainActor
protocol BackgroundPushRegistrationSyncing {
    func syncBackgroundPushRegistration(
        repository: any MoryMemoryRepositorying,
        force: Bool
    ) async -> BackgroundOperationOutcome
}

@MainActor
protocol BackgroundTriggerDispatching {
    func handle(
        trigger: BackgroundTrigger,
        repository: any MoryMemoryRepositorying,
        now: Date
    ) async -> BackgroundOperationReport
}
