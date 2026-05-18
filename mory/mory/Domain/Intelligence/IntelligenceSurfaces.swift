import Foundation

enum HomeBoardSignalKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case clarificationQuestion
    case dailyQuestion
    case revisit
    case chapterCandidate
    case entityProfile
    case contextCluster

    var id: String { rawValue }
}

struct HomeBoardSignal: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: HomeBoardSignalKind
    var targetType: ClarificationTargetType
    var targetID: UUID
    var sourceRecordIDs: [UUID]
    var title: String
    var subtitle: String
    var priority: Double
    var reason: String
    var suggestedWidthColumns: Int
    var suggestedHeightUnits: Int
    var createdAt: Date
    var expiresAt: Date?

    init(
        id: UUID = UUID(),
        kind: HomeBoardSignalKind,
        targetType: ClarificationTargetType,
        targetID: UUID,
        sourceRecordIDs: [UUID] = [],
        title: String,
        subtitle: String,
        priority: Double = 0,
        reason: String,
        suggestedWidthColumns: Int = 2,
        suggestedHeightUnits: Int = 1,
        createdAt: Date = .now,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.targetType = targetType
        self.targetID = targetID
        self.sourceRecordIDs = sourceRecordIDs
        self.title = title
        self.subtitle = subtitle
        self.priority = priority
        self.reason = reason
        self.suggestedWidthColumns = max(1, suggestedWidthColumns)
        self.suggestedHeightUnits = max(1, suggestedHeightUnits)
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}

enum NotificationIntentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case backgroundDone
    case dailyQuestion
    case repeatedTheme
    case stageForming
    case revisit

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

    var id: String { rawValue }
}

enum NotificationDeliveryChannel: String, Codable, CaseIterable, Identifiable, Sendable {
    case local
    case remote

    var id: String { rawValue }
}

struct NotificationIntent: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: NotificationIntentKind
    var title: String
    var body: String
    var privacyLevel: NotificationPrivacyLevel
    var targetType: ClarificationTargetType
    var targetID: UUID
    var scheduledAt: Date
    var status: NotificationIntentStatus
    var deliveryChannel: NotificationDeliveryChannel
    var createdAt: Date
    var deliveredAt: Date?
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
        createdAt: Date = .now,
        deliveredAt: Date? = nil,
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
        self.createdAt = createdAt
        self.deliveredAt = deliveredAt
        self.dismissedAt = dismissedAt
    }
}

