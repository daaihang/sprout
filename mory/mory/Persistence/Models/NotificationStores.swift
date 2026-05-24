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
    var createdAt: Date
    var deliveredAt: Date?
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
        createdAt: Date,
        deliveredAt: Date? = nil,
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
        self.createdAt = createdAt
        self.deliveredAt = deliveredAt
        self.dismissedAt = dismissedAt
    }
}
