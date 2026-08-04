import Foundation

struct Announcement: Identifiable, Equatable, Decodable {
    let id: String
    let title: String
    let body: String
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case message
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try container.decodeIfPresent(String.self, forKey: .id), !stringID.isEmpty {
            id = stringID
        } else if let integerID = try container.decodeIfPresent(Int.self, forKey: .id) {
            id = String(integerID)
        } else {
            id = UUID().uuidString
        }

        let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        title = (decodedTitle?.isEmpty == false ? decodedTitle : nil) ?? "Chapter update"
        body = try container.decodeIfPresent(String.self, forKey: .body)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .content)
            ?? ""
        createdAt = try container.announcementDate(for: .createdAt) ?? .distantPast
        updatedAt = try container.announcementDate(for: .updatedAt)
    }

    static func decodeAnnouncements(from data: Data) throws -> [Announcement] {
        let decoder = JSONDecoder()
        if let announcements = try? decoder.decode([Announcement].self, from: data) {
            return announcements
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let response = object as? [String: Any] else {
            throw KTPAPIError.decodeFailed("Expected an announcement array or response object.")
        }

        for key in ["announcements", "data"] {
            guard let value = response[key], JSONSerialization.isValidJSONObject(value) else { continue }
            let nestedData = try JSONSerialization.data(withJSONObject: value)
            if let announcements = try? decoder.decode([Announcement].self, from: nestedData) {
                return announcements
            }
        }

        throw KTPAPIError.decodeFailed("The response did not contain a supported announcement list.")
    }
}

private extension KeyedDecodingContainer {
    func announcementDate(for key: Key) throws -> Date? {
        guard let value = try decodeIfPresent(String.self, forKey: key) else { return nil }
        return AnnouncementDateParser.date(from: value)
    }
}

private enum AnnouncementDateParser {
    private static let fractionalISO8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601 = ISO8601DateFormatter()

    static func date(from value: String) -> Date? {
        fractionalISO8601.date(from: value) ?? iso8601.date(from: value)
    }
}
