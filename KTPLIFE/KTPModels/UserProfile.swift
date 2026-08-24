import Foundation

/// Editable profile returned by `GET /users/me`.
struct UserProfile: Identifiable, Decodable, Equatable {
    let id: String
    let preferredName: String?
    let firstName: String?
    let lastName: String?
    let username: String?
    let email: String?
    let personalEmail: String?
    let phone: String?
    let dateOfBirth: String?
    let major: String?
    let graduationYear: String?
    let linkedinURL: String?
    let pledgeClass: String?
    let aboutMe: String?
    let profilePictureAssetID: String?
    let calendarFeedToken: String?
    let memberGroup: String?

    var graduationDate: String? { graduationYear }

    var displayName: String {
        if let preferredName = preferredName?.nonEmptyTrimmed {
            return preferredName
        }

        let fullName = [firstName, lastName]
            .compactMap { $0?.nonEmptyTrimmed }
            .joined(separator: " ")
        return fullName.isEmpty ? "KTP Member" : fullName
    }

    enum CodingKeys: String, CodingKey {
        case id
        case authentikId = "authentik_id"
        case preferredName = "preferred_name"
        case camelPreferredName = "preferredName"
        case firstName = "first_name"
        case camelFirstName = "firstName"
        case lastName = "last_name"
        case camelLastName = "lastName"
        case username
        case email
        case personalEmail = "personal_email"
        case camelPersonalEmail = "personalEmail"
        case phone
        case dateOfBirth = "dob"
        case major
        case graduationDate = "graduation_date"
        case graduationYear = "graduation_year"
        case camelGraduationYear = "graduationYear"
        case year
        case linkedinURL = "linkedin_url"
        case camelLinkedinURL = "linkedinUrl"
        case pledgeClass = "pledge_class"
        case camelPledgeClass = "pledgeClass"
        case aboutMe = "about_me"
        case camelAboutMe = "aboutMe"
        case profilePictureAssetID = "profile_picture_asset_id"
        case camelProfilePictureAssetID = "profilePictureAssetId"
        case calendarFeedToken = "calendar_feed_token"
        case camelCalendarFeedToken = "calendarFeedToken"
        case memberGroup = "member_group"
        case camelMemberGroup = "memberGroup"
        case group
    }

    init(
        id: String,
        preferredName: String?,
        firstName: String?,
        lastName: String?,
        username: String? = nil,
        email: String?,
        personalEmail: String? = nil,
        phone: String? = nil,
        dateOfBirth: String? = nil,
        major: String?,
        graduationYear: String?,
        linkedinURL: String? = nil,
        pledgeClass: String? = nil,
        aboutMe: String? = nil,
        profilePictureAssetID: String? = nil,
        calendarFeedToken: String? = nil,
        memberGroup: String?
    ) {
        self.id = id
        self.preferredName = preferredName
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.email = email
        self.personalEmail = personalEmail
        self.phone = phone
        self.dateOfBirth = dateOfBirth
        self.major = major
        self.graduationYear = graduationYear
        self.linkedinURL = linkedinURL
        self.pledgeClass = pledgeClass
        self.aboutMe = aboutMe
        self.profilePictureAssetID = profilePictureAssetID
        self.calendarFeedToken = calendarFeedToken
        self.memberGroup = memberGroup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedID = try container.decodeFlexibleStringIfPresent(forKeys: [.id, .authentikId])
        let decodedPreferredName = try container.decodeFlexibleStringIfPresent(forKeys: [.preferredName, .camelPreferredName])
        let decodedFirstName = try container.decodeFlexibleStringIfPresent(forKeys: [.firstName, .camelFirstName])
        let decodedLastName = try container.decodeFlexibleStringIfPresent(forKeys: [.lastName, .camelLastName])
        let decodedEmail = try container.decodeFlexibleStringIfPresent(forKeys: [.email])

        guard decodedID != nil || decodedPreferredName != nil || decodedFirstName != nil || decodedEmail != nil else {
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: container,
                debugDescription: "Expected a user profile object."
            )
        }

