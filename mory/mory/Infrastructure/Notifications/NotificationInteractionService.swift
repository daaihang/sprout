import Combine
import Foundation

enum NotificationInteractionAction: String, Codable, Hashable, Sendable {
    case delivered
    case opened
    case dismissed
}

enum NotificationInteractionDestination: String, Codable, Hashable, Sendable {
    case home
    case memories
    case insights
    case search
}

struct NotificationInteractionRoute: Hashable, Sendable {
    var destination: NotificationInteractionDestination
    var deepLink: MoryDeepLinkRoute?
    var kind: NotificationIntentKind
    var targetType: ClarificationTargetType
    var targetID: UUID
}

struct NotificationInteractionEvent: Identifiable, Hashable, Sendable {
    let id: UUID
    var action: NotificationInteractionAction
    var payload: LocalNotificationPayload
    var receivedAt: Date

    init(
        id: UUID = UUID(),
        action: NotificationInteractionAction,
        payload: LocalNotificationPayload,
        receivedAt: Date = .now
    ) {
        self.id = id
        self.action = action
        self.payload = payload
        self.receivedAt = receivedAt
    }

    init?(
        action: NotificationInteractionAction,
        userInfo: [AnyHashable: Any],
        receivedAt: Date = .now
    ) {
        guard let payload = LocalNotificationPayload(userInfo: userInfo) else {
            return nil
        }
        self.init(action: action, payload: payload, receivedAt: receivedAt)
    }
}

struct NotificationInteractionResult: Hashable, Sendable {
    var route: NotificationInteractionRoute?
    var updatedIntent: NotificationIntent?
}

@MainActor
final class NotificationInteractionInbox: ObservableObject {
    static let shared = NotificationInteractionInbox()

    @Published private(set) var latestEvent: NotificationInteractionEvent?

    private init() {}

    func enqueue(_ event: NotificationInteractionEvent) {
        latestEvent = event
    }

    func consume(eventID: UUID) {
        guard latestEvent?.id == eventID else { return }
        latestEvent = nil
    }
}

@MainActor
struct NotificationInteractionService {
    func handle(
        event: NotificationInteractionEvent,
        repository: any MoryMemoryRepositorying,
        now: Date = .now
    ) throws -> NotificationInteractionResult {
        let updatedIntent = try updateIntentStatus(
            for: event,
            repository: repository,
            now: now
        )

        let route: NotificationInteractionRoute?
        switch event.action {
        case .opened:
            route = makeRoute(for: event.payload)
        case .delivered, .dismissed:
            route = nil
        }

        return NotificationInteractionResult(
            route: route,
            updatedIntent: updatedIntent
        )
    }

    func makeRoute(for payload: LocalNotificationPayload) -> NotificationInteractionRoute {
        NotificationInteractionRoute(
            destination: destination(for: payload),
            deepLink: deepLink(for: payload),
            kind: payload.kind,
            targetType: payload.targetType,
            targetID: payload.targetID
        )
    }

    private func updateIntentStatus(
        for event: NotificationInteractionEvent,
        repository: any MoryMemoryRepositorying,
        now: Date
    ) throws -> NotificationIntent? {
        let intents = try repository.fetchNotificationIntents(status: nil, limit: nil)
        guard var intent = intents.first(where: { $0.id == event.payload.intentID }) else {
            return nil
        }

        switch event.action {
        case .delivered:
            if intent.deliveredAt == nil {
                intent.deliveredAt = now
            }
            if intent.status == .pending || intent.status == .scheduled {
                intent.status = .delivered
            }
        case .opened:
            if intent.deliveredAt == nil {
                intent.deliveredAt = now
            }
            if intent.status == .pending || intent.status == .scheduled {
                intent.status = .delivered
            }
        case .dismissed:
            if intent.deliveredAt == nil {
                intent.deliveredAt = now
            }
            intent.dismissedAt = now
            intent.status = .dismissed
        }

        try repository.upsertNotificationIntent(intent)
        return intent
    }

    private func destination(for payload: LocalNotificationPayload) -> NotificationInteractionDestination {
        switch payload.kind {
        case .dailyQuestion, .backgroundDone:
            return .home
        case .revisit:
            switch payload.targetType {
            case .record, .artifact:
                return .memories
            case .question, .entity, .place, .theme, .decision, .chapter, .reflection:
                return .home
            }
        case .repeatedTheme:
            switch payload.targetType {
            case .record, .artifact:
                return .memories
            case .question:
                return .home
            case .entity, .place, .theme, .decision, .chapter, .reflection:
                return .insights
            }
        case .stageForming:
            switch payload.targetType {
            case .chapter, .reflection, .theme, .entity, .place, .decision:
                return .insights
            case .record, .artifact:
                return .memories
            case .question:
                return .home
            }
        }
    }

    private func deepLink(for payload: LocalNotificationPayload) -> MoryDeepLinkRoute? {
        switch payload.targetType {
        case .question:
            return .home(.question(payload.targetID))
        case .record:
            return .memories(.memory(payload.targetID))
        case .chapter:
            return .insights(.arc(payload.targetID))
        case .reflection:
            return .insights(.reflection(payload.targetID))
        case .entity, .place, .theme, .decision:
            return .insights(.entity(payload.targetID))
        case .artifact:
            return nil
        }
    }
}
