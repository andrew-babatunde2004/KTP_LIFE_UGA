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

                VStack(alignment: .center, spacing: 10) {
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

                VStack(spacing: 14) {
                    Button(action: retrySync) {
                        Text("Check Again")
                            .font(AppFont.headline())
                            .appTextOnCard()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.plain)
                    .background(AppSurfaceColor.primaryControl, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppSurfaceColor.cardBorder, lineWidth: 1)
                    }

                    Button(action: signOut) {
                        Text("Sign Out")
                            .font(AppFont.headline())
                            .appTextOnCardSecondary()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.plain)
                    .loginCard(radius: 24)
                }

                Spacer(minLength: 24)
            }
        }
    }
}

#Preview("Profile Incomplete") {
    ProfileIncompleteView(errorMessage: nil, retrySync: {}, signOut: {})
        .padding(20)
        .background(PageTheme.auth.previewBackground())
        .environment(\.pageTheme, PageTheme.auth)
}
