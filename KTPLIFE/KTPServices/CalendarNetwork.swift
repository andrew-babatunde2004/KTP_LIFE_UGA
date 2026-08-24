import Foundation

class CalendarNetworkService {
    private let baseURL: URL
    private let session: URLSession
    private let accessTokenProvider: () async throws -> String?

    init(
        baseURL: URL = APIConfig.baseURL,
        session: URLSession = .shared,
        accessTokenProvider: @escaping () async throws -> String? = { APIConfig.developmentAccessToken }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessTokenProvider = accessTokenProvider
    }

    func fetchCalendarEvents() async throws -> [CalendarEvent] {
        let url = baseURL.appendingPathComponent("events")
        let data = try await fetchData(from: url)
        return try Self.calendarDecoder.decode([CalendarEvent].self, from: data)
    }

    /// Fetches the caller-specific meeting projection used by calendar clients.
    /// This endpoint keeps private meetings out of the public `/events` feed.
    func fetchMeetingCalendarEvents() async throws -> [CalendarEvent] {
        let url = baseURL
            .appendingPathComponent("meetings")
            .appendingPathComponent("calendar")
        let data = try await fetchData(from: url)
        return try MeetingCalendarEntry.decodeCalendarEvents(from: data, using: Self.calendarDecoder)
    }

    private func fetchData(from url: URL) async throws -> Data {
        guard let accessToken = try await accessTokenProvider(), !accessToken.isEmpty else {
            throw CalendarNetworkError.missingAccessToken
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw CalendarNetworkError.badStatusCode(httpResponse.statusCode)
        }
        return data
    }

    private static var calendarDecoder: JSONDecoder {
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
        return decoder
    }
}

private struct MeetingCalendarEntry: Decodable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let description: String?
    let location: String?

    enum CodingKeys: String, CodingKey {
        case id
        case meetingId
        case title
        case startDate
        case startsAt
        case start
        case endDate
        case endsAt
        case end
        case description
        case message
        case location
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .meetingId) {
            id = value
        } else if let value = try container.decodeIfPresent(Int.self, forKey: .id) {
            id = String(value)
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Meeting calendar entry has no id")
            )
        }

        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Meeting"
        guard let decodedStartDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
            ?? container.decodeIfPresent(Date.self, forKey: .startsAt)
            ?? container.decodeIfPresent(Date.self, forKey: .start) else {
            throw DecodingError.keyNotFound(
                CodingKeys.startDate,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Meeting calendar entry has no start date")
            )
        }
        startDate = decodedStartDate
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
            ?? container.decodeIfPresent(Date.self, forKey: .endsAt)
            ?? container.decodeIfPresent(Date.self, forKey: .end)
            ?? decodedStartDate
        description = try container.decodeIfPresent(String.self, forKey: .description)
            ?? container.decodeIfPresent(String.self, forKey: .message)
        location = try container.decodeIfPresent(String.self, forKey: .location)
    }

    private var calendarEvent: CalendarEvent {
        CalendarEvent(
            id: "meeting:\(id)",
            title: title,
            startDate: startDate,
            endDate: endDate,
            description: description,
            location: location
        )
    }

    static func decodeCalendarEvents(from data: Data, using decoder: JSONDecoder) throws -> [CalendarEvent] {
        if let entries = try? decoder.decode([MeetingCalendarEntry].self, from: data) {
            return entries.map(\.calendarEvent)
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let response = object as? [String: Any] else {
            throw CalendarNetworkError.invalidMeetingCalendarResponse
        }

        for key in ["events", "meetings", "data"] {
            guard let value = response[key], JSONSerialization.isValidJSONObject(value) else { continue }
            let nestedData = try JSONSerialization.data(withJSONObject: value)
            if let entries = try? decoder.decode([MeetingCalendarEntry].self, from: nestedData) {
                return entries.map(\.calendarEvent)
            }
        }

        throw CalendarNetworkError.invalidMeetingCalendarResponse
    }
}

enum CalendarNetworkError: LocalizedError {
    case missingAccessToken
    case badStatusCode(Int)
    case invalidMeetingCalendarResponse

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "Sign in with SSO to load calendar events."
        case .badStatusCode(let statusCode):
            return "Calendar API failed with status \(statusCode)."
        case .invalidMeetingCalendarResponse:
            return "The meeting calendar response could not be read."
        }
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
