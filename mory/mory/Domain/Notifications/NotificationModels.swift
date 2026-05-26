import Foundation

enum NotificationIntentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case analysisReady
    case dailyQuestion
    case reflectionReady
    case debugTest

    var id: String { rawValue }
}

enum NotificationPrivacyLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case generic
    case contextual
    case rich

    var id: String { rawValue }
}

enum NotificationIntentStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending
    case scheduled
    case delivered
    case dismissed
    case blocked
    case inAppOnly

    var id: String { rawValue }
}

enum NotificationDeliveryChannel: String, Codable, CaseIterable, Identifiable, Sendable {
    case local
    case remote

    var id: String { rawValue }
}

enum NotificationTriggerSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case appLaunchRecovery
    case homeForegroundRefresh
    case backgroundRefresh
    case silentPush
    case pipelineCompleted
    case settingsChanged
    case debugManual

    var id: String { rawValue }
}

enum NotificationIntentCreator: String, Codable, CaseIterable, Identifiable, Sendable {
    case orchestrator
    case debug

    var id: String { rawValue }
}

enum NotificationManagementEventKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case generated
    case deduped
    case policyBlocked
    case deliveryError
    case routeError
    case scheduled
    case delivered
    case opened
    case dismissed
    case inAppOnly

    var id: String { rawValue }
}

struct NotificationManagementEvent: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var eventKind: NotificationManagementEventKind
    var intentID: UUID?
    var dedupeKey: String?
    var trigger: NotificationTriggerSource?
    var kind: NotificationIntentKind?
    var targetType: ClarificationTargetType?
    var targetID: UUID?
    var message: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        eventKind: NotificationManagementEventKind,
        intentID: UUID? = nil,
        dedupeKey: String? = nil,
        trigger: NotificationTriggerSource? = nil,
        kind: NotificationIntentKind? = nil,
        targetType: ClarificationTargetType? = nil,
        targetID: UUID? = nil,
        message: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.eventKind = eventKind
        self.intentID = intentID
        self.dedupeKey = dedupeKey
        self.trigger = trigger
        self.kind = kind
        self.targetType = targetType
        self.targetID = targetID
        self.message = message
        self.createdAt = createdAt
    }
}

struct NotificationIntent: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: NotificationIntentKind
    var title: String
    var body: String
    var privacyLevel: NotificationPrivacyLevel
    var targetType: ClarificationTargetType
    var targetID: UUID
    var scheduledAt: Date
    var status: NotificationIntentStatus
    var deliveryChannel: NotificationDeliveryChannel
    var dedupeKey: String
    var deepLink: String?
    var reason: String
    var sourceTrigger: NotificationTriggerSource
    var createdBy: NotificationIntentCreator
    var lastEvaluatedAt: Date
    var blockedReasons: [String]
    var createdAt: Date
    var deliveredAt: Date?
    var openedAt: Date?
    var dismissedAt: Date?

    init(
        id: UUID = UUID(),
        kind: NotificationIntentKind,
        title: String,
        body: String,
        privacyLevel: NotificationPrivacyLevel = .generic,
        targetType: ClarificationTargetType,
        targetID: UUID,
        scheduledAt: Date,
        status: NotificationIntentStatus = .pending,
        deliveryChannel: NotificationDeliveryChannel = .local,
        dedupeKey: String? = nil,
        deepLink: String? = nil,
        reason: String = "",
        sourceTrigger: NotificationTriggerSource = .debugManual,
        createdBy: NotificationIntentCreator = .orchestrator,
        lastEvaluatedAt: Date? = nil,
        blockedReasons: [String] = [],
        createdAt: Date = .now,
        deliveredAt: Date? = nil,
        openedAt: Date? = nil,
        dismissedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.privacyLevel = privacyLevel
        self.targetType = targetType
        self.targetID = targetID
        self.scheduledAt = scheduledAt
        self.status = status
        self.deliveryChannel = deliveryChannel
        self.dedupeKey = dedupeKey ?? NotificationIntent.makeDedupeKey(
            kind: kind,
            targetType: targetType,
            targetID: targetID
        )
        self.deepLink = deepLink
        self.reason = reason
        self.sourceTrigger = sourceTrigger
        self.createdBy = createdBy
        self.lastEvaluatedAt = lastEvaluatedAt ?? createdAt
        self.blockedReasons = blockedReasons
        self.createdAt = createdAt
        self.deliveredAt = deliveredAt
        self.openedAt = openedAt
        self.dismissedAt = dismissedAt
    }

    static func makeDedupeKey(
        kind: NotificationIntentKind,
        targetType: ClarificationTargetType,
        targetID: UUID
    ) -> String {
        "\(kind.rawValue)|\(targetType.rawValue)|\(targetID.uuidString)"
    }
}
