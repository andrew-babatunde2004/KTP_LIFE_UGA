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
            return .defaultBlue
        case .messages:
            return .defaultBlue
        case .opportunities:
            return .opportunities
        case .calendar:
            return .defaultBlue
        case .photos:
            return .defaultBlue
        }
    }
}

struct PageTheme {
    let backgroundColor: Color

    // Change the default app background color here. Home, Messages, Calendar, and Auth use this color.
    static let defaultBlue = PageTheme(backgroundColor: Color(red: 0.10, green: 0.20, blue: 0.40))

    // Change the Opportunities page background color here.
    static let opportunities = PageTheme(backgroundColor: Color(red: 0.10, green: 0.20, blue: 0.40))

    static let auth = defaultBlue
}
