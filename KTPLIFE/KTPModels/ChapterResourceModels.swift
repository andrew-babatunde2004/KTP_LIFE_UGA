import Foundation

struct DocumentFolder: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let parentID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case parentID = "parent_id"
    }

    init(id: String, name: String, parentID: String? = nil) {
        self.id = id
        self.name = name
        self.parentID = parentID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.flexibleString(forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? "Untitled Folder"
        parentID = try container.flexibleString(forKey: .parentID)
    }
}

struct ChapterDocument: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let folderID: String?
    let mimeType: String?
    let byteCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case fileName = "file_name"
        case originalName = "original_name"
        case folderID = "folder_id"
        case mimeType = "mime_type"
        case contentType = "content_type"
        case byteCount = "size"
        case fileSize = "file_size"
    }

    init(id: String, name: String, folderID: String? = nil, mimeType: String? = nil, byteCount: Int? = nil) {
        self.id = id
        self.name = name
        self.folderID = folderID
        self.mimeType = mimeType
        self.byteCount = byteCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.flexibleString(forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .fileName)
            ?? container.decodeIfPresent(String.self, forKey: .originalName)
            ?? "Untitled Document"
        folderID = try container.flexibleString(forKey: .folderID)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
            ?? container.decodeIfPresent(String.self, forKey: .contentType)
        byteCount = try container.flexibleInt(forKey: .byteCount)
            ?? container.flexibleInt(forKey: .fileSize)
    }
}

struct Committee: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let role: String?
    let isMember: Bool
    let memberCount: Int?
    let groupChatID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case role
        case membershipRole = "membership_role"
        case isMember = "is_member"
        case joined
        case membership
        case memberCount = "member_count"
        case membersCount = "members_count"
        case groupChatID = "group_chat_id"
        case chatID = "chat_id"
    }

    private struct Membership: Decodable {
        let role: String?
    }

    init(
        id: String,
        name: String,
        role: String? = nil,
        isMember: Bool = false,
        memberCount: Int? = nil,
        groupChatID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.isMember = isMember
        self.memberCount = memberCount
        self.groupChatID = groupChatID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.flexibleString(forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? "Committee"

        let membership = try container.decodeIfPresent(Membership.self, forKey: .membership)
        let resolvedRole = try container.decodeIfPresent(String.self, forKey: .role)
            ?? container.decodeIfPresent(String.self, forKey: .membershipRole)
            ?? membership?.role
        role = resolvedRole
        isMember = try container.decodeIfPresent(Bool.self, forKey: .isMember)
            ?? container.decodeIfPresent(Bool.self, forKey: .joined)
            ?? (membership != nil || resolvedRole != nil)
        memberCount = try container.flexibleInt(forKey: .memberCount)
            ?? container.flexibleInt(forKey: .membersCount)
        groupChatID = try container.flexibleString(forKey: .groupChatID)
            ?? container.flexibleString(forKey: .chatID)
    }
}

struct CommitteeMember: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case displayName = "display_name"
        case preferredName = "preferred_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case role
    }

    init(id: String, name: String, role: String) {
        self.id = id
        self.name = name
        self.role = role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.flexibleString(forKey: .id)
            ?? container.flexibleString(forKey: .userID)
            ?? UUID().uuidString

        let firstName = try container.decodeIfPresent(String.self, forKey: .preferredName)
            ?? container.decodeIfPresent(String.self, forKey: .firstName)
        let lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        let composedName = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? (composedName.isEmpty ? "Member" : composedName)
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "member"
    }
}

enum ChapterResourceResponse {
    static func decodeFolders(from data: Data) throws -> [DocumentFolder] {
        try decodeArray(from: data, keys: ["folders", "data"])
    }

    static func decodeDocuments(from data: Data) throws -> [ChapterDocument] {
        try decodeArray(from: data, keys: ["documents", "files", "data"])
    }

    static func decodeCommittees(from data: Data) throws -> [Committee] {
        try decodeArray(from: data, keys: ["committees", "data"])
    }

    static func decodeCommitteeMembers(from data: Data) throws -> [CommitteeMember] {
        try decodeArray(from: data, keys: ["members", "data"])
    }

    private static func decodeArray<Item: Decodable>(from data: Data, keys: [String]) throws -> [Item] {
        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([Item].self, from: data) {
            return direct
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw KTPAPIError.decodeFailed("Expected an array or keyed response object.")
        }

        for key in keys {
            guard let value = dictionary[key], JSONSerialization.isValidJSONObject(value) else { continue }
            let nestedData = try JSONSerialization.data(withJSONObject: value)
            if let decoded = try? decoder.decode([Item].self, from: nestedData) {
                return decoded
            }
        }

        throw KTPAPIError.decodeFailed("The response did not contain a supported list key.")
    }
}

struct DocumentPreviewPayload {
    let data: Data
    let suggestedFilename: String
}

private extension KeyedDecodingContainer {
    func flexibleString(forKey key: Key) throws -> String? {
        if let value = try decodeIfPresent(String.self, forKey: key), !value.isEmpty {
            return value
        }
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        return nil
    }

    func flexibleInt(forKey key: Key) throws -> Int? {
        if let value = try decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }
}

#if DEBUG
extension DocumentFolder {
    static let previewSamples = [
        DocumentFolder(id: "1", name: "Chapter Resources"),
        DocumentFolder(id: "2", name: "Recruitment")
    ]
}

extension ChapterDocument {
    static let previewSamples = [
        ChapterDocument(id: "1", name: "Chapter Bylaws.pdf", mimeType: "application/pdf", byteCount: 184_320),
        ChapterDocument(id: "2", name: "Fall Recruitment.pptx", mimeType: "application/vnd.openxmlformats-officedocument.presentationml.presentation")
    ]
}

extension Committee {
    static let previewSamples = [
        Committee(id: "1", name: "Professional Development", role: "member", isMember: true, memberCount: 12),
        Committee(id: "2", name: "Social", isMember: false, memberCount: 9)
    ]
}

extension CommitteeMember {
    static let previewSamples = [
        CommitteeMember(id: "1", name: "Jordan Lee", role: "chair"),
        CommitteeMember(id: "2", name: "Maya Patel", role: "member")
    ]
}
#endif
