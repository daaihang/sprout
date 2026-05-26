import Foundation

@MainActor
protocol IntelligenceNotificationRouting {
    func routeIntelligenceNotification(
        trigger: NotificationTrigger,
        repository: any NotificationPreparationRepositorying,
        now: Date
    ) async throws -> NotificationOrchestrationReport
}
