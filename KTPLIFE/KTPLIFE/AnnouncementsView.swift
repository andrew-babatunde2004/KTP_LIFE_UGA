import SwiftUI

struct AnnouncementsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @State private var announcements: [Announcement] = []
    @State private var isLoading = false
    @State private var loadError: String?

    private var apiService: KTPAPIService {
        KTPAPIService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    AppSectionHeading(
                        eyebrow: "Chapter news",
                        title: "Announcements",
                        subtitle: "Updates from the chapter, in the order they were shared.",
                        systemImage: "megaphone.fill"
                    )
                    .padding(.bottom, 22)

                    if isLoading {
                        AnnouncementStatusView(message: "Loading announcements...")
                    } else if let loadError {
                        AnnouncementStatusView(message: loadError, systemImage: "exclamationmark.circle")
                    } else if announcements.isEmpty {
                        AnnouncementStatusView(message: "There are no announcements yet.", systemImage: "megaphone")
                    } else {
                        ForEach(Array(announcements.enumerated()), id: \.element.id) { index, announcement in
                            AnnouncementThreadPost(
                                announcement: announcement,
                                showsConnector: index < announcements.count - 1
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(AppSystemColor.background)
            .navigationTitle("Announcements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppFont.subheadline(weight: .semibold))
                }
            }
            .task { await loadAnnouncements() }
            .refreshable { await loadAnnouncements() }
        }
        .background(AppSystemColor.background.ignoresSafeArea())
    }

    @MainActor
    private func loadAnnouncements() async {
        isLoading = true
        loadError = nil

        do {
            let fetchedAnnouncements = try await apiService.fetchAnnouncements()
            announcements = fetchedAnnouncements.sorted { $0.createdAt < $1.createdAt }
        } catch is CancellationError {
            return
        } catch {
            if announcements.isEmpty {
                loadError = announcementErrorMessage(for: error)
            }
        }

        isLoading = false
    }

    private func announcementErrorMessage(for error: Error) -> String {
        if case KTPAPIError.missingAccessToken = error {
            return "Sign in with SSO to view announcements."
        }

        if case KTPAPIError.badStatusCode(let statusCode, _) = error,
           statusCode == 401 || statusCode == 403 {
            return "Your announcement access has expired. Sign out and sign in again."
        }

        return "Announcements are temporarily unavailable. Please try again."
    }
}

private struct AnnouncementThreadPost: View {
    let announcement: Announcement
    let showsConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 0) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppSystemColor.background)
                    .frame(width: 34, height: 34)
                    .background(AppSystemColor.primaryLabel, in: Circle())

                if showsConnector {
                    Rectangle()
                        .fill(AppSystemColor.separator.opacity(0.65))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 7)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Kappa Theta Pi")
                        .font(AppFont.subheadline(weight: .semibold))
                        .foregroundStyle(AppSystemColor.primaryLabel)

                    Text(announcement.createdAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                        .font(AppFont.caption())
                        .foregroundStyle(AppSystemColor.secondaryLabel)
                        .lineLimit(1)
                }

                Text(announcement.title)
                    .font(AppFont.headline())
                    .foregroundStyle(AppSystemColor.primaryLabel)

                Text(announcement.body)
                    .font(AppFont.subheadline())
                    .foregroundStyle(AppSystemColor.primaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                if let updatedAt = announcement.updatedAt, updatedAt > announcement.createdAt {
                    Text("Edited \(updatedAt.formatted(.relative(presentation: .named)))")
                        .font(AppFont.caption())
                        .foregroundStyle(AppSystemColor.secondaryLabel)
                }
            }
            .padding(.bottom, showsConnector ? 24 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AnnouncementStatusView: View {
    let message: String
    var systemImage: String = "arrow.triangle.2.circlepath"

    var body: some View {
        AppStatusSurface(message: message, systemImage: systemImage)
            .padding(.vertical, 18)
    }
}
