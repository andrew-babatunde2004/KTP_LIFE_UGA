//
//  PageBackground.swift
//  KTPLIFE
//

import SwiftUI

struct PageBackground: View {
    let theme: PageTheme
    let animationValue: AppTab

    var body: some View {
        theme.backgroundColor
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: animationValue)
    }
}
