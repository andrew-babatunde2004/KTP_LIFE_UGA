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
                Text("Welcome to KTP Life")
                    .font(AppFont.largeTitle())
                    .foregroundStyle(.white)

                Text("Create an account or log in to continue.")
                    .font(AppFont.subheadline())
                    .foregroundStyle(.white.opacity(0.68))
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
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }

                Button(action: showLogin) {
                    Text("Log In")
                        .font(AppFont.headline())
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.plain)
                .matteCard(radius: 24)
            }

            Spacer()
        }
    }
}

#Preview("Sign Up") {
    SignupView(showLogin: {})
        .padding(20)
        .background(AppTab.home.theme.backgroundColor)
}
