import Foundation

enum LocalNotificationMetadata {
    static let categoryIdentifier = "mory.notification.intent"
    static let intentIDKey = "mory_notification_intent_id"
    static let kindKey = "mory_notification_kind"
    static let targetTypeKey = "mory_notification_target_type"
    static let targetIDKey = "mory_notification_target_id"
    static let deepLinkKey = "mory_notification_deep_link"

    static func requestIdentifier(for intentID: UUID) -> String {
        "mory.notification.\(intentID.uuidString)"
    }

    static func requestIdentifier(for intent: NotificationIntent) -> String {
        requestIdentifier(for: intent.id)
    }

    static func userInfo(for intent: NotificationIntent) -> [String: String] {
        var userInfo = [
            intentIDKey: intent.id.uuidString,
            kindKey: intent.kind.rawValue,
            targetTypeKey: intent.targetType.rawValue,
            targetIDKey: intent.targetID.uuidString,
        ]
        if let deepLink = intent.deepLink?.trimmedOrNil {
            userInfo[deepLinkKey] = deepLink
        }
        return userInfo
    }
}

struct LocalNotificationPayload: Hashable, Sendable {
    var intentID: UUID
    var kind: NotificationIntentKind
    var targetType: ClarificationTargetType
    var targetID: UUID
    var deepLink: String?

    init(
        intentID: UUID,
        kind: NotificationIntentKind,
        targetType: ClarificationTargetType,
        targetID: UUID,
        deepLink: String? = nil
    ) {
        self.intentID = intentID
        self.kind = kind
        self.targetType = targetType
        self.targetID = targetID
        self.deepLink = deepLink
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard
            let intentIDString = userInfo[LocalNotificationMetadata.intentIDKey] as? String,
            let intentID = UUID(uuidString: intentIDString),
            let kindString = userInfo[LocalNotificationMetadata.kindKey] as? String,
            let kind = NotificationIntentKind(rawValue: kindString),
            let targetTypeString = userInfo[LocalNotificationMetadata.targetTypeKey] as? String,
            let targetType = ClarificationTargetType(rawValue: targetTypeString),
            let targetIDString = userInfo[LocalNotificationMetadata.targetIDKey] as? String,
            let targetID = UUID(uuidString: targetIDString)
        else {
            return nil
        }

        self.init(
            intentID: intentID,
            kind: kind,
            targetType: targetType,
            targetID: targetID,
            deepLink: Self.resolvedDeepLink(from: userInfo)
        )
    }

    private static func resolvedDeepLink(from userInfo: [AnyHashable: Any]) -> String? {
        if let deepLink = (userInfo[LocalNotificationMetadata.deepLinkKey] as? String)?.trimmedOrNil {
            return deepLink
        }
        if let nested = userInfo["mory"] as? [String: Any],
           let deepLink = (nested["deep_link"] as? String)?.trimmedOrNil {
            return deepLink
        }
        return nil
    }
}
