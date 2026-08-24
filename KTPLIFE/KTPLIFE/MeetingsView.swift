import SwiftUI

struct MeetingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @State private var meetings: [Meeting] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var respondingMeetingIDs: Set<String> = []
    @State private var responseError: MeetingResponseError?
    @State private var isCreateMeetingPresented = false
    private let reminderScheduler = EventReminderScheduler()

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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isCreateMeetingPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create meeting")
                }
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
            .sheet(isPresented: $isCreateMeetingPresented) {
                CreateMeetingView { await loadMeetings(showsLoadingState: false) }
                    .environmentObject(authManager)
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
                .map { $0.resolvedOrganizer(for: authManager.currentUserID) }
                .sorted { $0.startsAt < $1.startsAt }
            await reminderScheduler.sync(meetings: meetings)
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
        // Organizers do not RSVP to their own meetings. Keep this guard in the
        // action as well as the card UI so a stale button or an accessibility
        // action cannot submit an organizer response.
        guard let meeting = meetings.first(where: { $0.id == meetingID }),
              !meeting.isOrganizer else {
            return
        }
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

private struct CreateMeetingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @State private var title = ""
    @State private var message = ""
    @State private var location = ""
    @State private var startsAt = Date().addingTimeInterval(3600)
    @State private var endsAt = Date().addingTimeInterval(5400)
    @State private var members: [DirectoryMember] = []
    @State private var selectedMemberIDs = Set<String>()
    @State private var isLoadingMembers = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    let didCreate: () async -> Void

    private var apiService: KTPAPIService {
        KTPAPIService(accessTokenProvider: { [authManager] in try await authManager.validAccessToken() })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meeting details") {
                    TextField("Title", text: $title)
                    TextField("Location", text: $location)
                    TextField("Note (optional)", text: $message, axis: .vertical)
                        .lineLimit(2...4)
                    DatePicker("Starts", selection: $startsAt)
                    DatePicker("Ends", selection: $endsAt, in: startsAt...)
                }
                Section("Invite members") {
                    if isLoadingMembers { ProgressView() }
                    ForEach(members) { member in
                        Button {
                            if selectedMemberIDs.contains(member.id) { selectedMemberIDs.remove(member.id) }
                            else { selectedMemberIDs.insert(member.id) }
                        } label: {
                            HStack {
                                Text(member.name).foregroundStyle(AppSystemColor.primaryLabel)
                                Spacer()
                                if selectedMemberIDs.contains(member.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppSystemColor.primaryLabel)
                                }
                            }
                        }
                    }
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .navigationTitle("New Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await createMeeting() } }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedMemberIDs.isEmpty || isSaving)
                }
            }
            .task { await loadMembers() }
        }
    }

    @MainActor private func loadMembers() async {
        defer { isLoadingMembers = false }
        do {
            let fetchedMembers = try await apiService.fetchDirectoryMembers()
            if let currentUserID = authManager.currentUserID {
                members = fetchedMembers
                    .filter { $0.id != currentUserID }
                    .sorted { $0.name < $1.name }
            } else {
                members = fetchedMembers.sorted { $0.name < $1.name }
            }
        }
        catch { errorMessage = "Members are temporarily unavailable. Please try again." }
    }

    @MainActor private func createMeeting() async {
        guard endsAt > startsAt else { errorMessage = "The end time must be after the start time."; return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await apiService.createMeeting(CreateMeetingRequest(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                message: message.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                startsAt: startsAt, endsAt: endsAt, inviteeIDs: Array(selectedMemberIDs)
            ))
            await didCreate()
            dismiss()
        } catch { errorMessage = "The meeting could not be created. Please try again." }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
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
            } else if meeting.isOrganizer {
                Text("Organizer • RSVP not required")
                    .font(AppFont.caption(weight: .semibold))
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
