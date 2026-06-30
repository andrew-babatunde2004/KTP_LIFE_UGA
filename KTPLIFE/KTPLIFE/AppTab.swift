//
//  AppTab.swift
//  KTPLIFE
//

import SwiftUI

// Add new cases here as you add pages to the tab bar.
enum AppTab: CaseIterable, Identifiable {
    case home
    case messages
    case opportunities
    case calendar
    case photos

    var id: Self { self }

    var icon: String {
        switch self {
        case .home:
            return "house.fill"
        case .messages:
            return "person.fill"
        case .opportunities:
            return "briefcase.fill"
        case .calendar:
            return "calendar"
        case .photos:
            return "photo"
        }
    }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .messages:
            return "Messages"
        case .opportunities:
            return "Opportunities"
        case .calendar:
            return "Calendar"
        case .photos:
            return "Photos"
        }
    }

    var theme: PageTheme {
        switch self {
        case .home:
            return .defaultWhite
        case .messages:
            return .defaultWhite
        case .opportunities:
            return .opportunities
        case .calendar:
            return .defaultWhite
        case .photos:
            return .defaultWhite
        }
    }
}

struct PageTheme {
  /// Light pages (Home) use dark chrome on the tab bar; dark pages use light glass + white icons.
  enum SurfaceStyle {
    case light
    case dark
  }

  let surfaceStyle: SurfaceStyle
  let lightModeBackground: Color
  let darkModeBackground: Color

  /// Page background for the current system appearance.
  func backgroundColor(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? darkModeBackground : lightModeBackground
  }

  /// Liquid glass tint on the bottom tab bar. Tweak opacity here.
  func tabBarGlassTint(for colorScheme: ColorScheme) -> Color {
    switch (surfaceStyle, colorScheme) {
    case (.light, .light):
      return Color.black.opacity(0.07)
    case (.light, .dark):
      return Color.white.opacity(0.12)
    case (.dark, _):
      return Color.white.opacity(0.10)
    }
  }

  func tabBarIconOpacity(isSelected: Bool) -> Double {
    isSelected ? 1 : 0.74
  }

  func tabBarIconColor(isSelected: Bool, colorScheme: ColorScheme) -> Color {
    let opacity = tabBarIconOpacity(isSelected: isSelected)
    switch (surfaceStyle, colorScheme) {
    case (.light, .light):
      return Color(red: 0.12, green: 0.14, blue: 0.18).opacity(opacity)
    default:
      return Color.white.opacity(opacity)
    }
  }

  // MARK: - Presets

  // Dark branded pages: Messages, Calendar, Photos, Auth, Opportunities.
  static let defaultBlue = PageTheme(
    surfaceStyle: .dark,
    lightModeBackground: Color(red: 0.10, green: 0.20, blue: 0.40),
    darkModeBackground: Color(red: 0.06, green: 0.10, blue: 0.22)
  )

  // Home: warm off-white in light mode, charcoal in dark mode.
  static let defaultWhite = PageTheme(
    surfaceStyle: .light,
    lightModeBackground: Color(red: 0.96, green: 0.96, blue: 0.94),
    darkModeBackground: Color(red: 0.11, green: 0.12, blue: 0.14)
  )

  static let opportunities = defaultBlue
  static let auth = defaultBlue

  /// Use in `#Preview` blocks. Pass `.dark` to preview dark mode in the canvas.
  func previewBackground(_ colorScheme: ColorScheme = .light) -> Color {
    backgroundColor(for: colorScheme)
  }
}
