//
//  AppTabBar.swift
//  KTPLIFE
//

import SwiftUI

struct AppTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        // increase and decreasing this spreads the icons themselves out lower = closer larger = further
        GlassEffectContainer(spacing: 5) {
            HStack(spacing: 5) {
                ForEach(AppTab.allCases) { tab in
                    AppTabBarButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        select: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                selectedTab = tab
                            }
                        }
                    )
                }
            }
            // ngl i dont even know what this does
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .glassEffect(.clear.tint(Color.white.opacity(0.08)), in: Capsule())
        }
        // the bar width itself
        .padding(.horizontal, 20)
        // the positon of the bar from the bottom of the screen
        .padding(.bottom, 10)
    }
}

private struct AppTabBarButton: View {
    let tab: AppTab
    let isSelected: Bool
    let select: () -> Void

    private var iconOpacity: Double {
        isSelected ? 1 : 0.74
    }

    var body: some View {
        Button(action: select) {
            Image(systemName: tab.icon)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(tab.title)
                .foregroundStyle(.white.opacity(iconOpacity))
        }
        .buttonStyle(.plain)
    }
}
