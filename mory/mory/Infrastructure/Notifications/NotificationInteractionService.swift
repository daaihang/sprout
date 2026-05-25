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

    @Published private(set) var currentEvent: NotificationInteractionEvent?
    @Published private(set) var queuedCount = 0

    private var queue: [NotificationInteractionEvent] = []

    private init() {}

    func enqueue(_ event: NotificationInteractionEvent) {
        queue.append(event)
        queuedCount = queue.count
        if currentEvent == nil {
            currentEvent = queue.first
        }
    }

    func consume(eventID: UUID) {
        guard queue.first?.id == eventID else { return }
        queue.removeFirst()
        queuedCount = queue.count
        currentEvent = queue.first
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
            route = try makeRoute(for: event.payload, repository: repository)
        case .delivered, .dismissed:
            route = nil
        }

        return NotificationInteractionResult(
            route: route,
            updatedIntent: updatedIntent
        )
    }

    func makeRoute(
        for payload: LocalNotificationPayload,
        repository: any MoryMemoryRepositorying
    ) throws -> NotificationInteractionRoute {
        NotificationInteractionRoute(
            destination: try destination(for: payload, repository: repository),
            deepLink: try deepLink(for: payload, repository: repository),
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

    private func destination(
        for payload: LocalNotificationPayload,
        repository: any MoryMemoryRepositorying
    ) throws -> NotificationInteractionDestination {
        if let deepLink = try deepLink(for: payload, repository: repository) {
            switch deepLink {
            case .homeRoot:
                return .home
            case .home:
                return .home
            case .memories:
                return .memories
            case .insights:
                return .insights
            case .search:
                return .search
            }
        }

        switch payload.kind {
        case .debugTest:
            return .home
        case .dailyQuestion:
            return .home
        case .analysisReady:
            switch payload.targetType {
            case .record, .artifact:
                return .memories
            case .question:
                return .home
            case .entity, .place, .theme, .decision, .chapter, .reflection:
                return .insights
            }
        case .reflectionReady:
            return .insights
        }
    }

    private func deepLink(
        for payload: LocalNotificationPayload,
        repository: any MoryMemoryRepositorying
    ) throws -> MoryDeepLinkRoute? {
        if let string = payload.deepLink?.trimmedOrNil,
           let parsed = MoryDeepLinkRoute.parse(string) {
            return parsed
        }

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
            guard let artifact = try repository.fetchArtifact(id: payload.targetID) else {
                return nil
            }
            return .memories(.memory(artifact.recordID))
        }
    }

}
