//
//  ContentView.swift
//  KTPLIFE
//
//  Created by Seyi Babatunde on 6/16/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedTab: AppTab = .home
    @State private var didBootstrap = false

    var body: some View {
        ZStack {
            PageBackground(theme: activePageTheme, animationValue: selectedTab)
            rootContent
        }
        .environment(\.pageTheme, activePageTheme)
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true
            await authManager.bootstrap()
        }
        .onChange(of: authManager.phase) { _, newPhase in
            if newPhase != .signedIn {
                selectedTab = .home
            }
        }
        .safeAreaInset(edge: .bottom) {
            if authManager.profileIsComplete {
                AppTabBar(selectedTab: $selectedTab)
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch authManager.phase {
        case .loading, .signedOut, .signingIn:
            SSOLoginView(
                isLoading: authManager.isBusy,
                errorMessage: authManager.errorMessage,
                signIn: {
                    Task {
                        await authManager.signInWithSSO()
                    }
                }
            )
            .contentShellPadding(bottom: 32)
        case .profileIncomplete:
            ProfileIncompleteView(
                errorMessage: authManager.errorMessage,
                retrySync: {
                    Task {
                        await authManager.checkProfileStatus()
                    }
                },
                signOut: {
                    Task {
                        await authManager.signOut()
                    }
                }
            )
            .contentShellPadding(bottom: 32)
        case .signedIn:
            appShellView
                .contentShellPadding(bottom: 116)
        }
    }

    private var activePageTheme: PageTheme {
        authManager.profileIsComplete ? selectedTab.theme : .auth
    }

    @ViewBuilder
    private var appShellView: some View {
        switch selectedTab {
        case .home:
            HomeView(returnToSignup: returnToSignupForTesting)
        case .messages:
            MessagesView()
        case .directory:
            MemberDirectoryView()
        case .opportunities:
            OpportunitiesView()
        case .calendar:
            CalendarView()
        case .photos:
            PhotosView()
        }
    }

    private func returnToSignupForTesting() {
        Task {
            await authManager.signOut()
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
        .environmentObject(AuthManager.previewSignedOut)
}
