import Foundation
import Observation

@Observable
class CalendarViewModel {
    var events: [CalendarEvent] = []
    var isLoading = false 
    var errorMessage: String? = nil

    @MainActor
    func fetchEvents(accessTokenProvider: @escaping () async throws -> String?) async {
        isLoading = true
        errorMessage = nil
        do {
            let networkService = CalendarNetworkService(accessTokenProvider: accessTokenProvider)
            let calendarEvents = try await networkService.fetchCalendarEvents()
            let meetingEvents: [CalendarEvent]

            do {
                meetingEvents = try await networkService.fetchMeetingCalendarEvents()
            } catch {
                // Some roles (including rush) cannot access meetings. Keep the
                // public/personalized event calendar useful when that feed is unavailable.
                AuthDebugLog.log("Meeting calendar fetch failed: \(error.localizedDescription)")
                meetingEvents = []
            }

            self.events = (calendarEvents + meetingEvents)
                .sorted { $0.startDate < $1.startDate }
        } catch {
            self.errorMessage = "Failed to load calendar events"
        }

        isLoading = false
    }
}
