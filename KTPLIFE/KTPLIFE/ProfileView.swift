//
//  ProfileView.swift
//  KTPLIFE
//

import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var pushNotificationManager: PushNotificationManager
    @State private var profile: UserProfile?
    @State private var preferredName = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var major = ""
    @State private var graduationYear = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var isDeletingAccount = false
    @State private var showsDeleteAccountConfirmation = false
    @State private var errorMessage: String?

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var apiService: KTPAPIService {
        KTPAPIService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading profile...")
                } else if profile == nil {
                    ContentUnavailableView(
                        "Profile unavailable",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text(errorMessage ?? "The profile could not be loaded.")
                    )
                } else {
                    profileForm
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }

                if profile != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isSaving ? "Saving..." : "Save") {
                            Task { await saveProfile() }
                        }
                        .disabled(isSaving || isDeletingAccount)
                    }
                }
            }
        }
        .task {
            await loadProfile()
        }
        .alert("Delete Account?", isPresented: $showsDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This permanently anonymizes your KTP Me profile and signs you out. Your messages and shared photos remain so other members’ conversations and albums are not broken. Chapter SSO access must be revoked separately by eboard.")
        }
    }

    private var profileForm: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    CurrentUserAvatarView(size: 92)

                    Text(preferredName.nonEmptyTrimmed ?? profile?.displayName ?? "KTP Member")
                        .font(AppFont.title(24))

                    if let email = profile?.email {
                        Text(email)
                            .font(AppFont.footnote())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .appElevatedSurface(radius: 28)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            .listRowBackground(Color.clear)

            Section("Editable profile") {
                TextField("Preferred name", text: $preferredName)
                    .textContentType(.nickname)
                TextField("First name", text: $firstName)
                    .textContentType(.givenName)
                TextField("Last name", text: $lastName)
                    .textContentType(.familyName)
                TextField("Major", text: $major)
                TextField("Graduation year", text: $graduationYear)
                    .keyboardType(.numberPad)
            }
            .listRowBackground(AppSystemColor.elevatedBackground)

            if let memberGroup = profile?.memberGroup?.nonEmptyTrimmed {
                Section("Membership") {
                    Label {
                        LabeledContent("Group", value: memberGroup.capitalized)
                    } icon: {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(AppSurfaceColor.primaryControl)
                    }
                }
                .listRowBackground(AppSystemColor.elevatedBackground)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(AppFont.footnote())
                        .foregroundStyle(.red)
                }
                .listRowBackground(AppSystemColor.elevatedBackground)
            }

            Section("Support and community") {
                Link(destination: URL(string: "https://ugaktp.com/code-of-conduct")!) {
                    Label("Community Guidelines", systemImage: "person.3.fill")
                }

                Link(destination: URL(string: "mailto:uga.ktp@gmail.com")!) {
                    Label("Contact Support", systemImage: "envelope.fill")
                }
            }
            .listRowBackground(AppSystemColor.elevatedBackground)

            if profile?.memberGroup?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "eboard" {
                Section("Chapter leadership") {
                    NavigationLink {
                        ReportsView()
                    } label: {
                        Label("Review Reports", systemImage: "checklist")
                    }
                }
                .listRowBackground(AppSystemColor.elevatedBackground)
            }

            Section("Settings") {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }

                NavigationLink {
                    NotificationSettingsView(apiService: apiService)
                } label: {
                    Label("Notifications", systemImage: "bell.fill")
                }
            }
            .listRowBackground(AppSystemColor.elevatedBackground)

            Section("Account") {
                Button("Sign Out") {
                    Task {
                        await pushNotificationManager.unregister(using: apiService)
                        await authManager.signOut()
                        dismiss()
                    }
                }
                .disabled(isDeletingAccount)
                .frame(maxWidth: .infinity)

                Button(isDeletingAccount ? "Deleting Account..." : "Delete Account", role: .destructive) {
                    showsDeleteAccountConfirmation = true
                }
                .disabled(isDeletingAccount)
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(AppSystemColor.elevatedBackground)
        }
        .tint(AppSurfaceColor.primaryControl)
        .listSectionSpacing(20)
        .scrollContentBackground(.hidden)
        .background(AppSystemColor.background)
    }

    @MainActor
    private func loadProfile() async {
        if let cachedProfile = authManager.currentUserProfile {
            apply(cachedProfile)
            isLoading = false
        }

#if DEBUG
        if isPreview {
            apply(.preview)
            isLoading = false
            return
        }
#endif

        do {
            let loadedProfile = try await apiService.fetchCurrentUserProfile()
            guard !Task.isCancelled else { return }
            authManager.updateCurrentUserProfile(loadedProfile)
            apply(loadedProfile)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            if profile == nil {
                errorMessage = "Could not load your profile. \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    @MainActor
    private func saveProfile() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        let request = UpdateUserProfileRequest(
            preferredName: preferredName.nonEmptyTrimmed,
            firstName: firstName.nonEmptyTrimmed,
            lastName: lastName.nonEmptyTrimmed,
            major: major.nonEmptyTrimmed,
            graduationYear: graduationYear.nonEmptyTrimmed
        )

        do {
            let updatedProfile = try await apiService.updateCurrentUserProfile(request)
            authManager.updateCurrentUserProfile(updatedProfile)
            apply(updatedProfile)
            dismiss()
        } catch {
            errorMessage = "Could not save your profile. \(error.localizedDescription)"
        }

        isSaving = false
    }

    @MainActor
    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        errorMessage = nil

        do {
            await pushNotificationManager.unregister(using: apiService)
            try await apiService.deleteCurrentUser()
            await authManager.signOut()
            dismiss()
        } catch {
            errorMessage = "Could not delete your account. Please try again or contact support. \(error.localizedDescription)"
            isDeletingAccount = false
        }
    }

    private func apply(_ profile: UserProfile) {
        self.profile = profile
        preferredName = profile.preferredName ?? ""
        firstName = profile.firstName ?? ""
        lastName = profile.lastName ?? ""
        major = profile.major ?? ""
        graduationYear = profile.graduationYear ?? ""
    }
}

