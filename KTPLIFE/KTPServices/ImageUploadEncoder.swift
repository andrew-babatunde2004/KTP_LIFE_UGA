import Foundation
import UIKit
import UniformTypeIdentifiers

/// Produces image data that the API can process consistently. The iOS photo
/// library commonly supplies HEIC/HEIF originals, while the API accepts JPEG
/// uploads across all of its image-processing paths.
enum ImageUploadEncoder {
    struct EncodedImage {
        let data: Data
        let fileExtension: String
        let mimeType: String
    }

    static func encodeForUpload(data: Data, contentType: UTType) throws -> EncodedImage {
        guard isHEIF(contentType) else {
            return EncodedImage(
                data: data,
                fileExtension: contentType.preferredFilenameExtension ?? "jpg",
                mimeType: contentType.preferredMIMEType ?? "image/jpeg"
            )
        }

        guard let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.92) else {
            throw ImageUploadEncodingError.couldNotConvertHEIF
        }

        return EncodedImage(data: jpegData, fileExtension: "jpg", mimeType: "image/jpeg")
    }

    private static func isHEIF(_ contentType: UTType) -> Bool {
        let identifier = contentType.identifier.lowercased()
        let fileExtension = contentType.preferredFilenameExtension?.lowercased() ?? ""
        return identifier == "public.heic"
            || identifier == "public.heif"
            || ["heic", "heif", "hif", "hief"].contains(fileExtension)
    }
}

enum ImageUploadEncodingError: LocalizedError {
    case couldNotConvertHEIF

    var errorDescription: String? {
        "Could not convert the selected HEIF photo for upload."
    }
}
