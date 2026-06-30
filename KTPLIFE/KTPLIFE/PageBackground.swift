//
//  PageBackground.swift
//  KTPLIFE
//

import SwiftUI

struct PageBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    let theme: PageTheme
    let animationValue: AppTab

    var body: some View {
        theme.backgroundColor(for: colorScheme)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: animationValue)
    }
}
