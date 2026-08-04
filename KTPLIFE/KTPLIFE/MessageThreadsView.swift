//
//  MessageThreadsView.swift
//  KTPLIFE
//

import SwiftUI

struct MessageThreadsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authManager: AuthManager
    @State private var threads: [MessageThread] = []
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var loadError: String?

    let refreshVersion: Int

    init(refreshVersion: Int = 0) {
        self.refreshVersion = refreshVersion
    }

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
                        MessageThreadSection(title: nil, threads: directThreads, apiService: apiService)
                    }

                    if !groupThreads.isEmpty {
                        MessageThreadSection(title: "Group Chats", threads: groupThreads, apiService: apiService)
                    }
                }
            }
        }
        .task(id: refreshVersion) {
            await monitorConversations()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await loadConversations(showsLoadingState: false) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .messageThreadShouldRefresh)) { _ in
            Task { await loadConversations(showsLoadingState: false) }
        }
    }

    private var directThreads: [MessageThread] {
        threads.filter { !$0.isGroup }
    }

    private var groupThreads: [MessageThread] {
        threads.filter(\.isGroup)
    }

    @MainActor
    private func monitorConversations() async {
        await loadConversations(showsLoadingState: true)

        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: 8_000_000_000)
            } catch {
                return
            }

            await loadConversations(showsLoadingState: false)
        }
    }

    @MainActor
    private func loadConversations(showsLoadingState: Bool) async {
#if DEBUG
        if isPreview {
            threads = MessageConversation.previewSamples.map(MessageThread.direct) + GroupChat.previewSamples.map(MessageThread.group)
            loadError = nil
            return
        }
#endif

        guard !isRefreshing else { return }
        isRefreshing = true
        if showsLoadingState, threads.isEmpty {
            isLoading = true
        }
        loadError = nil

        async let directResult = fetchDirectConversationsResult()
        async let groupResult = fetchGroupChatsResult()
        let (loadedDirectResult, loadedGroupResult) = await (directResult, groupResult)

        guard !Task.isCancelled else {
            isLoading = false
            isRefreshing = false
            return
        }

        let previousDirectThreads = directThreads
        let previousGroupThreads = groupThreads
        let resolvedDirectThreads: [MessageThread]
        let resolvedGroupThreads: [MessageThread]
        var loadFailures: [Error] = []

        switch loadedDirectResult {
        case .success(let conversations):
            resolvedDirectThreads = conversations.map(MessageThread.direct)
        case .failure(let error):
            resolvedDirectThreads = previousDirectThreads
            loadFailures.append(error)
        }

        switch loadedGroupResult {
        case .success(let chats):
            resolvedGroupThreads = chats.map(MessageThread.group)
        case .failure(let error):
            resolvedGroupThreads = previousGroupThreads
            loadFailures.append(error)
        }

        threads = sortedThreads(resolvedDirectThreads + resolvedGroupThreads)

        // A group-chat outage should not erase working direct messages (or vice
        // versa). Only replace the inbox with an error when neither request
        // succeeded and there is no previously loaded content to preserve.
        if loadFailures.count == 2, threads.isEmpty, let error = loadFailures.first {
            loadError = messagesErrorMessage(for: error)
        }

        isLoading = false
        isRefreshing = false
    }

    private func fetchDirectConversationsResult() async -> Result<[MessageConversation], Error> {
        do {
            return .success(try await apiService.fetchMessageConversations())
        } catch {
            return .failure(error)
        }
    }

    private func fetchGroupChatsResult() async -> Result<[GroupChat], Error> {
        do {
            return .success(try await apiService.fetchGroupChats())
        } catch {
            return .failure(error)
        }
    }

    private func sortedThreads(_ threads: [MessageThread]) -> [MessageThread] {
        threads.sorted { left, right in
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
    let title: String?
    let threads: [MessageThread]
    let apiService: KTPAPIService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(AppFont.headline())
                    .foregroundStyle(MessageDesign.primary(for: colorScheme))
            }

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
            threadAvatar

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

    @ViewBuilder
    private var threadAvatar: some View {
        if case .group(let chat) = thread {
            GroupChatAvatar(chat: chat, size: 51, apiService: apiService)
        } else {
            ProfileAvatarView(
                imageURL: thread.profileImageURL,
                profileID: profileID,
                name: thread.displayName,
                isGroup: false,
                size: 51,
                apiService: apiService
            )
        }
    }
}

