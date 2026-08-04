import SwiftUI

struct MeetingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @State private var meetings: [Meeting] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var respondingMeetingIDs: Set<String> = []
    @State private var responseError: MeetingResponseError?

    private var apiService: KTPAPIService {
        KTPAPIService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    AppSectionHeading(
                        eyebrow: "Your schedule",
                        title: "Meetings",
                        subtitle: "Private invitations, RSVP updates, and the details you need to attend.",
                        systemImage: "person.2.badge.gearshape"
                    )
                    .padding(.bottom, 6)

                    if isLoading {
                        MeetingStatusView(message: "Loading meetings...")
                    } else if let loadError {
                        MeetingStatusView(message: loadError, systemImage: "exclamationmark.circle")
                    } else if meetings.isEmpty {
                        MeetingStatusView(message: "You have no meetings right now.", systemImage: "calendar")
                    } else {
                        ForEach(meetings) { meeting in
                            MeetingCard(
                                meeting: meeting,
                                isResponding: respondingMeetingIDs.contains(meeting.id),
                                respond: { respond(to: meeting.id, with: $0) }
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(AppSystemColor.background)
            .navigationTitle("Meetings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppFont.subheadline(weight: .semibold))
                }
            }
            .task { await loadMeetings() }
            .refreshable { await loadMeetings() }
            .alert(item: $responseError) { error in
                Alert(
                    title: Text("Couldn’t Update RSVP"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .background(AppSystemColor.background.ignoresSafeArea())
    }

    @MainActor
    private func loadMeetings(showsLoadingState: Bool = true) async {
        if showsLoadingState {
            isLoading = true
        }
        loadError = nil

        do {
            meetings = try await apiService.fetchMeetings()
                .sorted { $0.startsAt < $1.startsAt }
        } catch is CancellationError {
            return
        } catch {
            if meetings.isEmpty {
                loadError = "Meetings are temporarily unavailable. Please try again."
            }
        }

        isLoading = false
    }

    private func respond(to meetingID: String, with response: MeetingResponse) {
        guard !respondingMeetingIDs.contains(meetingID) else { return }
        respondingMeetingIDs.insert(meetingID)

        Task { @MainActor in
            defer { respondingMeetingIDs.remove(meetingID) }
            do {
                try await apiService.respond(to: meetingID, response: response)
                if let index = meetings.firstIndex(where: { $0.id == meetingID }) {
                    meetings[index] = meetings[index].applying(response: response)
                }
                await loadMeetings(showsLoadingState: false)
            } catch is CancellationError {
                return
            } catch {
                responseError = MeetingResponseError(message: meetingErrorMessage(for: error))
            }
        }
    }
}

private struct MeetingCard: View {
    let meeting: Meeting
    let isResponding: Bool
    let respond: (MeetingResponse) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 2) {
                    Text(meeting.startsAt.formatted(.dateTime.month(.abbreviated)))
                        .font(AppFont.caption(weight: .bold))
                    Text(meeting.startsAt.formatted(.dateTime.day()))
                        .font(AppFont.title(20))
                }
                .foregroundStyle(AppSystemColor.primaryLabel)
                .frame(width: 52, height: 56)
                .background(AppSystemColor.insetBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title)
                        .font(AppFont.headline())
                        .foregroundStyle(AppSystemColor.primaryLabel)

                    Text(meeting.startsAt, format: .dateTime.weekday(.wide).hour().minute())
                        .font(AppFont.footnote())
                        .foregroundStyle(AppSystemColor.secondaryLabel)

                    if let location = meeting.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(AppFont.footnote())
                            .foregroundStyle(AppSystemColor.secondaryLabel)
                    }
                }

                Spacer(minLength: 0)
            }

            if let message = meeting.message, !message.isEmpty {
                Text(message)
                    .font(AppFont.subheadline())
                    .foregroundStyle(AppSystemColor.primaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if meeting.isCancelled {
                Text("Cancelled")
                    .font(AppFont.caption(weight: .bold))
                    .foregroundStyle(AppSystemColor.secondaryLabel)
            } else if !meeting.isOrganizer {
                HStack(spacing: 10) {
                    ForEach(MeetingResponse.allCases, id: \.self) { response in
                        Button(response.title) { respond(response) }
                            .font(AppFont.footnote(weight: .semibold))
                            .foregroundStyle(meeting.myResponse == response ? AppSystemColor.background : AppSystemColor.primaryLabel)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                meeting.myResponse == response ? AppSystemColor.primaryLabel : AppSystemColor.insetBackground,
                                in: Capsule()
                            )
                            .buttonStyle(.plain)
                            .disabled(isResponding)
                    }

                    if isResponding {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(17)
        .appElevatedSurface(radius: 20)
        .accessibilityElement(children: .contain)
    }
}

private struct MeetingStatusView: View {
    let message: String
    var systemImage: String = "arrow.triangle.2.circlepath"

    var body: some View {
        AppStatusSurface(message: message, systemImage: systemImage)
            .padding(.vertical, 18)
    }
}

private struct MeetingResponseError: Identifiable {
    let id = UUID()
    let message: String
}

private func meetingErrorMessage(for error: Error) -> String {
    if case AuthManagerError.notAuthenticated = error {
        return "Sign in with SSO to update your RSVP."
    }
    if case KTPAPIError.missingAccessToken = error {
        return "Sign in with SSO to update your RSVP."
    }
    if case KTPAPIError.badStatusCode(let statusCode, _) = error, statusCode == 401 || statusCode == 403 {
        return "You no longer have permission to respond to this meeting."
    }
    return "Your RSVP could not be saved. Please try again."
}
