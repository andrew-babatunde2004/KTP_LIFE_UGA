//
//  CalendarView.swift
//  KTPLIFE
//

import SwiftUI

struct CalendarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authManager: AuthManager
    @State private var viewModel = CalendarViewModel()
    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()
    @State private var userSelectedDate = false

    private let calendar = Calendar.ktpCalendar

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var sortedEvents: [CalendarEvent] {
        viewModel.events.sorted { $0.startDate < $1.startDate }
    }

    private var nextEvent: CalendarEvent? {
        sortedEvents.first { $0.endDate >= Date() } ?? sortedEvents.first
    }

    private var selectedDateEvents: [CalendarEvent] {
        sortedEvents.filter { calendar.isDate($0.startDate, inSameDayAs: selectedDate) }
    }

    private var visibleUpcomingEvents: [CalendarEvent] {
        let sameDayEvents = selectedDateEvents
        if !sameDayEvents.isEmpty {
            return sameDayEvents
        }

        return Array(sortedEvents.filter { $0.endDate >= Date() }.prefix(3))
    }

    var body: some View {
        PageScaffold(showsPageHeader: false) {
            VStack(spacing: 26) {
                CalendarMonthPanel(
                    displayedMonth: displayedMonth,
                    selectedDate: selectedDate,
                    events: sortedEvents,
                    selectDate: { date in
                        selectedDate = date
                        userSelectedDate = true
                    },
                    previousMonth: showPreviousMonth,
                    nextMonth: showNextMonth
                )

                upcomingSection
            }
            .frame(maxWidth: .infinity)
        }
        .background(CalendarDesign.background(for: colorScheme))
        .task {
            await loadCalendarEvents()
        }
        .onChange(of: viewModel.events.count) { _, _ in
            syncSelectionToNextEventIfNeeded()
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: viewModel.events.count)
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: displayedMonth)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selectedDate)
    }

    @ViewBuilder
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upcoming")
                .font(AppFont.largeTitle(20))
                .foregroundStyle(CalendarDesign.title(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)

            if viewModel.isLoading {
                CalendarStatusRow(message: "Loading calendar events...")
            } else if let errorMessage = viewModel.errorMessage {
                CalendarStatusRow(message: errorMessage)
            } else if visibleUpcomingEvents.isEmpty {
                CalendarStatusRow(message: "No events scheduled.")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(visibleUpcomingEvents.enumerated()), id: \.element.id) { index, event in
                        CalendarEventRow(event: event, accent: CalendarDesign.dotColors[index % CalendarDesign.dotColors.count])
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
        }
    }

    private func showPreviousMonth() {
        guard let month = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else {
            return
        }
        displayedMonth = month
        selectedDate = calendar.startOfMonth(for: month)
        userSelectedDate = true
    }

    private func showNextMonth() {
        guard let month = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else {
            return
        }
        displayedMonth = month
        selectedDate = calendar.startOfMonth(for: month)
        userSelectedDate = true
    }

    @MainActor
    private func loadCalendarEvents() async {
#if DEBUG
        if isPreview {
            viewModel.events = CalendarEvent.previewSamples
            viewModel.errorMessage = nil
            syncSelectionToNextEventIfNeeded()
            return
        }
#endif

        await viewModel.fetchEvents(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
        syncSelectionToNextEventIfNeeded()
    }

    private func syncSelectionToNextEventIfNeeded() {
        guard !userSelectedDate, let nextEvent else {
            return
        }

        selectedDate = nextEvent.startDate
        displayedMonth = calendar.startOfMonth(for: nextEvent.startDate)
    }
}

