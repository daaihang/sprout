import Foundation

@MainActor
struct NotificationDeliveryRouter {
    var localScheduler: LocalNotificationScheduler = .init()
    var pushEnqueuer: any PushNotificationEnqueuing

    func route(
        intent: NotificationIntent,
        repository: any NotificationIntentRepositorying,
        now: Date = .now
    ) async throws -> NotificationIntent {
        var routed = intent
        routed.deliveryChannel = pushEnqueuer.hasAPNSToken ? .remote : .local
        routed.lastEvaluatedAt = now
        try repository.upsertNotificationIntent(routed)
        if routed.deliveryChannel == .remote {
            _ = try await pushEnqueuer.enqueueRemoteNotificationIntent(routed)
            routed.status = .scheduled
            try repository.upsertNotificationIntent(routed)
        } else {
            let report = try await localScheduler.schedulePendingIntents(
                repository: repository,
                now: now,
                requestAuthorizationIfNeeded: false
            )
            if let result = report.results.first(where: { $0.intentID == routed.id }), !result.scheduled {
                routed.status = .blocked
                routed.blockedReasons = [result.skipReason?.rawValue].compactMap { $0 }
                try repository.upsertNotificationIntent(routed)
            } else {
                routed = try repository.fetchNotificationIntents(status: nil, limit: nil)
                    .first(where: { $0.id == routed.id }) ?? routed
            }
        }
        return routed
    }
}
