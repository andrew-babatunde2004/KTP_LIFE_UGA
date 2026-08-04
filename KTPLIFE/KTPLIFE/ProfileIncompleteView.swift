//
//  ProfileIncompleteView.swift
//  KTPLIFE
//

import SwiftUI

struct ProfileIncompleteView: View {
    let errorMessage: String?
    let retrySync: () -> Void
    let signOut: () -> Void

    private var title: String {
        errorMessage == nil ? "Finish your profile" : "Could not verify profile"
    }

    private var message: String {
        errorMessage
            ?? "Your Authentik login worked, but your member profile is not complete yet. Complete it, then come back here and tap Check Again."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 28) {
                Spacer(minLength: 24)

                KTPLogoMark()
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: errorMessage == nil ? "person.crop.circle.badge.checkmark" : "arrow.triangle.2.circlepath")
                        .font(.system(size: 28, weight: .semibold))
                        .appTextOnCard()
                        .frame(width: 60, height: 60)
                        .background(AppSurfaceColor.primaryControl, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Text(title)
                        .font(AppFont.largeTitle(30))
                        .appTextOnCard()
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(AppFont.subheadline())
                        .appTextSecondary()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .loginCard(radius: 28)

                VStack(spacing: 14) {
                    Button(action: retrySync) {
                        Text("Check Again")
                            .font(AppFont.headline())
                            .appTextOnCard()
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(AppSurfaceColor.primaryControl)

                    Button(action: signOut) {
                        Text("Sign Out")
                            .font(AppFont.headline())
                            .appTextOnCardSecondary()
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.glass)
                }

                Spacer(minLength: 24)
            }
        }
    }
}

#if DEBUG
#Preview("Profile Incomplete") {
    ProfileIncompleteView(errorMessage: nil, retrySync: {}, signOut: {})
        .padding(20)
        .background(PageTheme.auth.previewBackground())
        .environment(\.pageTheme, PageTheme.auth)
}
#endif
