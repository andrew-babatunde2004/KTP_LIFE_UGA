import Foundation

struct UserSyncResponse: Decodable {
    let profileComplete: Bool

    enum CodingKeys: String, CodingKey {
        case profileComplete = "profile_complete"
        case camelProfileComplete = "profileComplete"
    }

    init(profileComplete: Bool) {
        self.profileComplete = profileComplete
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try container.decodeFlexibleBoolIfPresent(forKey: .profileComplete) {
            profileComplete = value
            return
        }

        if let value = try container.decodeFlexibleBoolIfPresent(forKey: .camelProfileComplete) {
            profileComplete = value
            return
        }

        throw DecodingError.keyNotFound(
            CodingKeys.profileComplete,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected profile_complete or profileComplete in user sync response."
            )
        )
    }
}

enum UserSyncError: LocalizedError {
    case badStatusCode(Int, String)

    var errorDescription: String? {
        switch self {
        case .badStatusCode(let statusCode, let body):
            return "User sync failed with status \(statusCode): \(body)"
        }
    }
}

final class UserSyncService {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = APIConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func syncCurrentUser(accessToken: String) async throws -> UserSyncResponse {
        let url = baseURL.appendingPathComponent("users/sync")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            throw UserSyncError.badStatusCode(httpResponse.statusCode, responseBody)
        }

        return try JSONDecoder().decode(UserSyncResponse.self, from: data)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleBoolIfPresent(forKey key: Key) throws -> Bool? {
        if let boolValue = try decodeIfPresent(Bool.self, forKey: key) {
            return boolValue
        }

        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return intValue != 0
        }

        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
            switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        }

        return nil
    }
}
