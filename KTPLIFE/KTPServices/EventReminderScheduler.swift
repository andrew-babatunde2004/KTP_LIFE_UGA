import Foundation
import UserNotifications

/// Schedules a device-local fallback for upcoming events and meetings.
///
/// The backend remains the source of truth for remote APNs reminders. Local
/// notifications ensure members who have recently opened the app still receive
/// the standard reminders while server scheduling is being deployed.
final class EventReminderScheduler {
    private enum Reminder: CaseIterable {
        static let eventPrefix = "ktp.reminder.event."
        static let meetingPrefix = "ktp.reminder.meeting."
        static let maximumPendingReminders = 60

        case twoHours
        case thirtyMinutes

        var leadTime: TimeInterval {
            switch self {
            case .twoHours: 2 * 60 * 60
            case .thirtyMinutes: 30 * 60
            }
        }

        var identifierSuffix: String {
            switch self {
            case .twoHours: "two-hours"
            case .thirtyMinutes: "thirty-minutes"
            }
        }

        var bodyPrefix: String {
            switch self {
            case .twoHours: "Starts in 2 hours"
            case .thirtyMinutes: "Starts in 30 minutes"
            }
        }
    }

    private let notificationCenter: UNUserNotificationCenter

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    func sync(events: [CalendarEvent]) async {
        let preferences = NotificationPreferences.cached
        guard preferences.eventsEnabled, preferences.eventRemindersEnabled else {
            await removePendingReminders(withPrefix: Reminder.eventPrefix)
            return
        }

        let reminders = events.map {
            ScheduledItem(id: $0.id, title: $0.title, startDate: $0.startDate, type: "event")
        }
        await replacePendingReminders(for: reminders, prefix: Reminder.eventPrefix)
    }

    func sync(meetings: [Meeting]) async {
        let preferences = NotificationPreferences.cached
        guard preferences.meetingsEnabled, preferences.eventRemindersEnabled else {
            await removePendingReminders(withPrefix: Reminder.meetingPrefix)
            return
        }

        let reminders = meetings
            .filter { !$0.isCancelled }
            .map { ScheduledItem(id: $0.id, title: $0.title, startDate: $0.startsAt, type: "meeting") }
        await replacePendingReminders(for: reminders, prefix: Reminder.meetingPrefix)
    }

    func updateEnabledState() async {
        let preferences = NotificationPreferences.cached
        if !preferences.eventRemindersEnabled || !preferences.eventsEnabled {
            await removePendingReminders(withPrefix: Reminder.eventPrefix)
        }
        if !preferences.eventRemindersEnabled || !preferences.meetingsEnabled {
            await removePendingReminders(withPrefix: Reminder.meetingPrefix)
        }
    }

    private func replacePendingReminders(for items: [ScheduledItem], prefix: String) async {
        await removePendingReminders(withPrefix: prefix)

        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
        else {
            return
        }

        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let remainingSlots = max(0, Reminder.maximumPendingReminders - pendingRequests.count)
        guard remainingSlots > 0 else { return }

        let now = Date()
        var requests: [ScheduledReminderRequest] = []
        for item in items {
            for reminder in Reminder.allCases {
                let fireDate = item.startDate.addingTimeInterval(-reminder.leadTime)
                guard fireDate > now else { continue }
                requests.append(makeRequest(for: item, reminder: reminder, fireDate: fireDate, prefix: prefix))
            }
        }

        let scheduledRequests = requests
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(remainingSlots)

        for request in scheduledRequests {
            do {
                try await notificationCenter.add(request.notificationRequest)
            } catch {
                AuthDebugLog.log("Could not schedule reminder \(request.notificationRequest.identifier): \(error.localizedDescription)")
            }
        }
    }

    private func removePendingReminders(withPrefix prefix: String) async {
        let requestIDs = await notificationCenter.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: requestIDs)
    }

    private func makeRequest(
        for item: ScheduledItem,
        reminder: Reminder,
        fireDate: Date,
        prefix: String
    ) -> ScheduledReminderRequest {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = "\(reminder.bodyPrefix): \(item.title)."
        content.sound = .default
        content.userInfo = [
            "type": "\(item.type)_reminder",
            "\(item.type)_id": item.id,
        ]

        let components = Calendar.current.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "\(prefix)\(item.id).\(reminder.identifierSuffix)"
        return ScheduledReminderRequest(
            fireDate: fireDate,
            notificationRequest: UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
    }
}

private struct ScheduledItem {
    let id: String
    let title: String
    let startDate: Date
    let type: String
}

private struct ScheduledReminderRequest {
    let fireDate: Date
    let notificationRequest: UNNotificationRequest
}
