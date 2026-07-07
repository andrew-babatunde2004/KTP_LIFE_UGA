import Foundation

class PhotoService {
    private let baseURL: URL

    init(baseURL: URL = APIConfig.baseURL) {
        self.baseURL = baseURL
    }

    func fetchPhotos() async throws -> [PhotoItem] {
        let url = baseURL.appendingPathComponent("photos")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([PhotoItem].self, from: data)
    }
}
