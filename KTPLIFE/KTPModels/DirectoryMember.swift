import Foundation

struct DirectoryMember: Identifiable, Codable {
    let id: String
    let name: String
    let role: String
    let year: String?
    let group: MemberGroup
   // let profilePictureURL: URL?
    
}