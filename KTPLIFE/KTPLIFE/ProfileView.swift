//
//  ProfileView.swift
//  KTPLIFE
//

import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
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
            Text("This permanently anonymizes your KTP Life profile and signs you out. Your messages and shared photos remain so other members’ conversations and albums are not broken. Chapter SSO access must be revoked separately by eboard.")
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
                .padding(.vertical, 10)
            }

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

            if let memberGroup = profile?.memberGroup?.nonEmptyTrimmed {
                Section("Membership") {
                    LabeledContent("Group", value: memberGroup.capitalized)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(AppFont.footnote())
                        .foregroundStyle(.red)
                }
            }

            Section("Support and community") {
                Link(destination: URL(string: "https://ugaktp.com/code-of-conduct")!) {
                    Label("Community Guidelines", systemImage: "person.3.fill")
                }

                Link(destination: URL(string: "mailto:uga.ktp@gmail.com")!) {
                    Label("Contact Support", systemImage: "envelope.fill")
                }
            }

            if profile?.memberGroup?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "eboard" {
                Section("Chapter leadership") {
                    NavigationLink("Review Reports") {
                        ReportsView()
                    }
                }
            }

            Section("Account") {
                Button("Sign Out") {
                    Task {
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
        }
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
