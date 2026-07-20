//
//  MessageThreadsView.swift
//  KTPLIFE
//

import SwiftUI

struct MessageThreadsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var threads: [MessageThread] = []
    @State private var isLoading = false
    @State private var loadError: String?

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var apiService: KTPAPIService {
        KTPAPIService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }

    var body: some View {
        Group {
            if isLoading {
                MessagesStatusCard(message: "Loading messages...")
            } else if let loadError {
                MessagesStatusCard(message: loadError)
            } else if threads.isEmpty {
                MessagesStatusCard(message: "No conversations yet.")
            } else {
                VStack(alignment: .leading, spacing: MessageThreadLayout.sectionSpacing) {
                    if !directThreads.isEmpty {
                        MessageThreadSection(title: "Direct Messages", threads: directThreads, apiService: apiService)
                    }

                    if !groupThreads.isEmpty {
                        MessageThreadSection(title: "Group Chats", threads: groupThreads, apiService: apiService)
                    }
                }
            }
        }
        .task {
            await loadConversations()
        }
    }

    private var directThreads: [MessageThread] {
        threads.filter { !$0.isGroup }
    }

    private var groupThreads: [MessageThread] {
        threads.filter(\.isGroup)
    }

    @MainActor
    private func loadConversations() async {
#if DEBUG
        if isPreview {
            threads = MessageConversation.previewSamples.map(MessageThread.direct) + GroupChat.previewSamples.map(MessageThread.group)
            loadError = nil
            return
        }
#endif

        isLoading = true
        loadError = nil

        do {
            async let directConversations = apiService.fetchMessageConversations()
            async let groupChats = apiService.fetchGroupChats()
            let loadedDirectConversations = try await directConversations
            let loadedGroupChats = try await groupChats
            let loadedThreads = loadedDirectConversations.map(MessageThread.direct) + loadedGroupChats.map(MessageThread.group)
            threads = loadedThreads.sorted { left, right in
                switch (left.lastMessageDate, right.lastMessageDate) {
                case let (leftDate?, rightDate?):
                    return leftDate > rightDate
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return left.displayName < right.displayName
                }
            }
        } catch {
            threads = []
            loadError = messagesErrorMessage(for: error)
        }

        isLoading = false
    }
}

/// Layout values for the inbox sections. Keeping this here documents the intentional visual separation.
private enum MessageThreadLayout {
    /// Separates Direct Messages from Group Chats while keeping both on the same inbox screen.
    static let sectionSpacing: CGFloat = 28

    /// Separates individual conversations without placing them inside card rectangles.
    static let rowSpacing: CGFloat = 22
}

