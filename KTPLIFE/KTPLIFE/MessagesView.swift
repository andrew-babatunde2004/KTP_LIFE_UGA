//
//  MessagesView.swift
//  KTPLIFE
//

import SwiftUI

struct MessagesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var selectedSection: CommunitySection = .messages
    @State private var messagePath: [MessageThread] = []
    @Binding private var isConversationPresented: Bool

    init(isConversationPresented: Binding<Bool> = .constant(false)) {
        _isConversationPresented = isConversationPresented
    }

    var body: some View {
        NavigationStack(path: $messagePath) {
            PageScaffold() {
                VStack(spacing: 16) {
                    CommunitySectionPicker(
                        selection: $selectedSection,
                        reduceTransparency: reduceTransparency
                    )

                    switch selectedSection {
                    case .messages:
                        MessageThreadsView()
                    case .directory:
                        MemberDirectoryView(messageMember: openConversation(with:))
                    }
                }
            }
            // This inset belongs to the inbox screen, not the NavigationStack. Keeping
            // the stack full width lets the conversation destination fill the screen.
            .padding(.horizontal, 20)
            .navigationDestination(for: MessageThread.self) { thread in
                MessageConversationView(thread: thread)
            }
        }
        // Keep the custom app shell informed when a thread is pushed or dismissed.
        .onChange(of: messagePath) { _, newPath in
            isConversationPresented = !newPath.isEmpty
        }
        .onDisappear {
            isConversationPresented = false
        }
        .background(MessageDesign.background(for: colorScheme).ignoresSafeArea())
    }

    private func openConversation(with member: DirectoryMember) {
        let conversation = MessageConversation(
            id: "directory-\(member.id)",
            userId: member.id,
            displayName: member.name,
            preview: "No messages yet.",
            lastMessageDate: nil,
            unreadCount: 0
        )
        messagePath.append(.direct(conversation))
    }
}

/// Keeps the existing Messages/Directory structure while allowing iOS 26 to
/// render the two choices as one coordinated Liquid Glass control.
private struct CommunitySectionPicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: CommunitySection
    let reduceTransparency: Bool

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(CommunitySection.allCases) { section in
                        CommunityGlassSectionButton(
                            section: section,
                            isSelected: selection == section,
                            colorScheme: colorScheme,
                            select: { selection = section }
                        )
                    }
                }
            }
        } else {
            Picker("Community", selection: $selection) {
                ForEach(CommunitySection.allCases) { section in
                    Text(section.title)
                        .font(AppFont.subheadline())
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

@available(iOS 26.0, *)
private struct CommunityGlassSectionButton: View {
    let section: CommunitySection
    let isSelected: Bool
    let colorScheme: ColorScheme
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Text(section.title)
                .font(AppFont.subheadline(weight: .semibold))
                .foregroundStyle(MessageDesign.primary(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular
                .tint(isSelected ? MessageDesign.selectionTint(for: colorScheme) : Color.clear)
                .interactive(),
            in: .capsule
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private enum CommunitySection: String, CaseIterable, Identifiable {
    case messages
    case directory

    var id: Self { self }

    var title: String {
        switch self {
        case .messages: "Messages"
        case .directory: "Directory"
        }
    }
}

#if DEBUG
#Preview("Messages") {
    MessagesView()
        .padding(20)
        .background(AppTab.community.theme.previewBackground())
        .environmentObject(AuthManager.previewSignedOut)
        .environmentObject(AvatarRepository())
}
#endif
