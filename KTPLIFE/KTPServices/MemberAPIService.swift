import Foundation

enum KTPAPIError: Error {
    case missingAccessToken
    case badStatusCode(Int)
}

/// Client for the KTP API. Protected routes require an Authentik access token.
final class KTPAPIService {

    private let baseURL: URL
    private let session: URLSession
    private let accessTokenProvider: () -> String?

    init(
        baseURL: URL = APIConfig.baseURL,
        session: URLSession = .shared,
        accessTokenProvider: @escaping () -> String? = { APIConfig.developmentAccessToken }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessTokenProvider = accessTokenProvider
    }

    /// Fetches all completed member profiles from protected `GET /members`.
    func fetchDirectoryMembers() async throws -> [DirectoryMember] {
        let url = baseURL.appendingPathComponent("members")
        let data = try await fetchProtectedData(from: url)

        return try JSONDecoder().decode([DirectoryMember].self, from: data)
    }

    private func fetchProtectedData(from url: URL) async throws -> Data {
        guard let accessToken = accessTokenProvider(), !accessToken.isEmpty else {
            throw KTPAPIError.missingAccessToken
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw KTPAPIError.badStatusCode(httpResponse.statusCode)
        }

        return data
    }
}
