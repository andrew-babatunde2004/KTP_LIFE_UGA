import Foundation

/// The non-secret event credential encoded by an attendance QR code.
///
/// The attendee's access token is deliberately not part of this value. It is
/// added to the API request by `AttendanceCheckInService`.
struct AttendanceQRCode: Equatable {
    let eventID: String
    let token: String

    private init(eventID: String, token: String) {
        self.eventID = eventID
        self.token = token
    }

    init?(payload: String) {
        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPayload.isEmpty else { return nil }

        if let jsonCode = Self.decodeJSONPayload(trimmedPayload) {
            self = jsonCode
            return
        }

        guard let url = URL(string: trimmedPayload),
              let urlCode = Self.decodeURLPayload(url) else {
            return nil
        }

        self = urlCode
    }

    private static func decodeJSONPayload(_ payload: String) -> AttendanceQRCode? {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventID = nonemptyString(object["eventId"] ?? object["event_id"]),
              let token = nonemptyString(
                  object["token"] ?? object["attendanceCode"] ?? object["attendance_code"]
              ) else {
            return nil
        }

        return AttendanceQRCode(eventID: eventID, token: token)
    }

    private static func decodeURLPayload(_ url: URL) -> AttendanceQRCode? {
        var components = url.pathComponents.filter { $0 != "/" }

        // Custom URLs may encode "checkin" as the host:
        // ktplife://checkin/<event-id>/<token>
        if url.host?.lowercased() == "checkin" {
            components.insert("checkin", at: 0)
        }

        guard let checkInIndex = components.firstIndex(where: {
            $0.caseInsensitiveCompare("checkin") == .orderedSame
        }) else {
            return nil
        }

        let eventIndex = components.index(after: checkInIndex)
        guard eventIndex < components.endIndex else { return nil }
        let tokenIndex = components.index(after: eventIndex)
        guard tokenIndex < components.endIndex else { return nil }

        let eventID = components[eventIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let token = components[tokenIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !eventID.isEmpty, !token.isEmpty else { return nil }

        return AttendanceQRCode(eventID: eventID, token: token)
    }

    private static func nonemptyString(_ value: Any?) -> String? {
        let string: String?
        if let value = value as? String {
            string = value
        } else if let value = value as? NSNumber {
            string = value.stringValue
        } else {
            string = nil
        }

        guard let string else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct AttendanceCheckInResponse: Decodable {
    struct EventSummary: Decodable {
        let id: String
        let title: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let stringID = try container.decodeIfPresent(String.self, forKey: .id) {
                id = stringID
            } else {
                id = String(try container.decode(Int.self, forKey: .id))
            }
            title = try container.decode(String.self, forKey: .title)
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case title
        }
    }

    let message: String
    let event: EventSummary?
}

final class AttendanceCheckInService {
    private let baseURL: URL
    private let session: URLSession
    private let accessTokenProvider: () async throws -> String

    init(
        baseURL: URL = APIConfig.baseURL,
        session: URLSession = .shared,
        accessTokenProvider: @escaping () async throws -> String
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessTokenProvider = accessTokenProvider
    }

    func checkIn(using code: AttendanceQRCode) async throws -> AttendanceCheckInResponse {
        let accessToken = try await accessTokenProvider()
        guard !accessToken.isEmpty else {
            throw AttendanceCheckInError.notAuthenticated
        }

        // Always construct the destination from APIConfig. A QR code can never
        // choose a host that receives the user's bearer token.
        let url = baseURL
            .appendingPathComponent("checkin")
            .appendingPathComponent(code.eventID)
            .appendingPathComponent(code.token)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AttendanceCheckInError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let serverMessage = try? JSONDecoder().decode(ServerMessage.self, from: data).message
            throw AttendanceCheckInError.server(
                statusCode: httpResponse.statusCode,
                message: serverMessage
            )
        }

        do {
            return try JSONDecoder().decode(AttendanceCheckInResponse.self, from: data)
        } catch {
            throw AttendanceCheckInError.invalidResponse
        }
    }
}

enum AttendanceCheckInError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case server(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Your session has expired. Sign in again before checking in."
        case .invalidResponse:
            return "The attendance server returned an unexpected response. Please try again."
        case .server(let statusCode, let message):
            if let message, !message.isEmpty {
                return message
            }
            return "Check-in failed with status \(statusCode)."
        }
    }
}

private struct ServerMessage: Decodable {
    let message: String
}
