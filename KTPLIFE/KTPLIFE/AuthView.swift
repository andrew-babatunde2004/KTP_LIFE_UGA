//
//  AuthView.swift
//  KTPLIFE
//

import SwiftUI

struct AuthView: View {
    @Binding var email: String
    @Binding var password: String
 
    let signIn: () -> Void
    let showSignup: () -> Void
    let showResetPassword: () -> Void
    init(
        email: Binding<String>,
        password: Binding<String>,
        signIn: @escaping () -> Void,
        showSignup: @escaping () -> Void = {},
        showResetPassword: @escaping () -> Void = {}
    ) {
        self._email = email
        self._password = password
        self.signIn = signIn
        self.showSignup = showSignup
        self.showResetPassword = showResetPassword
    }

    private var canSignIn: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var body: some View {
        VStack(alignment: .center, spacing: 28) {
            Spacer(minLength: 24)

            KTPLogoMark()
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .center, spacing: 14) {
                authField(
                    title: "Email",
                    prompt: "name@uga.edu",
                    text: $email
                )

                authSecureField(
                    title: "Password",
                    prompt: "Enter password",
                    text: $password
                )
            }

            Button(action: signIn) {
                Text("Sign In")
                    .font(AppFont.headline())
                    .foregroundStyle(.white.opacity(canSignIn ? 1 : 0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(canSignIn ? 0.16 : 0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(canSignIn ? 0.14 : 0.06), lineWidth: 1)
            }
            .disabled(!canSignIn)

            Button(action: showSignup) {
                Text("Back to Sign Up")
                    .font(AppFont.footnote(weight: .bold))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .matteCard(radius: 24)

           Button(action: showResetPassword) {
                Text("Reset Password")
                    .font(AppFont.footnote(weight: .bold))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .matteCard(radius: 24)

            Spacer()
        }
    }

    private func authField(title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.footnote(weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 12) {
                TextField("", text: text, prompt: Text(prompt).foregroundStyle(.white.opacity(0.42)))
                    .font(AppFont.subheadline())
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .matteCard(radius: 24)
        }
    }

    private func authSecureField(title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.footnote(weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 12) {
                SecureField("", text: text, prompt: Text(prompt).foregroundStyle(.white.opacity(0.42)))
                    .font(AppFont.subheadline())
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .matteCard(radius: 24)
        }
    }
}

#Preview("Auth") {
    AuthView(
        email: .constant(""),
        password: .constant(""),
        signIn: {},
        showSignup: {},
        showResetPassword: {}
    )
    .padding(20)
    .background(AppTab.home.theme.backgroundColor)
}
