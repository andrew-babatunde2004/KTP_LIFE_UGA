import Foundation
import UniformTypeIdentifiers

struct PhotoAlbum: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let description: String?
    let createdBy: String?
    let audience: [String]
    let committeeIDs: [String]
    let photoCount: Int
    let coverPhotoIDs: [String]

    /// The server stores this shared destination as photos whose album_id is NULL.
    static let general = PhotoAlbum(
        id: "general",
        name: "Shared Album",
        description: nil,
        createdBy: nil,
        audience: [],
        committeeIDs: [],
        photoCount: 0,
        coverPhotoIDs: []
    )

    var apiAlbumID: String? { id == Self.general.id ? nil : id }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdBy = "created_by"
        case audience
        case committeeIDs = "committee_ids"
        case photoCount = "photo_count"
        case coverPhotoIDs = "cover_photo_ids"
    }

    init(
        id: String,
        name: String,
        description: String?,
        createdBy: String?,
        audience: [String],
        committeeIDs: [String],
        photoCount: Int,
        coverPhotoIDs: [String]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdBy = createdBy
        self.audience = audience
        self.committeeIDs = committeeIDs
        self.photoCount = photoCount
        self.coverPhotoIDs = coverPhotoIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? container.decode(String.self, forKey: .id) {
            id = stringID
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        audience = try container.decodeIfPresent([String].self, forKey: .audience) ?? []
        committeeIDs = try container.decodeFlexibleStringArrayIfPresent(forKey: .committeeIDs)
        photoCount = try container.decodeFlexibleIntIfPresent(forKey: .photoCount) ?? 0
        coverPhotoIDs = try container.decodeFlexibleStringArrayIfPresent(forKey: .coverPhotoIDs)
    }
}

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

    /// The API has returned both a bare array and `{ "photos": [...] }` while
    /// its clients were being rolled out. Keep gallery reads tolerant of either
    /// shape so a successful upload can always be followed by a refresh.
    static func decodePhotos(from data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> [PhotoItem] {
        if let photos = try? decoder.decode([PhotoItem].self, from: data) {
            return photos
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let response = object as? [String: Any] else {
            throw KTPAPIError.decodeFailed("Expected a photo array or response object.")
        }

        for key in ["photos", "data"] {
            guard let value = response[key], JSONSerialization.isValidJSONObject(value) else { continue }
            let nestedData = try JSONSerialization.data(withJSONObject: value)
            if let photos = try? decoder.decode([PhotoItem].self, from: nestedData) {
                return photos
            }
        }

        throw KTPAPIError.decodeFailed("The response did not contain a supported photo list.")
    }

    /// A photo upload is successful once the server accepts the multipart body.
    /// Some API versions return the created photo while others return an empty
    /// response or an acknowledgement envelope, so decoding is intentionally
    /// best-effort rather than a reason to report the upload as failed.
    static func decodeUploadedPhoto(from data: Data, decoder: JSONDecoder = JSONDecoder()) -> PhotoItem? {
        guard !data.isEmpty else { return nil }
        if let photo = try? decoder.decode(PhotoItem.self, from: data) {
            return photo
        }

        guard let object = try? JSONSerialization.jsonObject(with: data),
              let response = object as? [String: Any]
        else {
            return nil
        }

        for key in ["photo", "data"] {
            guard let value = response[key], JSONSerialization.isValidJSONObject(value),
                  let nestedData = try? JSONSerialization.data(withJSONObject: value),
                  let photo = try? decoder.decode(PhotoItem.self, from: nestedData)
            else {
                continue
            }
            return photo
        }

        return nil
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

private extension KeyedDecodingContainer where Key == PhotoAlbum.CodingKeys {
    func decodeFlexibleStringArrayIfPresent(forKey key: Key) throws -> [String] {
        if let strings = try decodeIfPresent([String].self, forKey: key) {
            return strings
        }
        if let integers = try decodeIfPresent([Int].self, forKey: key) {
            return integers.map(String.init)
        }
        return []
    }

    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let integer = try decodeIfPresent(Int.self, forKey: key) {
            return integer
        }
        if let string = try decodeIfPresent(String.self, forKey: key) {
            return Int(string)
        }
        return nil
    }
}
