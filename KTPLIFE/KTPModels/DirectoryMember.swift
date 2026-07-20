import Foundation

/// Directory entry returned by `GET /members`. JSON keys match `memberModel.toDirectoryJSON` in ktp-api.
struct DirectoryMember: Identifiable, Codable {
    let id: String
    let name: String
    let email: String?
    let role: String
    let year: String?
    let group: MemberGroup

    enum CodingKeys: String, CodingKey {
        case id
        case authentikId = "authentik_id"
        case name
        case displayName = "display_name"
        case fullName = "full_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case preferredName = "preferred_name"
        case username
        case email
        case emailAddress = "email_address"
        case role
        case title
        case major
        case memberGroup = "member_group"
        case year
        case graduationYear = "graduation_year"
        case graduationDate = "graduation_date"
        case classYear = "class_year"
        case group
        case status
    }

    init(id: String, name: String, email: String? = nil, role: String, year: String?, group: MemberGroup) {
        self.id = id
        self.name = name
        self.email = email
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

        if let directName = try container.decodeFirstPresentStringIfPresent(for: [.name, .displayName, .fullName, .preferredName]) {
            name = directName
        } else {
            let firstName = try container.decodeFirstPresentStringIfPresent(for: [.firstName])
            let lastName = try container.decodeFirstPresentStringIfPresent(for: [.lastName])
            let composedName = [firstName, lastName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            name = composedName.isEmpty
                ? try container.decodeFirstPresentString(for: [.username], fallback: "Unnamed Member")
                : composedName
        }

        email = try container.decodeFirstPresentStringIfPresent(for: [.email, .emailAddress])

        role = try container.decodeFirstPresentString(
            for: [.role, .title, .major, .memberGroup],
            fallback: "Member"
        )

        year = try container.decodeFirstPresentStringIfPresent(for: [.year, .graduationYear, .classYear, .graduationDate])

        if let groupValue = try container.decodeIfPresent(MemberGroup.self, forKey: .group) {
            group = groupValue
        } else if let memberGroupValue = try container.decodeIfPresent(MemberGroup.self, forKey: .memberGroup) {
            group = memberGroupValue
        } else if let statusValue = try container.decodeIfPresent(MemberGroup.self, forKey: .status) {
            group = statusValue
        } else {
            group = .active
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encode(group, forKey: .group)
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
