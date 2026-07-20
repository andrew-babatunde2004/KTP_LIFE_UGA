import SwiftUI

/// The content selected for a report. A user report intentionally has no `content_id`.
struct ReportTarget: Identifiable {
    let contentType: ReportContentType
    let contentID: String?
    let reportedUserID: String?
    let title: String

    var id: String {
        "\(contentType.rawValue)-\(contentID ?? reportedUserID ?? title)"
    }

    static func user(_ member: DirectoryMember) -> Self {
        Self(contentType: .user, contentID: nil, reportedUserID: member.id, title: member.name)
    }

    static func message(_ message: KTPMessage, isGroupMessage: Bool, senderName: String) -> Self {
        Self(
            contentType: isGroupMessage ? .groupMessage : .message,
            contentID: message.id,
            reportedUserID: message.senderId,
            title: "Message from \(senderName)"
        )
    }

    static func photo(_ photo: PhotoItem) -> Self {
        Self(contentType: .photo, contentID: photo.id, reportedUserID: photo.uploadedBy, title: photo.title)
    }
}

/// Self-service reporting sheet used from member, message, and media surfaces.
struct ReportContentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @State private var reason = ReportReason.harassment
    @State private var explanation = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    let target: ReportTarget

    private var apiService: KTPAPIService {
        KTPAPIService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(target.title)
                        .font(AppFont.subheadline(weight: .semibold))
                } header: {
                    Text("Reporting")
                } footer: {
                    Text("Reports are sent privately to chapter leadership for review.")
                }

                Section("Reason") {
                    Picker("Reason", selection: $reason) {
                        ForEach(ReportReason.allCases) { reason in
                            Text(reason.title).tag(reason)
                        }
                    }
                }

                Section("Additional details (optional)") {
                    TextEditor(text: $explanation)
                        .frame(minHeight: 110)
                        .accessibilityLabel("Additional report details")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(AppFont.footnote())
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Sending..." : "Submit Report") {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting || didSubmit)
                }
            }
        }
        .alert("Report Submitted", isPresented: $didSubmit) {
            Button("Done") { dismiss() }
        } message: {
            Text("Thank you. Chapter leadership will review your report.")
        }
    }

    @MainActor
    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            try await apiService.submitReport(
                SubmitReportRequest(
                    contentType: target.contentType,
                    contentID: target.contentID,
                    reportedUserID: target.reportedUserID,
                    reason: reason.rawValue,
                    explanation: explanation.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            )
            didSubmit = true
        } catch {
            errorMessage = reportErrorMessage(for: error)
        }

        isSubmitting = false
    }
}

/// Eboard queue for reviewing reports returned by `GET /reports`.
struct ReportsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var filter: ReportQueueFilter = .open
    @State private var reports: [ContentReport] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedReport: ContentReport?

    private var apiService: KTPAPIService {
        KTPAPIService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading reports...")
            } else if let errorMessage {
                ContentUnavailableView(
                    "Reports unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if reports.isEmpty {
                ContentUnavailableView(
                    "No reports",
                    systemImage: "checkmark.circle",
                    description: Text("There are no \(filter.title.lowercased()) reports."))
            } else {
                List(reports) { report in
                    Button { selectedReport = report } label: {
                        ReportRow(report: report)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Status", selection: $filter) {
                        ForEach(ReportQueueFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                } label: {
                    Text(filter.title)
                }
            }
        }
        .task(id: filter) {
            await loadReports()
        }
        .refreshable {
            await loadReports()
        }
        .sheet(item: $selectedReport) { report in
            ReportResolutionSheet(report: report) { status, response in
                await update(report, status: status, response: response)
            }
        }
    }

    @MainActor
    private func loadReports() async {
        isLoading = true
        errorMessage = nil

        do {
            reports = try await apiService.fetchReports(status: filter.status)
        } catch {
            reports = []
            errorMessage = reportErrorMessage(for: error)
        }

        isLoading = false
    }

    @MainActor
    private func update(_ report: ContentReport, status: ReportStatus, response: String?) async -> Error? {
        do {
            try await apiService.updateReportStatus(
                reportID: report.id,
                status: status,
                moderatorResponse: response
            )
            selectedReport = nil
            await loadReports()
            return nil
        } catch {
            return error
        }
    }
}

private struct ReportRow: View {
    let report: ContentReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(report.reason)
                .font(AppFont.headline())

            Text(report.reportedUserName ?? "Reported content")
                .font(AppFont.subheadline())
                .foregroundStyle(.secondary)

            if let createdAt = report.createdAt {
                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct ReportResolutionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var status: ReportStatus
    @State private var response: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    let report: ContentReport
    let update: (ReportStatus, String?) async -> Error?

    init(report: ContentReport, update: @escaping (ReportStatus, String?) async -> Error?) {
        self.report = report
        self.update = update
        _status = State(initialValue: report.status)
        _response = State(initialValue: report.moderatorResponse ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Report") {
                    LabeledContent("Reason", value: report.reason)
                    LabeledContent("Content", value: report.contentType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    if let reportedUserName = report.reportedUserName {
                        LabeledContent("Reported member", value: reportedUserName)
                    }
                    if let reporterName = report.reporterName {
                        LabeledContent("Submitted by", value: reporterName)
                    }
                    if let explanation = report.explanation?.nilIfEmpty {
                        Text(explanation)
                    }
                }

                Section("Decision") {
                    Picker("Status", selection: $status) {
                        ForEach(ReportStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    TextEditor(text: $response)
                        .frame(minHeight: 100)
                        .accessibilityLabel("Moderator response")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(AppFont.footnote())
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Review Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        errorMessage = nil
        if let error = await update(status, response.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty) {
            errorMessage = reportErrorMessage(for: error)
        }
        isSaving = false
    }
}

private enum ReportReason: String, CaseIterable, Identifiable {
    case harassment
    case hateSpeech = "hate_speech"
    case spam
    case explicitContent = "explicit_or_unsafe_content"
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .harassment: "Harassment or bullying"
        case .hateSpeech: "Hate speech"
        case .spam: "Spam"
        case .explicitContent: "Explicit or unsafe content"
        case .other: "Other"
        }
    }
}

private enum ReportQueueFilter: String, CaseIterable, Identifiable {
    case all
    case open
    case resolved
    case dismissed

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var status: ReportStatus? { ReportStatus(rawValue: rawValue) }
}

private func reportErrorMessage(for error: Error) -> String {
    if case AuthManagerError.notAuthenticated = error {
        return "Sign in with SSO to submit or review reports."
    }
    if case KTPAPIError.missingAccessToken = error {
        return "Sign in with SSO to submit or review reports."
    }
    if case KTPAPIError.badStatusCode(let statusCode, _) = error {
        if statusCode == 403 {
            return "You do not have permission to review reports."
        }
        return "The report could not be completed. Please try again."
    }
    return "The report could not be completed. Please try again."
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
