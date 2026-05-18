import Foundation
import UIKit

extension Notification.Name {
    static let moryAPNSTokenDidUpdate = Notification.Name("mory.apnsTokenDidUpdate")
    static let moryNotificationPreferencesDidChange = Notification.Name("mory.notificationPreferencesDidChange")
}

enum PushDeviceRegistrationStore {
    private static let apnsTokenKey = "mory.apnsTokenHex"
    private static let registrationDigestKey = "mory.remotePush.lastRegistrationDigest"
    private static let pendingWritebacksKey = "mory.remotePush.pendingWritebacks"

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

    static func lastRegistrationDigest() -> String? {
        UserDefaults.standard.string(forKey: registrationDigestKey)?.trimmedOrNil
    }

    static func saveLastRegistrationDigest(_ digest: String?) {
        UserDefaults.standard.set(digest, forKey: registrationDigestKey)
    }

    fileprivate static func loadPendingWritebacks() -> [StoredPushDeliveryWriteback] {
        guard
            let data = UserDefaults.standard.data(forKey: pendingWritebacksKey),
            let decoded = try? JSONDecoder().decode([StoredPushDeliveryWriteback].self, from: data)
        else {
            return []
        }
        return decoded
    }

    static func enqueuePendingWriteback(_ payload: MoryAPIClient.PushDeliveryWritebackPayload) {
        var writebacks = loadPendingWritebacks()
        if !writebacks.contains(where: { $0.payload == payload }) {
            writebacks.append(StoredPushDeliveryWriteback(payload: payload))
        }
        savePendingWritebacks(writebacks)
    }

    static func removePendingWritebacks(withIDs ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let remaining = loadPendingWritebacks().filter { !ids.contains($0.id) }
        savePendingWritebacks(remaining)
    }

    private static func savePendingWritebacks(_ writebacks: [StoredPushDeliveryWriteback]) {
        guard let data = try? JSONEncoder().encode(writebacks) else { return }
        UserDefaults.standard.set(data, forKey: pendingWritebacksKey)
    }

    #if DEBUG
    static func resetForTests() {
        UserDefaults.standard.removeObject(forKey: apnsTokenKey)
        UserDefaults.standard.removeObject(forKey: registrationDigestKey)
        UserDefaults.standard.removeObject(forKey: pendingWritebacksKey)
    }

    static func pendingWritebackCountForTests() -> Int {
        loadPendingWritebacks().count
    }
    #endif
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
        self.lastRegistrationDigest = PushDeviceRegistrationStore.lastRegistrationDigest()
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
            await flushPendingWritebacksIfPossible()
            return
        }

        do {
            _ = try await sendWithRefresh { bearerToken in
                try await apiClient.registerPushToken(payload: snapshot.payload, bearerToken: bearerToken)
            }
            lastRegistrationDigest = snapshot.digest
            PushDeviceRegistrationStore.saveLastRegistrationDigest(snapshot.digest)
            await flushPendingWritebacksIfPossible()
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
            try await sendWriteback(payload)
        } catch {
            PushDeviceRegistrationStore.enqueuePendingWriteback(payload)
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
            let flags = try? repository.fetchV6FeatureFlags(),
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
            backgroundDoneEnabled: notificationPreferences.backgroundDoneEnabled,
            dailyQuestionEnabled: notificationPreferences.dailyQuestionEnabled,
            repeatedThemeEnabled: notificationPreferences.repeatedThemeEnabled,
            stageFormingEnabled: notificationPreferences.stageFormingEnabled,
            revisitEnabled: notificationPreferences.revisitEnabled,
            deliveryPace: notificationPreferences.resolvedFrequencyStrategy.rawValue,
            maxPerDay: notificationPreferences.maxPerDay,
            minimumMinutesBetweenNotifications: notificationPreferences.resolvedMinimumMinutesBetweenNotifications,
            quietStart: formatQuietTime(
                hour: notificationPreferences.quietHoursStartHour,
                minute: notificationPreferences.quietHoursStartMinute
            ),
            quietEnd: formatQuietTime(
                hour: notificationPreferences.quietHoursEndHour,
                minute: notificationPreferences.quietHoursEndMinute
            ),
            richPreviewsEnabled: notificationPreferences.richPreviewsEnabled,
            localIntelligenceEnabled: preferences.localIntelligenceEnabled,
            cloudIntelligenceEnabled: preferences.cloudIntelligenceEnabled,
            semanticSearchEnabled: flags.semanticSearch,
            homeSuggestionsEnabled: preferences.homeSuggestionsEnabled
        )

        return RemotePushRegistrationSnapshot(payload: payload)
    }

    private func formatQuietTime(hour: Int?, minute: Int?) -> String? {
        guard let hour else { return nil }
        let resolvedMinute = minute ?? 0
        return String(format: "%02d:%02d", hour, resolvedMinute)
    }

    private func sendWriteback(
        _ payload: MoryAPIClient.PushDeliveryWritebackPayload
    ) async throws {
        _ = try await sendWithRefresh { bearerToken in
            try await apiClient.writeBackPushDelivery(payload: payload, bearerToken: bearerToken)
        }
    }

    private func flushPendingWritebacksIfPossible() async {
        let pending = PushDeviceRegistrationStore.loadPendingWritebacks()
        guard !pending.isEmpty else { return }

        var acknowledgedIDs = Set<UUID>()
        for item in pending {
            do {
                try await sendWriteback(item.payload)
                acknowledgedIDs.insert(item.id)
            } catch {
                continue
            }
        }

        PushDeviceRegistrationStore.removePendingWritebacks(withIDs: acknowledgedIDs)
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
            String(payload.backgroundDoneEnabled),
            String(payload.dailyQuestionEnabled),
            String(payload.repeatedThemeEnabled),
            String(payload.stageFormingEnabled),
            String(payload.revisitEnabled),
            payload.deliveryPace,
            String(payload.maxPerDay),
            String(payload.minimumMinutesBetweenNotifications),
            payload.quietStart ?? "",
            payload.quietEnd ?? "",
            String(payload.richPreviewsEnabled),
            String(payload.localIntelligenceEnabled),
            String(payload.cloudIntelligenceEnabled),
            String(payload.semanticSearchEnabled),
            String(payload.homeSuggestionsEnabled),
        ].joined(separator: "|")
    }
}

fileprivate struct StoredPushDeliveryWriteback: Identifiable, Codable, Equatable {
    let id: UUID
    let payload: MoryAPIClient.PushDeliveryWritebackPayload

    init(id: UUID = UUID(), payload: MoryAPIClient.PushDeliveryWritebackPayload) {
        self.id = id
        self.payload = payload
    }
}
