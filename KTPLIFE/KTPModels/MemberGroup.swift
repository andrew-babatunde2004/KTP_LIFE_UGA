import Foundation

/// Member directory segment. Raw values match the API `group` field and Postgres `member_group` column.
enum MemberGroup: String, Codable, Identifiable, CaseIterable {
    case active
    case pledge
    case eboard
    case chair
    case alumni

    var id: Self { self }

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
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue.lowercased() {
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
        default:
            self = .active
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
