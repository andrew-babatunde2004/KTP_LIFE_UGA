import Combine
import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deviceToken: String?
    @Published private(set) var pendingDestination: PushNotificationDestination?

    private let tokenDefaultsKey = "apnsDeviceToken"
    private var observerTokens: [NSObjectProtocol] = []

    override init() {
        deviceToken = UserDefaults.standard.string(forKey: tokenDefaultsKey)
        super.init()

        observerTokens.append(NotificationCenter.default.addObserver(
            forName: .apnsDeviceTokenRegistered,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let token = notification.object as? Data else { return }
            Task { @MainActor [weak self] in self?.storeDeviceToken(token) }
        })

        observerTokens.append(NotificationCenter.default.addObserver(
            forName: .pushNotificationTapped,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handle(userInfo: notification.userInfo ?? [:])
            }
        })
    }

    deinit {
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            AuthDebugLog.log("Notification authorization failed: \(error.localizedDescription)")
            await refreshAuthorizationStatus()
            return false
        }
    }

    func registerWithAPNsIfAuthorized() {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral else {
            return
        }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func clearBadge() async {
        do {
            try await UNUserNotificationCenter.current().setBadgeCount(0)
        } catch {
            AuthDebugLog.log("Notification badge reset failed: \(error.localizedDescription)")
        }
    }

    func syncRegistration(using apiService: KTPAPIService) async {
        guard let deviceToken, authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral else {
            return
        }

        do {
            try await apiService.registerNotificationDevice(
                NotificationDeviceRegistration(token: deviceToken, environment: apnsEnvironment)
            )
        } catch is CancellationError {
            return
        } catch {
            // Registration is retried when the token changes or the app becomes active.
            AuthDebugLog.log("Push device registration failed: \(error.localizedDescription)")
        }
    }

    func unregister(using apiService: KTPAPIService) async {
        guard let deviceToken else { return }
        do {
            try await apiService.unregisterNotificationDevice(token: deviceToken)
        } catch {
            // A later sign-out can retry removing the user/device association.
            AuthDebugLog.log("Push device unregister failed: \(error.localizedDescription)")
        }
    }

    func consumePendingDestination() -> PushNotificationDestination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }

    private func storeDeviceToken(_ token: Data) {
        let value = token.map { String(format: "%02x", $0) }.joined()
        guard !value.isEmpty else {
            AuthDebugLog.log("Ignoring an empty APNs device token.")
            return
        }
        deviceToken = value
        UserDefaults.standard.set(value, forKey: tokenDefaultsKey)
    }

    private func handle(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        switch type {
        case "direct_message":
            if let userID = stringValue(userInfo["conversation_user_id"]) {
                pendingDestination = .directMessage(userID: userID)
            }
        case "group_chat_message":
            if let chatID = stringValue(userInfo["group_chat_id"]) {
                pendingDestination = .groupMessage(chat: GroupChatPushDestination(
                    id: chatID,
                    name: stringValue(userInfo["group_chat_name"])
                ))
            }
        case "announcement":
            pendingDestination = .announcement(id: stringValue(userInfo["announcement_id"]))
        case "poll":
            pendingDestination = .poll(id: stringValue(userInfo["poll_id"]))
        case "meeting", "meeting_reminder":
            pendingDestination = .meeting(id: stringValue(userInfo["meeting_id"]))
        case "event", "event_reminder":
            if let eventID = stringValue(userInfo["event_id"]) {
                pendingDestination = .event(eventID: eventID)
            }
        case "interview":
            pendingDestination = .interview
        default:
            break
        }
    }

    private func stringValue(_ value: Any?) -> String? {
        if let value = value as? String, !value.isEmpty { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    private var apnsEnvironment: String {
#if DEBUG
        "development"
#else
        "production"
#endif
    }
}

extension Notification.Name {
    static let apnsDeviceTokenRegistered = Notification.Name("apnsDeviceTokenRegistered")
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
    static let messageThreadShouldRefresh = Notification.Name("messageThreadShouldRefresh")
    static let messageUnreadCountShouldRefresh = Notification.Name("messageUnreadCountShouldRefresh")
}

/// Keeps Apple's delivered-notification list in sync with conversations that
/// the member has actually opened. APNs can deliver several alerts for one
/// thread, while tapping one notification only identifies a single request.
enum MessageNotificationCleaner {
    static func clearDeliveredNotifications(
        for thread: MessageThread,
        using notificationCenter: UNUserNotificationCenter = .current()
    ) async {
        let destination: MessageNotificationDestination
        switch thread {
        case .direct(let conversation):
            destination = .direct(userID: conversation.userId)
        case .group(let chat):
            destination = .group(chatID: chat.id)
        }

        await clearDeliveredNotifications(for: destination, using: notificationCenter)
    }

    static func clearDeliveredNotifications(
        matching userInfo: [AnyHashable: Any],
        using notificationCenter: UNUserNotificationCenter = .current()
    ) async {
        guard let destination = destination(from: userInfo) else { return }
        await clearDeliveredNotifications(for: destination, using: notificationCenter)
    }

    private static func clearDeliveredNotifications(
        for destination: MessageNotificationDestination,
        using notificationCenter: UNUserNotificationCenter
    ) async {
        let delivered = await notificationCenter.deliveredNotifications()
        let identifiers = delivered.compactMap { notification -> String? in
            guard self.destination(from: notification.request.content.userInfo) == destination else {
                return nil
            }
            return notification.request.identifier
        }

        guard !identifiers.isEmpty else { return }
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private static func destination(from userInfo: [AnyHashable: Any]) -> MessageNotificationDestination? {
        switch userInfo["type"] as? String {
        case "direct_message":
            guard let userID = stringValue(userInfo["conversation_user_id"]) else { return nil }
            return .direct(userID: userID)
        case "group_chat_message":
            guard let chatID = stringValue(userInfo["group_chat_id"]) else { return nil }
            return .group(chatID: chatID)
        default:
            return nil
        }
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let value = value as? String, !value.isEmpty { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }
}

private enum MessageNotificationDestination: Equatable {
    case direct(userID: String)
    case group(chatID: String)
}
