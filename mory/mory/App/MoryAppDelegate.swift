import UIKit
import UserNotifications

final class MoryAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let backgroundTaskCoordinator = BackgroundTaskCoordinator()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        SystemLocalNotificationCenter.registerMoryNotificationCategories(on: center)
        center.delegate = self
        backgroundTaskCoordinator.registerTasks()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushDeviceRegistrationStore.saveAPNSToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("APNs registration failed: \(error.localizedDescription)")
        #endif
    }

    // MARK: - Silent push / background fetch

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            guard let repo = backgroundTaskCoordinator.repository else {
                completionHandler(.noData)
                return
            }
            _ = try? NotificationIntentPreparationService().prepareNextIntentIfNeeded(repository: repo)
            _ = try? await LocalNotificationScheduler().schedulePendingIntents(
                repository: repo,
                requestAuthorizationIfNeeded: false
            )
            completionHandler(.newData)
        }
    }

    // MARK: - Background URLSession

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == MoryAPIClient.backgroundSessionID else {
            completionHandler()
            return
        }
        BackgroundURLSessionCompletionStore.shared.handler = completionHandler
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await enqueueInteraction(
            action: .delivered,
            userInfo: notification.request.content.userInfo
        )
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action: NotificationInteractionAction =
            response.actionIdentifier == UNNotificationDismissActionIdentifier ? .dismissed : .opened
        await enqueueInteraction(
            action: action,
            userInfo: response.notification.request.content.userInfo
        )
    }

    private func enqueueInteraction(
        action: NotificationInteractionAction,
        userInfo: [AnyHashable: Any]
    ) async {
        guard let event = NotificationInteractionEvent(action: action, userInfo: userInfo) else {
            return
        }
        await MainActor.run {
            NotificationInteractionInbox.shared.enqueue(event)
        }
    }
}
