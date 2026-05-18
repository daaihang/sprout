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
    var scheduleReport: LocalNotificationSchedulerReport
    var cancellationReport: LocalNotificationCancellationReport
    var systemAuthorizationRequested: Bool
    var systemAuthorizationGranted: Bool
}

@MainActor
struct NotificationSettingsService {
    private let notificationCenter: any LocalNotificationSchedulingCenter
    private let scheduler: LocalNotificationScheduler
    private let intentPreparationService: NotificationIntentPreparationService

    init(policy: NotificationPolicy = NotificationPolicy()) {
        let center = SystemLocalNotificationCenter()
        self.notificationCenter = center
        self.scheduler = LocalNotificationScheduler(notificationCenter: center, policy: policy)
        self.intentPreparationService = NotificationIntentPreparationService(policy: policy)
    }

    init(
        notificationCenter: any LocalNotificationSchedulingCenter,
        policy: NotificationPolicy = NotificationPolicy()
    ) {
        self.notificationCenter = notificationCenter
        self.scheduler = LocalNotificationScheduler(notificationCenter: notificationCenter, policy: policy)
        self.intentPreparationService = NotificationIntentPreparationService(policy: policy)
    }

    func loadSnapshot(
        repository: any MoryMemoryRepositorying
    ) async throws -> NotificationSettingsSnapshot {
        try await makeSnapshot(repository: repository)
    }

    func setNotificationsEnabled(
        _ enabled: Bool,
        repository: any MoryMemoryRepositorying,
        requestSystemAuthorization: Bool = true,
        now: Date = .now
    ) async throws -> NotificationSettingsUpdateResult {
        try await updatePreferences(
            repository: repository,
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
        now: Date = .now,
        requestSystemAuthorization: Bool = false,
        mutation: (inout IntelligencePreferences) -> Void
    ) async throws -> NotificationSettingsUpdateResult {
        var preferences = try repository.fetchIntelligencePreferences()
        mutation(&preferences)
        preferences.updatedAt = now
        try repository.saveIntelligencePreferences(preferences)

        var authorizationRequested = false
        var authorizationGranted = false
        if preferences.notificationPreferences.enabled, requestSystemAuthorization {
            let authorization = try await requestAuthorizationIfNeeded()
            authorizationRequested = authorization.requested
            authorizationGranted = authorization.granted
        }

        let cancellationReport: LocalNotificationCancellationReport
        let scheduleReport: LocalNotificationSchedulerReport
        if preferences.notificationPreferences.enabled {
            _ = try intentPreparationService.prepareDailyQuestionIntentIfNeeded(
                repository: repository,
                now: now
            )
            cancellationReport = .empty
            scheduleReport = try await scheduler.schedulePendingIntents(
                repository: repository,
                now: now,
                requestAuthorizationIfNeeded: false
            )
        } else {
            cancellationReport = try await scheduler.cancelPendingAndScheduledLocalIntents(
                repository: repository,
                now: now
            )
            scheduleReport = .empty
        }

        return NotificationSettingsUpdateResult(
            snapshot: try await makeSnapshot(repository: repository),
            scheduleReport: scheduleReport,
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
