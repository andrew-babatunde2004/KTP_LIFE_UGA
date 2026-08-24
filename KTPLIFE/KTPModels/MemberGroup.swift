import Foundation

/// Member directory segment. Raw values match the API `group` field and Postgres `member_group` column.
enum MemberGroup: String, Codable, Identifiable, CaseIterable {
    case active
    case pledge
    case eboard
    case chair
    case alumni
    case rush

    var id: Self { self }

    /// Only pledge and rush users have a reduced in-app navigation set. All
    /// other groups deliberately retain the existing member experience.
    /// Rushees may initiate conversations only with chapter leadership. `nil`
    /// means the group retains the full member directory.
    var directoryContactGroups: [MemberGroup]? {
        self == .rush ? [.eboard] : nil
    }

    var canAccessFilesAndPhotos: Bool {
        // Keep the client navigation aligned with the API's
        // SHARED_ALBUM_GROUPS. Pledges are chapter members and may use the
        // shared albums; only rush accounts are intentionally excluded.
        self != .rush
    }

    var canAccessCommittees: Bool {
        self != .rush
    }

    var canAccessMeetings: Bool {
        self != .rush
    }

    var canAccessAttendance: Bool {
        self != .rush
    }

    var title: String {
        switch self {
        case .active:
            return "Active"
        case .pledge:
            return "Pledges"
        case .eboard:
            return "E-Board"
        case .chair:
            return "Chairs"
        case .alumni:
            return "Alumni"
        case .rush:
            return "Rushees"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        self = Self(groupValue: rawValue)
    }

    init?(groupValue: String?) {
        guard let groupValue else { return nil }
        self = Self(groupValue: groupValue)
    }

    private init(groupValue rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "active", "activemember", "active_member", "active-members", "activemembers":
            self = .active
        case "pledge", "pledges", "new_member", "newmember":
            self = .pledge
        case "eboard", "e_board", "e-board", "exec", "executive":
            self = .eboard
        case "chair", "chairs":
            self = .chair
        case "alumni", "alum", "alumnus":
            self = .alumni
        case "rush", "rushee", "rushees":
            self = .rush
        default:
            self = .active
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
