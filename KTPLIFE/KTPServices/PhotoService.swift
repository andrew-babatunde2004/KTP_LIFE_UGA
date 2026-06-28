import Foundation

class PhotoService {
    private let baseURL = URL(string: "http://192.168.1.174:3000/")!

    func fetchPhotos() async throws -> [PhotoItem] {
        let url = baseURL.appendingPathComponent("photos")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([PhotoItem].self, from: data)
    }
}