private struct AppearanceSettingsView: View {
    @AppStorage(AppAppearance.storageKey) private var appearanceRawValue = AppAppearance.light.rawValue

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .light
    }

    private var appearanceSelection: Binding<AppAppearance> {
        Binding(
            get: { selectedAppearance },
            set: { appearanceRawValue = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("App theme", selection: appearanceSelection) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title)
                            .tag(appearance)
                    }
                }
                .pickerStyle(.segmented)

                Text(selectedAppearance.description)
                    .font(AppFont.footnote())
                    .foregroundStyle(AppSystemColor.secondaryLabel)
            } header: {
                Text("Theme")
            } footer: {
                Text("Your choice is saved on this device and applies immediately throughout the app.")
            }
            .listRowBackground(AppSystemColor.elevatedBackground)
        }
        .tint(AppSurfaceColor.primaryControl)
        .listSectionSpacing(20)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppSystemColor.background)
    }
}

/// Reuses the shared, disk-backed avatar repository used by message threads.
struct CurrentUserAvatarView: View {
    @Environment(\.displayScale) private var displayScale
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var avatarRepository: AvatarRepository
    @State private var image: UIImage?

    let size: CGFloat

    private var userID: String? {
        authManager.currentUserID
    }

    private var fallbackInitials: String {
        let name = authManager.currentUserPreferredUsername ?? authManager.currentUserProfile?.displayName ?? "KTP"
        let initials = String(name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
        return initials.isEmpty ? "KT" : initials
    }

    private var apiService: KTPAPIService {
        KTPAPIService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(AppSystemColor.elevatedBackground)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(fallbackInitials)
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundStyle(AppSystemColor.primaryLabel)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(AppSystemColor.separator.opacity(0.5), lineWidth: 1)
        }
        .task(id: "\(userID ?? "unknown")-\(Int(size * displayScale))") {
            await loadImage()
        }
        .accessibilityLabel("Your profile picture")
    }

    @MainActor
    private func loadImage() async {
        guard let userID else {
            image = nil
            return
        }

        let loadedImage = await avatarRepository.image(
            for: userID,
            pointSize: size,
            displayScale: displayScale,
            loadData: {
                try await apiService.fetchProfilePictureData(for: userID)
            }
        )
        guard !Task.isCancelled else { return }
        image = loadedImage
    }
}

#if DEBUG
#Preview("Profile") {
    ProfileView()
        .environmentObject(AuthManager.previewSignedOut)
        .environmentObject(AvatarRepository())
}
#endif
