//
//  MessageThreadsView.swift
//  KTPLIFE
//

import SwiftUI

struct MessageThreadsView: View {
    var body: some View {
        LazyVStack(spacing: 14) {
            ForEach(Array(Self.messagePreviews.enumerated()), id: \.offset) { index, thread in
                MessageThreadCard(thread: thread, isUnread: index == 0)
            }
        }
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

private struct MessageThread {
    let title: String
    let preview: String
    let time: String
}

private extension MessageThreadsView {
    static let messagePreviews = [
        MessageThread(title: "General Thread", preview: "Chapter updates are live for this week.", time: "Now"),
        MessageThread(title: "Recruitment", preview: "Reminder: recruitment meeting starts at 7:00 PM.", time: "4:15"),
        MessageThread(title: "Committee Notes", preview: "Your committee notes were shared with the team.", time: "Yesterday"),
    ]
}

#Preview("Message Threads") {
    MessageThreadsView()
        .padding(20)
        .background(AppTab.messages.theme.backgroundColor)
}
