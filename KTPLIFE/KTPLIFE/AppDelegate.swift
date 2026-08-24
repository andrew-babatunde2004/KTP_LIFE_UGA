import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationCenter.default.post(name: .apnsDeviceTokenRegistered, object: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AuthDebugLog.log("APNs registration failed: \(error.localizedDescription)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        if isMessageNotification(userInfo) {
            NotificationCenter.default.post(
                name: .messageThreadShouldRefresh,
                object: nil,
                userInfo: userInfo
            )
            // `willPresent` is called only while the app is in the foreground.
            // Refresh the active message UI without showing a redundant banner,
            // playing a sound, or changing the badge.
            return []
        }

        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        NotificationCenter.default.post(
            name: .pushNotificationTapped,
            object: nil,
            userInfo: response.notification.request.content.userInfo
        )
    }

    private func isMessageNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        ["direct_message", "group_chat_message"].contains(userInfo["type"] as? String)
    }
}
