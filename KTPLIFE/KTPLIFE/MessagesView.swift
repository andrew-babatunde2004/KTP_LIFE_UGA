//
//  MessagesView.swift
//  KTPLIFE
//

import SwiftUI

struct MessagesView: View {
    @State private var selectedSection: MessagesSection = .messages
    @State private var selectedDirectoryGroup: MemberGroup = .activeMembers
    @State private var directoryMembers: [DirectoryMember] = []
    @State private var isLoadingDirectory = false
    @State private var directoryLoadError: String?

    // rename this to member service or something distinguishable
    private let apiService = KTPAPIService()

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        PageScaffold(showsPageHeader: false) {
            MessagesHotbar(selectedSection: $selectedSection)

            if selectedSection == .messages {
                messageList
            } else {
                directoryView
            }
        }
        .task(id: selectedSection) {
            guard selectedSection == .directory else { return }
            await loadDirectoryMembers()
        }
    }

    private var messageList: some View {
        LazyVStack(spacing: 14) {
            ForEach(Array(Self.messagePreviews.enumerated()), id: \.offset) { index, thread in
                MessageThreadCard(thread: thread, isUnread: index == 0)
            }
        }
    }

    private var directoryView: some View {
        VStack(spacing: 14) {
            MemberGroupPicker(selectedGroup: $selectedDirectoryGroup)

            if isLoadingDirectory {
                DirectoryStatusCard(message: "Loading directory...")
            } else if let directoryLoadError {
                DirectoryStatusCard(message: directoryLoadError)
            } else if filteredMembers.isEmpty {
                DirectoryStatusCard(message: "No members in this group yet.")
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(filteredMembers) { member in
                        DirectoryMemberCard(member: member)
                    }
                }
            }
        }
    }

    private var filteredMembers: [DirectoryMember] {
        directoryMembers.filter { $0.group == selectedDirectoryGroup }
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

private struct MessagesHotbar: View {
    @Binding var selectedSection: MessagesSection

    var body: some View {
        HStack(spacing: 10) {
            ForEach(MessagesSection.allCases) { section in
                SegmentedPillButton(
                    title: section.title,
                    isSelected: selectedSection == section,
                    select: { selectedSection = section }
                )
            }
        }
        .padding(8)
        .matteCard(radius: 24)
    }
}

private struct MemberGroupPicker: View {
    @Binding var selectedGroup: MemberGroup

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MemberGroup.allCases) { group in
                SegmentedPillButton(
                    title: group.title,
                    isSelected: selectedGroup == group,
                    select: { selectedGroup = group }
                )
            }
        }
        .padding(8)
        .matteCard(radius: 24)
    }
}

private struct SegmentedPillButton: View {
    let title: String
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Text(title)
                .font(AppFont.footnote(weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.68))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
                .background(Color.white.opacity(isSelected ? 0.18 : 0.06), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(isSelected ? 0.16 : 0.06), lineWidth: 1)
                }
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

private struct MessageThreadCard: View {
    let thread: MessageThread
    let isUnread: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(thread.title)
                    .font(AppFont.headline())
                    .foregroundStyle(.white)

                Text(thread.preview)
                    .font(AppFont.subheadline())
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(thread.time)
                    .font(AppFont.footnote(weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))

                if isUnread {
                    Text("Unread")
                        .font(AppFont.caption(weight: .bold))
                        .foregroundStyle(.white.opacity(0.74))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
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

private extension MessagesView {
    static let messagePreviews = [
        MessageThread(title: "General Thread", preview: "Chapter updates are live for this week.", time: "Now"),
        MessageThread(title: "Recruitment", preview: "Reminder: recruitment meeting starts at 7:00 PM.", time: "4:15"),
        MessageThread(title: "Committee Notes", preview: "Your committee notes were shared with the team.", time: "Yesterday")
    ]
}

private enum MessagesSection: CaseIterable, Identifiable {
    case messages
    case directory

    var id: Self { self }

    var title: String {
        switch self {
        case .messages:
            return "Messages"
        case .directory:
            return "Directory"
        }
    }
}

private struct MessageThread {
    let title: String
    let preview: String
    let time: String
}

#Preview("Messages") {
    MessagesView()
        .padding(20)
        .background(AppTab.messages.theme.backgroundColor)
}
