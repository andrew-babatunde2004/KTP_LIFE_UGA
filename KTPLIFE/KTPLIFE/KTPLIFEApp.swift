//
//  KTPLIFEApp.swift
//  KTPLIFE
//
//  Created by Seyi Babatunde on 6/16/26.
//

import SwiftUI

@main
struct KTPLIFEApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppAppearance.storageKey) private var appearanceRawValue = AppAppearance.system.rawValue
    @StateObject private var authManager = AuthManager()
    @StateObject private var avatarRepository = AvatarRepository()
    @StateObject private var galleryThumbnailRepository = GalleryThumbnailRepository()
    @StateObject private var galleryContentCache = GalleryContentCache()
    @StateObject private var messageAttachmentThumbnailRepository = MessageAttachmentThumbnailRepository()
    @StateObject private var pushNotificationManager = PushNotificationManager()
    @StateObject private var connectivityMonitor = ConnectivityMonitor.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appAppearance, appearance)
                .environmentObject(authManager)
                .environmentObject(avatarRepository)
                .environmentObject(galleryThumbnailRepository)
                .environmentObject(galleryContentCache)
                .environmentObject(messageAttachmentThumbnailRepository)
                .environmentObject(pushNotificationManager)
                .environmentObject(connectivityMonitor)
        }
    }

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }
}