        id = decodedID ?? "me"
        preferredName = decodedPreferredName
        firstName = decodedFirstName
        lastName = decodedLastName
        username = try container.decodeFlexibleStringIfPresent(forKeys: [.username])
        email = decodedEmail
        personalEmail = try container.decodeFlexibleStringIfPresent(forKeys: [.personalEmail, .camelPersonalEmail])
        phone = try container.decodeFlexibleStringIfPresent(forKeys: [.phone])
        dateOfBirth = try container.decodeFlexibleStringIfPresent(forKeys: [.dateOfBirth])
        major = try container.decodeFlexibleStringIfPresent(forKeys: [.major])
        graduationYear = try container.decodeFlexibleStringIfPresent(
            forKeys: [.graduationDate, .graduationYear, .camelGraduationYear, .year]
        )
        linkedinURL = try container.decodeFlexibleStringIfPresent(forKeys: [.linkedinURL, .camelLinkedinURL])
        pledgeClass = try container.decodeFlexibleStringIfPresent(forKeys: [.pledgeClass, .camelPledgeClass])
        aboutMe = try container.decodeFlexibleStringIfPresent(forKeys: [.aboutMe, .camelAboutMe])
        profilePictureAssetID = try container.decodeFlexibleStringIfPresent(
            forKeys: [.profilePictureAssetID, .camelProfilePictureAssetID]
        )
        calendarFeedToken = try container.decodeFlexibleStringIfPresent(
            forKeys: [.calendarFeedToken, .camelCalendarFeedToken]
        )
        memberGroup = try container.decodeFlexibleStringIfPresent(
            forKeys: [.memberGroup, .camelMemberGroup, .group]
        )
    }
}

struct UpdateUserProfileRequest: Encodable {
    let preferredName: String?
    let firstName: String?
    let lastName: String?
    let dateOfBirth: String?
    let major: String?
    let graduationDate: String?
    let phone: String?
    let email: String?
    let personalEmail: String?
    let linkedinURL: String?
    let pledgeClass: String?
    let aboutMe: String?

    enum CodingKeys: String, CodingKey {
        case preferredName = "preferred_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case dateOfBirth = "dob"
        case major
        case graduationDate = "graduation_date"
        case phone
        case email
        case personalEmail = "personal_email"
        case linkedinURL = "linkedin_url"
        case pledgeClass = "pledge_class"
        case aboutMe = "about_me"
    }
}

extension UserProfile {
    static func decodeResponse(from data: Data) throws -> UserProfile {
        let decoder = JSONDecoder()
        if let directProfile = try? decoder.decode(UserProfile.self, from: data) {
            return directProfile
        }

        return try decoder.decode(UserProfileEnvelope.self, from: data).profile
    }
}

private struct UserProfileEnvelope: Decodable {
    let profile: UserProfile

    enum CodingKeys: String, CodingKey {
        case profile
        case user
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let profile = try container.decodeIfPresent(UserProfile.self, forKey: .profile) {
            self.profile = profile
        } else if let user = try container.decodeIfPresent(UserProfile.self, forKey: .user) {
            profile = user
        } else {
            profile = try container.decode(UserProfile.self, forKey: .data)
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKeys keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key)?.nonEmptyTrimmed {
                return value
            }

            if let value = try decodeIfPresent(Int.self, forKey: key) {
                return String(value)
            }
        }

        return nil
    }
}

extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#if DEBUG
extension UserProfile {
    static let preview = UserProfile(
        id: "preview-user",
        preferredName: "Andrew",
        firstName: "Andrew",
        lastName: "Member",
        email: "andrew@uga.edu",
        major: "Computer Science",
        graduationYear: "2027",
        memberGroup: "active"
    )
}
#endif
