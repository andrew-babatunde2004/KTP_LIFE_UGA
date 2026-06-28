//
//  MemberDirectoryView.swift
//  KTPLIFE
//

import SwiftUI

struct MemberDirectoryView: View {
    @State private var directorySearchText = ""
    @State private var selectedDirectoryGroup: MemberGroup = .activeMembers
    @State private var directoryMembers: [DirectoryMember] = []
    @State private var isLoadingDirectory = false
    @State private var directoryLoadError: String?
    
    private let apiService = KTPAPIService()
    
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
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
                LazyVStack(spacing: 14) {
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
        // filters by pledges, eBoard, alumni, and active members
        directoryMembers.filter { $0.group == selectedDirectoryGroup }
            .filter { member in
                guard !directorySearchText.isEmpty else { return true }
                
                let query = directorySearchText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                
                return member.name.lowercased().contains(query) ||
                member.role.lowercased().contains(query) ||
                member.year?.lowercased().contains(query) ?? false
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
            directoryLoadError = "Could not load directory. Start the API with npm start in ktp-api."
        }
        
        isLoadingDirectory = false
    }
}
    
    private struct DirectorySearchBar: View {
        @Binding var searchText: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))
                
                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("Search members").foregroundStyle(.white.opacity(0.42))
                )
                .font(AppFont.subheadline())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .matteCard(radius: 24)
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
            .matteCard(radius: 28)
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
                    .foregroundStyle(.white.opacity(labelOpacity))
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
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .matteCard()
        }
    }
    
    private struct DirectoryMemberCard: View {
        let member: DirectoryMember
        
        var body: some View {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(member.name)
                        .font(AppFont.headline())
                        .foregroundStyle(.white)
                    
                    Text(member.role)
                        .font(AppFont.subheadline())
                        .foregroundStyle(.white.opacity(0.72))
                }
                
                Spacer()
                
                if let year = member.year {
                    Text(year)
                        .font(AppFont.footnote(weight: .bold))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .matteCard()
        }
    }
#Preview("Member Directory") {
    MemberDirectoryView()
        .padding(20)
        .background(AppTab.messages.theme.backgroundColor)
}
