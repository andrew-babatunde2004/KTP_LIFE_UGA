//
//  PageBackground.swift
//  KTPLIFE
//

import SwiftUI

struct PageBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let theme: PageTheme
    let animationValue: AppTab

    var body: some View {
        theme.backgroundColor(for: colorScheme)
            .ignoresSafeArea()
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: animationValue)
    }
}
