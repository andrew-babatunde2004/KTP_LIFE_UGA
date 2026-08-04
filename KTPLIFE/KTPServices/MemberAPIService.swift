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

    /// Fetches the authenticated member profile from protected `GET /users/me`.
    func fetchCurrentUserProfile() async throws -> UserProfile {
        let url = baseURL.appendingPathComponent("users/me")
        let data = try await fetchProtectedData(from: url, logLabel: "current user profile")

        do {
            return try UserProfile.decodeResponse(from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Current profile decode failed: \(error.localizedDescription). Body=\(responseBody)")
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    /// Updates editable fields through protected `PUT /users/me/profile`.
    func updateCurrentUserProfile(_ profile: UpdateUserProfileRequest) async throws -> UserProfile {
        let url = baseURL.appendingPathComponent("users/me/profile")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(profile)

        let data = try await fetchProtectedData(for: request, logLabel: "update current user profile")
        if !data.isEmpty, let updatedProfile = try? UserProfile.decodeResponse(from: data) {
            return updatedProfile
        }

        return try await fetchCurrentUserProfile()
    }

    /// Anonymizes the authenticated user's account through protected `DELETE /users/me`.
    func deleteCurrentUser() async throws {
        let url = baseURL.appendingPathComponent("users/me")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await fetchProtectedData(for: request, logLabel: "delete current user")
    }

    /// Fetches the authenticated user's block list through protected `GET /users/blocked`.
    func fetchBlockedUserIDs() async throws -> Set<String> {
        let url = baseURL.appendingPathComponent("users/blocked")
        let data = try await fetchProtectedData(from: url, logLabel: "blocked users")

        do {
            return try BlockedUsersResponse.decodeIDs(from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Blocked users decode failed: \(error.localizedDescription). Body=\(responseBody)")
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    /// Blocks a member through protected `POST /users/:id/block`.
    func blockUser(id: String) async throws {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(id)
            .appendingPathComponent("block")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try await fetchProtectedData(for: request, logLabel: "block user \(id)")
    }

    /// Unblocks a member through protected `DELETE /users/:id/block`.
    func unblockUser(id: String) async throws {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(id)
            .appendingPathComponent("block")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await fetchProtectedData(for: request, logLabel: "unblock user \(id)")
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

    /// Fetches group chats from protected `GET /group-chats`.
    func fetchGroupChats() async throws -> [GroupChat] {
        let url = baseURL.appendingPathComponent("group-chats")
        let data = try await fetchProtectedData(from: url, logLabel: "group chats")

        do {
            return try GroupChatsResponse.decodeChats(from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Group chats decode failed: \(error.localizedDescription). Body=\(responseBody)")
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    /// Fetches a group chat's member-only profile image.
    func fetchGroupChatPhotoData(chatID: String) async throws -> Data {
        let url = baseURL
            .appendingPathComponent("group-chats")
            .appendingPathComponent(chatID)
            .appendingPathComponent("photo")
            .appendingPathComponent("media")
        return try await fetchProtectedData(from: url, logLabel: "group chat photo for \(chatID)")
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

    /// Fetches messages from protected `GET /group-chats/:id/messages`.
    func fetchGroupChatMessages(chatId: String) async throws -> [KTPMessage] {
        let url = baseURL
            .appendingPathComponent("group-chats")
            .appendingPathComponent(chatId)
            .appendingPathComponent("messages")
        let data = try await fetchProtectedData(from: url, logLabel: "group chat \(chatId) messages")

        do {
            return try ConversationMessagesResponse.decodeMessages(from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Group chat messages decode failed: \(error.localizedDescription). Body=\(responseBody)")
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

    /// Marks one group chat read via protected `PUT /group-chats/:id/read`.
    func markGroupChatRead(chatId: String) async throws {
        let url = baseURL
            .appendingPathComponent("group-chats")
            .appendingPathComponent(chatId)
            .appendingPathComponent("read")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        _ = try await fetchProtectedData(for: request, logLabel: "mark group chat \(chatId) read")
    }

    /// Sends a direct message via protected `POST /messages`.
    func sendMessage(to userId: String, content: String) async throws -> KTPMessage {
        let url = baseURL.appendingPathComponent("messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SendMessageRequest(recipientId: userId, content: content))

        let data = try await fetchProtectedData(for: request, logLabel: "send message to \(userId)")
        if let message = try? SentMessageResponse.decodeMessage(from: data) {
            return message
        }

        // Some successful API versions return an acknowledgement or an empty
        // body instead of the created message. The 2xx status still means the
        // send succeeded, so render a local copy until the next inbox refresh.
        let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
        AuthDebugLog.log("Send message returned no decodable message. Using a local copy. Body=\(responseBody)")
        return KTPMessage(
            id: "local-\(UUID().uuidString)",
            senderId: nil,
            recipientId: userId,
            body: content,
            createdAt: Date(),
            isRead: true
        )
    }

    /// Toggles the authenticated user's emoji reaction on one direct message.
    func toggleMessageReaction(messageId: String, emoji: String) async throws {
        let url = baseURL
            .appendingPathComponent("messages")
            .appendingPathComponent(messageId)
            .appendingPathComponent("reactions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(MessageReactionRequest(emoji: emoji))
        _ = try await fetchProtectedData(for: request, logLabel: "toggle reaction on message \(messageId)")
    }

    /// Toggles the authenticated user's emoji reaction on one group-chat message.
    func toggleGroupChatMessageReaction(chatId: String, messageId: String, emoji: String) async throws {
        let url = baseURL
            .appendingPathComponent("group-chats")
            .appendingPathComponent(chatId)
            .appendingPathComponent("messages")
            .appendingPathComponent(messageId)
            .appendingPathComponent("reactions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(MessageReactionRequest(emoji: emoji))
        _ = try await fetchProtectedData(for: request, logLabel: "toggle reaction on group chat \(chatId) message \(messageId)")
    }

    /// Fetches polls visible to the authenticated member.
    func fetchPolls() async throws -> [Poll] {
        let url = baseURL.appendingPathComponent("polls")
        let data = try await fetchProtectedData(from: url, logLabel: "polls")

        do {
            return try Poll.decodePolls(from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Polls decode failed: \(error.localizedDescription). Body=\(responseBody)")
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    /// Fetches announcements visible to the authenticated member.
    func fetchAnnouncements() async throws -> [Announcement] {
        let url = baseURL.appendingPathComponent("announcements")
        let data = try await fetchProtectedData(from: url, logLabel: "announcements")

        do {
            return try Announcement.decodeAnnouncements(from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Announcements decode failed: \(error.localizedDescription). Body=\(responseBody)")
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    /// Fetches meetings organized by or inviting the authenticated member.
    func fetchMeetings() async throws -> [Meeting] {
        let url = baseURL.appendingPathComponent("meetings")
        let data = try await fetchProtectedData(from: url, logLabel: "meetings")

        do {
            return try Meeting.decodeMeetings(from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Meetings decode failed: \(error.localizedDescription). Body=\(responseBody)")
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    /// Sets or changes the caller's RSVP on a meeting invitation.
    func respond(to meetingID: String, response: MeetingResponse) async throws {
        let url = baseURL
            .appendingPathComponent("meetings")
            .appendingPathComponent(meetingID)
            .appendingPathComponent("respond")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["response": response.rawValue])
        _ = try await fetchProtectedData(for: request, logLabel: "respond to meeting \(meetingID)")
    }

    /// Replaces the caller's vote selection for one open poll.
    func vote(on pollID: String, optionIDs: [String]) async throws {
        let url = baseURL
            .appendingPathComponent("polls")
            .appendingPathComponent(pollID)
            .appendingPathComponent("vote")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(PollVoteRequest(optionIDs: optionIDs))
        _ = try await fetchProtectedData(for: request, logLabel: "vote on poll \(pollID)")
    }

    /// Sends a group chat message via protected `POST /group-chats/:id/messages`.
    func sendGroupChatMessage(chatId: String, body: String) async throws -> KTPMessage {
        let url = baseURL
            .appendingPathComponent("group-chats")
            .appendingPathComponent(chatId)
            .appendingPathComponent("messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SendGroupChatMessageRequest(body: body))

        let data = try await fetchProtectedData(for: request, logLabel: "send group chat \(chatId) message")
        do {
            if let message = try? JSONDecoder().decode(KTPMessage.self, from: data) {
                return message
            }

            return try ConversationMessagesResponse.decodeMessages(from: data).last ?? {
                throw KTPAPIError.emptyResponse
            }()
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Send group chat message decode failed: \(error.localizedDescription). Body=\(responseBody)")
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    /// Submits a member, message, group-message, or photo report via protected `POST /reports`.
    func submitReport(_ report: SubmitReportRequest) async throws {
        let url = baseURL.appendingPathComponent("reports")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(report)
        _ = try await fetchProtectedData(for: request, logLabel: "submit \(report.contentType.rawValue) report")
    }

    /// Fetches moderation reports through eboard-only `GET /reports`.
    func fetchReports(status: ReportStatus? = nil) async throws -> [ContentReport] {
        var components = URLComponents(url: baseURL.appendingPathComponent("reports"), resolvingAgainstBaseURL: false)
        if let status {
            components?.queryItems = [URLQueryItem(name: "status", value: status.rawValue)]
        }
        guard let url = components?.url else { throw URLError(.badURL) }

        let data = try await fetchProtectedData(from: url, logLabel: "moderation reports")
        do {
            return try ContentReport.decodeReports(from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Reports decode failed: \(error.localizedDescription). Body=\(responseBody)")
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    /// Updates a moderation decision through eboard-only `PUT /reports/:id/status`.
    func updateReportStatus(
        reportID: String,
        status: ReportStatus,
        moderatorResponse: String?
    ) async throws {
        let url = baseURL
            .appendingPathComponent("reports")
            .appendingPathComponent(reportID)
            .appendingPathComponent("status")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            UpdateReportStatusRequest(status: status, moderatorResponse: moderatorResponse)
        )
        _ = try await fetchProtectedData(for: request, logLabel: "update report \(reportID) status")
    }

    /// Fetches a member profile picture from protected `GET /users/:id/profile-picture/media`.
    func fetchProfilePictureData(for userId: String) async throws -> Data {
        let url = baseURL
            .appendingPathComponent("users")
            .appendingPathComponent(userId)
            .appendingPathComponent("profile-picture/media")
        return try await fetchProtectedData(from: url, logLabel: "profile picture for \(userId)")
    }

    /// Fetches visible homepage highlights from authenticated `GET /ios-homepage-photos`.
    func fetchHomepageSlides() async throws -> [HomepageSlide] {
        let url = baseURL.appendingPathComponent("ios-homepage-photos")
        let data = try await fetchProtectedData(from: url, logLabel: "homepage slides")

        do {
            return try JSONDecoder().decode(HomepageSlidesResponse.self, from: data).slides
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unable to read response body"
            AuthDebugLog.log("Homepage slides decode failed: \(error.localizedDescription). Body=\(responseBody)")
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    /// Fetches the protected image for a homepage highlight from `/:id/media`.
    func fetchHomepageSlideMediaData(for slide: HomepageSlide) async throws -> Data {
        let url = baseURL
            .appendingPathComponent("ios-homepage-photos")
            .appendingPathComponent(slide.id)
            .appendingPathComponent("media")
        return try await fetchProtectedData(from: url, logLabel: "homepage slide media for \(slide.id)")
    }

    /// Registers the current iOS device with protected `POST /notifications/devices`.
    func registerNotificationDevice(_ device: NotificationDeviceRegistration) async throws {
        let url = baseURL.appendingPathComponent("notifications/devices")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(device)
        _ = try await fetchProtectedData(for: request, logLabel: "register push device")
    }

    /// Removes this device's APNs registration through `DELETE /notifications/devices/:token`.
    func unregisterNotificationDevice(token: String) async throws {
        let url = baseURL
            .appendingPathComponent("notifications/devices")
            .appendingPathComponent(token)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await fetchProtectedData(for: request, logLabel: "unregister push device")
    }

    func fetchNotificationPreferences() async throws -> NotificationPreferences {
        let url = baseURL.appendingPathComponent("notifications/preferences")
        let data = try await fetchProtectedData(from: url, logLabel: "notification preferences")
        do {
            return try JSONDecoder().decode(NotificationPreferences.self, from: data)
        } catch {
            throw KTPAPIError.decodeFailed(error.localizedDescription)
        }
    }

    func updateNotificationPreferences(_ preferences: NotificationPreferences) async throws -> NotificationPreferences {
        let url = baseURL.appendingPathComponent("notifications/preferences")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(preferences)
        let data = try await fetchProtectedData(for: request, logLabel: "update notification preferences")
        do {
            return try JSONDecoder().decode(NotificationPreferences.self, from: data)
        } catch {
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
    let body: String

    init(recipientId: String, content: String) {
        self.recipientId = recipientId
        self.body = content
    }

    enum CodingKeys: String, CodingKey {
        case recipientId = "recipient_id"
        case body
    }
}

private struct SentMessageResponse: Decodable {
    let message: KTPMessage

    enum CodingKeys: String, CodingKey {
        case message
        case data
        case result
    }

    static func decodeMessage(from data: Data) throws -> KTPMessage {
        let decoder = JSONDecoder()
        if let directMessage = try? decoder.decode(KTPMessage.self, from: data),
           hasContent(directMessage) {
            return directMessage
        }

        if let messages = try? ConversationMessagesResponse.decodeMessages(from: data),
           let message = messages.last(where: hasContent) {
            return message
        }

        let message = try decoder.decode(SentMessageResponse.self, from: data).message
        guard hasContent(message) else {
            throw KTPAPIError.emptyResponse
        }
        return message
    }

    nonisolated private static func hasContent(_ message: KTPMessage) -> Bool {
        !message.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let message = try container.decodeIfPresent(KTPMessage.self, forKey: .message) {
            self.message = message
        } else if let message = try container.decodeIfPresent(KTPMessage.self, forKey: .data) {
            self.message = message
        } else {
            self.message = try container.decode(KTPMessage.self, forKey: .result)
        }
    }
}

private struct MessageReactionRequest: Encodable {
    let emoji: String
}

private struct PollVoteRequest: Encodable {
    let optionIDs: [String]

    enum CodingKeys: String, CodingKey {
        case optionIDs = "option_ids"
    }
}

private struct SendGroupChatMessageRequest: Encodable {
    let body: String
}

private enum BlockedUsersResponse {
    static func decodeIDs(from data: Data) throws -> Set<String> {
        let object = try JSONSerialization.jsonObject(with: data)
        let values: [Any]

        if let directValues = object as? [Any] {
            values = directValues
        } else if let envelope = object as? [String: Any] {
            values = (envelope["blocked_users"] as? [Any])
                ?? (envelope["blocked_user_ids"] as? [Any])
                ?? (envelope["users"] as? [Any])
                ?? (envelope["data"] as? [Any])
                ?? []
        } else {
            values = []
        }

        var ids = Set<String>()
        for value in values {
            if let id = userID(from: value) {
                ids.insert(id)
            }
        }
        return ids
    }

    private static func userID(from value: Any) -> String? {
        if let value = value as? String, !value.isEmpty {
            return value
        }
        if let value = value as? NSNumber {
            return value.stringValue
        }
        guard let object = value as? [String: Any] else { return nil }

        for key in ["blocked_user_id", "user_id", "id", "authentik_id"] {
            if let id = object[key] as? String, !id.isEmpty {
                return id
            }
            if let id = object[key] as? NSNumber {
                return id.stringValue
            }
        }
        return nil
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
