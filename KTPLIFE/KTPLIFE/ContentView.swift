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
    @State private var authScreen: AuthScreen = .signup
    @State private var isAuthenticated = false
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
            authFlowView
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
            HomeView(returnToSignup: returnToSignupForTesting)
        case .messages:
            MessagesView()
        case .opportunities:
            OpportunitiesView()
        case .calendar:
            CalendarView()
        case .photos:
            PhotosView()
        }
    }

    @ViewBuilder
    private var authFlowView: some View {
        switch authScreen {
        case .signup:
            SignupView(showLogin: showLogin)
        case .login:
            AuthView(
                email: $email,
                password: $password,
                signIn: signIn,
                showSignup: showSignup
            )
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

    private func showLogin() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            authScreen = .login
        }
    }

    private func showSignup() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            authScreen = .signup
        }
    }

    private func returnToSignupForTesting() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            isAuthenticated = false
            authScreen = .signup
            selectedTab = .home
            password = ""
        }
    }
}

private enum AuthScreen {
    case signup
    case login
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
