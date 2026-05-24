import Foundation
import OSLog
import UserNotifications

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mory", category: "app")

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
        do {
            try await repository.deleteSpotlightIndex()
        } catch {
            log.warning("Spotlight delete failed on owner switch: \(error)")
        }
        do {
            try await repository.rebuildSpotlightIndex()
        } catch {
            log.warning("Spotlight rebuild failed on owner switch: \(error)")
        }
        defaults.set(ownerID, forKey: LocalDataOwnerRegistry.activeOwnerDefaultsKey)
    }

    func clearActiveOwnerSystemState(repository: any MoryMemoryRepositorying) async {
        do {
            try await LocalNotificationScheduler().cancelPendingAndScheduledLocalIntents(repository: repository)
        } catch {
            log.warning("Cancel pending notifications failed on owner clear: \(error)")
        }
        clearSystemNotifications()
        do {
            try await repository.deleteSpotlightIndex()
        } catch {
            log.warning("Spotlight delete failed on owner clear: \(error)")
        }
        defaults.removeObject(forKey: LocalDataOwnerRegistry.activeOwnerDefaultsKey)
    }

    private func clearSystemNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
}
