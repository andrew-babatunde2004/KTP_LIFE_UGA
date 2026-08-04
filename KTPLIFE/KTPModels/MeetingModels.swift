import Foundation

enum MeetingResponse: String, Codable, CaseIterable {
    case going
    case notGoing = "not_going"

    var title: String {
        switch self {
        case .going: "Going"
        case .notGoing: "Can't Go"
        }
    }
}

struct Meeting: Identifiable, Equatable, Decodable {
    let id: String
    let title: String
    let message: String?
    let location: String?
    let startsAt: Date
    let endsAt: Date?
    let status: String
    let myResponse: MeetingResponse?
    let isOrganizer: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case message
        case description
        case location
        case startsAt = "starts_at"
        case startDate = "start_date"
        case endsAt = "ends_at"
        case endDate = "end_date"
        case status
        case myResponse = "my_response"
        case response
        case isOrganizer = "is_organizer"
        case organizerId = "organizer_id"
        case createdBy = "created_by"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try container.decodeIfPresent(String.self, forKey: .id) {
            id = stringID
        } else if let integerID = try container.decodeIfPresent(Int.self, forKey: .id) {
            id = String(integerID)
        } else {
            id = UUID().uuidString
        }

        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Meeting"
        message = try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .description)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        startsAt = try container.meetingDate(for: .startsAt)
            ?? container.meetingDate(for: .startDate)
            ?? .distantPast
        endsAt = try container.meetingDate(for: .endsAt)
            ?? container.meetingDate(for: .endDate)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "scheduled"

        let responseValue = try container.decodeIfPresent(String.self, forKey: .myResponse)
            ?? container.decodeIfPresent(String.self, forKey: .response)
        myResponse = responseValue.flatMap(MeetingResponse.init(rawValue:))
        isOrganizer = try container.decodeIfPresent(Bool.self, forKey: .isOrganizer) ?? false
    }

    var isCancelled: Bool {
        status.caseInsensitiveCompare("cancelled") == .orderedSame
    }

    func applying(response: MeetingResponse) -> Meeting {
        Meeting(
            id: id,
            title: title,
            message: message,
            location: location,
            startsAt: startsAt,
            endsAt: endsAt,
            status: status,
            myResponse: response,
            isOrganizer: isOrganizer
        )
    }

    private init(
        id: String,
        title: String,
        message: String?,
        location: String?,
        startsAt: Date,
        endsAt: Date?,
        status: String,
        myResponse: MeetingResponse?,
        isOrganizer: Bool
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.location = location
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.status = status
        self.myResponse = myResponse
        self.isOrganizer = isOrganizer
    }

    static func decodeMeetings(from data: Data) throws -> [Meeting] {
        let decoder = JSONDecoder()
        if let meetings = try? decoder.decode([Meeting].self, from: data) {
            return meetings
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let response = object as? [String: Any] else {
            throw KTPAPIError.decodeFailed("Expected a meeting array or response object.")
        }

        for key in ["meetings", "data"] {
            guard let value = response[key], JSONSerialization.isValidJSONObject(value) else { continue }
            let nestedData = try JSONSerialization.data(withJSONObject: value)
            if let meetings = try? decoder.decode([Meeting].self, from: nestedData) {
                return meetings
            }
        }

        throw KTPAPIError.decodeFailed("The response did not contain a supported meeting list.")
    }
}

private extension KeyedDecodingContainer {
    func meetingDate(for key: Key) throws -> Date? {
        guard let value = try decodeIfPresent(String.self, forKey: key) else { return nil }
        return MeetingDateParser.date(from: value)
    }
}

private enum MeetingDateParser {
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
