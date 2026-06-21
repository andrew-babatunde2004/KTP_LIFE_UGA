import Foundation

/// Member directory segment. Raw values match the API `group` field and Postgres `member_group` column.
enum MemberGroup: String, Codable, Identifiable, CaseIterable {
    case activeMembers
    case pledges
    case eBoard
    case alumni

    var id: Self { self }

    var title: String {
        switch self {
        case .activeMembers:
            return "Active"
        case .pledges:
            return "Pledges"
        case .eBoard:
            return "E-Board"
        case .alumni:
            return "Alumni"
        }
    }
}