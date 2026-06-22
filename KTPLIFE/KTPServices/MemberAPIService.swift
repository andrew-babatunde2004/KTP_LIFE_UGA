import Foundation

/// Client for the local KTP Node API (`ktp-api`). Used by the iOS app to load live directory data.
///
/// Development setup:
/// 1. Start Postgres and run `npm run db:init` in `ktp-api`.
/// 2. Run `npm start` in `ktp-api` (listens on port 3000).
/// 3. Run the app in the **Simulator** — it reaches the API at `http://localhost:3000`.
///
/// For a physical device, replace `baseURL` with your Mac's LAN IP (for example `http://192.168.1.10:3000/`).
final class KTPAPIService {

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://192.168.1.64:3000/")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Fetches all members for the Messages directory tab.
    /// Expected response: `[DirectoryMember]` from `GET /members`.
    func fetchDirectoryMembers() async throws -> [DirectoryMember] {
        let url = baseURL.appendingPathComponent("members")

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([DirectoryMember].self, from: data)
    }

    // func fetchMessageThreads() async throws -> [MessageThread] {
    //     let url = baseURL.appendingPathComponent("messages")
    //     ...
    // }
}
