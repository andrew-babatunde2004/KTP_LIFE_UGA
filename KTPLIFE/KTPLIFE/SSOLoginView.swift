//
//  SSOLoginView.swift
//  KTPLIFE
//

import SwiftUI

struct SSOLoginView: View {
    let isLoading: Bool
    let errorMessage: String?
    let signIn: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 28) {
            Spacer(minLength: 24)

            KTPLogoMark()
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .center, spacing: 10) {
                Text("Sign in with your KTP SSO")
                    .font(AppFont.largeTitle(30))
                    .appTextOnCard()
                    .multilineTextAlignment(.center)

                Text("Use your chapter Authentik account to continue.")
                    .font(AppFont.subheadline())
                    .appTextSecondary()
                    .multilineTextAlignment(.center)
            }

            Button(action: signIn) {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(isLoading ? "Signing In..." : "Sign in with SSO")
                        .font(AppFont.headline())
                        .appTextOnCard()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            .buttonStyle(.plain)
            .background(AppSurfaceColor.primaryControl, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppSurfaceColor.cardBorder, lineWidth: 1)
            }
            .disabled(isLoading)

            if let errorMessage {
                Text(errorMessage)
                    .font(AppFont.footnote())
                    .appTextOnCardSecondary()
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
    }
}

#Preview("SSO Login") {
    SSOLoginView(isLoading: false, errorMessage: nil, signIn: {})
        .padding(20)
        .background(PageTheme.auth.previewBackground())
        .environment(\.pageTheme, PageTheme.auth)
}
