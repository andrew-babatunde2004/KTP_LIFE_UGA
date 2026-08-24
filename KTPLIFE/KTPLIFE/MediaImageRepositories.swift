//
//  MediaImageRepositories.swift
//  KTPLIFE
//

import Combine
import CryptoKit
import ImageIO
import UIKit

/// A main-actor cache coordinator that shares image requests across SwiftUI rows.
@MainActor
class BoundedImageRepository {
    private let imageCache = NSCache<NSString, UIImage>()
    private let failedRequestLimit: Int
    private let diskCacheDirectory: URL?
    private let diskCacheFileLimit: Int
    private var failedRequestKeys = Set<String>()
    private var failedRequestOrder: [String] = []
    private var inFlightRequests: [String: Task<UIImage?, Never>] = [:]
    private var requestSubscribers: [String: Set<UUID>] = [:]

    init(
        cacheLimit: Int,
        failedRequestLimit: Int,
        diskCacheDirectoryName: String? = nil,
        diskCacheFileLimit: Int = 0
    ) {
        imageCache.countLimit = cacheLimit
        self.failedRequestLimit = failedRequestLimit
        self.diskCacheFileLimit = diskCacheFileLimit

        if let diskCacheDirectoryName,
           let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let directory = cachesDirectory.appendingPathComponent(diskCacheDirectoryName, isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            diskCacheDirectory = directory
        } else {
            diskCacheDirectory = nil
        }
    }

    func image(
        for sourceID: String,
        pointSize: CGFloat,
        displayScale: CGFloat,
        loadData: @escaping () async throws -> Data
    ) async -> UIImage? {
        let pixelSize = max(1, Int((pointSize * displayScale).rounded(.up)))
        let cacheKey = "\(sourceID)-\(pixelSize)px"

        if let cachedImage = imageCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }

        if let diskCacheURL = diskCacheURL(for: cacheKey),
           let diskImage = await DiskImageCache.image(at: diskCacheURL) {
            imageCache.setObject(diskImage, forKey: cacheKey as NSString)
            return diskImage
        }

        // Failed images are remembered so recycled tiles do not retry on every scroll pass.
        guard !failedRequestKeys.contains(cacheKey) else { return nil }

        let request: Task<UIImage?, Never>
        if let existingRequest = inFlightRequests[cacheKey] {
            request = existingRequest
        } else {
            request = Task<UIImage?, Never> {
                do {
                    let data = try await loadData()
                    return await ImageDownsampler.thumbnail(from: data, maxPixelSize: pixelSize)
                } catch {
                    return nil
                }
            }
            inFlightRequests[cacheKey] = request
        }

        let subscriberID = UUID()
        requestSubscribers[cacheKey, default: []].insert(subscriberID)
        let image = await withTaskCancellationHandler(operation: {
            let image = await request.value
            releaseSubscriber(subscriberID, for: cacheKey, cancelWhenUnused: false)
            return image
        }, onCancel: {
            Task { @MainActor in
                self.releaseSubscriber(subscriberID, for: cacheKey, cancelWhenUnused: true)
            }
        })

        guard !Task.isCancelled else { return nil }
        inFlightRequests[cacheKey] = nil

        if let image {
            imageCache.setObject(image, forKey: cacheKey as NSString)
            if let diskCacheURL = diskCacheURL(for: cacheKey) {
                DiskImageCache.store(image, at: diskCacheURL, trimming: diskCacheDirectory, to: diskCacheFileLimit)
            }
        } else {
            rememberFailedRequest(cacheKey)
        }

        return image
    }

    private func releaseSubscriber(_ subscriberID: UUID, for cacheKey: String, cancelWhenUnused: Bool) {
        guard var subscribers = requestSubscribers[cacheKey], subscribers.remove(subscriberID) != nil else {
            return
        }

        if subscribers.isEmpty {
            requestSubscribers[cacheKey] = nil
            if cancelWhenUnused {
                inFlightRequests[cacheKey]?.cancel()
                inFlightRequests[cacheKey] = nil
            }
        } else {
            requestSubscribers[cacheKey] = subscribers
        }
    }

    private func rememberFailedRequest(_ key: String) {
        guard failedRequestKeys.insert(key).inserted else { return }
        failedRequestOrder.append(key)

        while failedRequestOrder.count > failedRequestLimit {
            let expiredKey = failedRequestOrder.removeFirst()
            failedRequestKeys.remove(expiredKey)
        }
    }

    /// Removes protected thumbnails when a user signs out or changes accounts.
    func clear() {
        imageCache.removeAllObjects()
        failedRequestKeys.removeAll()
        failedRequestOrder.removeAll()
        inFlightRequests.values.forEach { $0.cancel() }
        inFlightRequests.removeAll()
        requestSubscribers.removeAll()

        guard let diskCacheDirectory else { return }
        Task.detached(priority: .utility) {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: diskCacheDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private func diskCacheURL(for cacheKey: String) -> URL? {
        guard let diskCacheDirectory else { return nil }
        let digest = SHA256.hash(data: Data(cacheKey.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return diskCacheDirectory.appendingPathComponent(digest).appendingPathExtension("jpg")
    }
}

/// Shared avatar cache for directory cards, inbox rows, message bubbles, and member sheets.
@MainActor
final class AvatarRepository: BoundedImageRepository, ObservableObject {
    init() {
        super.init(
            cacheLimit: 240,
            failedRequestLimit: 120,
            diskCacheDirectoryName: "KTPAvatarThumbnails",
            diskCacheFileLimit: 240
        )
    }
}

/// Shared thumbnail cache for visible gallery tiles. Full-size renderables remain viewer-only.
@MainActor
final class GalleryThumbnailRepository: BoundedImageRepository, ObservableObject {
    init() {
        super.init(cacheLimit: 160, failedRequestLimit: 80)
    }
}

/// Shared, downsampled cache for image attachments in message timelines.
/// Attachment responses can be substantially larger than their rendered bubble,
/// so they must never be decoded at full size while a row is being laid out.
@MainActor
final class MessageAttachmentThumbnailRepository: BoundedImageRepository, ObservableObject {
    init() {
        super.init(cacheLimit: 120, failedRequestLimit: 60)
    }
}

private enum ImageDownsampler {
    static func thumbnail(from data: Data, maxPixelSize: Int) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                    return nil
                }

                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
                ]

                guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                    return nil
                }

                return UIImage(cgImage: image)
            }
        }.value
    }
}

private enum DiskImageCache {
    static func image(at url: URL) async -> UIImage? {
        await Task.detached(priority: .utility) {
            UIImage(contentsOfFile: url.path)
        }.value
    }

    static func store(_ image: UIImage, at url: URL, trimming directory: URL?, to fileLimit: Int) {
        Task.detached(priority: .utility) {
            guard let data = image.jpegData(compressionQuality: 0.82) else { return }
            try? data.write(to: url, options: .atomic)

            guard let directory, fileLimit > 0 else { return }
            let files = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            let oldestFilesFirst = files.sorted {
                let leftDate = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let rightDate = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return leftDate < rightDate
            }

            for expiredFile in oldestFilesFirst.prefix(max(0, oldestFilesFirst.count - fileLimit)) {
                try? FileManager.default.removeItem(at: expiredFile)
            }
        }
    }
}
