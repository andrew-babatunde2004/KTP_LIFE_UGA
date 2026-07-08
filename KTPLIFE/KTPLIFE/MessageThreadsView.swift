//
//  MessageThreadsView.swift
//  KTPLIFE
//

import SwiftUI

struct MessageThreadsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var conversations: [MessageConversation] = []
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
            } else if conversations.isEmpty {
                MessagesStatusCard(message: "No conversations yet.")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(conversations) { conversation in
                        NavigationLink(value: conversation) {
                            MessageThreadCard(conversation: conversation)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task {
            await loadConversations()
        }
        .navigationDestination(for: MessageConversation.self) { conversation in
            MessageConversationView(conversation: conversation)
        }
    }

    @MainActor
    private func loadConversations() async {
        if isPreview {
            conversations = MessageConversation.previewSamples
            loadError = nil
            return
        }

        isLoading = true
        loadError = nil

        do {
            conversations = try await apiService.fetchMessageConversations()
        } catch {
            conversations = []
            loadError = messagesErrorMessage(for: error)
        }

        isLoading = false
    }
}

private struct MessageThreadCard: View {
    let conversation: MessageConversation

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ProfileAvatarView(
                imageURL: conversation.profileImageURL,
                name: conversation.displayName,
                size: 51
            )
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 5) {
                Text(conversation.displayName)
                    .font(.custom(AppFont.regularName, size: 15, relativeTo: .subheadline))
                    .foregroundStyle(Color(red: 0.56, green: 0.61, blue: 0.70))
                    .tracking(0.75)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(conversation.preview)
                    .font(.custom(AppFont.regularName, size: 16, relativeTo: .body))
                    .foregroundStyle(Color(red: 0.13, green: 0.17, blue: 0.27))
                    .tracking(0.75)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.top, 18)

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 12) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(red: 0.56, green: 0.61, blue: 0.70))
                    .frame(width: 28, height: 24)
                    .accessibilityHidden(true)

                if conversation.unreadCount > 0 {
                    Circle()
                        .fill(Color(red: 0.13, green: 0.17, blue: 0.27))
                        .frame(width: 8, height: 8)
                        .accessibilityLabel("Unread")
                }
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, minHeight: 95, alignment: .topLeading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.025), radius: 10, x: 0, y: 8)
    }
}

private struct ProfileAvatarView: View {
    let imageURL: URL?
    let name: String
    let size: CGFloat

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
                .fill(Color(red: 0.94, green: 0.95, blue: 0.97))

            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("\(name) profile picture")
    }

    private var fallback: some View {
        Text(initials)
            .font(AppFont.caption(weight: .bold))
            .foregroundStyle(Color(red: 0.13, green: 0.17, blue: 0.27))
    }
}

private struct MessageConversationView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var messages: [KTPMessage] = []
    @State private var draftMessage = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var loadError: String?

    let conversation: MessageConversation

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var apiService: KTPAPIService {
        KTPAPIService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }

    var body: some View {
        VStack(spacing: 14) {
            if isLoading {
                MessagesStatusCard(message: "Loading conversation...")
            } else if let loadError {
                MessagesStatusCard(message: loadError)
            } else if messages.isEmpty {
                MessagesStatusCard(message: "No messages in this conversation yet.")
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            messageComposer
        }
        .navigationTitle(conversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadConversation()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .safeAreaPadding(.bottom, 116)
        .background(AppTab.messages.theme.previewBackground())
    }

    private var messageComposer: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $draftMessage, axis: .vertical)
                .font(AppFont.subheadline())
                .lineLimit(1...4)
                .appTextOnCard()
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppSurfaceColor.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        composerCanSend ? AppSurfaceColor.primaryControl : AppSurfaceColor.disabledControl,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!composerCanSend)
            .accessibilityLabel("Send message")
        }
        .padding(10)
        .matteCard(radius: 8)
    }

    private var composerCanSend: Bool {
        !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    @MainActor
    private func loadConversation() async {
        if isPreview {
            messages = KTPMessage.previewSamples
            loadError = nil
            return
        }

        isLoading = true
        loadError = nil

        do {
            async let fetchedMessages = apiService.fetchConversation(with: conversation.userId)
            async let markRead: Void = apiService.markConversationRead(with: conversation.userId)
            messages = try await fetchedMessages
            _ = try? await markRead
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
            let sentMessage = try await apiService.sendMessage(to: conversation.userId, content: content)
            messages.append(sentMessage)
            draftMessage = ""
        } catch {
            loadError = messagesErrorMessage(for: error)
        }

        isSending = false
    }
}

private struct MessageBubble: View {
    let message: KTPMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.body)
                .font(AppFont.subheadline())
                .appTextOnCard()
                .fixedSize(horizontal: false, vertical: true)

            if let createdAt = message.createdAt {
                Text(createdAt.relativeMessageTime)
                    .font(AppFont.caption(weight: .medium))
                    .appTextOnCardMuted()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .matteCard(radius: 8)
    }
}

private struct MessagesStatusCard: View {
    let message: String

    var body: some View {
        Text(message)
            .font(AppFont.subheadline())
            .appTextOnCardSecondary()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .matteCard(radius: 8)
    }
}

private func messagesErrorMessage(for error: Error) -> String {
    if case AuthManagerError.notAuthenticated = error {
        return "Sign in with SSO to load messages."
    }

    if case KTPAPIError.missingAccessToken = error {
        return "Sign in with SSO to load messages."
    }

    if case KTPAPIError.badStatusCode(let statusCode, let body) = error {
        if statusCode == 401 || statusCode == 403 {
            return "Message access was rejected by the API (\(statusCode)). Sign out and sign in again. \(body)"
        }

        return "Messages API failed with status \(statusCode). \(body)"
    }

    if case KTPAPIError.decodeFailed(let message) = error {
        return "Message data did not match the app model. \(message)"
    }

    return "Could not load messages from the KTP API. \(error.localizedDescription)"
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

#Preview("Message Threads") {
    NavigationStack {
        MessageThreadsView()
            .padding(20)
            .background(AppTab.messages.theme.previewBackground())
    }
    .environmentObject(AuthManager.previewSignedOut)
}
