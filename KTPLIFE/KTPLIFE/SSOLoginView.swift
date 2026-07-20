//
//  SSOLoginView.swift
//  KTPLIFE
//

import SwiftUI

struct SSOLoginView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.pageTheme) private var pageTheme
    @State private var heroIsVisible = false
    @State private var actionsAreVisible = false

    let isLoading: Bool
    let errorMessage: String?
    let signIn: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    KTPLogoMark(maxWidth: 112, maxHeight: 44, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)

                    Spacer(minLength: 34)

                    FallRushCardMark(isPresented: heroIsVisible)
                        .frame(width: 278, height: 184)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("FALL RUSH ‘26")
                            .font(.system(size: 43, weight: .regular, design: .serif))
                            .tracking(0.4)
                            .foregroundStyle(SSOLoginPalette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text("Kappa Theta Pi · Phi Chapter")
                            .font(AppFont.subheadline())
                            .foregroundStyle(SSOLoginPalette.secondaryText)

                        Rectangle()
                            .fill(SSOLoginPalette.accent.opacity(0.72))
                            .frame(width: 48, height: 1)
                            .padding(.top, 5)
                    }
                    .padding(.top, 18)
                    .opacity(heroIsVisible ? 1 : 0)
                    .offset(y: heroIsVisible ? 0 : 12)

                    Spacer(minLength: 38)

                    VStack(spacing: 15) {
                        Button(action: signIn) {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView()
                                        .tint(SSOLoginPalette.ink)
                                        .transition(.scale.combined(with: .opacity))
                                }

                                Text(isLoading ? "Connecting..." : "Continue with KTP SSO")
                                    .font(AppFont.headline())
                                    .contentTransition(.opacity)
                            }
                            .foregroundStyle(SSOLoginPalette.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .contentShape(Capsule())
                        }
                        .modifier(SSOPrimaryActionSurface(
                            reduceTransparency: reduceTransparency
                        ))
                        .disabled(isLoading)
                        .accessibilityHint("Opens the secure KTP chapter sign-in service.")

                        Button(action: signIn) {
                            Text("Already have an account? Log In")
                                .font(AppFont.subheadline())
                                .underline()
                                .foregroundStyle(SSOLoginPalette.primaryText)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                    .opacity(actionsAreVisible ? 1 : 0)
                    .offset(y: actionsAreVisible ? 0 : 16)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppFont.footnote())
                            .foregroundStyle(SSOLoginPalette.errorText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Text("New and returning members use the same secure sign-in.")
                        .font(AppFont.caption())
                        .foregroundStyle(SSOLoginPalette.tertiaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                        .opacity(actionsAreVisible ? 1 : 0)
                }
                .frame(minHeight: geometry.size.height, alignment: .top)
                .padding(.vertical, 10)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pageTheme.backgroundColor(for: colorScheme).ignoresSafeArea())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isLoading)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: errorMessage)
        .onAppear(perform: revealContent)
    }

    private func revealContent() {
        guard !heroIsVisible || !actionsAreVisible else { return }

        if reduceMotion {
            heroIsVisible = true
            actionsAreVisible = true
            return
        }

        withAnimation(.smooth(duration: 0.55)) {
            heroIsVisible = true
        }

        withAnimation(.smooth(duration: 0.48).delay(0.14)) {
            actionsAreVisible = true
        }
    }
}

private enum SSOLoginPalette {
    static let primaryText = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let secondaryText = primaryText.opacity(0.72)
    static let tertiaryText = primaryText.opacity(0.48)
    static let accent = Color(red: 0.96, green: 0.79, blue: 0.65)
    static let ink = Color(red: 0.08, green: 0.13, blue: 0.24)
    static let errorText = Color(red: 1.00, green: 0.72, blue: 0.68)
}

private struct SSOPrimaryActionSurface: ViewModifier {
    let reduceTransparency: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .buttonStyle(.glassProminent)
                .tint(SSOLoginPalette.accent)
        } else {
            content
                .buttonStyle(.plain)
                .background(SSOLoginPalette.accent, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(SSOLoginPalette.primaryText.opacity(0.18), lineWidth: 1)
                }
        }
    }
}

/// SwiftUI recreation of the three-card Fall Rush illustration in Figma node 39:112.
private struct FallRushCardMark: View {
    let isPresented: Bool

    private let ink = Color(red: 0.12, green: 0.17, blue: 0.30)
    private let cardFill = SSOLoginPalette.accent

    var body: some View {
        ZStack {
            playingCard(suit: "♠")
                .rotationEffect(.degrees(isPresented ? -24 : -5))
                .offset(x: isPresented ? -58 : -14, y: isPresented ? 17 : 8)

            playingCard(suit: "♦")
                .offset(y: isPresented ? 2 : 8)

            playingCard(suit: "♥")
                .rotationEffect(.degrees(isPresented ? 24 : 5))
                .offset(x: isPresented ? 58 : 14, y: isPresented ? 17 : 8)
        }
        .opacity(isPresented ? 1 : 0)
        .scaleEffect(isPresented ? 1 : 0.92)
        .accessibilityHidden(true)
    }

    private func playingCard(suit: String) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(ink, lineWidth: 2)
                }

            Text("K")
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(ink)
                .padding(7)

            Text(suit)
                .font(.system(size: 37, weight: .bold, design: .serif))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 92, height: 126)
    }
}

/// Startup screen reproduced from Figma node 41:159 while authentication state restores.
struct KTPSplashView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            KTPLogoMark(maxWidth: 236, maxHeight: 135)
                .foregroundStyle(.white)
                .offset(y: -12)
        }
        .accessibilityLabel("Kappa Theta Pi Phi Chapter")
    }
}

#if DEBUG
#Preview("SSO Login") {
    SSOLoginView(isLoading: false, errorMessage: nil, signIn: {})
        .padding(20)
        .background(PageTheme.auth.previewBackground())
        .environment(\.pageTheme, PageTheme.auth)
        .preferredColorScheme(.dark)
}
#endif
