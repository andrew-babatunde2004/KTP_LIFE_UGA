import Foundation

enum KTPAPIError: Error {
    case missingAccessToken
    case badStatusCode(Int, String)
    case decodeFailed(String)
    case emptyResponse
}

/// Client for the KTP API. Protected routes require an Authentik access token.
final class KTPAPIService {

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

    /// Fetches all completed member profiles from protected `GET /members`.
    func fetchDirectoryMembers() async throws -> [DirectoryMember] {
        let url = baseURL.appendingPathComponent("members")
        let data = try await fetchProtectedData(from: url, logLabel: "directory members")

        do {
            return try DirectoryMembersResponse.decodeMembers(from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Directory decode failed: \(error.localizedDescription). Body=\(responseBody)")
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    /// Fetches message conversations from protected `GET /messages/conversations`.
    func fetchMessageConversations() async throws -> [MessageConversation] {
        let url = baseURL.appendingPathComponent("messages/conversations")
        let data = try await fetchProtectedData(from: url, logLabel: "message conversations")

        do {
            return try MessageConversationsResponse.decodeConversations(from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Message conversations decode failed: \(error.localizedDescription). Body=\(responseBody)")
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    /// Fetches one direct conversation from protected `GET /messages/conversations/:userId`.
    func fetchConversation(with userId: String) async throws -> [KTPMessage] {
        let url = baseURL
            .appendingPathComponent("messages/conversations")
            .appendingPathComponent(userId)
        let data = try await fetchProtectedData(from: url, logLabel: "conversation with \(userId)")

        do {
            return try ConversationMessagesResponse.decodeMessages(from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Conversation decode failed: \(error.localizedDescription). Body=\(responseBody)")
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    /// Marks one direct conversation read via protected `PUT /messages/conversations/:userId/read`.
    func markConversationRead(with userId: String) async throws {
        let url = baseURL
            .appendingPathComponent("messages/conversations")
            .appendingPathComponent(userId)
            .appendingPathComponent("read")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        _ = try await fetchProtectedData(for: request, logLabel: "mark conversation read for \(userId)")
    }

    /// Sends a direct message via protected `POST /messages`.
    func sendMessage(to userId: String, content: String) async throws -> KTPMessage {
        let url = baseURL.appendingPathComponent("messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SendMessageRequest(recipientId: userId, content: content))

        let data = try await fetchProtectedData(for: request, logLabel: "send message to \(userId)")
        do {
            if let message = try? JSONDecoder().decode(KTPMessage.self, from: data) {
                return message
            }

            return try ConversationMessagesResponse.decodeMessages(from: data).last ?? {
                throw KTPAPIError.emptyResponse
            }()
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Send message decode failed: \(error.localizedDescription). Body=\(responseBody)")
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    private func fetchProtectedData(from url: URL, logLabel: String) async throws -> Data {
        try await fetchProtectedData(for: URLRequest(url: url), logLabel: logLabel)
    }

    private func fetchProtectedData(for request: URLRequest, logLabel: String) async throws -> Data {
        guard let accessToken = try await accessTokenProvider(), !accessToken.isEmpty else {
            throw KTPAPIError.missingAccessToken
        }

        AuthDebugLog.log("Fetching \(logLabel) from \(request.url?.absoluteString ?? "unknown URL")")
        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: authenticatedRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            AuthDebugLog.log("KTP API failed status=\(httpResponse.statusCode), body=\(responseBody)")
            throw KTPAPIError.badStatusCode(httpResponse.statusCode, responseBody)
        }

        AuthDebugLog.log("KTP API request succeeded for \(logLabel).")
        return data
    }
}

private struct SendMessageRequest: Encodable {
    let recipientId: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case recipientId = "recipient_id"
        case content
    }
}

private struct DirectoryMembersResponse: Decodable {
    let members: [DirectoryMember]

    enum CodingKeys: String, CodingKey {
        case members
        case data
        case users
    }

    static func decodeMembers(from data: Data) throws -> [DirectoryMember] {
        let decoder = JSONDecoder()
        if let directMembers = try? decoder.decode([DirectoryMember].self, from: data) {
            return directMembers
        }

        let wrappedResponse = try decoder.decode(DirectoryMembersResponse.self, from: data)
        return wrappedResponse.members
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let members = try container.decodeIfPresent([DirectoryMember].self, forKey: .members) {
            self.members = members
        } else if let data = try container.decodeIfPresent([DirectoryMember].self, forKey: .data) {
            self.members = data
        } else {
            self.members = try container.decode([DirectoryMember].self, forKey: .users)
        }
    }
}
