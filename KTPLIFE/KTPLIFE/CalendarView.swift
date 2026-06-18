//
//  CalendarView.swift
//  KTPLIFE
//

import SwiftUI

struct CalendarView: View {
    var body: some View {
        PageScaffold {
            Text("Calendar view coming soon!")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .matteCard(radius: 28)
        }
    }
}

#Preview("Calendar") {
    CalendarView()
        .padding(20)
        .background(AppTab.calendar.theme.backgroundColor)
}
