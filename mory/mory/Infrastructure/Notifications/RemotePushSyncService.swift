import Foundation
import UIKit

extension Notification.Name {
    static let moryAPNSTokenDidUpdate = Notification.Name("mory.apnsTokenDidUpdate")
    static let moryNotificationPreferencesDidChange = Notification.Name("mory.notificationPreferencesDidChange")
}

enum PushDeviceRegistrationStore {
    private static let apnsTokenKey = "mory.apnsTokenHex"

    static func saveAPNSToken(_ tokenData: Data) {
        let hex = tokenData.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: apnsTokenKey)
        NotificationCenter.default.post(name: .moryAPNSTokenDidUpdate, object: nil)
    }

    static func currentAPNSToken() -> String? {
        let token = UserDefaults.standard.string(forKey: apnsTokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token, !token.isEmpty else { return nil }
        return token
    }

    static func currentDeviceID() -> String {
        if let id = UIDevice.current.identifierForVendor?.uuidString.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
            return id
        }
        return "mory-ios-device"
    }

    static func currentTimezoneID() -> String {
        TimeZone.autoupdatingCurrent.identifier
    }
}

@MainActor
protocol RemotePushSyncing: AnyObject {
    func registerSystemRemoteNotificationsIfNeeded(repository: any MoryMemoryRepositorying)
    func syncRegistrationIfPossible(repository: any MoryMemoryRepositorying, force: Bool) async
    func writeBackInteraction(_ event: NotificationInteractionEvent) async
}

@MainActor
final class RemotePushSyncService: RemotePushSyncing {
    private let apiClient: MoryAPIClient
    private let tokenProvider: MoryAuthTokenProvider
    private var lastRegistrationDigest: String?
    private let isoFormatter: ISO8601DateFormatter

    init(
        apiClient: MoryAPIClient,
        tokenProvider: MoryAuthTokenProvider,
        isoFormatter: ISO8601DateFormatter = ISO8601DateFormatter()
    ) {
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
        self.isoFormatter = isoFormatter
    }

    func registerSystemRemoteNotificationsIfNeeded(repository: any MoryMemoryRepositorying) {
        guard
            let preferences = try? repository.fetchIntelligencePreferences(),
            preferences.notificationPreferences.enabled
        else {
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func syncRegistrationIfPossible(
        repository: any MoryMemoryRepositorying,
        force: Bool = false
    ) async {
        guard let apnsToken = PushDeviceRegistrationStore.currentAPNSToken() else {
            return
        }
        guard let snapshot = makeRegistrationSnapshot(repository: repository, apnsToken: apnsToken) else {
            return
        }
        if !force, snapshot.digest == lastRegistrationDigest {
            return
        }

        do {
            _ = try await sendWithRefresh { bearerToken in
                try await apiClient.registerPushToken(payload: snapshot.payload, bearerToken: bearerToken)
            }
            lastRegistrationDigest = snapshot.digest
        } catch {
            // Keep local workflows uninterrupted when remote registration fails.
        }
    }

    func writeBackInteraction(_ event: NotificationInteractionEvent) async {
        let payload = MoryAPIClient.PushDeliveryWritebackPayload(
            deviceID: PushDeviceRegistrationStore.currentDeviceID(),
            intentID: event.payload.intentID.uuidString,
            action: event.action.rawValue,
            kind: event.payload.kind.rawValue,
            targetType: event.payload.targetType.rawValue,
            targetID: event.payload.targetID.uuidString,
            occurredAt: isoFormatter.string(from: event.receivedAt)
        )

        do {
            _ = try await sendWithRefresh { bearerToken in
                try await apiClient.writeBackPushDelivery(payload: payload, bearerToken: bearerToken)
            }
        } catch {
            // Local notification handling should not fail because writeback is unavailable.
        }
    }

    private func sendWithRefresh<Response: Sendable>(
        _ request: (String) async throws -> Response
    ) async throws -> Response {
        do {
            let token = try await tokenProvider.accessToken()
            return try await request(token)
        } catch MoryAPIClient.APIError.unauthorized {
            await tokenProvider.invalidate()
            let token = try await tokenProvider.accessToken()
            return try await request(token)
        }
    }

    private func makeRegistrationSnapshot(
        repository: any MoryMemoryRepositorying,
        apnsToken: String
    ) -> RemotePushRegistrationSnapshot? {
        guard
            let preferences = try? repository.fetchIntelligencePreferences(),
            let pendingQuestions = try? repository.fetchClarificationQuestions(status: .pending, limit: 64)
        else {
            return nil
        }

        let hasQuestionReady = pendingQuestions.contains { question in
            question.kind == .dailyReflection
        }

        let notificationPreferences = preferences.notificationPreferences
        let payload = MoryAPIClient.PushRegisterPayload(
            deviceID: PushDeviceRegistrationStore.currentDeviceID(),
            apnsToken: apnsToken,
            timezone: PushDeviceRegistrationStore.currentTimezoneID(),
            hasQuestionReady: hasQuestionReady,
            notificationsEnabled: notificationPreferences.enabled,
            dailyQuestionEnabled: notificationPreferences.dailyQuestionEnabled,
            deliveryPace: notificationPreferences.resolvedFrequencyStrategy.rawValue,
            maxPerDay: notificationPreferences.maxPerDay,
            quietStart: formatQuietTime(
                hour: notificationPreferences.quietHoursStartHour,
                minute: notificationPreferences.quietHoursStartMinute
            ),
            quietEnd: formatQuietTime(
                hour: notificationPreferences.quietHoursEndHour,
                minute: notificationPreferences.quietHoursEndMinute
            )
        )

        return RemotePushRegistrationSnapshot(payload: payload)
    }

    private func formatQuietTime(hour: Int?, minute: Int?) -> String? {
        guard let hour else { return nil }
        let resolvedMinute = minute ?? 0
        return String(format: "%02d:%02d", hour, resolvedMinute)
    }
}

private struct RemotePushRegistrationSnapshot {
    let payload: MoryAPIClient.PushRegisterPayload

    var digest: String {
        [
            payload.deviceID,
            payload.apnsToken,
            payload.timezone,
            String(payload.hasQuestionReady),
            String(payload.notificationsEnabled),
            String(payload.dailyQuestionEnabled),
            payload.deliveryPace,
            String(payload.maxPerDay),
            payload.quietStart ?? "",
            payload.quietEnd ?? "",
        ].joined(separator: "|")
    }
}
