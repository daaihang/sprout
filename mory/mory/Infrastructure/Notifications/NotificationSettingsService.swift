import Foundation

struct NotificationSettingsSnapshot: Hashable, Sendable {
    var preferences: IntelligencePreferences
    var featureFlags: V6FeatureFlags
    var authorizationState: LocalNotificationAuthorizationState

    var systemNotificationsAllowed: Bool {
        authorizationState.allowsScheduling
    }

    var canScheduleLocalNotifications: Bool {
        preferences.notificationPreferences.enabled
            && featureFlags.localNotifications
            && systemNotificationsAllowed
    }
}

struct NotificationSettingsUpdateResult: Hashable, Sendable {
    var snapshot: NotificationSettingsSnapshot
    var notificationReport: NotificationOrchestrationReport
    var cancellationReport: LocalNotificationCancellationReport
    var systemAuthorizationRequested: Bool
    var systemAuthorizationGranted: Bool
}

@MainActor
struct NotificationSettingsService {
    private let notificationCenter: any LocalNotificationSchedulingCenter
    private let scheduler: LocalNotificationScheduler

    init() {
        let center = SystemLocalNotificationCenter()
        self.notificationCenter = center
        self.scheduler = LocalNotificationScheduler(notificationCenter: center)
    }

    init(notificationCenter: any LocalNotificationSchedulingCenter) {
        self.notificationCenter = notificationCenter
        self.scheduler = LocalNotificationScheduler(notificationCenter: notificationCenter)
    }

    func loadSnapshot(
        repository: any MoryMemoryRepositorying
    ) async throws -> NotificationSettingsSnapshot {
        try await makeSnapshot(repository: repository)
    }

    func setNotificationsEnabled(
        _ enabled: Bool,
        repository: any MoryMemoryRepositorying,
        notificationOrchestrator: NotificationOrchestrator,
        requestSystemAuthorization: Bool = true,
        now: Date = .now
    ) async throws -> NotificationSettingsUpdateResult {
        try await updatePreferences(
            repository: repository,
            notificationOrchestrator: notificationOrchestrator,
            now: now,
            requestSystemAuthorization: requestSystemAuthorization
        ) { preferences in
            preferences.notificationPreferences.enabled = enabled
            if enabled {
                preferences.dailyQuestionsEnabled = true
                preferences.notificationPreferences.dailyQuestionEnabled = true
            }
        }
    }

    func updatePreferences(
        repository: any MoryMemoryRepositorying,
        notificationOrchestrator: NotificationOrchestrator,
        now: Date = .now,
        requestSystemAuthorization: Bool = false,
        mutation: (inout IntelligencePreferences) -> Void
    ) async throws -> NotificationSettingsUpdateResult {
        var preferences = try repository.fetchIntelligencePreferences()
        mutation(&preferences)
        preferences.updatedAt = now
        try repository.saveIntelligencePreferences(preferences)
        NotificationCenter.default.post(name: .moryNotificationPreferencesDidChange, object: nil)

        var authorizationRequested = false
        var authorizationGranted = false
        if preferences.notificationPreferences.enabled, requestSystemAuthorization {
            let authorization = try await requestAuthorizationIfNeeded()
            authorizationRequested = authorization.requested
            authorizationGranted = authorization.granted
        }

        let cancellationReport: LocalNotificationCancellationReport
        let notificationReport: NotificationOrchestrationReport
        if preferences.notificationPreferences.enabled {
            cancellationReport = .empty
            notificationReport = try await notificationOrchestrator.orchestrate(
                trigger: .settingsChanged,
                repository: repository,
                now: now
            )
        } else {
            cancellationReport = try await scheduler.cancelPendingAndScheduledLocalIntents(
                repository: repository,
                now: now
            )
            notificationReport = .empty
        }

        return NotificationSettingsUpdateResult(
            snapshot: try await makeSnapshot(repository: repository),
            notificationReport: notificationReport,
            cancellationReport: cancellationReport,
            systemAuthorizationRequested: authorizationRequested,
            systemAuthorizationGranted: authorizationGranted
        )
    }

    private func requestAuthorizationIfNeeded() async throws -> AuthorizationRequestResult {
        let currentState = await notificationCenter.authorizationState()
        guard currentState == .notDetermined else {
            return AuthorizationRequestResult(
                requested: false,
                granted: currentState.allowsScheduling
            )
        }

        let granted = try await notificationCenter.requestAuthorization()
        return AuthorizationRequestResult(requested: true, granted: granted)
    }

    private func makeSnapshot(
        repository: any MoryMemoryRepositorying
    ) async throws -> NotificationSettingsSnapshot {
        NotificationSettingsSnapshot(
            preferences: try repository.fetchIntelligencePreferences(),
            featureFlags: try repository.fetchV6FeatureFlags(),
            authorizationState: await notificationCenter.authorizationState()
        )
    }
}

private struct AuthorizationRequestResult {
    var requested: Bool
    var granted: Bool
}
