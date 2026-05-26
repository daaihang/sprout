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
            _ = try await pushEnqueuer.enqueueRemotePush(makeRemotePushPayload(for: routed))
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

    private func makeRemotePushPayload(for intent: NotificationIntent) -> RemotePushDeliveryPayload {
        RemotePushDeliveryPayload(
            intentID: intent.id,
            kind: intent.kind.rawValue,
            title: intent.title,
            body: intent.body,
            privacyLevel: intent.privacyLevel.rawValue,
            targetType: intent.targetType.rawValue,
            targetID: intent.targetID,
            deepLink: intent.deepLink ?? deepLink(for: intent),
            scheduledAt: intent.scheduledAt
        )
    }

    private func deepLink(for intent: NotificationIntent) -> String {
        switch intent.targetType {
        case .question:
            return "mory://home/question/\(intent.targetID.uuidString)"
        case .record:
            return "mory://memories/record/\(intent.targetID.uuidString)"
        case .artifact:
            return "mory://memories/artifact/\(intent.targetID.uuidString)"
        case .chapter:
            return "mory://insights/chapter/\(intent.targetID.uuidString)"
        case .reflection:
            return "mory://insights/reflection/\(intent.targetID.uuidString)"
        case .entity:
            return "mory://insights/entity/\(intent.targetID.uuidString)"
        case .place:
            return "mory://insights/place/\(intent.targetID.uuidString)"
        case .theme:
            return "mory://insights/theme/\(intent.targetID.uuidString)"
        case .decision:
            return "mory://insights/decision/\(intent.targetID.uuidString)"
        }
    }
}
