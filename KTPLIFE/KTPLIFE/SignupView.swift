//
//  SignupView.swift
//  KTPLIFE
//

import SwiftUI

struct SignupView: View {
    let showLogin: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 28) {
            Spacer(minLength: 24)

            KTPLogoMark()
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .center, spacing: 10) {
                Text("Create an account or log in to continue.")
                    .font(AppFont.subheadline())
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: 14) {
                Button(action: {}) {
                    Text("Sign Up")
                        .font(AppFont.headline())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.plain)
                .background(AppSurfaceColor.primaryControl, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppSurfaceColor.cardBorder, lineWidth: 1)
                }

                Button(action: showLogin) {
                    Text("Log In")
                        .font(AppFont.headline())
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.plain)
                .loginCard(radius: 24)
            }

            Spacer()
        }
    }
}

#Preview("Sign Up") {
    SignupView(showLogin: {})
        .padding(20)
        .background(AppTab.home.theme.previewBackground())
}
