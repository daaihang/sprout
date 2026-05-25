import Foundation

@MainActor
extension NotificationIntentStore {
    convenience init(domainModel: NotificationIntent) {
        self.init(
            id: domainModel.id,
            kindRawValue: domainModel.kind.rawValue,
            title: domainModel.title,
            body: domainModel.body,
            privacyLevelRawValue: domainModel.privacyLevel.rawValue,
            targetTypeRawValue: domainModel.targetType.rawValue,
            targetID: domainModel.targetID,
            scheduledAt: domainModel.scheduledAt,
            statusRawValue: domainModel.status.rawValue,
            deliveryChannelRawValue: domainModel.deliveryChannel.rawValue,
            dedupeKey: domainModel.dedupeKey,
            deepLink: domainModel.deepLink,
            reason: domainModel.reason,
            sourceTriggerRawValue: domainModel.sourceTrigger.rawValue,
            createdByRawValue: domainModel.createdBy.rawValue,
            lastEvaluatedAt: domainModel.lastEvaluatedAt,
            blockedReasons: domainModel.blockedReasons,
            createdAt: domainModel.createdAt,
            deliveredAt: domainModel.deliveredAt,
            openedAt: domainModel.openedAt,
            dismissedAt: domainModel.dismissedAt
        )
    }

    var domainModel: NotificationIntent {
        NotificationIntent(
            id: id,
            kind: Self.requireNotificationIntentKind(kindRawValue),
            title: title,
            body: body,
            privacyLevel: NotificationPrivacyLevel(rawValue: privacyLevelRawValue) ?? .generic,
            targetType: ClarificationTargetType(rawValue: targetTypeRawValue) ?? .record,
            targetID: targetID,
            scheduledAt: scheduledAt,
            status: NotificationIntentStatus(rawValue: statusRawValue) ?? .pending,
            deliveryChannel: NotificationDeliveryChannel(rawValue: deliveryChannelRawValue) ?? .local,
            dedupeKey: dedupeKey,
            deepLink: deepLink,
            reason: reason ?? "",
            sourceTrigger: sourceTriggerRawValue.flatMap(NotificationTriggerSource.init(rawValue:)) ?? .debugManual,
            createdBy: createdByRawValue.flatMap(NotificationIntentCreator.init(rawValue:)) ?? .orchestrator,
            lastEvaluatedAt: lastEvaluatedAt ?? createdAt,
            blockedReasons: blockedReasons ?? [],
            createdAt: createdAt,
            deliveredAt: deliveredAt,
            openedAt: openedAt,
            dismissedAt: dismissedAt
        )
    }

    private static func requireNotificationIntentKind(_ rawValue: String) -> NotificationIntentKind {
        guard let kind = NotificationIntentKind(rawValue: rawValue) else {
            preconditionFailure("Unsupported NotificationIntentKind raw value: \(rawValue)")
        }
        return kind
    }

    func apply(domainModel: NotificationIntent) {
        id = domainModel.id
        kindRawValue = domainModel.kind.rawValue
        title = domainModel.title
        body = domainModel.body
        privacyLevelRawValue = domainModel.privacyLevel.rawValue
        targetTypeRawValue = domainModel.targetType.rawValue
        targetID = domainModel.targetID
        scheduledAt = domainModel.scheduledAt
        statusRawValue = domainModel.status.rawValue
        deliveryChannelRawValue = domainModel.deliveryChannel.rawValue
        dedupeKey = domainModel.dedupeKey
        deepLink = domainModel.deepLink
        reason = domainModel.reason
        sourceTriggerRawValue = domainModel.sourceTrigger.rawValue
        createdByRawValue = domainModel.createdBy.rawValue
        lastEvaluatedAt = domainModel.lastEvaluatedAt
        blockedReasons = domainModel.blockedReasons
        createdAt = domainModel.createdAt
        deliveredAt = domainModel.deliveredAt
        openedAt = domainModel.openedAt
        dismissedAt = domainModel.dismissedAt
    }
}

@MainActor
extension NotificationManagementEventStore {
    convenience init(domainModel: NotificationManagementEvent) {
        self.init(
            id: domainModel.id,
            eventKindRawValue: domainModel.eventKind.rawValue,
            intentID: domainModel.intentID,
            dedupeKey: domainModel.dedupeKey,
            triggerRawValue: domainModel.trigger?.rawValue,
            kindRawValue: domainModel.kind?.rawValue,
            targetTypeRawValue: domainModel.targetType?.rawValue,
            targetID: domainModel.targetID,
            message: domainModel.message,
            createdAt: domainModel.createdAt
        )
    }

    var domainModel: NotificationManagementEvent {
        NotificationManagementEvent(
            id: id,
            eventKind: NotificationManagementEventKind(rawValue: eventKindRawValue) ?? .generated,
            intentID: intentID,
            dedupeKey: dedupeKey,
            trigger: triggerRawValue.flatMap(NotificationTriggerSource.init(rawValue:)),
            kind: Self.notificationIntentKind(kindRawValue),
            targetType: targetTypeRawValue.flatMap(ClarificationTargetType.init(rawValue:)),
            targetID: targetID,
            message: message,
            createdAt: createdAt
        )
    }

    private static func notificationIntentKind(_ rawValue: String?) -> NotificationIntentKind? {
        guard let rawValue else { return nil }
        guard let kind = NotificationIntentKind(rawValue: rawValue) else {
            preconditionFailure("Unsupported NotificationIntentKind raw value: \(rawValue)")
        }
        return kind
    }
}
