import Foundation

actor MessageOfflineStore {
    static let shared = MessageOfflineStore()

    struct PendingDelivery: Identifiable {
        enum Destination: String, Codable {
            case direct
            case group
        }

        let id: String
        let destination: Destination
        let destinationID: String
        let body: String?
        let attachment: MessageAttachmentUpload?
        let createdAt: Date

        var threadID: String {
            switch destination {
            case .direct: "direct-\(destinationID)"
            case .group: "group-\(destinationID)"
            }
        }

        func localMessage(currentUserID: String?) -> KTPMessage {
            KTPMessage(
                id: "pending-\(id)",
                senderId: currentUserID,
                recipientId: destination == .direct ? destinationID : nil,
                senderDisplayName: "You",
                body: body ?? "",
                attachment: attachment.map {
                    MessageAttachment(
                        kind: "file",
                        filename: $0.fileName,
                        mimeType: $0.mimeType,
                        size: $0.data.count
                    )
                },
                createdAt: createdAt,
                isRead: true
            )
        }
    }

    private struct Store: Codable {
        var inboxes: [String: [CachedThread]] = [:]
        var conversations: [String: [CachedMessage]] = [:]
        var outbox: [StoredDelivery] = []
    }

    private struct CachedThread: Codable {
        let kind: String
        let id: String
        let destinationID: String
        let displayName: String
        let preview: String
        let lastMessageDate: Date?
        let unreadCount: Int
        let imageURL: URL?
        let photoAssetID: String?

        init(_ thread: MessageThread) {
            switch thread {
            case .direct(let conversation):
                kind = "direct"
                id = conversation.id
                destinationID = conversation.userId
                displayName = conversation.displayName
                preview = conversation.preview
                lastMessageDate = conversation.lastMessageDate
                unreadCount = conversation.unreadCount
                imageURL = conversation.profileImageURL
                photoAssetID = nil
            case .group(let chat):
                kind = "group"
                id = chat.id
                destinationID = chat.id
                displayName = chat.name
                preview = chat.preview
                lastMessageDate = chat.lastMessageDate
                unreadCount = chat.unreadCount
                imageURL = nil
                photoAssetID = chat.photoAssetID
            }
        }

        var thread: MessageThread {
            if kind == "group" {
                return .group(GroupChat(
                    id: id,
                    name: displayName,
                    preview: preview,
                    lastMessageDate: lastMessageDate,
                    unreadCount: unreadCount,
                    photoAssetID: photoAssetID
                ))
            }
            return .direct(MessageConversation(
                id: id,
                userId: destinationID,
                displayName: displayName,
                preview: preview,
                lastMessageDate: lastMessageDate,
                unreadCount: unreadCount,
                profileImageURL: imageURL
            ))
        }
    }

    private struct CachedMessage: Codable {
        struct Attachment: Codable {
            let kind: String
            let filename: String?
            let mimeType: String?
            let size: Int?
        }

        struct Reaction: Codable {
            let emoji: String
            let count: Int
            let reactedByCurrentUser: Bool
        }

        let id: String
        let senderId: String?
        let recipientId: String?
        let senderDisplayName: String?
        let senderProfileImageURL: URL?
        let body: String
        let attachment: Attachment?
        let createdAt: Date?
        let isRead: Bool
        let reactions: [Reaction]

        init(_ message: KTPMessage) {
            id = message.id
            senderId = message.senderId
            recipientId = message.recipientId
            senderDisplayName = message.senderDisplayName
            senderProfileImageURL = message.senderProfileImageURL
            body = message.body
            attachment = message.attachment.map {
                Attachment(kind: $0.kind, filename: $0.filename, mimeType: $0.mimeType, size: $0.size)
            }
            createdAt = message.createdAt
            isRead = message.isRead
            reactions = message.reactions.map {
                Reaction(emoji: $0.emoji, count: $0.count, reactedByCurrentUser: $0.reactedByCurrentUser)
            }
        }

        var message: KTPMessage {
            KTPMessage(
                id: id,
                senderId: senderId,
                recipientId: recipientId,
                senderDisplayName: senderDisplayName,
                senderProfileImageURL: senderProfileImageURL,
                body: body,
                attachment: attachment.map {
                    MessageAttachment(kind: $0.kind, filename: $0.filename, mimeType: $0.mimeType, size: $0.size)
                },
                createdAt: createdAt,
                isRead: isRead,
                reactions: reactions.map {
                    MessageReactionSummary(
                        emoji: $0.emoji,
                        count: $0.count,
                        reactedByCurrentUser: $0.reactedByCurrentUser
                    )
                }
            )
        }
    }

    private struct StoredDelivery: Codable {
        let id: String
        let accountID: String
        let destination: PendingDelivery.Destination
        let destinationID: String
        let body: String?
        let attachmentData: Data?
        let attachmentFileName: String?
        let attachmentMIMEType: String?
        let createdAt: Date

        var pendingDelivery: PendingDelivery {
            PendingDelivery(
                id: id,
                destination: destination,
                destinationID: destinationID,
                body: body,
                attachment: attachmentData.flatMap { data in
                    guard let attachmentFileName, let attachmentMIMEType else { return nil }
                    return MessageAttachmentUpload(data: data, fileName: attachmentFileName, mimeType: attachmentMIMEType)
                },
                createdAt: createdAt
            )
        }
    }

    private let fileURL: URL
    private var store: Store
    private var claimedDeliveryIDs: Set<String> = []

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = baseURL.appendingPathComponent("KTPLIFE", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("messages-offline.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Store.self, from: data) {
            store = decoded
        } else {
            store = Store()
        }
    }

    func loadInbox(accountID: String) -> [MessageThread] {
        (store.inboxes[accountID] ?? []).map(\.thread)
    }

    func saveInbox(_ threads: [MessageThread], accountID: String) {
        store.inboxes[accountID] = threads.prefix(100).map(CachedThread.init)
        persist()
    }

    func loadConversation(threadID: String, accountID: String) -> [KTPMessage] {
        (store.conversations[conversationKey(threadID: threadID, accountID: accountID)] ?? []).map(\.message)
    }

    func saveConversation(_ messages: [KTPMessage], threadID: String, accountID: String) {
        store.conversations[conversationKey(threadID: threadID, accountID: accountID)] =
            messages.suffix(150).map(CachedMessage.init)
        persist()
    }

    func enqueue(
        destination: PendingDelivery.Destination,
        destinationID: String,
        body: String?,
        attachment: MessageAttachmentUpload?,
        accountID: String
    ) -> PendingDelivery {
        let delivery = StoredDelivery(
            id: UUID().uuidString,
            accountID: accountID,
            destination: destination,
            destinationID: destinationID,
            body: body,
            attachmentData: attachment?.data,
            attachmentFileName: attachment?.fileName,
            attachmentMIMEType: attachment?.mimeType,
            createdAt: Date()
        )
        store.outbox.append(delivery)
        persist()
        return delivery.pendingDelivery
    }

    func pendingDeliveries(accountID: String, threadID: String? = nil) -> [PendingDelivery] {
        store.outbox
            .filter { $0.accountID == accountID && (threadID == nil || $0.pendingDelivery.threadID == threadID) }
            .map(\.pendingDelivery)
            .sorted { $0.createdAt < $1.createdAt }
    }

    func claimPendingDeliveries(accountID: String, threadID: String? = nil) -> [PendingDelivery] {
        let deliveries = store.outbox
            .filter {
                $0.accountID == accountID
                    && !claimedDeliveryIDs.contains($0.id)
                    && (threadID == nil || $0.pendingDelivery.threadID == threadID)
            }
            .map(\.pendingDelivery)
            .sorted { $0.createdAt < $1.createdAt }
        claimedDeliveryIDs.formUnion(deliveries.map(\.id))
        return deliveries
    }

    func releaseDeliveries(ids: some Sequence<String>) {
        claimedDeliveryIDs.subtract(ids)
    }

    func removeDelivery(id: String, accountID: String) {
        if let delivery = store.outbox.first(where: { $0.id == id && $0.accountID == accountID }) {
            let key = conversationKey(threadID: delivery.pendingDelivery.threadID, accountID: accountID)
            store.conversations[key]?.removeAll { $0.id == "pending-\(id)" }
        }
        store.outbox.removeAll { $0.id == id && $0.accountID == accountID }
        claimedDeliveryIDs.remove(id)
        persist()
    }

    private func conversationKey(threadID: String, accountID: String) -> String {
        "\(accountID)|\(threadID)"
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

func isOfflineTransportError(_ error: Error) -> Bool {
    guard let error = error as? URLError else { return false }
    return [
        .notConnectedToInternet,
        .networkConnectionLost,
        .cannotConnectToHost,
        .cannotFindHost,
        .dnsLookupFailed,
        .timedOut,
        .internationalRoamingOff,
        .dataNotAllowed,
        .secureConnectionFailed,
    ].contains(error.code)
}
