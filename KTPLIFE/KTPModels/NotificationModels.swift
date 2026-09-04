import Foundation

struct NotificationPreferences: Codable, Equatable {
    var directMessagesEnabled: Bool
    var announcementsEnabled: Bool
    var pollsEnabled: Bool
    var meetingsEnabled: Bool
    var eventsEnabled: Bool
    var eventRemindersEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case directMessagesEnabled = "direct_messages_enabled"
        case announcementsEnabled = "announcements_enabled"
        case pollsEnabled = "polls_enabled"
        case meetingsEnabled = "meetings_enabled"
        case eventsEnabled = "events_enabled"
        case eventRemindersEnabled = "event_reminders_enabled"
    }

    init(
        directMessagesEnabled: Bool = true,
        announcementsEnabled: Bool = true,
        pollsEnabled: Bool = true,
        meetingsEnabled: Bool = true,
        eventsEnabled: Bool = true,
        eventRemindersEnabled: Bool = true
    ) {
        self.directMessagesEnabled = directMessagesEnabled
        self.announcementsEnabled = announcementsEnabled
        self.pollsEnabled = pollsEnabled
        self.meetingsEnabled = meetingsEnabled
        self.eventsEnabled = eventsEnabled
        self.eventRemindersEnabled = eventRemindersEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        directMessagesEnabled = try container.decodeIfPresent(Bool.self, forKey: .directMessagesEnabled) ?? true
        announcementsEnabled = try container.decodeIfPresent(Bool.self, forKey: .announcementsEnabled) ?? true
        pollsEnabled = try container.decodeIfPresent(Bool.self, forKey: .pollsEnabled) ?? true
        meetingsEnabled = try container.decodeIfPresent(Bool.self, forKey: .meetingsEnabled) ?? true
        eventsEnabled = try container.decodeIfPresent(Bool.self, forKey: .eventsEnabled) ?? true
        eventRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .eventRemindersEnabled) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(directMessagesEnabled, forKey: .directMessagesEnabled)
        try container.encode(announcementsEnabled, forKey: .announcementsEnabled)
        try container.encode(pollsEnabled, forKey: .pollsEnabled)
        try container.encode(meetingsEnabled, forKey: .meetingsEnabled)
        try container.encode(eventsEnabled, forKey: .eventsEnabled)
        try container.encode(eventRemindersEnabled, forKey: .eventRemindersEnabled)
    }

    static var cached: NotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let preferences = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else {
            return NotificationPreferences()
        }
        return preferences
    }

    func cacheLocally() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static let storageKey = "notificationPreferences"
}

struct NotificationDeviceRegistration: Encodable {
    let token: String
    let platform = "ios"
    let environment: String
}

/// Stores each member's per-group mute choices on this device. A server-side
/// preference route is still required to suppress remote APNs while the app is
/// not running; this preserves the user's selection until that route is added.
enum GroupChatMutePreferences {
    private static let storageKey = "mutedGroupChatIDs"

    static func isMuted(_ chatID: String) -> Bool {
        mutedChatIDs.contains(chatID)
    }

    static func setMuted(_ isMuted: Bool, for chatID: String) {
        var ids = mutedChatIDs
        if isMuted {
            ids.insert(chatID)
        } else {
            ids.remove(chatID)
        }
        UserDefaults.standard.set(Array(ids), forKey: storageKey)
        NotificationCenter.default.post(name: .groupChatMutePreferencesDidChange, object: nil)
    }

    static var mutedChatIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
    }
}

extension Notification.Name {
    static let groupChatMutePreferencesDidChange = Notification.Name("groupChatMutePreferencesDidChange")
}

enum PushNotificationDestination: Equatable {
    case directMessage(userID: String)
    case announcement(id: String?)
    case poll(id: String?)
    case meeting(id: String?)
    case event(eventID: String)
}
