import Foundation

struct NotificationPreferences: Codable, Equatable {
    var directMessagesEnabled: Bool
    var eventsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case directMessagesEnabled = "direct_messages_enabled"
        case eventsEnabled = "events_enabled"
    }
}

struct NotificationDeviceRegistration: Encodable {
    let token: String
    let platform = "ios"
    let environment: String
}

enum PushNotificationDestination: Equatable {
    case directMessage(userID: String)
    case event(eventID: String)
}
