//
//  MessagesView.swift
//  KTPLIFE
//

import SwiftUI

struct MessagesView: View {
    @State private var selectedSection: MessagesSection = .messages
    @State private var selectedDirectoryGroup: DirectoryGroup = .activeMembers

    var body: some View {
        PageScaffold(showsPageHeader: false) {
            MessagesHotbar(selectedSection: $selectedSection)

            if selectedSection == .messages {
                messageList
            } else {
                directoryView
            }
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
            DirectoryGroupPicker(selectedGroup: $selectedDirectoryGroup)

            LazyVStack(spacing: 14) {
                ForEach(filteredMembers) { member in
                    DirectoryMemberCard(member: member)
                }
            }
        }
    }

    private var filteredMembers: [DirectoryMember] {
        Self.directoryMembers.filter { $0.group == selectedDirectoryGroup }
    }
}

private struct MessagesHotbar: View {
    @Binding var selectedSection: MessagesSection

    var body: some View {
        HStack(spacing: 10) {
            ForEach(MessagesSection.allCases) { section in
                SegmentedPillButton(
                    title: section.title,
                    icon: section.icon,
                    isSelected: selectedSection == section,
                    select: { selectedSection = section }
                )
            }
        }
        .padding(8)
        .matteCard(radius: 24)
    }
}

private struct DirectoryGroupPicker: View {
    @Binding var selectedGroup: DirectoryGroup

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DirectoryGroup.allCases) { group in
                SegmentedPillButton(
                    title: group.title,
                    icon: group.icon,
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
    let icon: String
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))

                Text(title)
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
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

private struct MessageThreadCard: View {
    let thread: MessageThread
    let isUnread: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(thread.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text(thread.preview)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(thread.time)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))

                Image(systemName: isUnread ? "message.badge.fill" : "message.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.10), in: Circle())
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
            Image(systemName: member.group.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(member.name)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text(member.role)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Text(member.year)
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.58))
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

    static let directoryMembers = [
        DirectoryMember(name: "Jordan Lee", role: "Software Engineering Track", year: "2027", group: .activeMembers),
        DirectoryMember(name: "Maya Patel", role: "Data Science Track", year: "2026", group: .activeMembers),
        DirectoryMember(name: "Chris Nguyen", role: "New Member", year: "2028", group: .pledges),
        DirectoryMember(name: "Ava Brooks", role: "New Member", year: "2028", group: .pledges),
        DirectoryMember(name: "Sam Rivera", role: "President", year: "2026", group: .eBoard),
        DirectoryMember(name: "Taylor Kim", role: "VP Technology", year: "2027", group: .eBoard),
        DirectoryMember(name: "Morgan Chen", role: "Software Engineer", year: "Alum", group: .alumni),
        DirectoryMember(name: "Riley Johnson", role: "Product Manager", year: "Alum", group: .alumni)
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

    var icon: String {
        switch self {
        case .messages:
            return "message.fill"
        case .directory:
            return "person.2.fill"
        }
    }
}

private enum DirectoryGroup: CaseIterable, Identifiable {
    case activeMembers
    case pledges
    case eBoard
    case alumni

    var id: Self { self }

    var title: String {
        switch self {
        case .activeMembers:
            return "Active"
        case .pledges:
            return "Pledges"
        case .eBoard:
            return "E-Board"
        case .alumni:
            return "Alumni"
        }
    }

    var icon: String {
        switch self {
        case .activeMembers:
            return "person.2.fill"
        case .pledges:
            return "person.badge.plus"
        case .eBoard:
            return "star.fill"
        case .alumni:
            return "graduationcap.fill"
        }
    }
}

private struct MessageThread {
    let title: String
    let preview: String
    let time: String
}

private struct DirectoryMember: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let year: String
    let group: DirectoryGroup
}

#Preview("Messages") {
    MessagesView()
        .padding(20)
        .background(AppTab.messages.theme.backgroundColor)
}
