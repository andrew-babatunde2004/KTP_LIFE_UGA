import Foundation

/// Reads the public API URL from Info.plist. Local development overrides use the
/// Xcode scheme environment so credential files are never copied into the app bundle.
enum APIConfig {
    private static let baseURLKey = "API_BASE_URL"

    static let baseURL: URL = loadBaseURL()

    /// Optional Debug-only fallback. Release builds always use the native SSO token flow.
    static let developmentAccessToken: String? = {
#if DEBUG
        normalizedString(ProcessInfo.processInfo.environment["API_ACCESS_TOKEN"])
#else
        nil
#endif
    }()

    // this will be how u call the api from now on (e.g. APIConfig.url(path: "members")
    // is the same as https://api2.ugaktp.com/members when using production.
    static func url(path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    // this returns the absolute url for a relative path (e.g. "members")
    // is the same as https://api2.ugaktp.com/members when using production.
    static func absoluteURL(for relativePath: String) -> URL {
        URL(string: relativePath, relativeTo: baseURL)?.absoluteURL ?? baseURL
    }

    private static func loadBaseURL() -> URL {
#if DEBUG
        if let override = normalizedString(ProcessInfo.processInfo.environment[baseURLKey]),
           let url = normalizedURL(from: override) {
            return url
        }
#endif

        if let configuredValue = normalizedString(Bundle.main.object(forInfoDictionaryKey: baseURLKey) as? String),
           let url = normalizedURL(from: configuredValue) {
            return url
        }

        fatalError("Missing or invalid \(baseURLKey) in the app Info.plist.")
    }

    private static func normalizedURL(from value: String) -> URL? {
        var normalized = value
        if !normalized.hasSuffix("/") {
            normalized += "/"
        }

        return URL(string: normalized)
    }

    private static func normalizedString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
