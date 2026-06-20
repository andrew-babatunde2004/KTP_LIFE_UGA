//
//  AppTypography.swift
//  KTPLIFE
//

import SwiftUI

enum AppFont {
    // Change these PostScript names after adding a custom .ttf/.otf font to the app target.
    static let regularName = "AvenirNext-Regular"
    static let mediumName = "AvenirNext-Medium"
    static let semiboldName = "AvenirNext-DemiBold"
    static let boldName = "AvenirNext-Bold"

    static func largeTitle(_ size: CGFloat = 34) -> Font {
        .custom(boldName, size: size, relativeTo: .largeTitle)
    }

    static func title(_ size: CGFloat = 22) -> Font {
        .custom(boldName, size: size, relativeTo: .title3)
    }

    static func headline() -> Font {
        .custom(boldName, size: 17, relativeTo: .headline)
    }

    static func subheadline() -> Font {
        .custom(regularName, size: 15, relativeTo: .subheadline)
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
