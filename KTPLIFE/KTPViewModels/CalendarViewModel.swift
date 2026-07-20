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
            self.events = try await networkService.fetchCalendarEvents()
        } catch {
            self.errorMessage = "Failed to load calendar events"
        }

        isLoading = false
    }
}
