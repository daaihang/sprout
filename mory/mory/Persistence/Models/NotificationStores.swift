import Foundation
import SwiftData

@Model
final class NotificationIntentStore {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var title: String
    var body: String
    var privacyLevelRawValue: String
    var targetTypeRawValue: String
    var targetID: UUID
    var scheduledAt: Date
    var statusRawValue: String
    var deliveryChannelRawValue: String
    var dedupeKey: String?
    var deepLink: String?
    var reason: String?
    var sourceTriggerRawValue: String?
    var createdByRawValue: String?
    var lastEvaluatedAt: Date?
    var blockedReasons: [String]?
    var createdAt: Date
    var deliveredAt: Date?
    var openedAt: Date?
    var dismissedAt: Date?

    init(
        id: UUID,
        kindRawValue: String,
        title: String,
        body: String,
        privacyLevelRawValue: String,
        targetTypeRawValue: String,
        targetID: UUID,
        scheduledAt: Date,
        statusRawValue: String,
        deliveryChannelRawValue: String,
        dedupeKey: String,
        deepLink: String? = nil,
        reason: String,
        sourceTriggerRawValue: String,
        createdByRawValue: String,
        lastEvaluatedAt: Date,
        blockedReasons: [String] = [],
        createdAt: Date,
        deliveredAt: Date? = nil,
        openedAt: Date? = nil,
        dismissedAt: Date? = nil
    ) {
        self.id = id
        self.kindRawValue = kindRawValue
        self.title = title
        self.body = body
        self.privacyLevelRawValue = privacyLevelRawValue
        self.targetTypeRawValue = targetTypeRawValue
        self.targetID = targetID
        self.scheduledAt = scheduledAt
        self.statusRawValue = statusRawValue
        self.deliveryChannelRawValue = deliveryChannelRawValue
        self.dedupeKey = dedupeKey
        self.deepLink = deepLink
        self.reason = reason
        self.sourceTriggerRawValue = sourceTriggerRawValue
        self.createdByRawValue = createdByRawValue
        self.lastEvaluatedAt = lastEvaluatedAt
        self.blockedReasons = blockedReasons
        self.createdAt = createdAt
        self.deliveredAt = deliveredAt
        self.openedAt = openedAt
        self.dismissedAt = dismissedAt
    }
}

@Model
final class NotificationManagementEventStore {
    @Attribute(.unique) var id: UUID
    var eventKindRawValue: String
    var intentID: UUID?
    var dedupeKey: String?
    var triggerRawValue: String?
    var kindRawValue: String?
    var targetTypeRawValue: String?
    var targetID: UUID?
    var message: String
    var createdAt: Date

    init(
        id: UUID,
        eventKindRawValue: String,
        intentID: UUID? = nil,
        dedupeKey: String? = nil,
        triggerRawValue: String? = nil,
        kindRawValue: String? = nil,
        targetTypeRawValue: String? = nil,
        targetID: UUID? = nil,
        message: String,
        createdAt: Date
    ) {
        self.id = id
        self.eventKindRawValue = eventKindRawValue
        self.intentID = intentID
        self.dedupeKey = dedupeKey
        self.triggerRawValue = triggerRawValue
        self.kindRawValue = kindRawValue
        self.targetTypeRawValue = targetTypeRawValue
        self.targetID = targetID
        self.message = message
        self.createdAt = createdAt
    }
}