private struct GroupChatAvatar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @EnvironmentObject private var avatarRepository: AvatarRepository
    let chat: GroupChat
    let size: CGFloat
    let apiService: KTPAPIService

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(MessageDesign.avatarBackground(for: colorScheme))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.3.fill")
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(MessageDesign.primary(for: colorScheme))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("\(chat.name) group photo")
        // The asset ID is part of the cache key. A replacement upload creates a
        // different asset, so this task and its URL-equivalent cache key update too.
        .task(id: "\(chat.id)-\(chat.photoAssetID ?? "no-photo")-\(Int(size * displayScale))") {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        guard let photoAssetID = chat.photoAssetID, !photoAssetID.isEmpty else {
            image = nil
            return
        }

        image = nil
        image = await avatarRepository.image(
            for: "group-chat-\(chat.id)-\(photoAssetID)",
            pointSize: size,
            displayScale: displayScale,
            loadData: { try await apiService.fetchGroupChatPhotoData(chatID: chat.id) }
        )
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
    @State private var isRefreshingConversation = false
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
    @State private var reactionsByMessageID: [String: [String: MessageReactionSummary]] = [:]
    @State private var updatingReactionKeys: Set<String> = []
    @State private var reactionErrorMessage: String?
    @State private var sendErrorMessage: String?
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
        VStack(spacing: 12) {
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
            await monitorConversation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .messageThreadShouldRefresh)) { _ in
            Task { await loadConversation(showsLoadingState: false) }
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
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .onChange(of: isComposerFocused) { _, isFocused in
            guard isFocused, !messages.isEmpty else { return }

            // Let the keyboard finish resizing the timeline before aligning the
            // newest bubble. Scrolling during the transition can place content
            // underneath the composer.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                guard isComposerFocused else { return }
                scrollRequest = .latest(UUID())
            }
        }
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
        .alert("Couldn’t Update Reaction", isPresented: Binding(
            get: { reactionErrorMessage != nil },
            set: { if !$0 { reactionErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reactionErrorMessage ?? "Please try again.")
        }
        .alert("Couldn’t Send Message", isPresented: Binding(
            get: { sendErrorMessage != nil },
            set: { if !$0 { sendErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sendErrorMessage ?? "Please try again.")
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
                    .foregroundStyle(
                        composerCanSend
                            ? MessageDesign.sendForeground
                            : MessageDesign.muted(for: colorScheme)
                    )
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
                // The timeline is inserted only after the initial API load, so
                // an earlier scroll request can predate the ScrollViewReader.
                // Giving the scroll view a bottom default guarantees that a
                // newly opened thread begins at its most recent message.
                .defaultScrollAnchor(.bottom)
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
                        if let latestMessageID = visibleMessages.last?.id {
                            withAnimation {
                                proxy.scrollTo(latestMessageID, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .onAppear {
                // The initial request is set while the loading state is still
                // displayed, before this reader exists. Scroll explicitly once
                // the timeline has been laid out so opening a conversation always
                // lands on its newest message.
                Task { @MainActor in
                    await Task.yield()
                    if let latestMessageID = visibleMessages.last?.id {
                        proxy.scrollTo(latestMessageID, anchor: .bottom)
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
        LazyVStack(spacing: 10) {
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
                    showsSenderIdentity: startsMessageGroup(for: message),
                    apiService: apiService,
                    allowsReactions: true,
                    reactions: reactionSummaries(for: message),
                    updatingEmojis: updatingEmojis(for: message),
                    toggleReaction: { emoji in
                        Task { await toggleReaction(emoji, on: message) }
                    },
                    reportMessage: isSentByCurrentUser(message) ? nil : {
                        reportTarget = ReportTarget.message(
                            message,
                            isGroupMessage: thread.isGroup,
                            senderName: sender(for: message).name
                        )
                    }
                )
            }

        }
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func startsMessageGroup(for message: KTPMessage) -> Bool {
        guard let messageIndex = messages.firstIndex(where: { $0.id == message.id }) else {
            return true
        }

        // A visible window can begin in the middle of a run. Show its sender so
        // the truncated timeline still has useful context.
        guard message.id != visibleMessages.first?.id, messageIndex > 0 else {
            return true
        }

        let previousMessage = messages[messageIndex - 1]
        guard isSameMessageSender(previousMessage, message) else {
            return true
        }

        guard let previousDate = previousMessage.createdAt,
              let messageDate = message.createdAt else {
            return false
        }

        return messageDate.timeIntervalSince(previousDate) > MessageGrouping.maximumInterval
    }

    private func isSameMessageSender(_ left: KTPMessage, _ right: KTPMessage) -> Bool {
        let leftIsCurrentUser = isSentByCurrentUser(left)
        guard leftIsCurrentUser == isSentByCurrentUser(right) else { return false }
        guard !leftIsCurrentUser else { return true }

        if let leftSenderID = left.senderId, let rightSenderID = right.senderId {
            return leftSenderID == rightSenderID
        }

        return sender(for: left).name.caseInsensitiveCompare(sender(for: right).name) == .orderedSame
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
    private func monitorConversation() async {
        await loadBlockState()
        await loadConversation(showsLoadingState: true)

        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000)
            } catch {
                return
            }

            guard !isBlocked else { continue }
            await loadConversation(showsLoadingState: false)
        }
    }

    @MainActor
    private func loadConversation(showsLoadingState: Bool = true) async {
#if DEBUG
        if isPreview {
            messages = KTPMessage.previewSamples
            seedReactionState(from: messages)
            renderWindow.reset(totalCount: messages.count)
            scrollRequest = .latest(UUID())
            loadError = nil
            return
        }
#endif

        guard !isRefreshingConversation else { return }
        isRefreshingConversation = true
        defer { isRefreshingConversation = false }

        if showsLoadingState {
            isLoading = true
            loadError = nil
        }

        do {
            let loadedMessages: [KTPMessage]
            switch thread {
            case .direct(let conversation):
                loadedMessages = try await apiService.fetchConversation(with: conversation.userId)
            case .group(let chat):
                loadedMessages = try await apiService.fetchGroupChatMessages(chatId: chat.id)
            }

            let existingMessageIDs = Set(messages.map(\.id))
            let hasNewMessages = loadedMessages.contains { !existingMessageIDs.contains($0.id) }
            messages = loadedMessages
            messages.sort { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            seedReactionState(from: messages)
            // TODO: Replace this temporary client-side render window when the API exposes cursor/limit message pagination.
            renderWindow.reset(totalCount: messages.count)
            if showsLoadingState || (hasNewMessages && !isAwayFromLatest) {
                scrollRequest = .latest(UUID())
            }

            if showsLoadingState || hasNewMessages {
                switch thread {
                case .direct(let conversation):
                    try? await apiService.markConversationRead(with: conversation.userId)
                case .group(let chat):
                    try? await apiService.markGroupChatRead(chatId: chat.id)
                }
            }
        } catch is CancellationError {
            if showsLoadingState {
                isLoading = false
            }
            return
        } catch {
            if showsLoadingState, messages.isEmpty {
                loadError = messagesErrorMessage(for: error)
            }
        }

        if showsLoadingState {
            isLoading = false
        }
    }

    @MainActor
    private func sendMessage() async {
        let content = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !isSending else { return }

        isSending = true
        sendErrorMessage = nil

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
            loadError = nil
        } catch is CancellationError {
            isSending = false
            return
        } catch {
            sendErrorMessage = messageSendErrorMessage(for: error)
        }

        isSending = false
    }

    private func reactionSummaries(for message: KTPMessage) -> [MessageReactionSummary] {
        Array(reactionsByMessageID[message.id, default: [:]].values)
            .filter { $0.count > 0 }
            .sorted { left, right in
                let leftIndex = MessageReactionOptions.emojis.firstIndex(of: left.emoji) ?? .max
                let rightIndex = MessageReactionOptions.emojis.firstIndex(of: right.emoji) ?? .max
                return leftIndex == rightIndex ? left.emoji < right.emoji : leftIndex < rightIndex
            }
    }

    private func updatingEmojis(for message: KTPMessage) -> Set<String> {
        Set(MessageReactionOptions.emojis.filter {
            updatingReactionKeys.contains(reactionKey(messageID: message.id, emoji: $0))
        })
    }

    private func seedReactionState(from messages: [KTPMessage]) {
        reactionsByMessageID = Dictionary(uniqueKeysWithValues: messages.map { message in
            (
                message.id,
                Dictionary(uniqueKeysWithValues: message.reactions.map { ($0.emoji, $0) })
            )
        })
    }

    @MainActor
    private func toggleReaction(_ emoji: String, on message: KTPMessage) async {
        let updateKey = reactionKey(messageID: message.id, emoji: emoji)
        guard updatingReactionKeys.insert(updateKey).inserted else { return }
        defer { updatingReactionKeys.remove(updateKey) }

        let previous = reactionsByMessageID[message.id]?[emoji]
            ?? MessageReactionSummary(emoji: emoji, count: 0, reactedByCurrentUser: false)
        let isAdding = !previous.reactedByCurrentUser
        let updated = MessageReactionSummary(
            emoji: emoji,
            count: max(0, previous.count + (isAdding ? 1 : -1)),
            reactedByCurrentUser: isAdding
        )
        setReaction(updated, on: message.id)

        do {
            switch thread {
            case .direct:
                try await apiService.toggleMessageReaction(messageId: message.id, emoji: emoji)
            case .group(let chat):
                try await apiService.toggleGroupChatMessageReaction(
                    chatId: chat.id,
                    messageId: message.id,
                    emoji: emoji
                )
            }
        } catch is CancellationError {
            setReaction(previous, on: message.id)
        } catch {
            setReaction(previous, on: message.id)
            reactionErrorMessage = "The reaction could not be saved. Please try again."
        }
    }

    private func setReaction(_ reaction: MessageReactionSummary, on messageID: String) {
        if reaction.count == 0 {
            reactionsByMessageID[messageID]?[reaction.emoji] = nil
        } else {
            reactionsByMessageID[messageID, default: [:]][reaction.emoji] = reaction
        }
    }

    private func reactionKey(messageID: String, emoji: String) -> String {
        "\(messageID)|\(emoji)"
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

private enum MessageGrouping {
    /// Consecutive messages from one person remain a single visual group unless
    /// there has been a meaningful pause in the conversation.
    static let maximumInterval: TimeInterval = 5 * 60
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
    @State private var showsMessageActions = false
    @State private var holdFeedbackTrigger = 0
    let message: KTPMessage
    let sender: MessageSender
    let isSentByCurrentUser: Bool
    let showsSenderIdentity: Bool
    let apiService: KTPAPIService
    let allowsReactions: Bool
    let reactions: [MessageReactionSummary]
    let updatingEmojis: Set<String>
    let toggleReaction: (String) -> Void
    let reportMessage: (() -> Void)?

    var body: some View {
        VStack(alignment: isSentByCurrentUser ? .trailing : .leading, spacing: 6) {
            messageHeader

            messageSurface
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.35, maximumDistance: 22)
                        .onEnded { _ in
                            holdFeedbackTrigger += 1
                            showsMessageActions = true
                        }
                )
                .sensoryFeedback(.impact(weight: .medium), trigger: holdFeedbackTrigger)
                .popover(
                    isPresented: $showsMessageActions,
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: isSentByCurrentUser ? .trailing : .leading
                ) {
                    messageActionsPopover
                        .presentationCompactAdaptation(.popover)
                }

            if allowsReactions, !reactions.isEmpty {
                reactionBar
            }
        }
        .frame(maxWidth: .infinity, alignment: isSentByCurrentUser ? .trailing : .leading)
        .accessibilityHint("Touch and hold for reactions and reporting options")
    }

    private var messageSurface: some View {
        VStack(alignment: .leading, spacing: 5) {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 260, alignment: .leading)
        .modifier(MessageBubbleSurface(
            isSentByCurrentUser: isSentByCurrentUser,
            colorScheme: colorScheme,
            reduceTransparency: reduceTransparency
        ))
    }

    private var messageActionsPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            if allowsReactions {
                HStack(spacing: 4) {
                    ForEach(MessageReactionOptions.emojis, id: \.self) { emoji in
                        Button {
                            showsMessageActions = false
                            toggleReaction(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 22))
                                .frame(width: 38, height: 38)
                                .background(
                                    hasCurrentUserReaction(emoji)
                                        ? MessageDesign.selectionTint(for: colorScheme)
                                        : Color.clear,
                                    in: Circle()
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(updatingEmojis.contains(emoji))
                        .accessibilityLabel(
                            hasCurrentUserReaction(emoji)
                                ? "Remove \(emoji) reaction"
                                : "React with \(emoji)"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            if let reportMessage {
                Divider()

                Button(role: .destructive) {
                    showsMessageActions = false
                    reportMessage()
                } label: {
                    Label("Report Message", systemImage: "exclamationmark.bubble")
                        .font(AppFont.footnote(weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(12)
        .frame(width: 230)
    }

    private func hasCurrentUserReaction(_ emoji: String) -> Bool {
        reactions.contains { $0.emoji == emoji && $0.reactedByCurrentUser }
    }

    @ViewBuilder
    private var messageHeader: some View {
        if showsSenderIdentity {
            HStack(spacing: 6) {
                if showsSenderIdentity, isSentByCurrentUser {
                    Text(sender.name)
                        .font(AppFont.caption(weight: .bold))
                        .foregroundStyle(MessageDesign.muted(for: colorScheme))
                        .lineLimit(1)

                    AuthenticatedMessageAvatar(sender: sender, apiService: apiService)
                        .frame(width: 24, height: 24)
                } else if showsSenderIdentity {
                    AuthenticatedMessageAvatar(sender: sender, apiService: apiService)
                        .frame(width: 24, height: 24)

                    Text(sender.name)
                        .font(AppFont.caption(weight: .bold))
                        .foregroundStyle(MessageDesign.muted(for: colorScheme))
                        .lineLimit(1)
                }

            }
        }
    }

    private var reactionBar: some View {
        HStack(spacing: 6) {
            ForEach(reactions) { reaction in
                HStack(spacing: 4) {
                    Text(reaction.emoji)
                    Text("\(reaction.count)")
                        .font(AppFont.caption(weight: .semibold))
                }
                .foregroundStyle(MessageDesign.primary(for: colorScheme))
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(
                    reaction.reactedByCurrentUser
                        ? MessageDesign.selectionTint(for: colorScheme)
                        : MessageDesign.card(for: colorScheme),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(MessageDesign.border(for: colorScheme), lineWidth: 1)
                }
                .accessibilityLabel(
                    "\(reaction.emoji) reaction, \(reaction.count), "
                    + (reaction.reactedByCurrentUser ? "selected" : "not selected")
                )
            }
        }
    }
}

private enum MessageReactionOptions {
    static let emojis = ["👍", "❤️", "😂", "🎉", "😮"]
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
        .task(id: "\(sender.id ?? sender.imageURL?.absoluteString ?? sender.name)-\(Int(24 * displayScale))") {
            await loadImage()
        }
        .accessibilityLabel("\(sender.name) profile picture")
    }

    @MainActor
    private func loadImage() async {
        let sourceID = sender.id ?? sender.imageURL?.absoluteString ?? sender.name
        let avatar = await avatarRepository.image(
            for: sourceID,
            pointSize: 24,
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
        AppSystemColor.primaryLabel.opacity(colorScheme == .dark ? 0.20 : 0.10)
    }

    static func selectionTint(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.primaryLabel.opacity(colorScheme == .dark ? 0.18 : 0.12)
    }

    static func glassTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.32)
    }

    static var sendForeground: Color {
        AppSystemColor.background
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
                        ? AppSystemColor.primaryLabel.opacity(colorScheme == .dark ? 0.18 : 0.12)
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
                    .tint(canSend ? AppSystemColor.primaryLabel : AppSystemColor.secondaryLabel)
                    .interactive(canSend),
                in: .circle
            )
        } else {
            content.background(
                canSend ? AppSystemColor.primaryLabel : AppSystemColor.secondaryLabel,
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

private func messageSendErrorMessage(for error: Error) -> String {
    if case AuthManagerError.notAuthenticated = error {
        return "Sign in with SSO before sending a message."
    }

    if case KTPAPIError.missingAccessToken = error {
        return "Sign in with SSO before sending a message."
    }

    if case KTPAPIError.badStatusCode(let statusCode, _) = error {
        if statusCode == 401 || statusCode == 403 {
            return "Your message access has expired. Sign out and sign in again."
        }

        return "The server could not send this message. Your conversation is still available—please try again."
    }

    return "The message could not be sent. Check your connection and try again."
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
