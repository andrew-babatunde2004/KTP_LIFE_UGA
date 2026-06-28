import Foundation

class CalendarNetworkService {
    private let baseURL = URL(string: "http://192.168.1.174:3000/")!
    
    // come back and fix this later
    func fetchCalendarEvents() async throws -> [CalendarEvent] {
        let url = baseURL.appendingPathComponent("events")
        let (data, response) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode([CalendarEvent].self, from: data)
    }
}
