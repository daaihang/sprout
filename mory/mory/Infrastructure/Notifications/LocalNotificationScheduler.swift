import Foundation
import UserNotifications

enum LocalNotificationAuthorizationState: String, Codable, Hashable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var allowsScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        }
    }
}

struct LocalNotificationScheduleRequest: Hashable, Sendable {
    var identifier: String
    var title: String
    var body: String
    var scheduledAt: Date
    var userInfo: [String: String]
}

@MainActor
protocol LocalNotificationSchedulingCenter: AnyObject {
    func authorizationState() async -> LocalNotificationAuthorizationState
    func requestAuthorization() async throws -> Bool
    func add(_ request: LocalNotificationScheduleRequest) async throws
    func removePendingRequests(withIdentifiers identifiers: [String]) async
}

@MainActor
final class SystemLocalNotificationCenter: LocalNotificationSchedulingCenter {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        Self.registerMoryNotificationCategories(on: center)
    }

    static func registerMoryNotificationCategories(on center: UNUserNotificationCenter = .current()) {
        let category = UNNotificationCategory(
            identifier: LocalNotificationMetadata.categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    func authorizationState() async -> LocalNotificationAuthorizationState {
        let settings = await center.notificationSettings()
        return LocalNotificationAuthorizationState(settings.authorizationStatus)
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func add(_ request: LocalNotificationScheduleRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.userInfo = request.userInfo
        content.categoryIdentifier = LocalNotificationMetadata.categoryIdentifier

        let timeInterval = max(1, request.scheduledAt.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let notificationRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        )
        try await center.add(notificationRequest)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

enum LocalNotificationSchedulerSkipReason: String, Codable, Hashable, Sendable {
    case unsupportedChannel
    case authorizationRequired
    case authorizationDenied
    case authorizationRequestDenied
    case policyBlocked
    case scheduleFailed
}

struct LocalNotificationSchedulerItemResult: Hashable, Sendable {
    var intentID: UUID
    var scheduled: Bool
    var skipReason: LocalNotificationSchedulerSkipReason?
    var policyBlockReasons: [NotificationPolicyBlockReason]

    init(
        intentID: UUID,
        scheduled: Bool,
        skipReason: LocalNotificationSchedulerSkipReason? = nil,
        policyBlockReasons: [NotificationPolicyBlockReason] = []
    ) {
        self.intentID = intentID
        self.scheduled = scheduled
        self.skipReason = skipReason
        self.policyBlockReasons = policyBlockReasons
    }
}

struct LocalNotificationSchedulerReport: Hashable, Sendable {
    var results: [LocalNotificationSchedulerItemResult]

    var scheduledCount: Int {
        results.filter(\.scheduled).count
    }

    var skippedCount: Int {
        results.count - scheduledCount
    }

    static var empty: LocalNotificationSchedulerReport {
        LocalNotificationSchedulerReport(results: [])
    }
}

struct LocalNotificationCancellationReport: Hashable, Sendable {
    var cancelledCount: Int

    static var empty: LocalNotificationCancellationReport {
        LocalNotificationCancellationReport(cancelledCount: 0)
    }
}

@MainActor
struct LocalNotificationScheduler {
    private let notificationCenter: any LocalNotificationSchedulingCenter
    private let policy: NotificationPolicy

    init(policy: NotificationPolicy = NotificationPolicy()) {
        self.notificationCenter = SystemLocalNotificationCenter()
        self.policy = policy
    }

    init(
        notificationCenter: any LocalNotificationSchedulingCenter,
        policy: NotificationPolicy = NotificationPolicy()
    ) {
        self.notificationCenter = notificationCenter
        self.policy = policy
    }

    func schedulePendingIntents(
        repository: any MoryMemoryRepositorying,
        now: Date = .now,
        limit: Int? = 20,
        requestAuthorizationIfNeeded: Bool = false
    ) async throws -> LocalNotificationSchedulerReport {
        let pendingIntents = try repository.fetchNotificationIntents(status: .pending, limit: limit)
        guard !pendingIntents.isEmpty else {
            return .empty
        }

        let authorization = try await resolvedAuthorization(
            requestAuthorizationIfNeeded: requestAuthorizationIfNeeded
        )
        guard authorization.state.allowsScheduling else {
            return LocalNotificationSchedulerReport(
                results: pendingIntents.map { intent in
                    skippedResult(for: intent, reason: skipReason(for: authorization))
                }
            )
        }

        let preferences = try repository.fetchIntelligencePreferences()
        let flags = try repository.fetchV6FeatureFlags()
        let existingIntents = try repository.fetchNotificationIntents(status: nil, limit: nil)
        var scheduledThisRun: [NotificationIntent] = []
        var results: [LocalNotificationSchedulerItemResult] = []

        for intent in pendingIntents {
            guard intent.deliveryChannel == .local else {
                results.append(skippedResult(for: intent, reason: .unsupportedChannel))
                continue
            }

            let policyExistingIntents = existingIntents
                .filter { $0.id != intent.id && $0.status != .pending }
                + scheduledThisRun
            let decision = policy.evaluate(
                intent: intent,
                existingIntents: policyExistingIntents,
                preferences: preferences,
                flags: flags,
                now: now
            )

            guard let approvedIntent = decision.approvedIntent else {
                results.append(
                    skippedResult(
                        for: intent,
                        reason: .policyBlocked,
                        policyBlockReasons: decision.blockReasons
                    )
                )
                continue
            }

            do {
                try await notificationCenter.add(scheduleRequest(for: approvedIntent))
                var scheduledIntent = approvedIntent
                scheduledIntent.status = .scheduled
                try repository.upsertNotificationIntent(scheduledIntent)
                scheduledThisRun.append(scheduledIntent)
                results.append(LocalNotificationSchedulerItemResult(intentID: scheduledIntent.id, scheduled: true))
            } catch {
                results.append(skippedResult(for: intent, reason: .scheduleFailed))
            }
        }

        return LocalNotificationSchedulerReport(results: results)
    }

    func cancelPendingAndScheduledLocalIntents(
        repository: any MoryMemoryRepositorying,
        now: Date = .now
    ) async throws -> LocalNotificationCancellationReport {
        let cancellableIntents = try repository.fetchNotificationIntents(status: nil, limit: nil)
            .filter { intent in
                intent.deliveryChannel == .local
                    && (intent.status == .pending || intent.status == .scheduled)
            }
        guard !cancellableIntents.isEmpty else {
            return .empty
        }

        await notificationCenter.removePendingRequests(
            withIdentifiers: cancellableIntents.map(LocalNotificationMetadata.requestIdentifier(for:))
        )

        for intent in cancellableIntents {
            var dismissedIntent = intent
            dismissedIntent.status = .dismissed
            dismissedIntent.dismissedAt = now
            try repository.upsertNotificationIntent(dismissedIntent)
        }

        return LocalNotificationCancellationReport(cancelledCount: cancellableIntents.count)
    }

    private func resolvedAuthorization(
        requestAuthorizationIfNeeded: Bool
    ) async throws -> AuthorizationResolution {
        let currentState = await notificationCenter.authorizationState()
        guard currentState == .notDetermined, requestAuthorizationIfNeeded else {
            return AuthorizationResolution(state: currentState)
        }

        let granted = try await notificationCenter.requestAuthorization()
        guard granted else {
            return AuthorizationResolution(state: .denied, requestDenied: true)
        }

        let refreshedState = await notificationCenter.authorizationState()
        return AuthorizationResolution(
            state: refreshedState == .notDetermined ? .authorized : refreshedState
        )
    }

    private func skipReason(for authorization: AuthorizationResolution) -> LocalNotificationSchedulerSkipReason {
        if authorization.requestDenied {
            return .authorizationRequestDenied
        }

        switch authorization.state {
        case .notDetermined:
            return .authorizationRequired
        case .denied:
            return .authorizationDenied
        case .authorized, .provisional, .ephemeral:
            return .scheduleFailed
        }
    }

    private func skippedResult(
        for intent: NotificationIntent,
        reason: LocalNotificationSchedulerSkipReason,
        policyBlockReasons: [NotificationPolicyBlockReason] = []
    ) -> LocalNotificationSchedulerItemResult {
        LocalNotificationSchedulerItemResult(
            intentID: intent.id,
            scheduled: false,
            skipReason: reason,
            policyBlockReasons: policyBlockReasons
        )
    }

    private func scheduleRequest(for intent: NotificationIntent) -> LocalNotificationScheduleRequest {
        LocalNotificationScheduleRequest(
            identifier: LocalNotificationMetadata.requestIdentifier(for: intent),
            title: intent.title,
            body: intent.body,
            scheduledAt: intent.scheduledAt,
            userInfo: LocalNotificationMetadata.userInfo(for: intent)
        )
    }
}

private struct AuthorizationResolution {
    var state: LocalNotificationAuthorizationState
    var requestDenied: Bool = false
}

private extension LocalNotificationAuthorizationState {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        @unknown default:
            self = .denied
        }
    }
}
