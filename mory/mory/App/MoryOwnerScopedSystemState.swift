import Foundation
import UserNotifications

@MainActor
struct MoryOwnerScopedSystemStateCoordinator {
    private static let lastPreparedOwnerIDKey = "mory.localData.lastPreparedOwnerID.v1"

    private let defaults: UserDefaults
    private let notificationCenter: UNUserNotificationCenter

    init(
        defaults: UserDefaults = .standard,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    func prepareActiveOwner(
        ownerID: String,
        repository: any MoryMemoryRepositorying,
        remotePushSyncService: any RemotePushSyncing
    ) async {
        remotePushSyncService.prepareForLocalDataOwner(ownerID)

        let previousOwnerID = defaults.string(forKey: Self.lastPreparedOwnerIDKey)
        guard previousOwnerID != ownerID else {
            return
        }

        clearSystemNotifications()
        _ = try? await repository.deleteSpotlightIndex()
        _ = try? await repository.rebuildSpotlightIndex()
        defaults.set(ownerID, forKey: Self.lastPreparedOwnerIDKey)
    }

    func clearActiveOwnerSystemState(repository: any MoryMemoryRepositorying) async {
        _ = try? await LocalNotificationScheduler().cancelPendingAndScheduledLocalIntents(repository: repository)
        clearSystemNotifications()
        _ = try? await repository.deleteSpotlightIndex()
        defaults.removeObject(forKey: Self.lastPreparedOwnerIDKey)
    }

    private func clearSystemNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
}
