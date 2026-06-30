//
//  MessagesView.swift
//  KTPLIFE
//

import SwiftUI

struct MessagesView: View {
    @State private var selectedSection: MessagesSection = .messages

    var body: some View {
        PageScaffold(showsPageHeader: false) {
            MessagesHotbar(selectedSection: $selectedSection)

            if selectedSection == .messages {
                MessageThreadsView()
            } else {
                MemberDirectoryView()
            }
        }
    }
}

private struct MessagesHotbar: View {
    @Binding var selectedSection: MessagesSection

    var body: some View {
        HStack(spacing: 20) {
            ForEach(MessagesSection.allCases) { section in
                MessagesHotbarButton(
                    section: section,
                    isSelected: selectedSection == section,
                    select: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            selectedSection = section
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
        .matteCard(radius: 28)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct MessagesHotbarButton: View {
    let section: MessagesSection
    let isSelected: Bool
    let select: () -> Void

    private var iconOpacity: Double {
        isSelected ? 1 : 0.74
    }

    var body: some View {
        Button(action: select) {
            Image(systemName: section.icon)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(section.title)
                .foregroundStyle(.white.opacity(iconOpacity))
        }
        .buttonStyle(.plain)
    }
}

private enum MessagesSection: CaseIterable, Identifiable {
    case messages
    case directory

    var id: Self { self }

    var icon: String {
        switch self {
        case .messages:
            return "bubble.left.and.bubble.right.fill"
        case .directory:
            return "person.2.fill"
        }
    }

    var title: String {
        switch self {
        case .messages:
            return "Messages"
        case .directory:
            return "Directory"
        }
    }
}

#Preview("Messages") {
    MessagesView()
        .padding(20)
        .background(AppTab.messages.theme.previewBackground())
}
