import Foundation

/// Reads API settings from `Secrets.plist` (local, gitignored) with fallback to `Secrets.example.plist`.
enum APIConfig {
    private static let baseURLKey = "API_BASE_URL"
    private static let accessTokenKey = "API_ACCESS_TOKEN"

    static let baseURL: URL = loadBaseURL()
    // Optional dev fallback. The production app should use the native SSO token flow.
    static let developmentAccessToken: String? = loadOptionalString(accessTokenKey)

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

    // this loads the base url from the secrets file
    private static func loadBaseURL() -> URL {
        for plistName in ["Secrets", "Secrets.example"] {
            if let url = baseURL(fromPlistNamed: plistName) {
                return url
            }
        }

        fatalError(
            """
            Missing \(baseURLKey) in Secrets.plist.
            Copy KTPLIFE/KTPLIFE/Secrets.example.plist to KTPLIFE/KTPLIFE/Secrets.plist and set your API URL.
            """
        )
    }

    private static func baseURL(fromPlistNamed name: String) -> URL? {
        guard
            let plistURL = Bundle.main.url(forResource: name, withExtension: "plist"),
            let data = try? Data(contentsOf: plistURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let rawValue = plist[baseURLKey] as? String
        else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var normalized = trimmed
        if !normalized.hasSuffix("/") {
            normalized += "/"
        }

        guard let url = URL(string: normalized) else { return nil }
        return url
    }

    private static func loadOptionalString(_ key: String) -> String? {
        for plistName in ["Secrets", "Secrets.example"] {
            guard let value = stringValue(for: key, fromPlistNamed: plistName) else {
                continue
            }

            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }

    private static func stringValue(for key: String, fromPlistNamed name: String) -> String? {
        guard
            let plistURL = Bundle.main.url(forResource: name, withExtension: "plist"),
            let data = try? Data(contentsOf: plistURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return nil
        }

        return plist[key] as? String
    }
}
