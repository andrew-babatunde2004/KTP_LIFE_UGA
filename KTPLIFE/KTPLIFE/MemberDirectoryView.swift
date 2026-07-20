//
//  MemberDirectoryView.swift
//  KTPLIFE
//

import SwiftUI

struct MemberDirectoryView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var avatarRepository: AvatarRepository
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var directorySearchText = ""
    @State private var directoryMembers: [DirectoryMember] = []
    @State private var isLoadingDirectory = false
    @State private var directoryLoadError: String?
    @State private var selectedMember: DirectoryMember?

    let messageMember: (DirectoryMember) -> Void

    init(messageMember: @escaping (DirectoryMember) -> Void = { _ in }) {
        self.messageMember = messageMember
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                DirectorySearchBar(searchText: $directorySearchText)
                    .padding(.bottom, 2)

                if isLoadingDirectory {
                    DirectoryStatusCard(message: "Loading directory...")
                } else if let directoryLoadError {
                    DirectoryStatusCard(message: directoryLoadError)
                } else if filteredMembers.isEmpty {
                    DirectoryStatusCard(
                        message: directorySearchText.isEmpty ?
                        "No members in the directory yet."
                        : "No members found matching '\(directorySearchText)'."
                    )
                } else {
                    LazyVStack(spacing: 7) {
                        ForEach(filteredMembers) { member in
                            DirectoryMemberCard(
                                member: member,
                                apiService: apiService,
                                messageMember: messageMember,
                                selectMember: { selectedMember = member }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.top, 2)
        }
        .task {
            await loadDirectoryMembers()
        }
        .sheet(item: $selectedMember) { member in
            MemberDetailSheet(
                member: member,
                apiService: apiService,
                messageMember: messageMember
            )
        }
    }
    
    private var filteredMembers: [DirectoryMember] {
        directoryMembers.filter { member in
            guard !directorySearchText.isEmpty else { return true }

            let query = directorySearchText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            return member.name.lowercased().contains(query) ||
                member.role.lowercased().contains(query) ||
                member.group.title.lowercased().contains(query) ||
                (member.year?.lowercased().contains(query) ?? false)
        }
    }
    @MainActor
    private func loadDirectoryMembers() async {
#if DEBUG
        if isPreview {
            directoryMembers = DirectoryMember.previewSamples
            directoryLoadError = nil
            return
        }
#endif
        
        isLoadingDirectory = true
        directoryLoadError = nil
        
        do {
            directoryMembers = try await apiService.fetchDirectoryMembers()
            prefetchInitialAvatars(from: directoryMembers)
        } catch {
            directoryMembers = []
            directoryLoadError = directoryErrorMessage(for: error)
        }
        
        isLoadingDirectory = false
    }

    private func prefetchInitialAvatars(from members: [DirectoryMember]) {
        let priorityMembers = Array(members.prefix(16))
        let service = apiService

        Task { @MainActor in
            for batchStart in stride(from: 0, to: priorityMembers.count, by: 4) {
                let batchEnd = min(batchStart + 4, priorityMembers.count)
                let batch = priorityMembers[batchStart..<batchEnd]

                await withTaskGroup(of: Void.self) { group in
                    for member in batch {
                        group.addTask { @MainActor in
                            _ = await avatarRepository.image(
                                for: member.id,
                                pointSize: 40,
                                displayScale: displayScale,
                                loadData: { try await service.fetchProfilePictureData(for: member.id) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func directoryErrorMessage(for error: Error) -> String {
        if case AuthManagerError.notAuthenticated = error {
            return "Sign in with SSO to load the directory."
        }

        if case KTPAPIError.missingAccessToken = error {
            return "Sign in with SSO to load the directory."
        }

        if case KTPAPIError.badStatusCode(let statusCode, let body) = error {
            if statusCode == 401 || statusCode == 403 {
                return "Directory access was rejected by the API (\(statusCode)). Sign out and sign in again. \(body)"
            }

            return "Directory API failed with status \(statusCode). \(body)"
        }

        if case KTPAPIError.decodeFailed(let message) = error {
            return "Directory data did not match the app model. \(message)"
        }

        return "Could not load directory from the KTP API. \(error.localizedDescription)"
    }
}
    
    private struct DirectorySearchBar: View {
        @Environment(\.colorScheme) private var colorScheme
        @Binding var searchText: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(DirectoryDesign.searchIcon(for: colorScheme))
                
                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("Search").foregroundStyle(DirectoryDesign.placeholder(for: colorScheme))
                )
                .font(AppFont.subheadline())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(DirectoryDesign.primary(for: colorScheme))
            }
            .padding(.horizontal, 15)
            .frame(height: 40)
            .background(DirectoryDesign.searchBackground(for: colorScheme), in: Capsule())
        }
    }
    
    private struct DirectoryStatusCard: View {
        @Environment(\.colorScheme) private var colorScheme
        let message: String
        
        var body: some View {
            Text(message)
                .font(AppFont.subheadline())
                .foregroundStyle(DirectoryDesign.secondary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(DirectoryDesign.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
    
    private struct DirectoryMemberCard: View {
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.openURL) private var openURL
        let member: DirectoryMember
        let apiService: KTPAPIService
        let messageMember: (DirectoryMember) -> Void
        let selectMember: () -> Void

        private var initials: String {
            let parts = member.name
                .split(separator: " ")
                .prefix(2)
                .compactMap(\.first)

            let value = String(parts).uppercased()
            return value.isEmpty ? "KT" : value
        }

        private var detailLine: String {
            guard let year = member.year?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !year.isEmpty else {
                return member.role
            }

            return "\(member.role) '\(year.suffix(2))"
        }

        private var groupLine: String {
            "\(member.group.shortTitle.lowercased()) | member"
        }
        
        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                DirectoryProfilePictureView(member: member, apiService: apiService, initials: initials)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(AppFont.headline())
                        .foregroundStyle(DirectoryDesign.name(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(detailLine)
                        .font(AppFont.footnote())
                        .foregroundStyle(DirectoryDesign.primary(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(groupLine)
                        .font(AppFont.footnote())
                        .foregroundStyle(DirectoryDesign.primary(for: colorScheme))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(spacing: 14) {
                    DirectoryMemberActionButton(
                        systemImage: "message.fill",
                        label: "Message \(member.name)",
                        action: { messageMember(member) }
                    )

                    DirectoryMemberActionButton(
                        systemImage: "envelope.fill",
                        label: "Email \(member.name)",
                        isEnabled: mailURL != nil,
                        action: {
                            if let mailURL {
                                openURL(mailURL)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(DirectoryDesign.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .clipped()
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onTapGesture(perform: selectMember)
        }

        private var mailURL: URL? {
            guard let email = member.email?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !email.isEmpty else {
                return nil
            }

            return URL(string: "mailto:\(email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email)")
        }
    }

    private struct DirectoryMemberActionButton: View {
        @Environment(\.colorScheme) private var colorScheme
        let systemImage: String
        let label: String
        var isEnabled = true
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DirectoryDesign.actionIcon(for: colorScheme))
                    .frame(width: 34, height: 34)
                    .background(DirectoryDesign.actionBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.42)
            .accessibilityLabel(label)
        }
    }

    private struct DirectoryProfilePictureView: View {
        @EnvironmentObject private var avatarRepository: AvatarRepository
        @Environment(\.displayScale) private var displayScale
        let member: DirectoryMember
        let apiService: KTPAPIService
        let initials: String
        var size: CGFloat = 40

        @State private var image: UIImage?

        var body: some View {
            ZStack {
                Circle()
                    .fill(DirectoryDesign.avatarBackground)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(initials)
                        .font(AppFont.footnote(weight: .bold))
                        .foregroundStyle(DirectoryDesign.avatarText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .clipShape(Circle())
            .accessibilityLabel("\(member.name) profile picture")
            .task(id: "\(member.id)-\(Int(size * displayScale))") {
                await loadProfilePicture()
            }
        }

        @MainActor
        private func loadProfilePicture() async {
            let avatar = await avatarRepository.image(
                for: member.id,
                pointSize: size,
                displayScale: displayScale,
                loadData: { try await apiService.fetchProfilePictureData(for: member.id) }
            )
            guard !Task.isCancelled else { return }
            image = avatar
        }
    }

    private struct MemberDetailSheet: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(\.openURL) private var openURL
        @Environment(\.colorScheme) private var colorScheme
        @EnvironmentObject private var authManager: AuthManager
        @State private var reportTarget: ReportTarget?
        @State private var isBlocked = false
        @State private var isUpdatingBlock = false
        @State private var showsBlockConfirmation = false
        @State private var blockErrorMessage: String?

        let member: DirectoryMember
        let apiService: KTPAPIService
        let messageMember: (DirectoryMember) -> Void

        private var mailURL: URL? {
            guard let email = member.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
                return nil
            }

            return URL(string: "mailto:\(email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email)")
        }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 16) {
                            DirectoryProfilePictureView(member: member, apiService: apiService, initials: initials, size: 76)
                                .frame(width: 76, height: 76)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(member.name)
                                    .font(AppFont.title())
                                    .foregroundStyle(DirectoryDesign.name(for: colorScheme))

                                Text(member.role)
                                    .font(AppFont.subheadline())
                                    .foregroundStyle(DirectoryDesign.secondary(for: colorScheme))
                            }
                        }

                        detailCard

                        HStack(spacing: 12) {
                            Button("Message") {
                                messageMember(member)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBlocked || isUpdatingBlock)

                            Button("Email") {
                                if let mailURL {
                                    openURL(mailURL)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(mailURL == nil)
                        }

                        if member.id != authManager.currentUserID {
                            VStack(alignment: .leading, spacing: 12) {
                                Button(isBlocked ? "Unblock Member" : "Block Member", role: isBlocked ? nil : .destructive) {
                                    if isBlocked {
                                        Task { await setBlocked(false) }
                                    } else {
                                        showsBlockConfirmation = true
                                    }
                                }
                                .disabled(isUpdatingBlock)
                                .font(AppFont.footnote(weight: .semibold))

                                Button("Report Member", role: .destructive) {
                                    reportTarget = .user(member)
                                }
                                .font(AppFont.footnote(weight: .semibold))

                                if let blockErrorMessage {
                                    Text(blockErrorMessage)
                                        .font(AppFont.footnote())
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
                .navigationTitle("Member Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .sheet(item: $reportTarget) { target in
                ReportContentSheet(target: target)
            }
            .task {
                await loadBlockState()
            }
            .confirmationDialog(
                "Block \(member.name)?",
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
        }

        @MainActor
        private func loadBlockState() async {
            do {
                isBlocked = try await apiService.fetchBlockedUserIDs().contains(member.id)
            } catch is CancellationError {
                return
            } catch {
                blockErrorMessage = "Could not load block status."
            }
        }

        @MainActor
        private func setBlocked(_ shouldBlock: Bool) async {
            guard !isUpdatingBlock else { return }
            isUpdatingBlock = true
            blockErrorMessage = nil

            do {
                if shouldBlock {
                    try await apiService.blockUser(id: member.id)
                } else {
                    try await apiService.unblockUser(id: member.id)
                }
                isBlocked = shouldBlock
            } catch {
                blockErrorMessage = shouldBlock
                    ? "Could not block this member. Please try again."
                    : "Could not unblock this member. Please try again."
            }

            isUpdatingBlock = false
        }

        private var initials: String {
            let value = String(member.name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
            return value.isEmpty ? "KT" : value
        }

        private var detailCard: some View {
            VStack(alignment: .leading, spacing: 12) {
                detailRow("Group", member.group.title)

                if let year = member.year?.trimmingCharacters(in: .whitespacesAndNewlines), !year.isEmpty {
                    detailRow("Graduation Year", year)
                }

                if let email = member.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
                    detailRow("Email", email)
                }
            }
            .padding(16)
            .background(DirectoryDesign.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }

        private func detailRow(_ title: String, _ value: String) -> some View {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFont.caption(weight: .bold))
                    .foregroundStyle(DirectoryDesign.secondary(for: colorScheme))

                Text(value)
                    .font(AppFont.subheadline())
                    .foregroundStyle(DirectoryDesign.primary(for: colorScheme))
            }
        }
    }

private enum DirectoryDesign {
    static let avatarBackground = AppSystemColor.insetBackground
    static let avatarText = AppSystemColor.primaryLabel

    static func primary(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.primaryLabel
    }

    static func secondary(for colorScheme: ColorScheme) -> Color {
        primary(for: colorScheme).opacity(0.66)
    }

    static func name(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.primaryLabel
    }

    static func placeholder(for colorScheme: ColorScheme) -> Color {
        primary(for: colorScheme).opacity(0.62)
    }

    static func searchIcon(for colorScheme: ColorScheme) -> Color {
        primary(for: colorScheme).opacity(0.52)
    }

    static func searchBackground(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.insetBackground
    }

    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.elevatedBackground
    }

    static func actionBackground(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.insetBackground
    }

    static func actionIcon(for colorScheme: ColorScheme) -> Color {
        AppSurfaceColor.primaryControl
    }
}

private extension MemberGroup {
    var shortTitle: String {
        switch self {
        case .active:
            return "active"
        case .pledge:
            return "pledge"
        case .eboard:
            return "eboard"
        case .chair:
            return "chair"
        case .alumni:
            return "alumni"
        }
    }
}

#if DEBUG
#Preview("Member Directory") {
    MemberDirectoryView()
        .padding(20)
        .background(AppTab.directory.theme.previewBackground())
        .environmentObject(AuthManager.previewSignedOut)
        .environmentObject(AvatarRepository())
}
#endif
