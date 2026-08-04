//
//  AppTabBar.swift
//  KTPLIFE
//

import SwiftUI

private enum AppTabBarMetrics {
    static let itemSize: CGFloat = 40
    static let iconSize: CGFloat = 20
}

struct AppTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedTab: AppTab
    let openProfile: () -> Void

    private var activeTheme: PageTheme {
        selectedTab.theme
    }

    private var opaqueSurfaceColor: Color {
        activeTheme.backgroundColor(for: colorScheme)
    }

    var body: some View {
        GlassEffectContainer(spacing: 22) {
            tabButtons
                // These values control the glass capsule's size and icon spacing.
                .padding(.horizontal, 30)
                .padding(.vertical, 8)
        }
        .modifier(TabBarGlassSurface(
            tint: activeTheme.tabBarGlassTint(for: colorScheme),
            reduceTransparency: reduceTransparency,
            opaqueSurfaceColor: opaqueSurfaceColor
        ))
        .padding(.horizontal, 0)
        // Keep the floating glass close to the home-indicator safe area, like the
        // bottom navigation in feed apps, while preserving a small visual clearance.
        .padding(.bottom, -10)
    }

    private var tabButtons: some View {
        HStack(spacing: 12) {
            ForEach(AppTab.allCases) { tab in
                AppTabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    iconColor: activeTheme.tabBarIconColor(
                        isSelected: selectedTab == tab,
                        colorScheme: colorScheme
                    ),
                    select: {
                        if reduceMotion {
                            selectedTab = tab
                        } else {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                selectedTab = tab
                            }
                        }
                    }
                )
            }

            Button(action: openProfile) {
                CurrentUserAvatarView(size: AppTabBarMetrics.iconSize)
                    .frame(
                        width: AppTabBarMetrics.itemSize,
                        height: AppTabBarMetrics.itemSize
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open your profile")
        }
    }
}

private struct TabBarGlassSurface: ViewModifier {
    let tint: Color
    let reduceTransparency: Bool
    let opaqueSurfaceColor: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            // Settings > Accessibility > Display & Text Size > Reduce Transparency.
            // Keep the bar fully opaque so its controls remain easy to distinguish.
            content
                .background(opaqueSurfaceColor, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.primary.opacity(0.18), lineWidth: 1)
                }
        } else {
            content
                .glassEffect(.clear.tint(tint), in: Capsule())
        }
    }
}

private struct AppTabBarButton: View {
    let tab: AppTab
    let isSelected: Bool
    let iconColor: Color
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Image(systemName: tab.icon)
                .font(.system(size: AppTabBarMetrics.iconSize, weight: .semibold))
                .frame(
                    width: AppTabBarMetrics.iconSize,
                    height: AppTabBarMetrics.iconSize
                )
                .frame(
                    width: AppTabBarMetrics.itemSize,
                    height: AppTabBarMetrics.itemSize
                )
                .contentShape(Rectangle())
                .accessibilityLabel(tab.title)
                .foregroundStyle(iconColor)
        }
        .buttonStyle(.plain)
    }
}
