//
//  AppTabBar.swift
//  KTPLIFE
//

import SwiftUI

struct AppTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        // Nav bar spacing: increase/decrease this and the HStack spacing together to spread tabs out or pull them in.
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
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
            // Nav bar thickness: larger padding makes the glass capsule taller/wider around the tab buttons.
            .padding(10)
            .glassEffect(.clear.tint(Color.white.opacity(0.08)), in: Capsule())
        }
        // Nav bar screen width/position: larger horizontal padding makes the whole bar use less screen width.
        .padding(.horizontal, 30)
        .padding(.bottom, 10)
    }
}

private struct AppTabBarButton: View {
    let tab: AppTab
    let isSelected: Bool
    let select: () -> Void

    private var tintOpacity: Double {
        isSelected ? 0.16 : 0.06
    }

    private var iconOpacity: Double {
        isSelected ? 1 : 0.74
    }

    var body: some View {
        Button(action: select) {
            Image(systemName: tab.icon)
                .font(.system(size: 20, weight: .semibold))
                // Individual tab size: width controls each tab's clickable area and the total visible nav bar width.
                .frame(width: 80, height: 52)
                .contentShape(Capsule())
                .accessibilityLabel(tab.title)
                .foregroundStyle(.white.opacity(iconOpacity))
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.tint(Color.white.opacity(tintOpacity)), in: Capsule())
    }
}
