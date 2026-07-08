import Combine
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    enum Phase: Equatable {
        case loading
        case signedOut
        case signingIn
        case profileIncomplete
        case signedIn
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var errorMessage: String?

    private let authService: OIDCAuthService
    private let userSyncService: UserSyncService
    private let keychain: KeychainStore

    private var tokens: AuthTokens?
    private var lastAccessTokenClaims: TokenClaimSummary?

    init(
        authService: OIDCAuthService = OIDCAuthService(),
        userSyncService: UserSyncService = UserSyncService(),
        keychain: KeychainStore = KeychainStore()
    ) {
        self.authService = authService
        self.userSyncService = userSyncService
        self.keychain = keychain
    }

    func bootstrap() async {
        AuthDebugLog.log("Bootstrap started.")
        phase = .loading
        errorMessage = nil

        do {
            guard let storedTokens = try keychain.loadTokens() else {
                AuthDebugLog.log("No stored tokens found.")
                phase = .signedOut
                return
            }

            AuthDebugLog.log("Stored tokens found. Refreshing if needed.")
            tokens = storedTokens
            try await refreshIfNeeded()
            try await updateProfileState()
        } catch is AuthManagerError {
            AuthDebugLog.log("Bootstrap failed because user is not authenticated.")
            await signOut()
        } catch {
            AuthDebugLog.log("Bootstrap profile verification failed: \(error.localizedDescription)")
            if tokens != nil {
                // Keep the user in the authenticated flow if profile sync fails.
                phase = .profileIncomplete
                errorMessage = profileVerificationMessage(for: error)
            } else {
                await signOut()
            }
        }
    }

    func signInWithSSO() async {
        AuthDebugLog.log("Sign-in button tapped.")
        phase = .signingIn
        errorMessage = nil

        do {
            let newTokens = try await authService.signIn()
            AuthDebugLog.log("Sign-in returned tokens. Saving.")
            try save(tokens: newTokens)
            try await updateProfileState()
        } catch let error as AuthServiceError {
            AuthDebugLog.log("AuthServiceError: \(error.localizedDescription)")
            if case .cancelled = error {
                phase = .signedOut
                return
            }

            if tokens != nil {
                phase = .profileIncomplete
                errorMessage = profileVerificationMessage(for: error)
            } else {
                phase = .signedOut
            }
        } catch {
            AuthDebugLog.log("SSO sign-in failed: \(error.localizedDescription)")
            if tokens != nil {
                phase = .profileIncomplete
                errorMessage = profileVerificationMessage(for: error)
            } else {
                phase = .signedOut
                errorMessage = error.localizedDescription
            }
        }
    }

    func checkProfileStatus() async {
        AuthDebugLog.log("Manual profile status check started.")
        guard isAuthenticated else {
            AuthDebugLog.log("Profile status check blocked because user is not authenticated.")
            phase = .signedOut
            return
        }

        do {
            try await updateProfileState()
        } catch {
            AuthDebugLog.log("Manual profile status check failed: \(error.localizedDescription)")
            if tokens != nil {
                // Profile sync failed, but the user is still authenticated.
                phase = .profileIncomplete
                errorMessage = profileVerificationMessage(for: error)
            } else {
                errorMessage = profileVerificationMessage(for: error)
            }
        }
    }

    func signOut() async {
        AuthDebugLog.log("Signing out and clearing tokens.")
        tokens = nil
        lastAccessTokenClaims = nil
        errorMessage = nil
        phase = .signedOut

        do {
            try keychain.deleteTokens()
        } catch {
            // Ignore keychain cleanup failures for sign-out.
        }
    }

    func validAccessToken() async throws -> String {
        guard tokens != nil else {
            throw AuthManagerError.notAuthenticated
        }

        do {
            try await refreshIfNeeded()
        } catch {
            await signOut()
            throw error
        }

        guard let tokens else {
            throw AuthManagerError.notAuthenticated
        }

        return tokens.accessToken
    }

    var isAuthenticated: Bool {
        phase == .profileIncomplete || phase == .signedIn
    }

    var isBusy: Bool {
        phase == .loading || phase == .signingIn
    }

    var profileIsComplete: Bool {
        phase == .signedIn
    }

    private func updateProfileState() async throws {
        AuthDebugLog.log("Updating profile state via /users/sync.")
        let accessToken = try await validAccessToken()
        lastAccessTokenClaims = TokenClaimSummary(accessToken: accessToken)
        if let lastAccessTokenClaims {
            AuthDebugLog.log("Access token claims: \(lastAccessTokenClaims.description)")
        }
        let response = try await userSyncService.syncCurrentUser(accessToken: accessToken)
        AuthDebugLog.log("User sync succeeded. profileComplete=\(response.profileComplete)")
        errorMessage = nil
        phase = response.profileComplete ? .signedIn : .profileIncomplete
    }

    private func refreshIfNeeded() async throws {
        guard let currentTokens = tokens else {
            throw AuthManagerError.notAuthenticated
        }

        guard currentTokens.expiresAt.timeIntervalSinceNow < 60 else {
            AuthDebugLog.log("Access token still valid. Seconds remaining=\(Int(currentTokens.expiresAt.timeIntervalSinceNow))")
            return
        }

        guard let refreshToken = currentTokens.refreshToken else {
            throw AuthManagerError.notAuthenticated
        }

        AuthDebugLog.log("Access token near expiry. Refreshing.")
        let refreshedTokens = try await authService.refresh(refreshToken: refreshToken)
        try save(tokens: refreshedTokens)
    }

    private func save(tokens: AuthTokens) throws {
        self.tokens = tokens
        try keychain.saveTokens(tokens)
    }

    private func profileVerificationMessage(for error: Error) -> String {
        var message: String
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            message = description
        } else {
            message = "Could not verify profile status. Your login worked, but the app could not confirm profile completion from the API."
        }

        if let lastAccessTokenClaims {
            message += "\n\nToken claims: \(lastAccessTokenClaims.description)"
        }

        return message
    }
}

