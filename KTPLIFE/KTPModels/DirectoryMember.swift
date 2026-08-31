import Foundation

/// Directory entry returned by `GET /members`. JSON keys match `memberModel.toDirectoryJSON` in ktp-api.
struct DirectoryMember: Identifiable, Codable, Hashable {
    let id: String
    /// Stable user identity used by message senders and profile-picture routes.
    /// Some directory responses also include a legacy numeric `id`.
    let authentikID: String?
    let name: String
    let username: String?
    let firstName: String?
    let lastName: String?
    let preferredName: String?
    let email: String?
    let personalEmail: String?
    let phone: String?
    let dateOfBirth: String?
    let linkedinURL: String?
    let major: String?
    let graduationDate: String?
    let pledgeClass: String?
    let aboutMe: String?
    let executiveTitle: String?
    let chairedCommittees: [String]
    let profilePictureAssetID: String?
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
        case personalEmail = "personal_email"
        case phone
        case dob
        case linkedin
        case linkedinURL = "linkedin_url"
        case camelLinkedinURL = "linkedinUrl"
        case linkedIn = "linkedIn"
        case camelLinkedInURL = "linkedInUrl"
        case role
        case title
        case major
        case pledgeClass = "pledge_class"
        case aboutMe = "about_me"
        case executiveTitle = "exec_title"
        case chairedCommittees
        case snakeChairedCommittees = "chaired_committees"
        case profilePictureAssetID = "profile_picture_asset_id"
        case memberGroup = "member_group"
        case year
        case graduationYear = "graduation_year"
        case graduationDate = "graduation_date"
        case classYear = "class_year"
        case group
        case status
    }

    init(
        id: String,
        authentikID: String? = nil,
        name: String,
        username: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        preferredName: String? = nil,
        email: String? = nil,
        personalEmail: String? = nil,
        phone: String? = nil,
        dateOfBirth: String? = nil,
        linkedinURL: String? = nil,
        major: String? = nil,
        graduationDate: String? = nil,
        pledgeClass: String? = nil,
        aboutMe: String? = nil,
        executiveTitle: String? = nil,
        chairedCommittees: [String] = [],
        profilePictureAssetID: String? = nil,
        role: String,
        year: String?,
        group: MemberGroup
    ) {
        self.id = id
        self.authentikID = authentikID
        self.name = name
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.preferredName = preferredName
        self.email = email
        self.personalEmail = personalEmail
        self.phone = phone
        self.dateOfBirth = dateOfBirth
        self.linkedinURL = linkedinURL
        self.major = major
        self.graduationDate = graduationDate ?? year
        self.pledgeClass = pledgeClass
        self.aboutMe = aboutMe
        self.executiveTitle = executiveTitle
        self.chairedCommittees = chairedCommittees
        self.profilePictureAssetID = profilePictureAssetID
        self.role = role
        self.year = year
        self.group = group
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedAuthentikID = try container.decodeFirstPresentStringIfPresent(for: [.authentikId])
        let decodedID = try container.decodeFirstPresentStringIfPresent(for: [.id])
        authentikID = decodedAuthentikID
        id = decodedAuthentikID ?? decodedID ?? UUID().uuidString

        username = try container.decodeFirstPresentStringIfPresent(for: [.username])
        firstName = try container.decodeFirstPresentStringIfPresent(for: [.firstName])
        lastName = try container.decodeFirstPresentStringIfPresent(for: [.lastName])
        preferredName = try container.decodeFirstPresentStringIfPresent(for: [.preferredName])

        if let directName = try container.decodeFirstPresentStringIfPresent(for: [.name, .displayName, .fullName]) {
            name = directName
        } else {
            let composedName = [preferredName ?? firstName, lastName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            name = composedName.isEmpty
                ? username ?? "Unnamed Member"
                : composedName
        }

        email = try container.decodeFirstPresentStringIfPresent(for: [.email, .emailAddress, .personalEmail])
        personalEmail = try container.decodeFirstPresentStringIfPresent(for: [.personalEmail])
        phone = try container.decodeFirstPresentStringIfPresent(for: [.phone])
        dateOfBirth = try container.decodeFirstPresentStringIfPresent(for: [.dob])
        linkedinURL = try container.decodeFirstPresentStringIfPresent(
            for: [.linkedinURL, .camelLinkedinURL, .camelLinkedInURL, .linkedin, .linkedIn]
        )
        major = try container.decodeFirstPresentStringIfPresent(for: [.major])
        graduationDate = try container.decodeFirstPresentStringIfPresent(for: [.graduationDate, .graduationYear, .classYear, .year])
        year = graduationDate
        pledgeClass = try container.decodeFirstPresentStringIfPresent(for: [.pledgeClass])
        aboutMe = try container.decodeFirstPresentStringIfPresent(for: [.aboutMe])
        executiveTitle = try container.decodeFirstPresentStringIfPresent(for: [.executiveTitle])
        chairedCommittees = try container.decodeIfPresent([String].self, forKey: .chairedCommittees)
            ?? container.decodeIfPresent([String].self, forKey: .snakeChairedCommittees)
            ?? []
        profilePictureAssetID = try container.decodeFirstPresentStringIfPresent(for: [.profilePictureAssetID])

        if let groupValue = try container.decodeIfPresent(MemberGroup.self, forKey: .group) {
            group = groupValue
        } else if let memberGroupValue = try container.decodeIfPresent(MemberGroup.self, forKey: .memberGroup) {
            group = memberGroupValue
        } else if let statusValue = try container.decodeIfPresent(MemberGroup.self, forKey: .status) {
            group = statusValue
        } else {
            group = .active
        }

        let decodedRole = try container.decodeFirstPresentStringIfPresent(for: [.role, .title])
        role = executiveTitle ?? decodedRole ?? group.memberRoleTitle
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(authentikID, forKey: .authentikId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(firstName, forKey: .firstName)
        try container.encodeIfPresent(lastName, forKey: .lastName)
        try container.encodeIfPresent(preferredName, forKey: .preferredName)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(personalEmail, forKey: .personalEmail)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(dateOfBirth, forKey: .dob)
        try container.encodeIfPresent(linkedinURL, forKey: .linkedinURL)
        try container.encodeIfPresent(major, forKey: .major)
        try container.encodeIfPresent(graduationDate, forKey: .graduationDate)
        try container.encodeIfPresent(pledgeClass, forKey: .pledgeClass)
        try container.encodeIfPresent(aboutMe, forKey: .aboutMe)
        try container.encodeIfPresent(executiveTitle, forKey: .executiveTitle)
        try container.encode(chairedCommittees, forKey: .chairedCommittees)
        try container.encodeIfPresent(profilePictureAssetID, forKey: .profilePictureAssetID)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encode(group, forKey: .group)
    }
}

private extension MemberGroup {
    var memberRoleTitle: String {
        switch self {
        case .active: "Active Member"
        case .pledge: "Pledge"
        case .eboard: "Executive Board"
        case .chair: "Committee Chair"
        case .alumni: "Alumni"
        case .rush: "Rushee"
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
