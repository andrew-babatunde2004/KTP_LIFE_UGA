//
//  ContentView.swift
//  KTPLIFE
//
//  Created by Seyi Babatunde on 6/16/26.
//

import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var avatarRepository: AvatarRepository
    @EnvironmentObject private var galleryThumbnailRepository: GalleryThumbnailRepository
    @State private var selectedTab: AppTab = .home
    @State private var didBootstrap = false
    @State private var presentedFullScreen: AppFullScreenDestination?
    @State private var isKeyboardPresented = false
    @State private var isMessageConversationPresented = false
    @State private var presentedSheet: AppSheetDestination?
    @State private var scannedQRCode: ScannedQRCode?

    var body: some View {
        ZStack {
            PageBackground(theme: activePageTheme, animationValue: selectedTab)
            rootContent
                // Let the system join scrolling content to the fixed masthead and tab bar.
                // The hard edge preserves contrast when Reduce Transparency is enabled.
                .scrollEdgeEffectStyle(reduceTransparency ? .hard : .soft, for: [.top, .bottom])
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
                isMessageConversationPresented = false
                presentedSheet = nil
                presentedFullScreen = nil
            }

            if newPhase == .signedOut {
                avatarRepository.clear()
                galleryThumbnailRepository.clear()
            }
        }
        .onChange(of: selectedTab) { _, _ in
            isMessageConversationPresented = false
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            // This iOS 26 bar API extends the system scroll-edge effect into the custom
            // tab bar. Conversation detail owns the bottom safe area for its composer.
            if authManager.profileIsComplete && !isKeyboardPresented && !isMessageConversationPresented {
                AppTabBar(selectedTab: $selectedTab)
            }
        }
        // The masthead is the only persistent top element: a quiet brand anchor that
        // begins below the Dynamic Island and keeps every page on the same visual grid.
        .safeAreaBar(edge: .top, spacing: 0) {
            if authManager.profileIsComplete {
                KTPAppHeader(
                    showsProfileButton: selectedTab == .home,
                    showsQRButton: selectedTab == .home,
                    openProfile: { presentedSheet = .profile },
                    openQRScanner: { presentedSheet = .qrScanner }
                )
            }
        }
        .fullScreenCover(item: $presentedFullScreen) { destination in
            switch destination {
            case .photos:
                PhotosView(showsCloseButton: true)
                    .environmentObject(authManager)
                    .background(AppTab.photos.theme.previewBackground())
            case .documents:
                DocumentsView()
                    .environmentObject(authManager)
            case .committees:
                CommitteesView()
                    .environmentObject(authManager)
            }
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .profile:
                ProfileView()
            case .qrScanner:
                QRCodeScannerView { payload in
                    scannedQRCode = ScannedQRCode(payload: payload)
                }
            }
        }
        .alert("QR Code Scanned", isPresented: Binding(
            get: { scannedQRCode != nil },
            set: { if !$0 { scannedQRCode = nil } }
        )) {
            if let url = scannedQRCode?.webURL {
                Button("Open Link") {
                    openURL(url)
                    scannedQRCode = nil
                }
            }

            Button("Copy") {
                UIPasteboard.general.string = scannedQRCode?.payload
                scannedQRCode = nil
            }

            Button("Cancel", role: .cancel) {
                scannedQRCode = nil
            }
        } message: {
            Text(scannedQRCode?.payload ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardPresented = false
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch authManager.phase {
        case .loading:
            KTPSplashView()
        case .signedOut, .signingIn:
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
                // Keep the navigation container full width. MessageThreadsView owns the
                // inset for its inbox, which allows a pushed conversation to transition
                // across the entire screen instead of inside the app-shell margins.
                .contentShellPadding(
                    top: 16,
                    bottom: isKeyboardPresented || isMessageConversationPresented ? 24 : 122,
                    horizontal: selectedTab.isMessagesTab ? 0 : 24
                )
        }
    }

    private var activePageTheme: PageTheme {
        authManager.profileIsComplete ? selectedTab.theme : .auth
    }

    @ViewBuilder
    private var appShellView: some View {
        switch selectedTab {
        case .home:
            HomeView(
                showPhotos: { presentedFullScreen = .photos },
                showEvents: { selectedTab = .calendar },
                showDocuments: { presentedFullScreen = .documents },
                showCommittees: { presentedFullScreen = .committees }
            )
        case .community:
            MessagesView(isConversationPresented: $isMessageConversationPresented)
        case .messages:
            MessagesView(isConversationPresented: $isMessageConversationPresented)
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

}

private struct KTPAppHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.pageTheme) private var pageTheme
    let showsProfileButton: Bool
    let showsQRButton: Bool
    let openProfile: () -> Void
    let openQRScanner: () -> Void

    var body: some View {
        ZStack {
            KTPLogoMark(maxWidth: 94, maxHeight: 36)

            if showsProfileButton || showsQRButton {
                HStack {
                    if showsQRButton {
                        Button(action: openQRScanner) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTextColor.primary(on: pageTheme, colorScheme: colorScheme))
                                .frame(width: 40, height: 40)
                                .background(AppSystemColor.elevatedBackground, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .accessibilityLabel("Scan a QR code")
                        .padding(.leading, 20)
                    }

                    Spacer()

                    if showsProfileButton {
                        Button(action: openProfile) {
                            CurrentUserAvatarView(size: 40)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .accessibilityLabel("Open your profile")
                        .padding(.trailing, 20)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(pageTheme.backgroundColor(for: colorScheme))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTextColor.primary(on: pageTheme, colorScheme: colorScheme).opacity(0.08))
                .frame(height: 0.5)
        }
    }
}

private enum AppSheetDestination: String, Identifiable {
    case profile
    case qrScanner

    var id: String { rawValue }
}

private struct ScannedQRCode {
    let payload: String

    var webURL: URL? {
        guard let url = URL(string: payload),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else {
            return nil
        }
        return url
    }
}

private enum AppFullScreenDestination: String, Identifiable {
    case photos
    case documents
    case committees

    var id: String { rawValue }
}

private extension View {
    func contentShellPadding(top: CGFloat = 24, bottom: CGFloat, horizontal: CGFloat = 20) -> some View {
        padding(.horizontal, horizontal)
            .padding(.top, top)
            .safeAreaPadding(.bottom, bottom)
    }
}

private extension AppTab {
    var isMessagesTab: Bool {
        self == .community || self == .messages
    }
}

#if DEBUG
#Preview {
    ContentView()
        .modelContainer(PreviewModelContainer.shared)
        .environmentObject(AuthManager.previewSignedOut)
        .environmentObject(AvatarRepository())
        .environmentObject(GalleryThumbnailRepository())
}
#endif
