import Foundation

struct PhotoItem: Identifiable, Codable {
    let id: String
    let title: String
    let imagePath: String
    let caption: String?
    let uploadedBy: String?
}

#if DEBUG
extension PhotoItem {
    static let previewSamples: [PhotoItem] = [
        PhotoItem(
            id: "1",
            title: "Chapter Social",
            imagePath: "uploads/seed-preview-1.jpg",
            caption: "Sample chapter photo",
            uploadedBy: nil
        ),
        PhotoItem(
            id: "2",
            title: "Professional Development",
            imagePath: "uploads/seed-preview-2.jpg",
            caption: "Sample chapter photo",
            uploadedBy: nil
        ),
        PhotoItem(
            id: "3",
            title: "Group Photo",
            imagePath: "uploads/seed-preview-3.jpg",
            caption: "Sample chapter photo",
            uploadedBy: nil
        ),
    ]
}
#endif
