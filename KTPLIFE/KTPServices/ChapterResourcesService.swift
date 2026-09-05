import Foundation

/// Authenticated client for the chapter document library and committee directory.
final class ChapterResourcesService {
    private let baseURL: URL
    private let session: URLSession
    private let accessTokenProvider: () async throws -> String?

    init(
        baseURL: URL = APIConfig.baseURL,
        session: URLSession = .shared,
        accessTokenProvider: @escaping () async throws -> String? = { APIConfig.developmentAccessToken }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessTokenProvider = accessTokenProvider
    }

    func fetchFolders(parentID: String?) async throws -> [DocumentFolder] {
        let url = try resourceURL(path: "documents/folders", queryName: "parent_id", value: parentID)
        let (data, _) = try await perform(URLRequest(url: url), label: "document folders")
        return try ChapterResourceResponse.decodeFolders(from: data)
    }

    func fetchDocuments(folderID: String?) async throws -> [ChapterDocument] {
        let url = try resourceURL(path: "documents", queryName: "folder_id", value: folderID)
        let (data, _) = try await perform(URLRequest(url: url), label: "documents")
        return try ChapterResourceResponse.decodeDocuments(from: data)
    }

    func previewDocument(_ document: ChapterDocument) async throws -> DocumentPreviewPayload {
        let url = baseURL
            .appendingPathComponent("documents")
            .appendingPathComponent(document.id)
            .appendingPathComponent("preview")
        let (data, response) = try await perform(URLRequest(url: url), label: "document preview")
        return DocumentPreviewPayload(
            data: data,
            suggestedFilename: response.suggestedFilename ?? document.name
        )
    }

    func fetchCommittees() async throws -> [Committee] {
        let url = baseURL.appendingPathComponent("committees")
        let (data, _) = try await perform(URLRequest(url: url), label: "committees")
        return try ChapterResourceResponse.decodeCommittees(from: data)
    }

    /// The website now treats this route as a chair-approved membership request.
    func requestCommitteeMembership(id: String) async throws {
        let url = baseURL
            .appendingPathComponent("committees")
            .appendingPathComponent(id)
            .appendingPathComponent("join")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try await perform(request, label: "committee membership request")
    }

    func leaveCommittee(id: String) async throws {
        let url = baseURL
            .appendingPathComponent("committees")
            .appendingPathComponent(id)
            .appendingPathComponent("leave")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await perform(request, label: "leave committee")
    }

    func cancelCommitteeMembershipRequest(id: String, userID: String) async throws {
        let url = baseURL
            .appendingPathComponent("committees")
            .appendingPathComponent(id)
            .appendingPathComponent("requests")
            .appendingPathComponent(userID)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await perform(request, label: "committee membership request withdrawal")
    }

    func fetchCommitteeMembers(id: String) async throws -> [CommitteeMember] {
        let url = baseURL
            .appendingPathComponent("committees")
            .appendingPathComponent(id)
            .appendingPathComponent("members")
        let (data, _) = try await perform(URLRequest(url: url), label: "committee members")
        return try ChapterResourceResponse.decodeCommitteeMembers(from: data)
    }

    private func resourceURL(path: String, queryName: String, value: String?) throws -> URL {
        let url = baseURL.appendingPathComponent(path)
        guard let value else { return url }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: queryName, value: value)]
        guard let resolvedURL = components.url else { throw URLError(.badURL) }
        return resolvedURL
    }

    private func perform(_ request: URLRequest, label: String) async throws -> (Data, HTTPURLResponse) {
        guard let accessToken = try await accessTokenProvider(), !accessToken.isEmpty else {
            throw KTPAPIError.missingAccessToken
        }

        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        AuthDebugLog.log("Fetching \(label) from \(request.url?.absoluteString ?? "unknown URL")")

        let (data, response) = try await session.data(for: authenticatedRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw KTPAPIError.badStatusCode(httpResponse.statusCode, body)
        }
        return (data, httpResponse)
    }
}