private struct CalendarMonthPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    let displayedMonth: Date
    let selectedDate: Date
    let events: [CalendarEvent]
    let selectDate: (Date) -> Void
    let previousMonth: () -> Void
    let nextMonth: () -> Void

    private let calendar = Calendar.ktpCalendar

    private var monthDays: [CalendarDay] {
        calendar.monthGrid(containing: displayedMonth)
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide))
    }

    private var yearTitle: String {
        displayedMonth.formatted(.dateTime.year())
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                VStack(spacing: 2) {
                    Text(monthTitle)
                        .font(AppFont.title(23))
                        .foregroundStyle(CalendarDesign.title(for: colorScheme))

                    Text(yearTitle)
                        .font(AppFont.caption(weight: .medium))
                        .foregroundStyle(CalendarDesign.muted(for: colorScheme))
                }

                GlassEffectContainer(spacing: 16) {
                    HStack {
                        MonthButton(systemName: "chevron.left", action: previousMonth)

                        Spacer()

                        MonthButton(systemName: "chevron.right", action: nextMonth)
                    }
                }
            }

            VStack(spacing: 10) {
                HStack {
                    ForEach(CalendarDay.weekdaySymbols, id: \.self) { weekday in
                        Text(weekday)
                            .font(AppFont.footnote(weight: .medium))
                            .foregroundStyle(CalendarDesign.muted(for: colorScheme))
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 20) {
                    ForEach(monthDays) { day in
                        CalendarDayCell(
                            day: day,
                            isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                            eventCount: eventCount(on: day.date),
                            dotOffset: dotOffset(for: day.date),
                            action: { selectDate(day.date) }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func eventCount(on date: Date) -> Int {
        min(events.filter { calendar.isDate($0.startDate, inSameDayAs: date) }.count, 3)
    }

    private func dotOffset(for date: Date) -> Int {
        guard let event = events.first(where: { calendar.isDate($0.startDate, inSameDayAs: date) }) else {
            return 0
        }

        return abs(event.id.hashValue) % CalendarDesign.dotColors.count
    }
}

private struct MonthButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(CalendarDesign.title(for: colorScheme))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName == "chevron.left" ? "Previous month" : "Next month")
        .glassEffect(
            .regular.tint(CalendarDesign.element(for: colorScheme)).interactive(),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

private struct CalendarDayCell: View {
    @Environment(\.colorScheme) private var colorScheme
    let day: CalendarDay
    let isSelected: Bool
    let eventCount: Int
    let dotOffset: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(CalendarDesign.selectedDay(for: colorScheme))
                            .frame(width: 30, height: 30)
                    }

                    Text("\(day.number)")
                        .font(AppFont.footnote(weight: isSelected ? .bold : .medium))
                        .foregroundStyle(textColor)
                        .frame(width: 34, height: 30)
                        .contentTransition(.numericText())
                }

                HStack(spacing: 3) {
                    ForEach(0..<eventCount, id: \.self) { index in
                        Circle()
                            .fill(CalendarDesign.dotColors[(index + dotOffset) % CalendarDesign.dotColors.count])
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var textColor: Color {
        if isSelected {
            return CalendarDesign.selectedText(for: colorScheme)
        }

        return day.isInDisplayedMonth ? CalendarDesign.title(for: colorScheme) : CalendarDesign.muted(for: colorScheme)
    }

    private var accessibilityLabel: String {
        eventCount == 1 ? "\(day.number), 1 event" : "\(day.number), \(eventCount) events"
    }
}

private struct CalendarEventRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let event: CalendarEvent
    let accent: Color

    private var timeRange: String {
        if !Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) {
            return "\(event.startDate.formatted(date: .abbreviated, time: .shortened)) - \(event.endDate.formatted(date: .abbreviated, time: .shortened))"
        }

        return "\(event.startDate.formatted(date: .omitted, time: .shortened))-\(event.endDate.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(accent)
                .frame(width: 6, height: 6)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 7) {
                Text(timeRange)
                    .font(AppFont.footnote(weight: .medium))
                    .foregroundStyle(CalendarDesign.muted(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(event.title)
                    .font(AppFont.subheadline())
                    .foregroundStyle(CalendarDesign.title(for: colorScheme))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(CalendarDesign.muted(for: colorScheme))
                .padding(.top, 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CalendarDesign.element(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CalendarDesign.border(for: colorScheme).opacity(0.42))
                .frame(height: 1)
                .padding(.leading, 36)
        }
    }
}

private struct CalendarStatusRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: String

    var body: some View {
        Text(message)
            .font(AppFont.subheadline())
            .foregroundStyle(CalendarDesign.muted(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(CalendarDesign.element(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct CalendarDay: Identifiable {
    let date: Date
    let number: Int
    let isInDisplayedMonth: Bool

    var id: Date { date }

    static let weekdaySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
}

private enum CalendarDesign {
    static let dotColors = [
        Color(red: 0.14, green: 0.38, blue: 1.00),
        Color(red: 0.00, green: 0.68, blue: 0.45),
        Color(red: 0.48, green: 0.32, blue: 1.00)
    ]

    static func background(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.background
    }

    static func element(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.elevatedBackground
    }

    static func title(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.primaryLabel
    }

    static func muted(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.secondaryLabel
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.separator
    }

    static func selectedDay(for colorScheme: ColorScheme) -> Color {
        AppSurfaceColor.primaryControl
    }

    static func selectedText(for colorScheme: ColorScheme) -> Color {
        .white
    }
}

private extension Calendar {
    static var ktpCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }

    func monthGrid(containing date: Date) -> [CalendarDay] {
        let monthStart = startOfMonth(for: date)
        let range = range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let leadingDays = (component(.weekday, from: monthStart) - firstWeekday + 7) % 7
        let gridStart = self.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart
        let totalCells = Int(ceil(Double(leadingDays + range.count) / 7.0)) * 7

        return (0..<totalCells).compactMap { offset in
            guard let cellDate = self.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }

            return CalendarDay(
                date: cellDate,
                number: component(.day, from: cellDate),
                isInDisplayedMonth: isDate(cellDate, equalTo: monthStart, toGranularity: .month)
            )
        }
    }
}

#if DEBUG
#Preview("Calendar") {
    CalendarView()
        .padding(20)
        .background(AppTab.calendar.theme.previewBackground())
        .environment(\.pageTheme, AppTab.calendar.theme)
}
#endif
