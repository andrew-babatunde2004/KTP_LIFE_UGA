import Foundation

/// The type of content referenced by the reports API.
enum ReportContentType: String, Codable {
    case user
    case message
    case groupMessage = "group_message"
    case photo
}

enum ReportStatus: String, CaseIterable, Codable, Identifiable {
    case open
    case resolved
    case dismissed

    var id: Self { self }

    var title: String { rawValue.capitalized }
}

struct SubmitReportRequest: Encodable {
    let contentType: ReportContentType
    let contentID: String?
    let reportedUserID: String?
    let reason: String
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case contentID = "content_id"
        case reportedUserID = "reported_user_id"
        case reason
        case explanation
    }
}

struct UpdateReportStatusRequest: Encodable {
    let status: ReportStatus
    let moderatorResponse: String?

    enum CodingKeys: String, CodingKey {
        case status
        case moderatorResponse = "moderator_response"
    }
}

/// A moderation record returned by `GET /reports` for eboard members.
struct ContentReport: Identifiable, Decodable {
    let id: String
    let contentType: ReportContentType
    let contentID: String?
    let reportedUserID: String?
    let reportedUserName: String?
    let reporterName: String?
    let reason: String
    let explanation: String?
    let status: ReportStatus
    let moderatorResponse: String?
    let createdAt: Date?
    let resolvedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case contentType = "content_type"
        case contentID = "content_id"
        case reportedUserID = "reported_user_id"
        case reportedUserName = "reported_user_name"
        case reportedUser = "reported_user"
        case reporterName = "reporter_name"
        case reporter
        case reason
        case explanation
        case status
        case moderatorResponse = "moderator_response"
        case createdAt = "created_at"
        case resolvedAt = "resolved_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(for: .id)
        contentType = try container.decode(ReportContentType.self, forKey: .contentType)
        contentID = try container.decodeFlexibleStringIfPresent(for: .contentID)
        reportedUserID = try container.decodeFlexibleStringIfPresent(for: .reportedUserID)
        reportedUserName = try container.decodeFlexibleStringIfPresent(for: .reportedUserName)
            ?? container.decodeReportPersonName(for: .reportedUser)
        reporterName = try container.decodeFlexibleStringIfPresent(for: .reporterName)
            ?? container.decodeReportPersonName(for: .reporter)
        reason = try container.decode(String.self, forKey: .reason)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
        status = try container.decode(ReportStatus.self, forKey: .status)
        moderatorResponse = try container.decodeIfPresent(String.self, forKey: .moderatorResponse)
        createdAt = try container.decodeReportDateIfPresent(for: .createdAt)
        resolvedAt = try container.decodeReportDateIfPresent(for: .resolvedAt)
    }
}

extension ContentReport {
    static func decodeReports(from data: Data) throws -> [ContentReport] {
        let decoder = JSONDecoder()
        if let reports = try? decoder.decode([ContentReport].self, from: data) {
            return reports
        }

        return try decoder.decode(ContentReportsResponse.self, from: data).reports
    }
}

private struct ContentReportsResponse: Decodable {
    let reports: [ContentReport]

    enum CodingKeys: String, CodingKey {
        case reports
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reports = try container.decodeIfPresent([ContentReport].self, forKey: .reports)
            ?? container.decode([ContentReport].self, forKey: .data)
    }
}

private extension KeyedDecodingContainer where Key == ContentReport.CodingKeys {
    func decodeFlexibleString(for key: Key) throws -> String {
        if let value = try decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Expected a string or integer."))
    }

    func decodeFlexibleStringIfPresent(for key: Key) throws -> String? {
        if let value = try decodeIfPresent(String.self, forKey: key), !value.isEmpty {
            return value
        }
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        return nil
    }

    func decodeReportPersonName(for key: Key) -> String? {
        guard let nested = try? decodeIfPresent(ReportPerson.self, forKey: key) else { return nil }
        return nested.displayName
    }

    func decodeReportDateIfPresent(for key: Key) throws -> Date? {
        guard let value = try decodeIfPresent(String.self, forKey: key) else { return nil }
        return ReportDateParser.date(from: value)
    }
}

private struct ReportPerson: Decodable {
    let name: String?
    let displayNameValue: String?
    let preferredName: String?
    let firstName: String?
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case name
        case displayNameValue = "display_name"
        case preferredName = "preferred_name"
        case firstName = "first_name"
        case lastName = "last_name"
    }

    var displayName: String? {
        name ?? displayNameValue ?? preferredName ?? [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private enum ReportDateParser {
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
