import Foundation
import UniformTypeIdentifiers

struct PhotoItem: Identifiable, Codable {
    let id: String
    let title: String
    let imagePath: String
    let caption: String?
    let uploadedBy: String?
    let albumId: String?
    let mediaType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case imagePath
        case assetId
        case immichAssetId
        case caption
        case uploadedBy
        case albumId
        case mediaType
    }

    init(
        id: String,
        title: String,
        imagePath: String,
        caption: String?,
        uploadedBy: String?,
        albumId: String? = nil,
        mediaType: String? = nil
    ) {
        self.id = id
        self.title = title
        self.imagePath = imagePath
        self.caption = caption
        self.uploadedBy = uploadedBy
        self.albumId = albumId
        self.mediaType = mediaType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let stringId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = stringId
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }

        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Chapter Photo"
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
            ?? container.decodeIfPresent(String.self, forKey: .assetId)
            ?? container.decodeIfPresent(String.self, forKey: .immichAssetId)
            ?? ""
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        uploadedBy = try container.decodeIfPresent(String.self, forKey: .uploadedBy)
        albumId = try container.decodeIfPresent(String.self, forKey: .albumId)
        mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(imagePath, forKey: .imagePath)
        try container.encodeIfPresent(caption, forKey: .caption)
        try container.encodeIfPresent(uploadedBy, forKey: .uploadedBy)
        try container.encodeIfPresent(albumId, forKey: .albumId)
        try container.encodeIfPresent(mediaType, forKey: .mediaType)
    }

    var isVideo: Bool {
        if mediaType?.localizedCaseInsensitiveContains("video") == true {
            return true
        }

        guard !imagePath.isEmpty else { return false }
        let fileExtension = URL(fileURLWithPath: imagePath).pathExtension
        return UTType(filenameExtension: fileExtension)?.conforms(to: .movie) == true
    }
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
