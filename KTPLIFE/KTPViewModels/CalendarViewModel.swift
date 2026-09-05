import Foundation
import Observation

@Observable
class CalendarViewModel {
    var events: [CalendarEvent] = []
    var isLoading = false 
    var errorMessage: String? = nil
    var isShowingCachedEvents = false
    var cacheUpdatedAt: Date?

    private let cache = CalendarEventCache.shared
    private var isFetching = false

    @MainActor
    func fetchEvents(accountID: String, accessTokenProvider: @escaping () async throws -> String?) async {
        guard !isFetching else { return }
        isFetching = true
        defer {
            isFetching = false
            isLoading = false
        }

        if events.isEmpty, let snapshot = await cache.load(accountID: accountID) {
            events = snapshot.events.sorted { $0.startDate < $1.startDate }
            cacheUpdatedAt = snapshot.updatedAt
            isShowingCachedEvents = true
        }

        isLoading = events.isEmpty
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
            let refreshedAt = Date()
            await cache.save(self.events, accountID: accountID, updatedAt: refreshedAt)
            cacheUpdatedAt = refreshedAt
            isShowingCachedEvents = false
        } catch {
            if events.isEmpty {
                self.errorMessage = "Failed to load calendar events"
            } else {
                isShowingCachedEvents = true
            }
        }
    }
}
