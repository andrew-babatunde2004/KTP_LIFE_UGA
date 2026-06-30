//
//  SharedViews.swift
//  KTPLIFE
//

import SwiftUI

struct KTPLogoMark: View {
    var maxWidth: CGFloat = 220
    var maxHeight: CGFloat = 78
    var alignment: Alignment = .center

    var body: some View {
        Image("KTPLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
            .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: alignment)
    }
}

struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.headline())
                .foregroundStyle(.white)

            Text(message)
                .font(AppFont.subheadline())
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .matteCard(radius: 28)
    }
}

extension View {

    func loginCard(radius: CGFloat = 24) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(AppSurfaceColor.loginCard)
        )
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(AppSurfaceColor.cardBorder, lineWidth: 1)
        }
    }
}

extension View {
    func matteCard(radius: CGFloat = 26) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(AppSurfaceColor.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(AppSurfaceColor.cardBorder, lineWidth: 1)
        }
    }
}

enum AppSurfaceColor {
    static let loginCard = Color(red: 0.17, green: 0.27, blue: 0.45)
    static let card = Color(white: 0.08)
    static let cardBorder = Color(red: 0.23, green: 0.33, blue: 0.51)
    static let primaryControl = Color(red: 0.27, green: 0.37, blue: 0.55)
    static let disabledControl = Color(red: 0.14, green: 0.24, blue: 0.42)
    static let lightPanel = Color(red: 0.66, green: 0.70, blue: 0.78)
    static let lightPanelSecondary = Color(red: 0.70, green: 0.73, blue: 0.80)
    static let lightPanelBorder = Color(red: 0.54, green: 0.59, blue: 0.68)
    static let darkPill = Color(red: 0.14, green: 0.16, blue: 0.20)
    static let mutedPill = Color(red: 0.60, green: 0.64, blue: 0.72)
}

/// Semantic text colors for light/dark pages. Use instead of hard-coded `.white` on page backgrounds.
enum AppTextColor {
    static func primary(on theme: PageTheme, colorScheme: ColorScheme) -> Color {
        theme.surfaceStyle == .light && colorScheme == .light
            ? Color(red: 0.10, green: 0.12, blue: 0.16)
            : .white
    }

    static func secondary(on theme: PageTheme, colorScheme: ColorScheme) -> Color {
        primary(on: theme, colorScheme: colorScheme).opacity(0.72)
    }
}
