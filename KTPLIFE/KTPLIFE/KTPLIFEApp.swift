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
    @AppStorage(AppAppearance.storageKey) private var appearanceRawValue = AppAppearance.light.rawValue
    @StateObject private var authManager = AuthManager()
    @StateObject private var avatarRepository = AvatarRepository()
    @StateObject private var galleryThumbnailRepository = GalleryThumbnailRepository()
    @StateObject private var pushNotificationManager = PushNotificationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appAppearance, appearance)
                .preferredColorScheme(appearance.preferredColorScheme)
                .environmentObject(authManager)
                .environmentObject(avatarRepository)
                .environmentObject(galleryThumbnailRepository)
                .environmentObject(pushNotificationManager)
        }
    }

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .light
    }
}