enum AuthManagerError: Error {
    case notAuthenticated
}

private struct TokenClaimSummary {
    let issuer: String?
    let audience: String?
    let subject: String?
    let preferredUsername: String?
    let groups: String?
    let expiration: Date?

    init?(accessToken: String) {
        let parts = accessToken.split(separator: ".")
        guard parts.count >= 2,
              let payloadData = Self.base64URLDecode(String(parts[1])),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else {
            return nil
        }

        issuer = payload["iss"] as? String
        subject = payload["sub"] as? String
        preferredUsername = payload["preferred_username"] as? String

        if let groupsArray = payload["groups"] as? [String] {
            groups = groupsArray.joined(separator: ", ")
        } else if let groupsString = payload["groups"] as? String {
            groups = groupsString
        } else {
            groups = nil
        }

        if let audienceString = payload["aud"] as? String {
            audience = audienceString
        } else if let audienceArray = payload["aud"] as? [String] {
            audience = audienceArray.joined(separator: ", ")
        } else {
            audience = nil
        }

        if let exp = payload["exp"] as? TimeInterval {
            expiration = Date(timeIntervalSince1970: exp)
        } else {
            expiration = nil
        }
    }

    var description: String {
        [
            "iss=\(issuer ?? "missing")",
            "aud=\(audience ?? "missing")",
            "sub=\(subject ?? "missing")",
            "preferred_username=\(preferredUsername ?? "missing")",
            "groups=\(groups ?? "missing")",
            "exp=\(expiration?.formatted(date: .abbreviated, time: .standard) ?? "missing")"
        ].joined(separator: ", ")
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)

        return Data(base64Encoded: base64)
    }
}

#if DEBUG
extension AuthManager {
    static var previewSignedOut: AuthManager {
        let manager = AuthManager()
        manager.phase = .signedOut
        return manager
    }
}
#endif
