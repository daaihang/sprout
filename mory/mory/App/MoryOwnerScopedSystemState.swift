import Foundation
import UserNotifications

@MainActor
struct MoryOwnerScopedSystemStateCoordinator {
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

        let previousOwnerID = defaults.string(forKey: LocalDataOwnerRegistry.activeOwnerDefaultsKey)
        guard previousOwnerID != ownerID else {
            return
        }

        clearSystemNotifications()
        _ = try? await repository.deleteSpotlightIndex()
        _ = try? await repository.rebuildSpotlightIndex()
        defaults.set(ownerID, forKey: LocalDataOwnerRegistry.activeOwnerDefaultsKey)
    }

    func clearActiveOwnerSystemState(repository: any MoryMemoryRepositorying) async {
        _ = try? await LocalNotificationScheduler().cancelPendingAndScheduledLocalIntents(repository: repository)
        clearSystemNotifications()
        _ = try? await repository.deleteSpotlightIndex()
        defaults.removeObject(forKey: LocalDataOwnerRegistry.activeOwnerDefaultsKey)
    }

    private func clearSystemNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
}
