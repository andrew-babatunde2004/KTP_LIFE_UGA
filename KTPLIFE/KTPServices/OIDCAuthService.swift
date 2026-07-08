import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}

enum AuthServiceError: LocalizedError {
    case missingAuthorizationCode
    case missingCodeVerifier
    case invalidCallback
    case missingDiscoveryEndpoint
    case invalidTokenResponse
    case cancelled
    case badStatusCode(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAuthorizationCode:
            return "Missing authorization code."
        case .missingCodeVerifier:
            return "Missing PKCE verifier."
        case .invalidCallback:
            return "Invalid authentication callback."
        case .missingDiscoveryEndpoint:
            return "Unable to load OIDC discovery document."
        case .invalidTokenResponse:
            return "Invalid token response."
        case .cancelled:
            return "Authentication was cancelled."
        case .badStatusCode(let statusCode, let body):
            return "Auth request failed with status \(statusCode): \(body)"
        }
    }
}

final class OIDCAuthService {
    private let session: URLSession
    private var authenticationSession: ASWebAuthenticationSession?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func signIn() async throws -> AuthTokens {
        AuthDebugLog.log("Starting OIDC sign-in with issuer=\(AuthConfiguration.issuer.absoluteString), clientID=\(AuthConfiguration.clientID)")
        let configuration = try await discoverConfiguration()
        let pkce = PKCE.generate()
        let state = RandomString.generate(length: 32)
        let nonce = RandomString.generate(length: 32)

        var components = URLComponents(url: configuration.authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: AuthConfiguration.clientID),
            URLQueryItem(name: "redirect_uri", value: AuthConfiguration.redirectURI.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: AuthConfiguration.scopeString),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce)
        ]

        guard let authorizationURL = components?.url else {
            throw AuthServiceError.missingDiscoveryEndpoint
        }

        AuthDebugLog.log("Opening authorization URL: \(authorizationURL.absoluteString)")
        let callbackURL = try await startAuthenticationSession(url: authorizationURL)
        AuthDebugLog.log("Received callback URL: \(callbackURL.absoluteString)")
        guard callbackURL.scheme == AuthConfiguration.redirectURI.scheme else {
            throw AuthServiceError.invalidCallback
        }

        guard let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let returnedState = callbackComponents.queryItems?.first(where: { $0.name == "state" })?.value,
              returnedState == state,
              let authorizationCode = callbackComponents.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw AuthServiceError.missingAuthorizationCode
        }

        return try await exchangeCode(
            authorizationCode,
            codeVerifier: pkce.verifier,
            tokenEndpoint: configuration.tokenEndpoint
        )
    }

    func refresh(refreshToken: String) async throws -> AuthTokens {
        let configuration = try await discoverConfiguration()

        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "grant_type": "refresh_token",
            "client_id": AuthConfiguration.clientID,
            "refresh_token": refreshToken
        ])

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try decodeTokens(from: data, fallbackRefreshToken: refreshToken)
    }

    private func discoverConfiguration() async throws -> OIDCConfiguration {
        let discoveryURL = AuthConfiguration.issuer.appendingPathComponent(".well-known/openid-configuration")
        AuthDebugLog.log("Fetching discovery document: \(discoveryURL.absoluteString)")
        let (data, response) = try await session.data(from: discoveryURL)
        try validateHTTPResponse(response, data: data)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let configuration = try decoder.decode(OIDCConfiguration.self, from: data)
        AuthDebugLog.log("Discovery loaded. authEndpoint=\(configuration.authorizationEndpoint.absoluteString), tokenEndpoint=\(configuration.tokenEndpoint.absoluteString)")
        return configuration
    }

    private func exchangeCode(
        _ code: String,
        codeVerifier: String,
        tokenEndpoint: URL
    ) async throws -> AuthTokens {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "grant_type": "authorization_code",
            "client_id": AuthConfiguration.clientID,
            "code": code,
            "redirect_uri": AuthConfiguration.redirectURI.absoluteString,
            "code_verifier": codeVerifier
        ])

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data)
        AuthDebugLog.log("Token exchange succeeded.")
        return try decodeTokens(from: data)
    }

    private func decodeTokens(from data: Data, fallbackRefreshToken: String? = nil) throws -> AuthTokens {
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let expiresIn = response.expiresIn else {
            throw AuthServiceError.invalidTokenResponse
        }

        return AuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? fallbackRefreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn))
        )
    }

    private func formBody(_ values: [String: String]) -> Data {
        let encoded = values
            .map { key, value in
                "\(urlEncode(key))=\(urlEncode(value))"
            }
            .sorted()
            .joined(separator: "&")

        return Data(encoded.utf8)
    }

    private func urlEncode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"
            AuthDebugLog.log("HTTP failure status=\(httpResponse.statusCode), body=\(body)")
            throw AuthServiceError.badStatusCode(httpResponse.statusCode, body)
        }
    }

    private func startAuthenticationSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: AuthConfiguration.redirectURI.scheme
            ) { [weak self] callbackURL, error in
                self?.authenticationSession = nil

                if let callbackURL {
                    AuthDebugLog.log("Authentication session completed with callback.")
                    continuation.resume(returning: callbackURL)
                    return
                }

                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    AuthDebugLog.log("Authentication session cancelled.")
                    continuation.resume(throwing: AuthServiceError.cancelled)
                    return
                }

                if error != nil {
                    AuthDebugLog.log("Authentication session failed: \(error?.localizedDescription ?? "Unknown error")")
                    continuation.resume(throwing: AuthServiceError.invalidCallback)
                    return
                }

                continuation.resume(throwing: AuthServiceError.invalidCallback)
            }

            session.presentationContextProvider = PresentationContextProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            authenticationSession = session
            session.start()
        }
    }
}

enum AuthDebugLog {
    static func log(_ message: String) {
        #if DEBUG
        print("AUTH_DEBUG:", message)
        #endif
    }
}

private struct OIDCConfiguration: Decodable {
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct PKCE {
    let verifier: String
    let challenge: String

    static func generate() -> PKCE {
        let verifier = RandomString.generate(length: 96)
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return PKCE(verifier: verifier, challenge: challenge)
    }
}

private enum RandomString {
    static func generate(length: Int) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
}

private final class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
