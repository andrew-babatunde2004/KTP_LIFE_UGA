import Foundation

/// Directory entry returned by `GET /members`. JSON keys match `memberModel.toDirectoryJSON` in ktp-api.
struct DirectoryMember: Identifiable, Codable {
    let id: String
    let name: String
    let role: String
    let year: String?
    let group: MemberGroup

    enum CodingKeys: String, CodingKey {
        case id
        case authentikId = "authentik_id"
        case name
        case displayName = "display_name"
        case fullName = "full_name"
        case username
        case role
        case title
        case major
        case memberGroup = "member_group"
        case year
        case graduationYear = "graduation_year"
        case classYear = "class_year"
        case group
        case status
    }

    init(id: String, name: String, role: String, year: String?, group: MemberGroup) {
        self.id = id
        self.name = name
        self.role = role
        self.year = year
        self.group = group
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let stringId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try container.decodeIfPresent(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try container.decode(String.self, forKey: .authentikId)
        }

        name = try container.decodeFirstPresentString(
            for: [.name, .displayName, .fullName, .username],
            fallback: "Unnamed Member"
        )

        role = try container.decodeFirstPresentString(
            for: [.role, .title, .major, .memberGroup],
            fallback: "Member"
        )

        year = try container.decodeFirstPresentStringIfPresent(for: [.year, .graduationYear, .classYear])

        if let groupValue = try container.decodeIfPresent(MemberGroup.self, forKey: .group) {
            group = groupValue
        } else if let memberGroupValue = try container.decodeIfPresent(MemberGroup.self, forKey: .memberGroup) {
            group = memberGroupValue
        } else {
            group = try container.decode(MemberGroup.self, forKey: .status)
        }
    }
}

#if DEBUG
extension DirectoryMember {
    static let previewSamples: [DirectoryMember] = [
        DirectoryMember(id: "1", name: "Jordan Lee", role: "Software Engineering Track", year: "2027", group: .active),
        DirectoryMember(id: "2", name: "Maya Patel", role: "Data Science Track", year: "2026", group: .active),
        DirectoryMember(id: "3", name: "Chris Nguyen", role: "New Member", year: "2028", group: .pledge),
        DirectoryMember(id: "4", name: "Sam Rivera", role: "President", year: "2026", group: .eboard),
        DirectoryMember(id: "5", name: "Morgan Chen", role: "Software Engineer", year: "Alum", group: .alumni),
    ]
}
#endif

private extension KeyedDecodingContainer {
    func decodeFirstPresentString(for keys: [Key], fallback: String) throws -> String {
        try decodeFirstPresentStringIfPresent(for: keys) ?? fallback
    }

    func decodeFirstPresentStringIfPresent(for keys: [Key]) throws -> String? {
        for key in keys {
            if let stringValue = try decodeIfPresent(String.self, forKey: key), !stringValue.isEmpty {
                return stringValue
            }

            if let intValue = try decodeIfPresent(Int.self, forKey: key) {
                return String(intValue)
            }
        }

        return nil
    }
}
