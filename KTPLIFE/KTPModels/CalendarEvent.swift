import Foundation

struct CalendarEvent: Identifiable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startDate
        case endDate
        case description
    }

    init(id: String, title: String, startDate: Date, endDate: Date, description: String?) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.description = description
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
    }
}

#if DEBUG
extension CalendarEvent {
    static let previewSamples: [CalendarEvent] = [
        CalendarEvent(id: "1", title: "Chapter Meeting", startDate: Date(), endDate: Date(), description: "Weekly chapter meeting"),
        CalendarEvent(id: "2", title: "Professional Development Workshop", startDate: Date(), endDate: Date(), description: "Resume and interview prep with alumni"),
        CalendarEvent(id: "3", title: "Social Event", startDate: Date(), endDate: Date(), description: "End-of-semester chapter social"),
    ]
}
#endif
