import Foundation

struct MessageConversation: Identifiable, Hashable, Decodable {
    let id: String
    let userId: String
    let displayName: String
    let preview: String
    let lastMessageDate: Date?
    let unreadCount: Int
    let profileImageURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case otherUserId = "other_user_id"
        case memberId = "member_id"
        case recipientId = "recipient_id"
        case senderId = "sender_id"
        case name
        case displayName = "display_name"
        case fullName = "full_name"
        case username
        case profileImageURL = "profile_image_url"
        case profilePictureURL = "profile_picture_url"
        case avatarURL = "avatar_url"
        case photoURL = "photo_url"
        case imageURL = "image_url"
        case lastMessage = "last_message"
        case latestMessage = "latest_message"
        case preview
        case content
        case body
        case text
        case message
        case lastMessageAt = "last_message_at"
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case unreadCount = "unread_count"
        case unread
        case isUnread = "is_unread"
    }

    init(
        id: String,
        userId: String,
        displayName: String,
        preview: String,
        lastMessageDate: Date?,
        unreadCount: Int,
        profileImageURL: URL? = nil
    ) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.preview = preview
        self.lastMessageDate = lastMessageDate
        self.unreadCount = unreadCount
        self.profileImageURL = profileImageURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let resolvedUserId = try container.decodeFirstPresentString(
            for: [.userId, .otherUserId, .memberId, .recipientId, .senderId],
            fallback: ""
        )
        userId = resolvedUserId
        id = try container.decodeFirstPresentString(
            for: [.id, .conversationId, .userId, .otherUserId, .memberId],
            fallback: resolvedUserId
        )
        displayName = try container.decodeFirstPresentString(
            for: [.name, .displayName, .fullName, .username],
            fallback: "Member"
        )
        profileImageURL = try container.decodeFirstPresentURLIfPresent(
            for: [.profileImageURL, .profilePictureURL, .avatarURL, .photoURL, .imageURL]
        )

        if let nestedMessage = try container.decodeIfPresent(KTPMessage.self, forKey: .lastMessage) {
            preview = nestedMessage.body
            lastMessageDate = nestedMessage.createdAt
        } else if let nestedMessage = try container.decodeIfPresent(KTPMessage.self, forKey: .latestMessage) {
            preview = nestedMessage.body
            lastMessageDate = nestedMessage.createdAt
        } else {
            preview = try container.decodeFirstPresentString(
                for: [.preview, .content, .body, .text, .message],
                fallback: "No messages yet."
            )
            lastMessageDate = try container.decodeFirstPresentDateIfPresent(
                for: [.lastMessageAt, .updatedAt, .createdAt]
            )
        }

        if let count = try container.decodeIfPresent(Int.self, forKey: .unreadCount) {
            unreadCount = count
        } else if let countString = try container.decodeIfPresent(String.self, forKey: .unreadCount),
                  let count = Int(countString) {
            unreadCount = count
        } else {
            let unread = try container.decodeIfPresent(Bool.self, forKey: .unread) ?? false
            let isUnread = try container.decodeIfPresent(Bool.self, forKey: .isUnread) ?? false
            unreadCount = unread || isUnread ? 1 : 0
        }
    }
}

struct KTPMessage: Identifiable, Hashable, Decodable {
    let id: String
    let senderId: String?
    let recipientId: String?
    let body: String
    let createdAt: Date?
    let isRead: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case messageId = "message_id"
        case senderId = "sender_id"
        case fromUserId = "from_user_id"
        case recipientId = "recipient_id"
        case toUserId = "to_user_id"
        case content
        case body
        case text
        case message
        case createdAt = "created_at"
        case sentAt = "sent_at"
        case timestamp
        case isRead = "is_read"
        case read
    }

    init(
        id: String,
        senderId: String?,
        recipientId: String?,
        body: String,
        createdAt: Date?,
        isRead: Bool
    ) {
        self.id = id
        self.senderId = senderId
        self.recipientId = recipientId
        self.body = body
        self.createdAt = createdAt
        self.isRead = isRead
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFirstPresentString(for: [.id, .messageId], fallback: UUID().uuidString)
        senderId = try container.decodeFirstPresentStringIfPresent(for: [.senderId, .fromUserId])
        recipientId = try container.decodeFirstPresentStringIfPresent(for: [.recipientId, .toUserId])
        body = try container.decodeFirstPresentString(for: [.content, .body, .text, .message], fallback: "")
        createdAt = try container.decodeFirstPresentDateIfPresent(for: [.createdAt, .sentAt, .timestamp])
        let directReadValue = try container.decodeIfPresent(Bool.self, forKey: .isRead)
        let fallbackReadValue = try container.decodeIfPresent(Bool.self, forKey: .read)
        isRead = directReadValue ?? fallbackReadValue ?? false
    }
}

