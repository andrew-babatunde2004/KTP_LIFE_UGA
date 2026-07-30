//
//  SharedViews.swift
//  KTPLIFE
//

import Foundation
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    static let storageKey = "appAppearance"

    case light
    case dark
    case gray

    var id: Self { self }

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .gray: "Gray"
        }
    }

    var description: String {
        switch self {
        case .light: "A bright white background with dark text."
        case .dark: "A true-black background designed for low-light use."
        case .gray: "A softer blue-gray background inspired by classic social-app themes."
        }
    }

    var preferredColorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark, .gray: .dark
        }
    }

    static var current: AppAppearance {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey),
              let appearance = AppAppearance(rawValue: rawValue)
        else {
            return .light
        }
        return appearance
    }
}

private struct AppAppearanceKey: EnvironmentKey {
    static let defaultValue = AppAppearance.light
}

extension EnvironmentValues {
    var appAppearance: AppAppearance {
        get { self[AppAppearanceKey.self] }
        set { self[AppAppearanceKey.self] = newValue }
    }
}

struct KTPLogoMark: View {
    var maxWidth: CGFloat = 220
    var maxHeight: CGFloat = 78
    var alignment: Alignment = .center

    var body: some View {
        Image("KTPLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .appTextPrimary()
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
                .appTextOnCard()

            Text(message)
                .font(AppFont.subheadline())
                .appTextOnCardSecondary()
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

/// Semantic system surfaces shared by the standard app pages.
/// Branded authentication and opportunity panels intentionally use AppSurfaceColor instead.
enum AppSystemColor {
    static var background: Color {
        switch AppAppearance.current {
        case .light:
            Color(uiColor: .systemBackground)
        case .dark:
            Color.black
        case .gray:
            Color(red: 0.082, green: 0.125, blue: 0.169)
        }
    }

    static var elevatedBackground: Color {
        switch AppAppearance.current {
        case .light:
            Color(uiColor: .secondarySystemBackground)
        case .dark:
            Color(white: 0.09)
        case .gray:
            Color(red: 0.118, green: 0.176, blue: 0.227)
        }
    }

    static var insetBackground: Color {
        switch AppAppearance.current {
        case .light:
            Color(uiColor: .tertiarySystemFill)
        case .dark:
            Color.white.opacity(0.12)
        case .gray:
            Color(red: 0.165, green: 0.231, blue: 0.286)
        }
    }

    static var primaryLabel: Color {
        switch AppAppearance.current {
        case .light:
            Color(uiColor: .label)
        case .dark:
            Color.white
        case .gray:
            Color(red: 0.961, green: 0.973, blue: 0.980)
        }
    }

    static var secondaryLabel: Color {
        switch AppAppearance.current {
        case .light:
            Color(uiColor: .secondaryLabel)
        case .dark:
            Color.white.opacity(0.68)
        case .gray:
            Color(red: 0.667, green: 0.722, blue: 0.761)
        }
    }

    static var separator: Color {
        switch AppAppearance.current {
        case .light:
            Color(uiColor: .separator)
        case .dark:
            Color.white.opacity(0.18)
        case .gray:
            Color(red: 0.220, green: 0.267, blue: 0.302)
        }
    }
}
