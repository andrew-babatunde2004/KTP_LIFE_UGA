import Foundation
import Observation

@Observable
class CalendarViewModel {
    var events: [Calendar] = []
    var isLoading = false 
    var errorMessage: String? = nil

    // in java terms we're letting network service become an instance of the class CalendarNetworkService
    private let networkService = CalendarNetworkService()

    @MainActor
    func fetchEvents() async {
        isLoading = true
        errorMessage = nil
        do {
            // because network service is an instance of the class CalendarNetworkService, we can call the function fetchCalendarEvents() on it
            self.events = try await networkService.fetchCalendarEvents()
        } catch {
            self.errorMessage = "Failed to load calendar events"
        } finally {
            isLoading = false
        }
    }
}