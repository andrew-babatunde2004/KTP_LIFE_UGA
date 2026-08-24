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
    @State private var monthTransitionDirection: CalendarMonthTransitionDirection = .forward
    @State private var addingEventID: String?
    @State private var addedEventIDs: Set<String> = []
    @State private var calendarErrorMessage: String?
    @Binding private var deepLinkedEventID: String?

    private let calendar = Calendar.ktpCalendar
    private let deviceCalendarService = DeviceCalendarService()
    private let reminderScheduler = EventReminderScheduler()
    private static let addedEventIDsStorageKey = "deviceCalendarAddedEventIDs"

    init(deepLinkedEventID: Binding<String?> = .constant(nil)) {
        _deepLinkedEventID = deepLinkedEventID
    }

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
                    transitionDirection: monthTransitionDirection,
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
            loadAddedEventIDs()
            await loadCalendarEvents()
        }
        .onChange(of: viewModel.events.count) { _, _ in
            syncSelectionToNextEventIfNeeded()
            selectDeepLinkedEventIfNeeded()
        }
        .onChange(of: deepLinkedEventID) { _, _ in selectDeepLinkedEventIfNeeded() }
        .alert("Couldn’t Add Event", isPresented: Binding(
            get: { calendarErrorMessage != nil },
            set: { if !$0 { calendarErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { calendarErrorMessage = nil }
        } message: {
            Text(calendarErrorMessage ?? "Please try again.")
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            CalendarAgendaHeader(
                eyebrow: selectedDateEvents.isEmpty ? "NEXT UP" : "SELECTED DAY",
                title: selectedDateEvents.isEmpty
                    ? "Upcoming"
                    : selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                count: viewModel.isLoading ? nil : visibleUpcomingEvents.count
            )

            if viewModel.isLoading {
                CalendarStatusRow(
                    message: "Loading calendar events...",
                    systemImage: "calendar.badge.clock"
                )
            } else if let errorMessage = viewModel.errorMessage {
                CalendarStatusRow(
                    message: errorMessage,
                    systemImage: "exclamationmark.circle"
                )
            } else if visibleUpcomingEvents.isEmpty {
                CalendarStatusRow(
                    message: "No events scheduled.",
                    systemImage: "calendar"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(visibleUpcomingEvents) { event in
                        CalendarEventRow(
                            event: event,
                            accent: accent(for: event),
                            isAdding: addingEventID == event.id,
                            isAdded: addedEventIDs.contains(event.id),
                            addToCalendar: { addToDeviceCalendar(event) }
                        )
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
        }
    }

    private func accent(for event: CalendarEvent) -> Color {
        let index = Int(event.id.hashValue.magnitude % UInt(CalendarDesign.dotColors.count))
        return CalendarDesign.dotColors[index]
    }

    private func loadAddedEventIDs() {
        let storedIDs = UserDefaults.standard.stringArray(forKey: Self.addedEventIDsStorageKey) ?? []
        addedEventIDs = Set(storedIDs)
    }

    private func addToDeviceCalendar(_ event: CalendarEvent) {
        guard addingEventID == nil, !addedEventIDs.contains(event.id) else {
            return
        }

        addingEventID = event.id

        Task {
            do {
                try await deviceCalendarService.add(event)
                await MainActor.run {
                    addedEventIDs.insert(event.id)
                    UserDefaults.standard.set(
                        Array(addedEventIDs).sorted(),
                        forKey: Self.addedEventIDsStorageKey
                    )
                }
            } catch is CancellationError {
                // The user left the view before the Calendar request completed.
            } catch {
                await MainActor.run {
                    calendarErrorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                addingEventID = nil
            }
        }
    }

    private func showPreviousMonth() {
        guard let month = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else {
            return
        }
        monthTransitionDirection = .backward
        displayedMonth = month
        selectedDate = calendar.startOfMonth(for: month)
        userSelectedDate = true
    }

    private func showNextMonth() {
        guard let month = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else {
            return
        }
        monthTransitionDirection = .forward
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
        await reminderScheduler.sync(events: viewModel.events)
        syncSelectionToNextEventIfNeeded()
        selectDeepLinkedEventIfNeeded()
    }

    private func syncSelectionToNextEventIfNeeded() {
        guard !userSelectedDate, let nextEvent else {
            return
        }

        selectedDate = nextEvent.startDate
        displayedMonth = calendar.startOfMonth(for: nextEvent.startDate)
    }

    private func selectDeepLinkedEventIfNeeded() {
        guard let eventID = deepLinkedEventID,
              let event = viewModel.events.first(where: { $0.id == eventID })
        else { return }

        selectedDate = event.startDate
        displayedMonth = calendar.startOfMonth(for: event.startDate)
        userSelectedDate = true
        deepLinkedEventID = nil
    }
}

private struct CalendarAgendaHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let eyebrow: String
    let title: String
    let count: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(AppFont.caption(weight: .semibold))
                .tracking(1.35)
                .foregroundStyle(CalendarDesign.accent)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(AppFont.title(21))
                    .foregroundStyle(CalendarDesign.title(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 12)

                if let count {
                    Text(count == 1 ? "1 EVENT" : "\(count) EVENTS")
                        .font(AppFont.caption(weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(CalendarDesign.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(CalendarDesign.accent.opacity(0.10), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CalendarMonthPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    let displayedMonth: Date
    let selectedDate: Date
    let events: [CalendarEvent]
    let transitionDirection: CalendarMonthTransitionDirection
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

    private var monthID: Date {
        calendar.startOfMonth(for: displayedMonth)
    }

    private var monthTransition: AnyTransition {
        let incomingEdge: Edge = transitionDirection == .forward ? .trailing : .leading
        let outgoingEdge: Edge = transitionDirection == .forward ? .leading : .trailing

        return .asymmetric(
            insertion: .move(edge: incomingEdge).combined(with: .opacity),
            removal: .move(edge: outgoingEdge).combined(with: .opacity)
        )
    }

    var body: some View {
        let eventMetadata = eventMetadataByDay

        VStack(spacing: 22) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(yearTitle)
                        .font(AppFont.caption(weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(CalendarDesign.accent)

                    Text(monthTitle)
                        .font(AppFont.largeTitle(29))
                        .foregroundStyle(CalendarDesign.title(for: colorScheme))
                }

                Spacer(minLength: 12)

                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 18) {
                        MonthButton(systemName: "chevron.left", action: previousMonth)
                        MonthButton(systemName: "chevron.right", action: nextMonth)
                    }
                }
            }

            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    ForEach(CalendarDay.weekdaySymbols, id: \.self) { weekday in
                        Text(weekday)
                            .font(AppFont.caption(weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(CalendarDesign.muted(for: colorScheme))
                            .frame(maxWidth: .infinity)
                    }
                }

                ZStack(alignment: .top) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                        spacing: 8
                    ) {
                        ForEach(monthDays) { day in
                            let metadata = eventMetadata[calendar.startOfDay(for: day.date)] ?? .empty

                            CalendarDayCell(
                                day: day,
                                isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                                eventCount: metadata.count,
                                dotOffset: metadata.dotOffset,
                                action: { selectDate(day.date) }
                            )
                        }
                    }
                    .id(monthID)
                    .transition(monthTransition)
                }
                .frame(maxWidth: .infinity, minHeight: 304, alignment: .top)
                .clipped()
                .animation(.easeInOut(duration: 0.26), value: monthID)
            }
        }
        .padding(20)
        .background(
            CalendarDesign.element(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(CalendarDesign.border(for: colorScheme).opacity(0.32), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 7)
    }

    private var eventMetadataByDay: [Date: CalendarDayEventMetadata] {
        var metadataByDay: [Date: CalendarDayEventMetadata] = [:]

        for event in events {
            let day = calendar.startOfDay(for: event.startDate)
            if var metadata = metadataByDay[day] {
                metadata.count = min(metadata.count + 1, 3)
                metadataByDay[day] = metadata
            } else {
                let dotOffset = Int(event.id.hashValue.magnitude % UInt(CalendarDesign.dotColors.count))
                metadataByDay[day] = CalendarDayEventMetadata(count: 1, dotOffset: dotOffset)
            }
        }

        return metadataByDay
    }
}

private struct MonthButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(CalendarDesign.title(for: colorScheme))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName == "chevron.left" ? "Previous month" : "Next month")
        .glassEffect(
            .regular.tint(CalendarDesign.controlTint(for: colorScheme)).interactive(),
            in: .rect(cornerRadius: 13)
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
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(CalendarDesign.selectedDay(for: colorScheme))
                        .frame(width: 36, height: 36)
                        .shadow(
                            color: CalendarDesign.selectedDay(for: colorScheme).opacity(0.24),
                            radius: 5,
                            y: 2
                        )
                        .scaleEffect(isSelected ? 1 : 0.86)
                        .opacity(isSelected ? 1 : 0)
                        .animation(.easeOut(duration: 0.16), value: isSelected)

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(CalendarDesign.accent.opacity(0.72), lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                        .opacity(isToday && !isSelected ? 1 : 0)

                    Text("\(day.number)")
                        .font(AppFont.subheadline(weight: isSelected || isToday ? .semibold : .medium))
                        .foregroundStyle(textColor)
                        .frame(width: 38, height: 36)
                }

                HStack(spacing: 2) {
                    ForEach(0..<eventCount, id: \.self) { index in
                        Circle()
                            .fill(CalendarDesign.dotColors[(index + dotOffset) % CalendarDesign.dotColors.count])
                            .frame(width: 3.5, height: 3.5)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(day.isInDisplayedMonth || isSelected ? 1 : 0.36)
        .accessibilityLabel(accessibilityLabel)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    private var textColor: Color {
        if isSelected {
            return CalendarDesign.selectedText(for: colorScheme)
        }

        return CalendarDesign.title(for: colorScheme)
    }

    private var accessibilityLabel: String {
        let date = day.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let eventLabel = eventCount == 1 ? "1 event" : "\(eventCount) events"
        return isSelected ? "\(date), selected, \(eventLabel)" : "\(date), \(eventLabel)"
    }
}

private struct CalendarEventRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let event: CalendarEvent
    let accent: Color
    let isAdding: Bool
    let isAdded: Bool
    let addToCalendar: () -> Void

    private var timeRange: String {
        if !Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) {
            return "\(event.startDate.formatted(date: .abbreviated, time: .shortened)) – \(event.endDate.formatted(date: .abbreviated, time: .shortened))"
        }

        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return start == end ? start : "\(start)–\(end)"
    }

    private var eventDescription: String? {
        guard let description = event.description?.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty else {
            return nil
        }
        return description
    }

    private var eventLocation: String? {
        guard let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines),
              !location.isEmpty else {
            return nil
        }
        return location
    }

    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            VStack(spacing: 2) {
                Text(event.startDate.formatted(.dateTime.weekday(.abbreviated)))
                    .font(AppFont.caption(weight: .semibold))
                    .textCase(.uppercase)

                Text(event.startDate.formatted(.dateTime.day()))
                    .font(AppFont.title(20))
            }
            .foregroundStyle(accent)
            .frame(width: 56, height: 60)
            .background(
                accent.opacity(0.11),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(event.title)
                    .font(AppFont.headline())
                    .foregroundStyle(CalendarDesign.title(for: colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .semibold))

                    Text(timeRange)
                        .font(AppFont.footnote(weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                .foregroundStyle(CalendarDesign.muted(for: colorScheme))

                if let eventLocation {
                    Label(eventLocation, systemImage: "mappin.and.ellipse")
                        .font(AppFont.footnote(weight: .medium))
                        .foregroundStyle(CalendarDesign.muted(for: colorScheme))
                        .lineLimit(2)
                }

                if let eventDescription {
                    Text(eventDescription)
                        .font(AppFont.footnote())
                        .foregroundStyle(CalendarDesign.muted(for: colorScheme))
                        .lineLimit(2)
                }

                calendarAction
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            CalendarDesign.element(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CalendarDesign.border(for: colorScheme).opacity(0.30), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.045), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var calendarAction: some View {
        if isAdded {
            Label("Added to Calendar", systemImage: "checkmark.circle.fill")
                .font(AppFont.footnote(weight: .semibold))
                .foregroundStyle(CalendarDesign.accent)
                .padding(.top, 2)
        } else {
            Button(action: addToCalendar) {
                Label(
                    isAdding ? "Adding…" : "Add to Calendar",
                    systemImage: isAdding ? "arrow.triangle.2.circlepath" : "calendar.badge.plus"
                )
                .font(AppFont.footnote(weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(CalendarDesign.accent)
            .disabled(isAdding)
            .accessibilityLabel(isAdding ? "Adding event to Calendar" : "Add event to Calendar")
        }
    }
}

private struct CalendarStatusRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(CalendarDesign.accent)
                .frame(width: 40, height: 40)
                .background(CalendarDesign.accent.opacity(0.10), in: Circle())

            Text(message)
                .font(AppFont.subheadline())
                .foregroundStyle(CalendarDesign.muted(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            CalendarDesign.element(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CalendarDesign.border(for: colorScheme).opacity(0.30), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CalendarDay: Identifiable {
    let date: Date
    let number: Int
    let isInDisplayedMonth: Bool

    var id: Date { date }

    static let weekdaySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
}

private enum CalendarMonthTransitionDirection {
    case backward
    case forward
}

private struct CalendarDayEventMetadata {
    var count: Int
    let dotOffset: Int

    static let empty = CalendarDayEventMetadata(count: 0, dotOffset: 0)
}

private enum CalendarDesign {
    static let accent = AppSystemColor.primaryLabel

    static let dotColors = [
        AppSystemColor.primaryLabel,
        AppSystemColor.secondaryLabel,
        Color(uiColor: .tertiaryLabel)
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

    static func controlTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : accent.opacity(0.08)
    }

    static func selectedDay(for colorScheme: ColorScheme) -> Color {
        accent
    }

    static func selectedText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
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