struct MessageConversationsResponse: Decodable {
    let conversations: [MessageConversation]

    enum CodingKeys: String, CodingKey {
        case conversations
        case data
        case threads
        case messages
    }

    static func decodeConversations(from data: Data) throws -> [MessageConversation] {
        let decoder = JSONDecoder()
        if let directConversations = try? decoder.decode([MessageConversation].self, from: data) {
            return directConversations
        }

        return try decoder.decode(MessageConversationsResponse.self, from: data).conversations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let conversations = try container.decodeIfPresent([MessageConversation].self, forKey: .conversations) {
            self.conversations = conversations
        } else if let data = try container.decodeIfPresent([MessageConversation].self, forKey: .data) {
            self.conversations = data
        } else if let threads = try container.decodeIfPresent([MessageConversation].self, forKey: .threads) {
            self.conversations = threads
        } else {
            self.conversations = try container.decode([MessageConversation].self, forKey: .messages)
        }
    }
}

struct ConversationMessagesResponse: Decodable {
    let messages: [KTPMessage]

    enum CodingKeys: String, CodingKey {
        case messages
        case data
        case conversation
    }

    static func decodeMessages(from data: Data) throws -> [KTPMessage] {
        let decoder = JSONDecoder()
        if let directMessages = try? decoder.decode([KTPMessage].self, from: data) {
            return directMessages
        }

        return try decoder.decode(ConversationMessagesResponse.self, from: data).messages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let messages = try container.decodeIfPresent([KTPMessage].self, forKey: .messages) {
            self.messages = messages
        } else if let data = try container.decodeIfPresent([KTPMessage].self, forKey: .data) {
            self.messages = data
        } else {
            self.messages = try container.decode([KTPMessage].self, forKey: .conversation)
        }
    }
}

#if DEBUG
extension MessageConversation {
    static let previewSamples: [MessageConversation] = [
        MessageConversation(
            id: "1",
            userId: "1",
            displayName: "Jordan Lee",
            preview: "Chapter updates are live for this week.",
            lastMessageDate: Date(),
            unreadCount: 1
        ),
        MessageConversation(
            id: "2",
            userId: "2",
            displayName: "Maya Patel",
            preview: "Reminder: recruitment meeting starts at 7:00 PM.",
            lastMessageDate: Calendar.current.date(byAdding: .hour, value: -2, to: Date()),
            unreadCount: 0
        )
    ]
}

extension KTPMessage {
    static let previewSamples: [KTPMessage] = [
        KTPMessage(
            id: "1",
            senderId: "1",
            recipientId: "2",
            body: "Chapter updates are live for this week.",
            createdAt: Date(),
            isRead: false
        )
    ]
}
#endif

private extension KeyedDecodingContainer {
    func decodeFirstPresentString(for keys: [Key], fallback: String) throws -> String {
        try decodeFirstPresentStringIfPresent(for: keys) ?? fallback
    }

    func decodeFirstPresentStringIfPresent(for keys: [Key]) throws -> String? {
        for key in keys {
            if let stringValue = try decodeIfPresent(String.self, forKey: key), !stringValue.isEmpty {
                return stringValue
            }

            if let intValue = try decodeIfPresent(Int.self, forKey: key) {
                return String(intValue)
            }
        }

        return nil
    }

    func decodeFirstPresentDateIfPresent(for keys: [Key]) throws -> Date? {
        for key in keys {
            if let stringValue = try decodeIfPresent(String.self, forKey: key),
               let date = MessageDateParser.date(from: stringValue) {
                return date
            }

            if let timestamp = try decodeIfPresent(TimeInterval.self, forKey: key) {
                return Date(timeIntervalSince1970: timestamp)
            }
        }

        return nil
    }

    func decodeFirstPresentURLIfPresent(for keys: [Key]) throws -> URL? {
        for key in keys {
            if let stringValue = try decodeIfPresent(String.self, forKey: key),
               let url = URL(string: stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return url
            }
        }

        return nil
    }
}

private enum MessageDateParser {
    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601 = ISO8601DateFormatter()

    static func date(from value: String) -> Date? {
        iso8601WithFractionalSeconds.date(from: value) ?? iso8601.date(from: value)
    }
}
