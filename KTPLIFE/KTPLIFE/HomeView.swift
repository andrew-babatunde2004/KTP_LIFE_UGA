//
//  HomeView.swift
//  KTPLIFE
//

import SwiftUI

struct HomeView: View {
    let returnToSignup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            thisWeekSection
            Spacer()
            returnToSignupButton
        }
    }

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("This week")
                .font(AppFont.headline())
                .appTextPrimary()

            ForEach(Self.upcomingEvents) { event in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(event.day)
                        .font(AppFont.footnote(weight: .semibold))
                        .frame(width: 52, alignment: .leading)
                        .appTextMuted()

                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(AppFont.headline())
                            .appTextPrimary()

                        Text(event.time)
                            .font(AppFont.footnote())
                            .appTextSecondary()
                    }
                }
            }
        }
    }

    private var returnToSignupButton: some View {
        Button(action: returnToSignup) {
            HStack(spacing: 12) {
                Text("Back to Sign Up")
                    .font(AppFont.headline())
                    .appTextOnCard()

                Spacer()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .matteCard()
    }
}

private struct HomeEvent: Identifiable {
    let id = UUID()
    let day: String
    let title: String
    let time: String
}

private extension HomeView {
    static let upcomingEvents: [HomeEvent] = [
        HomeEvent(day: "Thu 3", title: "Chapter Meeting", time: "7:00 PM"),
        HomeEvent(day: "Sat 5", title: "Professional Development", time: "2:00 PM"),
    ]
}

#Preview("Home — Light") {
    HomeView(returnToSignup: {})
        .padding(.horizontal, 20)
        .background(AppTab.home.theme.previewBackground(.light))
        .environment(\.pageTheme, AppTab.home.theme)
        .preferredColorScheme(.light)
}

#Preview("Home — Dark") {
    HomeView(returnToSignup: {})
        .padding(.horizontal, 20)
        .background(AppTab.home.theme.previewBackground(.dark))
        .environment(\.pageTheme, AppTab.home.theme)
        .preferredColorScheme(.dark)
}