/// A labeled inbox section that keeps one-to-one conversations distinct from group chats.
private struct MessageThreadSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let threads: [MessageThread]
    let apiService: KTPAPIService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppFont.headline())
                .foregroundStyle(MessageDesign.primary(for: colorScheme))

            threadRows
        }
    }

    private var threadRows: some View {
        LazyVStack(spacing: MessageThreadLayout.rowSpacing) {
            ForEach(threads) { thread in
                NavigationLink(value: thread) {
                    MessageThreadCard(thread: thread, apiService: apiService)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MessageThreadCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let thread: MessageThread
    let apiService: KTPAPIService

    private var profileID: String? {
        guard case .direct(let conversation) = thread else { return nil }
        return conversation.userId
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ProfileAvatarView(
                imageURL: thread.profileImageURL,
                profileID: profileID,
                name: thread.displayName,
                isGroup: thread.isGroup,
                size: 51,
                apiService: apiService
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(thread.displayName)
                    .font(AppFont.subheadline(weight: .semibold))
                    .foregroundStyle(MessageDesign.primary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(thread.preview)
                    .font(AppFont.subheadline())
                    .foregroundStyle(MessageDesign.muted(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 12)

            if thread.unreadCount > 0 {
                Circle()
                    .fill(AppSurfaceColor.primaryControl)
                    .frame(width: 9, height: 9)
                    .accessibilityLabel("Unread")
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct ProfileAvatarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @EnvironmentObject private var avatarRepository: AvatarRepository
    let imageURL: URL?
    let profileID: String?
    let name: String
    let isGroup: Bool
    let size: CGFloat
    let apiService: KTPAPIService

    @State private var image: UIImage?

    private var initials: String {
        let parts = name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)

        let value = String(parts).uppercased()
        return value.isEmpty ? "KT" : value
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(MessageDesign.avatarBackground(for: colorScheme))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isGroup {
                Image(systemName: "person.3.fill")
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(MessageDesign.primary(for: colorScheme))
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("\(name) profile picture")
        .task(id: "\(profileID ?? imageURL?.absoluteString ?? name)-\(Int(size * displayScale))") {
            await loadImage()
        }
    }

    private var fallback: some View {
        Text(initials)
            .font(AppFont.caption(weight: .bold))
            .foregroundStyle(MessageDesign.primary(for: colorScheme))
    }

    @MainActor
    private func loadImage() async {
        guard !isGroup else {
            image = nil
            return
        }

        let sourceID = profileID ?? imageURL?.absoluteString ?? name
        let avatar = await avatarRepository.image(
            for: sourceID,
            pointSize: size,
            displayScale: displayScale,
            loadData: {
                if let imageURL {
                    return try await URLSession.shared.data(from: imageURL).0
                }

                guard let profileID else { throw URLError(.badURL) }
                return try await apiService.fetchProfilePictureData(for: profileID)
            }
        )
        guard !Task.isCancelled else { return }
        image = avatar
    }
}

struct MessageConversationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var authManager: AuthManager
    @State private var messages: [KTPMessage] = []
    @State private var draftMessage = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var loadError: String?
    @State private var sentMessageIDs: Set<String> = []
    @State private var renderWindow = ConversationRenderWindow()
    @State private var isAwayFromLatest = false
    @State private var scrollRequest: ConversationScrollRequest?
    @State private var reportTarget: ReportTarget?
    @State private var isBlocked = false
    @State private var isUpdatingBlock = false
    @State private var showsBlockConfirmation = false
    @State private var blockErrorMessage: String?
    @FocusState private var isComposerFocused: Bool

    let thread: MessageThread

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var apiService: KTPAPIService {
        KTPAPIService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }

    var body: some View {
        VStack(spacing: 20) {
            if isBlocked {
                MessagesStatusCard(message: "You blocked \(thread.displayName). Unblock them to resume this conversation.")
            } else if isLoading {
                MessagesStatusCard(message: "Loading conversation...")
            } else if let loadError {
                MessagesStatusCard(message: loadError)
            } else if messages.isEmpty {
                MessagesStatusCard(message: "No messages in this conversation yet.")
            } else {
                messageTimeline
            }

        }
        // Fill the navigation destination so the safe-area composer is anchored to
        // the bottom of the screen instead of immediately following short content.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(thread.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBlockState()
            await loadConversation()
        }
        .toolbar {
            if directConversation != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if isBlocked {
                            Button("Unblock Member") {
                                Task { await setBlocked(false) }
                            }
                        } else {
                            Button("Block Member", role: .destructive) {
                                showsBlockConfirmation = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .disabled(isUpdatingBlock)
                    .accessibilityLabel("Conversation options")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isBlocked {
                messageComposer
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(MessageDesign.background(for: colorScheme))
            }
        }
        .background(MessageDesign.background(for: colorScheme).ignoresSafeArea())
        .sheet(item: $reportTarget) { target in
            ReportContentSheet(target: target)
        }
        .confirmationDialog(
            "Block \(thread.displayName)?",
            isPresented: $showsBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Block Member", role: .destructive) {
                Task { await setBlocked(true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They will not be able to start new direct messages with you, and their messages will be hidden from your conversation and group-chat views.")
        }
        .alert("Couldn’t Update Block", isPresented: Binding(
            get: { blockErrorMessage != nil },
            set: { if !$0 { blockErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(blockErrorMessage ?? "Please try again.")
        }
    }

    private var directConversation: MessageConversation? {
        guard case .direct(let conversation) = thread else { return nil }
        return conversation
    }

    @ViewBuilder
    private var messageComposer: some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            GlassEffectContainer(spacing: 16) {
                messageComposerContent
            }
        } else {
            messageComposerContent
        }
    }

    private var messageComposerContent: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $draftMessage, axis: .vertical)
                .font(AppFont.subheadline())
                .lineLimit(1...4)
                .foregroundStyle(MessageDesign.primary(for: colorScheme))
                .textInputAutocapitalization(.sentences)
                .focused($isComposerFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .modifier(MessageComposerFieldSurface(
                    colorScheme: colorScheme,
                    reduceTransparency: reduceTransparency
                ))

            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(AppFont.footnote(weight: .semibold))
                    .foregroundStyle(composerCanSend ? .white : MessageDesign.muted(for: colorScheme))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .modifier(MessageSendButtonSurface(
                canSend: composerCanSend,
                reduceTransparency: reduceTransparency
            ))
            .disabled(!composerCanSend)
            .accessibilityLabel("Send message")
        }
        .padding(4)
    }

    private var composerCanSend: Bool {
        !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private var visibleMessages: [KTPMessage] {
        Array(messages.suffix(renderWindow.visibleCount))
    }

    private var messageTimeline: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView(showsIndicators: false) {
                    messageStack
                }
                .scrollDismissesKeyboard(.interactively)
                .onScrollGeometryChange(for: Bool.self, of: { geometry in
                    geometry.contentOffset.y + geometry.containerSize.height < geometry.contentSize.height - 32
                }, action: { _, isAwayFromLatest in
                    self.isAwayFromLatest = isAwayFromLatest
                })

                if isAwayFromLatest {
                    Button("Jump to Latest", systemImage: "arrow.down") {
                        scrollRequest = .latest(UUID())
                    }
                    .modifier(MessageTimelineActionSurface(
                        prominent: true,
                        reduceTransparency: reduceTransparency
                    ))
                    .padding(12)
                }
            }
            .onChange(of: scrollRequest) { _, request in
                guard let request else { return }

                Task { @MainActor in
                    await Task.yield()

                    switch request {
                    case .preservePosition(let messageID):
                        proxy.scrollTo(messageID, anchor: .top)
                    case .latest:
                        withAnimation {
                            proxy.scrollTo(ConversationScrollAnchor.latest, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var messageStack: some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            GlassEffectContainer(spacing: 16) {
                messageStackContent
            }
        } else {
            messageStackContent
        }
    }

    private var messageStackContent: some View {
        LazyVStack(spacing: 16) {
            if renderWindow.hasEarlierMessages(totalCount: messages.count) {
                Button("Load earlier messages") {
                    let preservedMessageID = visibleMessages.first?.id
                    renderWindow.loadEarlierMessages(totalCount: messages.count)

                    if let preservedMessageID {
                        scrollRequest = .preservePosition(preservedMessageID)
                    }
                }
                .modifier(MessageTimelineActionSurface(
                    prominent: false,
                    reduceTransparency: reduceTransparency
                ))
                .padding(.bottom, 4)
            }

            ForEach(visibleMessages) { message in
                MessageBubble(
                    message: message,
                    sender: sender(for: message),
                    isSentByCurrentUser: isSentByCurrentUser(message),
                    apiService: apiService,
                    reportMessage: isSentByCurrentUser(message) ? nil : {
                        reportTarget = ReportTarget.message(
                            message,
                            isGroupMessage: thread.isGroup,
                            senderName: sender(for: message).name
                        )
                    }
                )
            }

            Color.clear
                .frame(height: 1)
                .id(ConversationScrollAnchor.latest)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func sender(for message: KTPMessage) -> MessageSender {
        switch thread {
        case .direct(let conversation):
            if message.senderId == conversation.userId {
                return MessageSender(
                    id: conversation.userId,
                    name: conversation.displayName,
                    imageURL: message.senderProfileImageURL ?? conversation.profileImageURL
                )
            }

            return MessageSender(
                id: message.senderId,
                name: message.senderDisplayName ?? "You",
                imageURL: message.senderProfileImageURL
            )
        case .group:
            return MessageSender(
                id: message.senderId,
                name: message.senderDisplayName ?? "Member",
                imageURL: message.senderProfileImageURL
            )
        }
    }

    private func isSentByCurrentUser(_ message: KTPMessage) -> Bool {
        if sentMessageIDs.contains(message.id) {
            return true
        }

        switch thread {
        case .direct(let conversation):
            if message.senderId == authManager.currentUserID {
                return true
            }

            if message.recipientId == authManager.currentUserID {
                return false
            }

            if message.senderId == conversation.userId {
                return false
            }

            if message.recipientId == conversation.userId {
                return true
            }

            return false
        case .group:
            return message.senderId == authManager.currentUserID ||
                message.senderDisplayName?.caseInsensitiveCompare("You") == .orderedSame
        }
    }

    @MainActor
    private func loadBlockState() async {
        guard let conversation = directConversation else { return }

        do {
            isBlocked = try await apiService.fetchBlockedUserIDs().contains(conversation.userId)
        } catch is CancellationError {
            return
        } catch {
            blockErrorMessage = "Could not load this member’s block status."
        }
    }

    @MainActor
    private func setBlocked(_ shouldBlock: Bool) async {
        guard let conversation = directConversation, !isUpdatingBlock else { return }
        isUpdatingBlock = true
        blockErrorMessage = nil

        do {
            if shouldBlock {
                try await apiService.blockUser(id: conversation.userId)
                messages = []
                draftMessage = ""
                isComposerFocused = false
            } else {
                try await apiService.unblockUser(id: conversation.userId)
            }
            isBlocked = shouldBlock

            if !shouldBlock {
                await loadConversation()
            }
        } catch {
            blockErrorMessage = shouldBlock
                ? "Could not block this member. Please try again."
                : "Could not unblock this member. Please try again."
        }

        isUpdatingBlock = false
    }

    @MainActor
    private func loadConversation() async {
#if DEBUG
        if isPreview {
            messages = KTPMessage.previewSamples
            renderWindow.reset(totalCount: messages.count)
            scrollRequest = .latest(UUID())
            loadError = nil
            return
        }
#endif

        isLoading = true
        loadError = nil

        do {
            switch thread {
            case .direct(let conversation):
                async let fetchedMessages = apiService.fetchConversation(with: conversation.userId)
                async let markRead: Void = apiService.markConversationRead(with: conversation.userId)
                messages = try await fetchedMessages
                _ = try? await markRead
            case .group(let chat):
                async let fetchedMessages = apiService.fetchGroupChatMessages(chatId: chat.id)
                async let markRead: Void = apiService.markGroupChatRead(chatId: chat.id)
                messages = try await fetchedMessages
                _ = try? await markRead
            }
            messages.sort { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            // TODO: Replace this temporary client-side render window when the API exposes cursor/limit message pagination.
            renderWindow.reset(totalCount: messages.count)
            scrollRequest = .latest(UUID())
        } catch {
            messages = []
            loadError = messagesErrorMessage(for: error)
        }

        isLoading = false
    }

    @MainActor
    private func sendMessage() async {
        let content = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !isSending else { return }

        isSending = true
        loadError = nil

        do {
            let sentMessage: KTPMessage
            switch thread {
            case .direct(let conversation):
                sentMessage = try await apiService.sendMessage(to: conversation.userId, content: content)
            case .group(let chat):
                sentMessage = try await apiService.sendGroupChatMessage(chatId: chat.id, body: content)
            }
            messages.append(sentMessage)
            messages.sort { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            sentMessageIDs.insert(sentMessage.id)
            renderWindow.reset(totalCount: messages.count)
            scrollRequest = .latest(UUID())
            draftMessage = ""
        } catch {
            loadError = messagesErrorMessage(for: error)
        }

        isSending = false
    }
}

/// Limits the rendered conversation while the current API returns one unpaginated message array.
private struct ConversationRenderWindow {
    private let pageSize = 50
    private(set) var visibleCount = 0

    mutating func reset(totalCount: Int) {
        visibleCount = min(pageSize, totalCount)
    }

    mutating func loadEarlierMessages(totalCount: Int) {
        visibleCount = min(totalCount, visibleCount + pageSize)
    }

    func hasEarlierMessages(totalCount: Int) -> Bool {
        visibleCount < totalCount
    }
}

private enum ConversationScrollAnchor {
    static let latest = "conversation-latest"
}

private enum ConversationScrollRequest: Equatable {
    case preservePosition(String)
    case latest(UUID)
}

private struct MessageSender {
    let id: String?
    let name: String
    let imageURL: URL?
}

private struct MessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let message: KTPMessage
    let sender: MessageSender
    let isSentByCurrentUser: Bool
    let apiService: KTPAPIService
    let reportMessage: (() -> Void)?

    var body: some View {
        VStack(alignment: isSentByCurrentUser ? .trailing : .leading, spacing: 10) {
            messageHeader

            VStack(alignment: .leading, spacing: 10) {
                Text(message.body)
                    .font(AppFont.subheadline())
                    .foregroundStyle(MessageDesign.primary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                if let createdAt = message.createdAt {
                    Text(createdAt.relativeMessageTime)
                        .font(AppFont.caption(weight: .medium))
                        .foregroundStyle(MessageDesign.muted(for: colorScheme))
                }
            }
            .padding(16)
            .frame(maxWidth: 290, alignment: .leading)
            .modifier(MessageBubbleSurface(
                isSentByCurrentUser: isSentByCurrentUser,
                colorScheme: colorScheme,
                reduceTransparency: reduceTransparency
            ))
        }
        .frame(maxWidth: .infinity, alignment: isSentByCurrentUser ? .trailing : .leading)
    }

    @ViewBuilder
    private var messageHeader: some View {
        HStack(spacing: 10) {
            if isSentByCurrentUser {
                Text(sender.name)
                    .font(AppFont.caption(weight: .bold))
                    .foregroundStyle(MessageDesign.muted(for: colorScheme))
                    .lineLimit(1)

                AuthenticatedMessageAvatar(sender: sender, apiService: apiService)
                    .frame(width: 28, height: 28)
            } else {
                AuthenticatedMessageAvatar(sender: sender, apiService: apiService)
                    .frame(width: 28, height: 28)

                Text(sender.name)
                    .font(AppFont.caption(weight: .bold))
                    .foregroundStyle(MessageDesign.muted(for: colorScheme))
                    .lineLimit(1)
            }

            if let reportMessage {
                Menu {
                    Button("Report Message", role: .destructive, action: reportMessage)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(AppFont.caption(weight: .bold))
                        .foregroundStyle(MessageDesign.muted(for: colorScheme))
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("Report message options")
            }
        }
    }
}

private struct AuthenticatedMessageAvatar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @EnvironmentObject private var avatarRepository: AvatarRepository
    let sender: MessageSender
    let apiService: KTPAPIService

    @State private var image: UIImage?

    private var initials: String {
        let value = String(sender.name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
        return value.isEmpty ? "KT" : value
    }

    var body: some View {
        ZStack {
            Circle().fill(MessageDesign.avatarBackground(for: colorScheme))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initials)
                    .font(AppFont.caption(weight: .bold))
                    .foregroundStyle(MessageDesign.primary(for: colorScheme))
            }
        }
        .clipShape(Circle())
        .task(id: "\(sender.id ?? sender.imageURL?.absoluteString ?? sender.name)-\(Int(28 * displayScale))") {
            await loadImage()
        }
        .accessibilityLabel("\(sender.name) profile picture")
    }

    @MainActor
    private func loadImage() async {
        let sourceID = sender.id ?? sender.imageURL?.absoluteString ?? sender.name
        let avatar = await avatarRepository.image(
            for: sourceID,
            pointSize: 28,
            displayScale: displayScale,
            loadData: {
                if let imageURL = sender.imageURL {
                    return try await URLSession.shared.data(from: imageURL).0
                }

                guard let senderID = sender.id else { throw URLError(.badURL) }
                return try await apiService.fetchProfilePictureData(for: senderID)
            }
        )
        guard !Task.isCancelled else { return }
        image = avatar
    }
}

private struct MessagesStatusCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: String

    var body: some View {
        Text(message)
            .font(AppFont.subheadline())
            .foregroundStyle(MessageDesign.secondary(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(MessageDesign.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MessageDesign.border(for: colorScheme), lineWidth: 1)
            }
    }
}

enum MessageDesign {
    static func background(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.background
    }

    static func card(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.elevatedBackground
    }

    static func primary(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.primaryLabel
    }

    static func secondary(for colorScheme: ColorScheme) -> Color {
        primary(for: colorScheme).opacity(0.72)
    }

    static func muted(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.secondaryLabel
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.separator.opacity(colorScheme == .dark ? 0.65 : 0.45)
    }

    static func shadow(for colorScheme: ColorScheme) -> Color {
        Color.black.opacity(colorScheme == .dark ? 0.12 : 0.035)
    }

    static func avatarBackground(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.insetBackground
    }

    static func input(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.insetBackground
    }

    static func sentBubble(for colorScheme: ColorScheme) -> Color {
        AppSurfaceColor.primaryControl.opacity(colorScheme == .dark ? 0.40 : 0.18)
    }

    static func selectionTint(for colorScheme: ColorScheme) -> Color {
        AppSurfaceColor.primaryControl.opacity(colorScheme == .dark ? 0.38 : 0.20)
    }

    static func glassTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.32)
    }
}

private struct MessageBubbleSurface: ViewModifier {
    let isSentByCurrentUser: Bool
    let colorScheme: ColorScheme
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(
                .regular.tint(
                    isSentByCurrentUser
                        ? AppSurfaceColor.primaryControl.opacity(colorScheme == .dark ? 0.34 : 0.20)
                        : MessageDesign.glassTint(for: colorScheme)
                ),
                in: .rect(cornerRadius: 18)
            )
        } else {
            content
                .background(
                    isSentByCurrentUser
                        ? MessageDesign.sentBubble(for: colorScheme)
                        : MessageDesign.card(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(MessageDesign.border(for: colorScheme), lineWidth: 1)
                }
        }
    }
}

private struct MessageComposerFieldSurface: ViewModifier {
    let colorScheme: ColorScheme
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(.regular, in: .rect(cornerRadius: 18))
        } else {
            content
                .background(
                    MessageDesign.input(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(MessageDesign.border(for: colorScheme), lineWidth: 1)
                }
        }
    }
}

private struct MessageSendButtonSurface: ViewModifier {
    let canSend: Bool
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(
                .regular
                    .tint(canSend ? AppSurfaceColor.primaryControl : AppSurfaceColor.disabledControl)
                    .interactive(canSend),
                in: .circle
            )
        } else {
            content.background(
                canSend ? AppSurfaceColor.primaryControl : AppSurfaceColor.disabledControl,
                in: Circle()
            )
        }
    }
}

private struct MessageTimelineActionSurface: ViewModifier {
    let prominent: Bool
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else if prominent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

private func messagesErrorMessage(for error: Error) -> String {
    if case AuthManagerError.notAuthenticated = error {
        return "Sign in with SSO to load messages."
    }

    if case KTPAPIError.missingAccessToken = error {
        return "Sign in with SSO to load messages."
    }

    if case KTPAPIError.badStatusCode(let statusCode, _) = error {
        if statusCode == 401 || statusCode == 403 {
            return "Your message access has expired. Sign out and sign in again."
        }

        return "Messages are temporarily unavailable. Please try again later."
    }

    if case KTPAPIError.decodeFailed(_) = error {
        return "Messages returned an unsupported response. Please try again later."
    }

    return "Could not load messages. Please check your connection and try again."
}

private extension Date {
    var relativeMessageTime: String {
        if Calendar.current.isDateInToday(self) {
            return formatted(date: .omitted, time: .shortened)
        }

        if Calendar.current.isDateInYesterday(self) {
            return "Yesterday"
        }

        return formatted(date: .abbreviated, time: .omitted)
    }
}

#if DEBUG
#Preview("Message Threads") {
    NavigationStack {
        MessageThreadsView()
            .padding(20)
            .background(AppTab.messages.theme.previewBackground())
    }
    .environmentObject(AuthManager.previewSignedOut)
    .environmentObject(AvatarRepository())
}
#endif
