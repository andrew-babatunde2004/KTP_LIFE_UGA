//
//  MessagesView.swift
//  KTPLIFE
//

import SwiftUI

struct MessagesView: View {
    var body: some View {
        NavigationStack {
            PageScaffold(title: "Messages") {
                MessageThreadsView()
            }
        }
    }
}

#Preview("Messages") {
    MessagesView()
        .padding(20)
        .background(AppTab.messages.theme.previewBackground())
}
