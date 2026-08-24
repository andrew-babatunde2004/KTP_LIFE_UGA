import Foundation

enum AuthConfiguration {
    static let issuer = URL(string: "https://auth.ugaktp.com/application/o/ktpios/")!
    static let clientID = "B5n2OnF37aF8eWTEN1hHmHNx8ohsObzvo2Af6sOO"
    static let redirectURI = URL(string: "ktpapp://auth/callback")!
    static let endSessionEndpoint = URL(string: "https://auth.ugaktp.com/application/o/ktpios/end-session/")!
    static let scopes = ["openid", "profile", "groups", "offline_access"]

    static var scopeString: String {
        scopes.joined(separator: " ")
    }
}
