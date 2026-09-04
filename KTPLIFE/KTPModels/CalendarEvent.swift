import Foundation

struct CalendarEvent: Identifiable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let description: String?
    let location: String?
    let url: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startDate
        case endDate
        case description
        case location
        case url
        case link
        case eventUrl
        case calendlyUrl
    }

    init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        description: String?,
        location: String? = nil,
        url: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.description = description
        self.location = location
        self.url = url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let stringId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = stringId
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }

        title = try container.decode(String.self, forKey: .title)
        let decodedStartDate = try container.decode(Date.self, forKey: .startDate)
        startDate = decodedStartDate
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate) ?? decodedStartDate
        description = try container.decodeIfPresent(String.self, forKey: .description)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
            ?? container.decodeIfPresent(URL.self, forKey: .link)
            ?? container.decodeIfPresent(URL.self, forKey: .eventUrl)
            ?? container.decodeIfPresent(URL.self, forKey: .calendlyUrl)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(url, forKey: .url)
    }
}

#if DEBUG
extension CalendarEvent {
    static let previewSamples: [CalendarEvent] = [
        CalendarEvent(id: "1", title: "Chapter Meeting", startDate: Date(), endDate: Date(), description: "Weekly chapter meeting", location: "Tate Student Center"),
        CalendarEvent(id: "2", title: "Professional Development Workshop", startDate: Date(), endDate: Date(), description: "Resume and interview prep with alumni"),
        CalendarEvent(id: "3", title: "Social Event", startDate: Date(), endDate: Date(), description: "End-of-semester chapter social"),
    ]
}
#endif
