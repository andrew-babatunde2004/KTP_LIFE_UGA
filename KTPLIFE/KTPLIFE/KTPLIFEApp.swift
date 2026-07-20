//
//  KTPLIFEApp.swift
//  KTPLIFE
//
//  Created by Seyi Babatunde on 6/16/26.
//

import SwiftUI

@main
struct KTPLIFEApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var avatarRepository = AvatarRepository()
    @StateObject private var galleryThumbnailRepository = GalleryThumbnailRepository()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(avatarRepository)
                .environmentObject(galleryThumbnailRepository)
        }
    }
}
