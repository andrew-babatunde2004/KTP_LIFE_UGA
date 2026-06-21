import Foundation

/// Directory entry returned by `GET /members`. JSON keys match `memberModel.toDirectoryJSON` in ktp-api.
struct DirectoryMember: Identifiable, Codable {
    let id: String
    let name: String
    let role: String
    let year: String?
    let group: MemberGroup
}

#if DEBUG
extension DirectoryMember {
    static let previewSamples: [DirectoryMember] = [
        DirectoryMember(id: "1", name: "Jordan Lee", role: "Software Engineering Track", year: "2027", group: .activeMembers),
        DirectoryMember(id: "2", name: "Maya Patel", role: "Data Science Track", year: "2026", group: .activeMembers),
        DirectoryMember(id: "3", name: "Chris Nguyen", role: "New Member", year: "2028", group: .pledges),
        DirectoryMember(id: "4", name: "Sam Rivera", role: "President", year: "2026", group: .eBoard),
        DirectoryMember(id: "5", name: "Morgan Chen", role: "Software Engineer", year: "Alum", group: .alumni),
    ]
}
#endif