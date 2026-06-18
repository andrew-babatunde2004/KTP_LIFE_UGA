//
//  AuthView.swift
//  KTPLIFE
//

import SwiftUI

struct AuthView: View {
    @Binding var email: String
    @Binding var password: String

    let signIn: () -> Void

    private var canSignIn: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer(minLength: 24)

            Image("KTPLogo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(maxWidth: 220, maxHeight: 78)
                .frame(maxWidth: .infinity, alignment: .center)
                .shadow(color: .white.opacity(0.08), radius: 14, y: 6)

            VStack(alignment: .leading, spacing: 14) {
                authField(
                    title: "Email",
                    prompt: "name@uga.edu",
                    text: $email,
                    icon: "envelope.fill"
                )

                authSecureField(
                    title: "Password",
                    prompt: "Enter password",
                    text: $password,
                    icon: "lock.fill"
                )
            }

            Button(action: signIn) {
                Text("Sign In")
                    .font(.system(.headline, design: .rounded, weight: .bold))
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

            Text("This screen is the local auth gate right now. Hook the sign-in action to your real auth flow when you add it.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))

            Spacer()
        }
    }

    private func authField(title: String, prompt: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 18)

                TextField("", text: text, prompt: Text(prompt).foregroundStyle(.white.opacity(0.42)))
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

    private func authSecureField(title: String, prompt: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 18)

                SecureField("", text: text, prompt: Text(prompt).foregroundStyle(.white.opacity(0.42)))
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
        signIn: {}
    )
    .padding(20)
    .background(AppTab.home.theme.backgroundColor)
}
