import SwiftUI

struct ResetPasswordView: View {
    let showLogin: () -> Void

    @State private var email = ""
    @State private var isEmailSent = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .center, spacing: 28) {
            Spacer(minLength: 24)

            KTPLogoMark()
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Enter your email to reset your password")
                .font(AppFont.subheadline())
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)

            Button(action: showLogin) {
                Text("Back to Log In")
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
}

#Preview("Reset Password") {
    ResetPasswordView(showLogin: {})
        .padding(20)
        .background(AppTab.home.theme.backgroundColor)
}
