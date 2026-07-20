import Foundation

/// A visible homepage slide returned by authenticated `GET /ios-homepage-photos`.
struct HomepageSlide: Identifiable, Decodable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let altText: String
    let linkURL: URL?
    let linkLabel: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case altText = "alt_text"
        case linkURL = "link_url"
        case linkLabel = "link_label"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? container.decode(String.self, forKey: .id) {
            id = stringID
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        altText = try container.decodeIfPresent(String.self, forKey: .altText) ?? "Chapter highlight"
        linkURL = try container.decodeIfPresent(URL.self, forKey: .linkURL)
        linkLabel = try container.decodeIfPresent(String.self, forKey: .linkLabel)
    }
}

struct HomepageSlidesResponse: Decodable {
    let slides: [HomepageSlide]
}
