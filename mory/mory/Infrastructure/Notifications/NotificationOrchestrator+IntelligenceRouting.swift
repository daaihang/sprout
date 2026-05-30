import Foundation

extension NotificationOrchestrator: IntelligenceNotificationRouting {
    func routeIntelligenceNotification(
        trigger: NotificationTrigger,
        repository: any NotificationPreparationRepositorying,
        now: Date
    ) async throws -> NotificationOrchestrationReport {
        try await orchestrate(trigger: trigger, repository: repository, now: now)
    }
}
