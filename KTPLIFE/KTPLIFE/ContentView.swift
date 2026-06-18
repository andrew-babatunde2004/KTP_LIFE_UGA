//
//  ContentView.swift
//  KTPLIFE
//
//  Created by Seyi Babatunde on 6/16/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var email = ""
    @State private var password = ""
    // Keep true to show the authenticated state by default for faster development, but set to false before shipping.
    @State private var isAuthenticated = true
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack {
            PageBackground(theme: activePageTheme, animationValue: selectedTab)
            rootContent
        }
        .safeAreaInset(edge: .bottom) {
            if isAuthenticated {
                AppTabBar(selectedTab: $selectedTab)
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if isAuthenticated {
            appShellView
                .contentShellPadding(bottom: 116)
        } else {
            AuthView(
                email: $email,
                password: $password,
                signIn: signIn
            )
            .contentShellPadding(bottom: 32)
        }
    }

    private var activePageTheme: PageTheme {
        isAuthenticated ? selectedTab.theme : .auth
    }

    @ViewBuilder
    private var appShellView: some View {
        switch selectedTab {
        case .home:
            HomeView(returnToAuth: returnToAuthForTesting)
        case .messages:
            MessagesView()
        case .opportunities:
            OpportunitiesView()
        case .calendar:
            CalendarView()
        }
    }

    private var canSignIn: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    private func signIn() {
        guard canSignIn else { return }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            isAuthenticated = true
        }
    }

    private func returnToAuthForTesting() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            isAuthenticated = false
            selectedTab = .home
            password = ""
        }
    }
}

private extension View {
    func contentShellPadding(bottom: CGFloat) -> some View {
        padding(.horizontal, 20)
            .padding(.top, 24)
            .safeAreaPadding(.bottom, bottom)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewModelContainer.shared)
}
