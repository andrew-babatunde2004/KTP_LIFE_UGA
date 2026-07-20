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
        guard let accessToken = try await accessTokenProvider(), !accessToken.isEmpty else {
            throw CalendarNetworkError.missingAccessToken
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
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
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw CalendarNetworkError.badStatusCode(httpResponse.statusCode)
        }
        return try decoder.decode([CalendarEvent].self, from: data)
    }
}

enum CalendarNetworkError: LocalizedError {
    case missingAccessToken
    case badStatusCode(Int)

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "Sign in with SSO to load calendar events."
        case .badStatusCode(let statusCode):
            return "Calendar API failed with status \(statusCode)."
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
