//
//  MessageThreadsView.swift
//  KTPLIFE
//

import CoreTransferable
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import WebKit

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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var authManager: AuthManager
    @State private var messages: [KTPMessage] = []
    @State private var draftMessage = ""
    @State private var isLoading = false
    @State private var isRefreshingConversation = false
    @State private var isSending = false
    @State private var loadError: String?
    @State private var conversationCursor: String?
    @State private var conversationETag: String?
    @State private var hasLoadedInitialConversationPage = false
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
    @State private var messagePendingDeletion: KTPMessage?
    @State private var deletingMessageIDs: Set<String> = []
    @State private var deleteErrorMessage: String?
    @State private var selectedMediaItem: PhotosPickerItem?
    @State private var pendingAttachment: MessageAttachmentUpload?
    @State private var pendingAttachmentPreview: UIImage?
    @State private var isPreparingAttachment = false
    @State private var attachmentDataByMessageID: [String: Data] = [:]
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
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await loadConversation(showsLoadingState: false) }
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
        .onChange(of: selectedMediaItem) { _, item in
            guard let item else { return }
            Task { await prepareAttachment(from: item) }
        }
        .overlay {
            if let message = messagePendingDeletion {
                MessageDeleteConfirmationOverlay(
                    cancel: {
                        withAnimation(.easeOut(duration: 0.16)) {
                            messagePendingDeletion = nil
                        }
                    },
                    confirm: {
                        messagePendingDeletion = nil
                        Task { await deleteMessage(message) }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeOut(duration: 0.16), value: messagePendingDeletion?.id)
        .alert("Couldn’t Delete Message", isPresented: Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "Please try again.")
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
        VStack(alignment: .leading, spacing: 8) {
            if let pendingAttachment {
                MessageAttachmentDraftPreview(
                    attachment: pendingAttachment,
                    previewImage: pendingAttachmentPreview,
                    remove: clearPendingAttachment
                )
            }

            HStack(spacing: 10) {
                if directConversation != nil {
                    mediaPicker
                }

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
                    Task { await sendMessage() }
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
        }
        .padding(4)
    }

    private var mediaPicker: some View {
        PhotosPicker(
            selection: $selectedMediaItem,
            matching: .images,
            preferredItemEncoding: .current
        ) {
            Image(systemName: isPreparingAttachment ? "hourglass" : "photo.on.rectangle.angled")
                .font(AppFont.subheadline(weight: .semibold))
                .foregroundStyle(MessageDesign.primary(for: colorScheme))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .disabled(isPreparingAttachment || isSending)
        .accessibilityLabel("Choose an image or GIF")
    }

    private var composerCanSend: Bool {
        (!draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingAttachment != nil)
            && !isSending
            && !isPreparingAttachment
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
                    attachmentSourceID: "\(thread.id)-\(message.id)",
                    attachmentData: attachmentDataByMessageID[message.id],
                    loadAttachmentData: { try await attachmentData(for: message) },
                    allowsReactions: true,
                    reactions: reactionSummaries(for: message),
                    updatingEmojis: updatingEmojis(for: message),
                    toggleReaction: { emoji in
                        Task { await toggleReaction(emoji, on: message) }
                    },
                    deleteMessage: isSentByCurrentUser(message) && !message.id.hasPrefix("local-") ? {
                        messagePendingDeletion = message
                    } : nil,
                    isDeleting: deletingMessageIDs.contains(message.id),
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
                // Foreground APNs notifications refresh this view immediately.
                // Retain a low-frequency fallback only for installations where
                // notifications are unavailable or delayed.
                try await Task.sleep(nanoseconds: 60_000_000_000)
            } catch {
                return
            }

            guard scenePhase == .active, !isBlocked else { continue }
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
            let isIncrementalRequest = hasLoadedInitialConversationPage && conversationCursor != nil
            let syncResponse: ConversationSyncResponse
            switch thread {
            case .direct(let conversation):
                syncResponse = try await apiService.syncConversation(
                    with: conversation.userId,
                    after: isIncrementalRequest ? conversationCursor : nil,
                    eTag: conversationETag
                )
            case .group(let chat):
                syncResponse = try await apiService.syncGroupChatMessages(
                    chatId: chat.id,
                    after: isIncrementalRequest ? conversationCursor : nil,
                    eTag: conversationETag
                )
            }

            var hasNewMessages = false
            switch syncResponse {
            case .notModified:
                break
            case .updated(let page, let eTag):
                let merge = merge(page, incrementally: isIncrementalRequest)
                hasNewMessages = !merge.newMessageIDs.isEmpty

                if merge.messages != messages {
                    messages = merge.messages
                    updateReactionState(
                        for: merge.updatedMessages,
                        removing: merge.deletedMessageIDs,
                        replacesAll: !isIncrementalRequest
                    )

                    if !isIncrementalRequest {
                        renderWindow.reset(totalCount: messages.count)
                    } else {
                        renderWindow.clamp(to: messages.count)
                    }
                }

                hasLoadedInitialConversationPage = true
                if let nextCursor = page.nextCursor, !nextCursor.isEmpty {
                    conversationCursor = nextCursor
                }
                if let eTag, !eTag.isEmpty {
                    conversationETag = eTag
                }
            }

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
                NotificationCenter.default.post(name: .messageUnreadCountShouldRefresh, object: nil)
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

    private func merge(
        _ page: ConversationMessagePage,
        incrementally: Bool
    ) -> ConversationMessageMerge {
        let incomingMessages = page.messages.filter { !$0.isDeleted }
        let deletedMessageIDs = page.deletedMessageIDs.union(
            page.messages.lazy.filter(\.isDeleted).map(\.id)
        )

        // Cursor responses are normally ordered, append-only deltas. Keep that
        // inexpensive path free of a dictionary rebuild and full sort.
        if incrementally,
           deletedMessageIDs.isEmpty,
           isAppendOnlyDelta(incomingMessages) {
            return ConversationMessageMerge(
                messages: messages + incomingMessages,
                updatedMessages: incomingMessages,
                newMessageIDs: Set(incomingMessages.map(\.id)),
                deletedMessageIDs: []
            )
        }

        var mergedMessages = incrementally ? messages : []
        var indexesByID = Dictionary(uniqueKeysWithValues: mergedMessages.enumerated().map { ($1.id, $0) })
        var didChange = !incrementally
        var newMessageIDs = Set<String>()

        if !deletedMessageIDs.isEmpty {
            let retainedMessages = mergedMessages.filter { !deletedMessageIDs.contains($0.id) }
            didChange = didChange || retainedMessages.count != mergedMessages.count
            mergedMessages = retainedMessages
            indexesByID = Dictionary(uniqueKeysWithValues: mergedMessages.enumerated().map { ($1.id, $0) })
        }

        for message in incomingMessages {
            if let index = indexesByID[message.id] {
                if mergedMessages[index] != message {
                    mergedMessages[index] = message
                    didChange = true
                }
            } else {
                indexesByID[message.id] = mergedMessages.count
                mergedMessages.append(message)
                newMessageIDs.insert(message.id)
                didChange = true
            }
        }

        guard didChange else {
            return ConversationMessageMerge(
                messages: messages,
                updatedMessages: [],
                newMessageIDs: [],
                deletedMessageIDs: []
            )
        }

        if !isChronologicallyOrdered(mergedMessages) {
            mergedMessages.sort {
                ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast)
            }
        }

        return ConversationMessageMerge(
            messages: mergedMessages,
            updatedMessages: incomingMessages,
            newMessageIDs: newMessageIDs,
            deletedMessageIDs: deletedMessageIDs
        )
    }

    private func isAppendOnlyDelta(_ incomingMessages: [KTPMessage]) -> Bool {
        guard !incomingMessages.isEmpty else { return true }
        guard isChronologicallyOrdered(incomingMessages) else { return false }
        guard let latestMessage = messages.last else { return true }

        return (incomingMessages.first?.createdAt ?? .distantPast)
            >= (latestMessage.createdAt ?? .distantPast)
    }

    private func isChronologicallyOrdered(_ messages: [KTPMessage]) -> Bool {
        zip(messages, messages.dropFirst()).allSatisfy {
            ($0.createdAt ?? .distantPast) <= ($1.createdAt ?? .distantPast)
        }
    }

    private func updateReactionState(
        for updatedMessages: [KTPMessage],
        removing deletedMessageIDs: Set<String>,
        replacesAll: Bool
    ) {
        if replacesAll {
            seedReactionState(from: messages)
            return
        }

        for messageID in deletedMessageIDs {
            reactionsByMessageID[messageID] = nil
        }

        for message in updatedMessages {
            reactionsByMessageID[message.id] = Dictionary(
                uniqueKeysWithValues: message.reactions.map { ($0.emoji, $0) }
            )
        }
    }

    @MainActor
    private func sendMessage() async {
        let draftBeforeSending = draftMessage
        let content = draftBeforeSending.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachment = pendingAttachment
        guard (!content.isEmpty || attachment != nil), !isSending else { return }

        isSending = true
        sendErrorMessage = nil
        // Clear at send time, not after the request returns. This gives the
        // composer deterministic behavior even when a sync refresh races the
        // response, while preserving text if the send actually fails.
        draftMessage = ""

        do {
            let sentMessage: KTPMessage
            switch thread {
            case .direct(let conversation):
                sentMessage = try await apiService.sendMessage(
                    to: conversation.userId,
                    body: content.isEmpty ? nil : content,
                    attachment: attachment
                )
            case .group(let chat):
                sentMessage = try await apiService.sendGroupChatMessage(chatId: chat.id, body: content)
            }
            if let attachment {
                attachmentDataByMessageID[sentMessage.id] = attachment.data
            }
            messages.append(sentMessage)
            messages.sort { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            sentMessageIDs.insert(sentMessage.id)
            renderWindow.reset(totalCount: messages.count)
            scrollRequest = .latest(UUID())
            clearPendingAttachment()
            loadError = nil
        } catch is CancellationError {
            if draftMessage.isEmpty {
                draftMessage = draftBeforeSending
            }
            isSending = false
            return
        } catch {
            if draftMessage.isEmpty {
                draftMessage = draftBeforeSending
            }
            sendErrorMessage = messageSendErrorMessage(for: error)
        }

        isSending = false
    }

    @MainActor
    private func prepareAttachment(from item: PhotosPickerItem) async {
        isPreparingAttachment = true
        defer {
            isPreparingAttachment = false
            selectedMediaItem = nil
        }

        do {
            guard let selectedImage = try await item.loadTransferable(type: MessagePickedImage.self) else {
                throw MessageAttachmentError.unreadableImage
            }
            defer { try? FileManager.default.removeItem(at: selectedImage.url) }

            let data = try await readAttachmentData(from: selectedImage.url)
            guard data.count <= MessageAttachmentLimits.maximumBytes else {
                throw MessageAttachmentError.fileTooLarge
            }

            let contentType = UTType(filenameExtension: selectedImage.url.pathExtension) ?? .image
            guard contentType.conforms(to: .image) else {
                throw MessageAttachmentError.unsupportedType
            }

            let fileExtension = contentType.preferredFilenameExtension ?? "jpg"
            pendingAttachment = MessageAttachmentUpload(
                data: data,
                fileName: "ktp-message-\(UUID().uuidString).\(fileExtension)",
                mimeType: contentType.preferredMIMEType ?? "image/jpeg"
            )
            pendingAttachmentPreview = await decodeAttachmentPreview(from: data)
            sendErrorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            sendErrorMessage = messageAttachmentErrorMessage(for: error)
        }
    }

    private func clearPendingAttachment() {
        pendingAttachment = nil
        pendingAttachmentPreview = nil
    }

    private func readAttachmentData(from url: URL) async throws -> Data {
        try await Task.detached(priority: .utility) {
            try Data(contentsOf: url, options: [.mappedIfSafe])
        }.value
    }

    private func decodeAttachmentPreview(from data: Data) async -> UIImage? {
        await Task.detached(priority: .utility) {
            UIImage(data: data)
        }.value
    }

    private func attachmentData(for message: KTPMessage) async throws -> Data {
        switch thread {
        case .direct:
            return try await apiService.fetchMessageAttachmentData(messageID: message.id)
        case .group(let chat):
            return try await apiService.fetchGroupChatMessageAttachmentData(chatID: chat.id, messageID: message.id)
        }
    }

    private func messageAttachmentErrorMessage(for error: Error) -> String {
        if let attachmentError = error as? MessageAttachmentError {
            return attachmentError.errorDescription ?? "Couldn’t prepare that attachment."
        }
        return "Couldn’t prepare that image or GIF. Please try again."
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

    @MainActor
    private func deleteMessage(_ message: KTPMessage) async {
        guard deletingMessageIDs.insert(message.id).inserted else { return }
        messagePendingDeletion = nil
        deleteErrorMessage = nil
        defer { deletingMessageIDs.remove(message.id) }

        do {
            switch thread {
            case .direct:
                try await apiService.deleteMessage(id: message.id)
            case .group(let chat):
                try await apiService.deleteGroupChatMessage(chatId: chat.id, messageId: message.id)
            }

            messages.removeAll { $0.id == message.id }
            sentMessageIDs.remove(message.id)
            reactionsByMessageID[message.id] = nil
            renderWindow.reset(totalCount: messages.count)
            NotificationCenter.default.post(name: .messageThreadShouldRefresh, object: nil)
        } catch is CancellationError {
            return
        } catch {
            deleteErrorMessage = "The message could not be deleted. Please try again."
        }
    }
}

private struct MessageDeleteConfirmationOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    let cancel: () -> Void
    let confirm: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .opacity(colorScheme == .dark ? 0.16 : 0.09)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: cancel)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Delete Message?")
                        .font(AppFont.title(20))
                        .foregroundStyle(AppSystemColor.primaryLabel)

                    Text("This removes the message for everyone in the conversation.")
                        .font(AppFont.subheadline())
                        .foregroundStyle(AppSystemColor.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button("Cancel", action: cancel)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                    Button("Delete", role: .destructive, action: confirm)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(
                AppSystemColor.elevatedBackground,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppSystemColor.separator.opacity(0.40), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 22, y: 10)
            .padding(28)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
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

    /// Keeps a user-expanded history window intact when an incremental delta
    /// arrives, while still handling a concurrent deletion.
    mutating func clamp(to totalCount: Int) {
        visibleCount = min(visibleCount, totalCount)
    }

    func hasEarlierMessages(totalCount: Int) -> Bool {
        visibleCount < totalCount
    }
}

private struct ConversationMessageMerge {
    let messages: [KTPMessage]
    let updatedMessages: [KTPMessage]
    let newMessageIDs: Set<String>
    let deletedMessageIDs: Set<String>
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
    let attachmentSourceID: String
    let attachmentData: Data?
    let loadAttachmentData: () async throws -> Data
    let allowsReactions: Bool
    let reactions: [MessageReactionSummary]
    let updatingEmojis: Set<String>
    let toggleReaction: (String) -> Void
    let deleteMessage: (() -> Void)?
    let isDeleting: Bool
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
        .accessibilityHint(
            isSentByCurrentUser
                ? "Touch and hold for reactions and message options"
                : "Touch and hold for reactions and reporting options"
        )
    }

    private var messageSurface: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let attachment = message.attachment, attachment.isImage {
                MessageAttachmentPreview(
                    attachment: attachment,
                    sourceID: attachmentSourceID,
                    cachedData: attachmentData,
                    loadData: loadAttachmentData
                )
            }

            if !message.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(message.body)
                    .font(AppFont.subheadline())
                    .foregroundStyle(MessageDesign.primary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

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

            if let deleteMessage {
                Divider()

                Button(role: .destructive) {
                    showsMessageActions = false
                    deleteMessage()
                } label: {
                    Label(isDeleting ? "Deleting…" : "Delete Message", systemImage: "trash")
                        .font(AppFont.footnote(weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .disabled(isDeleting)
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

private struct MessageAttachmentPreview: View {
    @Environment(\.displayScale) private var displayScale
    @EnvironmentObject private var thumbnailRepository: MessageAttachmentThumbnailRepository
    let attachment: MessageAttachment
    let sourceID: String
    let cachedData: Data?
    let loadData: () async throws -> Data

    @State private var image: UIImage?
    @State private var gifData: Data?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if attachment.isGIF, let gifData {
                AnimatedGIFView(data: gifData)
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if loadFailed {
                unavailableMedia
            } else {
                ProgressView()
                    .frame(width: 220, height: 152)
            }
        }
        .frame(width: 220, height: 152)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: attachmentLoadID) {
            do {
                if attachment.isGIF {
                    if let cachedData {
                        gifData = cachedData
                    } else {
                        gifData = try await loadData()
                    }
                    // GIFs remain animated instead of being flattened into a
                    // thumbnail. They are not decoded by UIImage in the scroll path.
                    return
                }

                image = await thumbnailRepository.image(
                    for: sourceID,
                    pointSize: 220,
                    displayScale: displayScale,
                    loadData: {
                        if let cachedData { return cachedData }
                        return try await loadData()
                    }
                )
                loadFailed = image == nil
            } catch is CancellationError {
                return
            } catch {
                loadFailed = true
            }
        }
        .accessibilityLabel(attachment.isGIF ? "Animated GIF attachment" : "Image attachment")
    }

    private var attachmentLoadID: String {
        "\(sourceID)-\(attachment.filename ?? "attachment")-\(cachedData?.count ?? 0)-\(Int(displayScale * 220))"
    }

    private var unavailableMedia: some View {
        Label("Image unavailable", systemImage: "photo.badge.exclamationmark")
            .font(AppFont.footnote(weight: .semibold))
            .foregroundStyle(MessageDesign.muted(for: .light))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AnimatedGIFView: UIViewRepresentable {
    let data: Data

    final class Coordinator {
        var loadedContentHash: Int?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // SwiftUI can call updateUIView while an unrelated row state changes.
        // Reloading a WebKit GIF restarts its animation and unnecessarily
        // decodes the asset, so only hand WebKit new content.
        let contentHash = data.hashValue
        guard context.coordinator.loadedContentHash != contentHash else { return }
        context.coordinator.loadedContentHash = contentHash
        webView.load(
            data,
            mimeType: "image/gif",
            characterEncodingName: "utf-8",
            baseURL: URL(string: "about:blank")!
        )
    }
}

private struct MessageAttachmentDraftPreview: View {
    let attachment: MessageAttachmentUpload
    let previewImage: UIImage?
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if attachment.isGIF {
                AnimatedGIFView(data: attachment.data)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            Spacer(minLength: 0)

            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 19, weight: .semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove attachment")
        }
        .padding(8)
        .background(MessageDesign.input(for: .light), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension MessageAttachment {
    var isImage: Bool {
        mimeType?.lowercased().hasPrefix("image/") == true || kind.lowercased() == "image"
    }

    var isGIF: Bool {
        mimeType?.lowercased() == "image/gif" || filename?.lowercased().hasSuffix(".gif") == true
    }
}

private extension MessageAttachmentUpload {
    var isGIF: Bool {
        mimeType.lowercased() == "image/gif" || fileName.lowercased().hasSuffix(".gif")
    }
}

private enum MessageAttachmentLimits {
    static let maximumBytes = 25 * 1024 * 1024
}

private enum MessageAttachmentError: LocalizedError {
    case unreadableImage
    case unsupportedType
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "Couldn’t read that image or GIF."
        case .unsupportedType:
            return "Choose an image or GIF file."
        case .fileTooLarge:
            return "Images and GIFs must be 25 MB or smaller."
        }
    }
}

private struct MessagePickedImage: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let fileExtension = received.file.pathExtension.isEmpty ? "jpg" : received.file.pathExtension
            let copiedURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)
            try FileManager.default.copyItem(at: received.file, to: copiedURL)
            return MessagePickedImage(url: copiedURL)
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
            .navigationDestination(for: MessageThread.self) { thread in
                MessageConversationView(thread: thread)
            }
    }
    .environmentObject(AuthManager.previewSignedOut)
    .environmentObject(AvatarRepository())
    .environmentObject(MessageAttachmentThumbnailRepository())
}
#endif
