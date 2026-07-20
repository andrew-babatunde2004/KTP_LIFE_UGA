//
//  AppTypography.swift
//  KTPLIFE
//

import SwiftUI

enum AppFont {
    // Inter is bundled with the app so the same typography renders consistently
    // across devices. SwiftUI's `relativeTo` scaling preserves Dynamic Type.
    static let regularName = "Inter-Regular"
    static let mediumName = "Inter-Medium"
    static let semiboldName = "Inter-SemiBold"
    static let boldName = "Inter-Bold"

    static func largeTitle(_ size: CGFloat = 34) -> Font {
        .custom(boldName, size: size, relativeTo: .largeTitle)
    }

    static func title(_ size: CGFloat = 22) -> Font {
        .custom(boldName, size: size, relativeTo: .title3)
    }

    static func headline() -> Font {
        .custom(boldName, size: 17, relativeTo: .headline)
    }

    static func subheadline(weight: FontWeight = .regular) -> Font {
        .custom(fontName(for: weight), size: 15, relativeTo: .subheadline)
    }

    static func footnote(weight: FontWeight = .regular) -> Font {
        .custom(fontName(for: weight), size: 13, relativeTo: .footnote)
    }

    static func caption(weight: FontWeight = .regular) -> Font {
        .custom(fontName(for: weight), size: 12, relativeTo: .caption)
    }

    private static func fontName(for weight: FontWeight) -> String {
        switch weight {
        case .regular:
            return regularName
        case .medium:
            return mediumName
        case .semibold:
            return semiboldName
        case .bold:
            return boldName
        }
    }
}

enum FontWeight {
    case regular
    case medium
    case semibold
    case bold
}

// MARK: - Semantic text colors (light / dark aware)

enum AppTextRole {
    case primary
    case secondary
    case muted
    case placeholder
    case onCard
    case onCardSecondary
    case onCardMuted
    case onCardPlaceholder
    case onPanel
    case onPanelSecondary
    case onPanelMuted
}

enum AppTextColor {
    static func color(_ role: AppTextRole, theme: PageTheme, colorScheme: ColorScheme) -> Color {
        switch role {
        case .primary:
            return pagePrimary(theme: theme, colorScheme: colorScheme)
        case .secondary:
            return pagePrimary(theme: theme, colorScheme: colorScheme).opacity(0.72)
        case .muted:
            return pagePrimary(theme: theme, colorScheme: colorScheme).opacity(0.48)
        case .placeholder:
            return pagePrimary(theme: theme, colorScheme: colorScheme).opacity(0.42)
        case .onCard:
            return .white
        case .onCardSecondary:
            return .white.opacity(0.72)
        case .onCardMuted:
            return .white.opacity(0.58)
        case .onCardPlaceholder:
            return .white.opacity(0.42)
        case .onPanel:
            return Color(red: 0.10, green: 0.12, blue: 0.16).opacity(0.86)
        case .onPanelSecondary:
            return Color(red: 0.10, green: 0.12, blue: 0.16).opacity(0.62)
        case .onPanelMuted:
            return Color(red: 0.10, green: 0.12, blue: 0.16).opacity(0.46)
        }
    }

    static func primary(on theme: PageTheme, colorScheme: ColorScheme) -> Color {
        color(.primary, theme: theme, colorScheme: colorScheme)
    }

    static func secondary(on theme: PageTheme, colorScheme: ColorScheme) -> Color {
        color(.secondary, theme: theme, colorScheme: colorScheme)
    }

    private static func pagePrimary(theme: PageTheme, colorScheme: ColorScheme) -> Color {
        switch theme.surfaceStyle {
        case .light:
            return AppSystemColor.primaryLabel
        case .dark:
            return Color(red: 0.96, green: 0.96, blue: 0.94)
        }
    }

    /// Use for `TextField` / `SecureField` prompts, which require `Text`.
    static func prompt(
        _ string: String,
        role: AppTextRole,
        theme: PageTheme,
        colorScheme: ColorScheme
    ) -> Text {
        Text(string).foregroundStyle(color(role, theme: theme, colorScheme: colorScheme))
    }
}

private struct AppTextStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.pageTheme) private var pageTheme

    let role: AppTextRole

    func body(content: Content) -> some View {
        content.foregroundStyle(AppTextColor.color(role, theme: pageTheme, colorScheme: colorScheme))
    }
}

extension View {
    func appTextPrimary() -> some View {
        modifier(AppTextStyleModifier(role: .primary))
    }

    func appTextSecondary() -> some View {
        modifier(AppTextStyleModifier(role: .secondary))
    }

    func appTextMuted() -> some View {
        modifier(AppTextStyleModifier(role: .muted))
    }

    func appTextPlaceholder() -> some View {
        modifier(AppTextStyleModifier(role: .placeholder))
    }

    func appTextOnCard() -> some View {
        modifier(AppTextStyleModifier(role: .onCard))
    }

    func appTextOnCardSecondary() -> some View {
        modifier(AppTextStyleModifier(role: .onCardSecondary))
    }

    func appTextOnCardMuted() -> some View {
        modifier(AppTextStyleModifier(role: .onCardMuted))
    }

    func appTextOnCardPlaceholder() -> some View {
        modifier(AppTextStyleModifier(role: .onCardPlaceholder))
    }

    func appTextOnPanel() -> some View {
        modifier(AppTextStyleModifier(role: .onPanel))
    }

    func appTextOnPanelSecondary() -> some View {
        modifier(AppTextStyleModifier(role: .onPanelSecondary))
    }

    func appTextOnPanelMuted() -> some View {
        modifier(AppTextStyleModifier(role: .onPanelMuted))
    }

    func appTextOnCard(opacity: Double) -> some View {
        foregroundStyle(Color.white.opacity(opacity))
    }
}
