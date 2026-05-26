import OSLog
import Sentry
import UIKit
import UserNotifications

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mory", category: "app")

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
        log.warning("APNs registration failed: \(error.localizedDescription)")
    }

    // MARK: - Silent push / background fetch

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            let report = await backgroundTaskCoordinator.handle(
                trigger: BackgroundTrigger(kind: .silentPush, source: "APNs")
            )
            if let report, !report.errors.isEmpty {
                log.error("Silent push background work failed: \(report.errors.joined(separator: "; "))")
            }
            completionHandler(report == nil ? .noData : .newData)
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
        Task { @MainActor in
            _ = await backgroundTaskCoordinator.handle(
                trigger: BackgroundTrigger(
                    kind: .backgroundURLSessionCompleted,
                    source: "URLSession",
                    metadata: ["identifier": identifier]
                )
            )
        }
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
