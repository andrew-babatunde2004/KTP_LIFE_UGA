//
//  MemberDirectoryView.swift
//  KTPLIFE
//

import SwiftUI

struct MemberDirectoryView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var directorySearchText = ""
    @State private var selectedDirectoryGroup: MemberGroup = .active
    @State private var directoryMembers: [DirectoryMember] = []
    @State private var isLoadingDirectory = false
    @State private var directoryLoadError: String?

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
            DirectorySearchBar(searchText: $directorySearchText)
            MemberGroupPicker(selectedGroup: $selectedDirectoryGroup)
            
            if isLoadingDirectory {
                DirectoryStatusCard(message: "Loading directory...")
            } else if let directoryLoadError {
                DirectoryStatusCard(message: directoryLoadError)
            } else if filteredMembers.isEmpty {
                DirectoryStatusCard(
                    message: directorySearchText.isEmpty ?
                    "No members in this group yet."
                    : "No members found matching '\(directorySearchText)'."
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredMembers) { member in
                        DirectoryMemberCard(member: member)
                    }
                }
            }
        }
        .task {
            await loadDirectoryMembers()
        }
    }
    
    private var filteredMembers: [DirectoryMember] {
        // Filters by production member groups: active, pledge, eboard, chair, and alumni.
        directoryMembers.filter { $0.group == selectedDirectoryGroup }
            .filter { member in
                guard !directorySearchText.isEmpty else { return true }
                
                let query = directorySearchText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                
                return member.name.lowercased().contains(query) ||
                    member.role.lowercased().contains(query) ||
                    (member.year?.lowercased().contains(query) ?? false)
            }
    }
    @MainActor
    private func loadDirectoryMembers() async {
        if isPreview {
            directoryMembers = DirectoryMember.previewSamples
            directoryLoadError = nil
            return
        }
        
        isLoadingDirectory = true
        directoryLoadError = nil
        
        do {
            directoryMembers = try await apiService.fetchDirectoryMembers()
        } catch {
            directoryMembers = []
            directoryLoadError = directoryErrorMessage(for: error)
        }
        
        isLoadingDirectory = false
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
        @Environment(\.pageTheme) private var pageTheme
        @Binding var searchText: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .appTextOnCardMuted()
                
                TextField(
                    "",
                    text: $searchText,
                    prompt: AppTextColor.prompt(
                        "Search members",
                        role: .onCardPlaceholder,
                        theme: pageTheme,
                        colorScheme: colorScheme
                    )
                )
                .font(AppFont.subheadline())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .appTextOnCard()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .matteCard(radius: 8)
        }
    }
    
    private struct MemberGroupPicker: View {
        @Binding var selectedGroup: MemberGroup
        
        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(MemberGroup.allCases) { group in
                        MemberGroupFilterButton(
                            title: group.title,
                            isSelected: selectedGroup == group,
                            select: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    selectedGroup = group
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 5)
            }
            .matteCard(radius: 8)
        }
    }
    
    private struct MemberGroupFilterButton: View {
        let title: String
        let isSelected: Bool
        let select: () -> Void
        
        private var labelOpacity: Double {
            isSelected ? 1 : 0.74
        }
        
        var body: some View {
            Button(action: select) {
                Text(title)
                    .font(AppFont.footnote(weight: .bold))
                    .lineLimit(1)
                    .appTextOnCard(opacity: labelOpacity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private struct DirectoryStatusCard: View {
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
    
    private struct DirectoryMemberCard: View {
        let member: DirectoryMember

        private var initials: String {
            let parts = member.name
                .split(separator: " ")
                .prefix(2)
                .compactMap(\.first)

            let value = String(parts).uppercased()
            return value.isEmpty ? "KT" : value
        }

        private var displayYear: String {
            guard let year = member.year?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !year.isEmpty else {
                return "N/A"
            }

            return year
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Text(initials)
                        .font(AppFont.caption(weight: .bold))
                        .appTextOnCard()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(width: 38, height: 38)
                        .background(AppSurfaceColor.primaryControl, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Spacer(minLength: 8)

                    Text(member.group.title.uppercased())
                        .font(AppFont.caption(weight: .bold))
                        .appTextOnCardMuted()
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .frame(maxWidth: 78, alignment: .trailing)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(member.name)
                        .font(AppFont.headline())
                        .appTextOnCard()
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(member.role)
                        .font(AppFont.footnote())
                        .appTextOnCardSecondary()
                        .lineLimit(3)
                        .minimumScaleFactor(0.76)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("YEAR")
                        .font(AppFont.caption(weight: .bold))
                        .appTextOnCardMuted()
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text(displayYear)
                        .font(AppFont.footnote(weight: .bold))
                        .appTextOnCard()
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
            .background(AppSurfaceColor.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(AppSurfaceColor.cardBorder)
                    .frame(height: 1)
                    .opacity(0.85)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppSurfaceColor.cardBorder, lineWidth: 1)
            }
            .clipped()
        }
    }
#Preview("Member Directory") {
    MemberDirectoryView()
        .padding(20)
        .background(AppTab.messages.theme.previewBackground())
        .environmentObject(AuthManager.previewSignedOut)
}
