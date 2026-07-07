import Foundation

class CalendarNetworkService {
    private let baseURL: URL

    init(baseURL: URL = APIConfig.baseURL) {
        self.baseURL = baseURL
    }

    func fetchCalendarEvents() async throws -> [CalendarEvent] {
        let url = baseURL.appendingPathComponent("events")
        let (data, response) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.ktpInternetDateTimeWithFractionalSeconds.date(from: value) {
                return date
            }

            if let date = ISO8601DateFormatter.ktpInternetDateTime.date(from: value) {
                return date
            }

            if let date = ISO8601DateFormatter.ktpInternetDate.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode([CalendarEvent].self, from: data)
    }
}

private extension ISO8601DateFormatter {
    static let ktpInternetDateTimeWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let ktpInternetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let ktpInternetDate: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}
