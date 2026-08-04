import Foundation

/// An attendance check-in link of the form
/// `https://ugaktp.com/checkin/{eventId}/{token}`, as encoded into the QR code
/// the eboard displays during an event.
///
/// There are two ways one of these reaches the app and they must agree on what
/// counts as valid, so both go through this single parser:
///   1. A Universal Link — the member points the iOS Camera at the QR and iOS
///      hands the URL straight to the app (requires the Associated Domains
///      entitlement plus the apple-app-site-association file on the website).
///   2. The in-app scanner in `QRCodeScannerView`, which yields a raw string.
struct CheckInLink: Equatable {
    let eventId: String
    let token: String

    /// The website answers on both domains, and the QR encodes whichever origin
    /// the eboard member happened to be browsing at the time
    /// (`AttendancePage.jsx` builds it from `window.location.origin`), so a link
    /// can legitimately arrive on either host.
    static let allowedHosts: Set<String> = [
        "ugaktp.com", "www.ugaktp.com",
        "ktpgeorgia.com", "www.ktpgeorgia.com",
    ]

    init?(url: URL) {
        guard let host = url.host?.lowercased(), Self.allowedHosts.contains(host) else { return nil }

        // Expecting exactly ["checkin", eventId, token] — anything longer or
        // shorter is some other page on the site, not a check-in.
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 3, parts[0].lowercased() == "checkin" else { return nil }

        let eventId = parts[1]
        let token = parts[2]
        guard !eventId.isEmpty, !token.isEmpty else { return nil }

        self.eventId = eventId
        self.token = token
    }

    /// Convenience for the scanner, which hands back an arbitrary string that
    /// may not be a URL at all.
    init?(payload: String) {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return nil }
        self.init(url: url)
    }
}

struct CheckInResult {
    let message: String
    let eventTitle: String?
}

enum CheckInError: LocalizedError {
    /// The server refused the code — expired, wrong event, or outside the
    /// check-in window. Its message is member-facing, so surface it verbatim.
    case refused(String)
    case transport

    var errorDescription: String? {
        switch self {
        case .refused(let message): return message
        case .transport: return "Couldn't reach KTP. Check your connection and try again."
        }
    }
}

/// Performs a self check-in against `POST /checkin/:eventId/:token`.
///
/// No backend work was needed for this: that route already sits behind plain
/// `requireAuth` and identifies the member from the bearer token, so the app can
/// call it exactly as the website does.
enum CheckInService {
    private struct Response: Decodable {
        struct Event: Decodable {
            let title: String?
        }
        let message: String?
        let event: Event?
    }

    private struct ErrorResponse: Decodable {
        let message: String?
    }

    static func checkIn(
        _ link: CheckInLink,
        accessToken: String,
        session: URLSession = .shared
    ) async throws -> CheckInResult {
        var request = URLRequest(url: APIConfig.url(path: "checkin/\(link.eventId)/\(link.token)"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CheckInError.transport
        }

        guard let http = response as? HTTPURLResponse else {
            throw CheckInError.transport
        }

        guard 200..<300 ~= http.statusCode else {
            // ktp-api returns { message } on failure — a 403 here means the
            // code is invalid or the check-in window has closed, which is a
            // normal thing for a member to hit, not a crash.
            let decoded = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw CheckInError.refused(decoded?.message ?? "That check-in code isn't valid right now.")
        }

        let decoded = try? JSONDecoder().decode(Response.self, from: data)
        return CheckInResult(
            message: decoded?.message ?? "Checked in",
            eventTitle: decoded?.event?.title
        )
    }
}
