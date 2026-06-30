//
//  CalendarView.swift
//  KTPLIFE
//

import SwiftUI

struct CalendarView: View {
    @State private var calendarEvent: [CalendarEvent] = []
    @State private var isLoadingCalendar = false
    @State private var errorMessage: String? = nil

    private let networkService = CalendarNetworkService()

     private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        PageScaffold {
                calendarEventList
                .padding(20)
        }
         .task {
                    await loadCalendarEvents()
                }
    }

    private var calendarEventList: some View {
        LazyVStack(spacing: 14) {
            if isLoadingCalendar {
                CalendarStatusCard(message: "Loading calendar events...")
            } else if let errorMessage {
                CalendarStatusCard(message: errorMessage)
            } else if calendarEvent.isEmpty {
                CalendarStatusCard(message: "No calendar events found.")
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(calendarEvent) { event in
                        CalendarEventCard(event: event)
                    }
                }
            }
        }
    }

    private struct CalendarStatusCard: View {
        let message: String

        var body: some View {
            Text(message)
                .font(AppFont.subheadline())
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .matteCard()
        }
    }

    @MainActor
    private func loadCalendarEvents() async {
        if isPreview {
            calendarEvent = CalendarEvent.previewSamples
            errorMessage = nil
            return
        }

        isLoadingCalendar = true
        errorMessage = nil
        do {
            calendarEvent = try await networkService.fetchCalendarEvents()
        } catch {
            calendarEvent = []
            errorMessage = "Failed to load calendar events"
        }
        isLoadingCalendar = false
    }


private struct CalendarEventCard: View {
    let event: CalendarEvent
    var body: some View {
        Text(event.title + " - " + event.startDate.formatted(date: .abbreviated, time: .omitted))
            .font(AppFont.headline())
        .foregroundStyle(.white)
    }
 }
}

#Preview("Calendar") {
    CalendarView()
        .padding(20)
        .background(AppTab.calendar.theme.previewBackground())
}

