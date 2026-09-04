import EventKit
import Foundation

enum DeviceCalendarServiceError: LocalizedError {
    case accessDenied
    case noCalendarAvailable

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access wasn’t allowed. You can enable it in Settings."
        case .noCalendarAvailable:
            return "No calendar is available for new events on this device."
        }
    }
}

final class DeviceCalendarService {
    private let eventStore = EKEventStore()

    func add(_ calendarEvent: CalendarEvent) async throws {
        let accessGranted: Bool

        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly:
            accessGranted = true
        case .notDetermined:
            accessGranted = try await eventStore.requestWriteOnlyAccessToEvents()
        case .denied, .restricted:
            throw DeviceCalendarServiceError.accessDenied
        @unknown default:
            throw DeviceCalendarServiceError.accessDenied
        }

        guard accessGranted else {
            throw DeviceCalendarServiceError.accessDenied
        }

        guard let destinationCalendar = eventStore.defaultCalendarForNewEvents else {
            throw DeviceCalendarServiceError.noCalendarAvailable
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = calendarEvent.title
        event.startDate = calendarEvent.startDate
        event.endDate = calendarEvent.endDate
        event.notes = calendarEvent.description
        event.location = calendarEvent.location
        event.url = calendarEvent.url
        event.calendar = destinationCalendar

        try eventStore.save(event, span: .thisEvent)
    }
}
