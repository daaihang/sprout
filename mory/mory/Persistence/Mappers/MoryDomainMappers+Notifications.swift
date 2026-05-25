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
            dismissedAt: domainModel.dismissedAt
        )
    }

    var domainModel: NotificationIntent {
        NotificationIntent(
            id: id,
            kind: NotificationIntentKind(rawValue: kindRawValue) ?? .dailyQuestion,
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
            dismissedAt: dismissedAt
        )
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
        dismissedAt = domainModel.dismissedAt
    }
}
