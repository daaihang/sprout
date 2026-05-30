import Foundation

struct NotificationManagementSnapshot: Hashable, Sendable {
    static let queueStatuses: [NotificationIntentStatus] = [
        .pending,
        .scheduled,
        .inAppOnly,
        .blocked,
    ]

    static let historyKinds: [NotificationManagementEventKind] = [
        .delivered,
        .opened,
        .dismissed,
    ]

    static let errorKinds: [NotificationManagementEventKind] = [
        .policyBlocked,
        .deliveryError,
        .routeError,
    ]

    var queueIntents: [NotificationIntent]
    var historyEvents: [NotificationManagementEvent]
    var dedupeEvents: [NotificationManagementEvent]
    var errorEvents: [NotificationManagementEvent]

    static let empty = NotificationManagementSnapshot(
        queueIntents: [],
        historyEvents: [],
        dedupeEvents: [],
        errorEvents: []
    )

    static func build(
        intents: [NotificationIntent],
        events: [NotificationManagementEvent]
    ) -> NotificationManagementSnapshot {
        NotificationManagementSnapshot(
            queueIntents: intents
                .filter { queueStatuses.contains($0.status) }
                .sorted { lhs, rhs in
                    if lhs.status != rhs.status {
                        let lhsIndex = queueStatuses.firstIndex(of: lhs.status) ?? Int.max
                        let rhsIndex = queueStatuses.firstIndex(of: rhs.status) ?? Int.max
                        return lhsIndex < rhsIndex
                    }
                    return lhs.scheduledAt < rhs.scheduledAt
                },
            historyEvents: events
                .filter { historyKinds.contains($0.eventKind) }
                .sorted { $0.createdAt > $1.createdAt },
            dedupeEvents: events
                .filter { $0.eventKind == .deduped }
                .sorted { $0.createdAt > $1.createdAt },
            errorEvents: events
                .filter { errorKinds.contains($0.eventKind) }
                .sorted { $0.createdAt > $1.createdAt }
        )
    }
}
