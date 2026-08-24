import SwiftUI
import UIKit

struct NotificationSettingsView: View {
    @EnvironmentObject private var pushNotificationManager: PushNotificationManager
    let apiService: KTPAPIService

    @State private var preferences = NotificationPreferences()
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                permissionContent
            } header: {
                Text("Device permission")
            } footer: {
                Text("KTP Me only registers this device after you allow notifications.")
            }

            Section("Notification types") {
                Toggle("Direct Messages", isOn: binding(for: \.directMessagesEnabled))
                    .disabled(isLoading || isSaving)
                Toggle("Announcements", isOn: binding(for: \.announcementsEnabled))
                    .disabled(isLoading || isSaving)
                Toggle("Polls", isOn: binding(for: \.pollsEnabled))
                    .disabled(isLoading || isSaving)
                Toggle("Meetings", isOn: binding(for: \.meetingsEnabled))
                    .disabled(isLoading || isSaving)
                Toggle("Events", isOn: binding(for: \.eventsEnabled))
                    .disabled(isLoading || isSaving)
            }

            Section {
                Toggle("Event & Meeting Reminders", isOn: binding(for: \.eventRemindersEnabled))
                    .disabled(isLoading || isSaving)
            } footer: {
                Text("Receive reminders 2 hours and 30 minutes before upcoming events and meetings.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(AppFont.footnote())
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await pushNotificationManager.refreshAuthorizationStatus()
            await loadPreferences()
        }
    }

    @ViewBuilder
    private var permissionContent: some View {
        switch pushNotificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            Label("Notifications are enabled", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .notDetermined:
            Button("Enable Notifications") {
                Task {
                    let granted = await pushNotificationManager.requestAuthorization()
                    if !granted {
                        errorMessage = "Notifications were not enabled. You can change this later in Settings."
                    }
                }
            }
        case .denied:
            Button("Open System Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        @unknown default:
            Text("Notification permission status is unavailable.")
        }
    }

    private func binding(for keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { preferences[keyPath: keyPath] },
            set: { newValue in
                let previous = preferences
                preferences[keyPath: keyPath] = newValue
                Task { await savePreferences(revertingTo: previous) }
            }
        )
    }

    @MainActor
    private func loadPreferences() async {
        isLoading = true
        defer { isLoading = false }
        do {
            preferences = try await apiService.fetchNotificationPreferences()
            preferences.cacheLocally()
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Could not load notification settings. Please try again later."
        }
    }

    @MainActor
    private func savePreferences(revertingTo previous: NotificationPreferences) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            preferences = try await apiService.updateNotificationPreferences(preferences)
            preferences.cacheLocally()
            await EventReminderScheduler().updateEnabledState()
            errorMessage = nil
        } catch is CancellationError {
            preferences = previous
        } catch {
            preferences = previous
            errorMessage = "Could not save notification settings. Please try again."
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        NotificationSettingsView(apiService: KTPAPIService())
    }
    .environmentObject(PushNotificationManager())
}
#endif
