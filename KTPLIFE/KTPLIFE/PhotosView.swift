//
//  PhotosView.swift
//  KTPLIFE
//

import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers
import AVKit
import CoreTransferable

struct PhotosView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var photos: [PhotoItem] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedMedia: PhotoItem?
    @State private var isUploading = false
    @State private var loadError: String?

    let showsCloseButton: Bool

    init(showsCloseButton: Bool = false) {
        self.showsCloseButton = showsCloseButton
    }
    
    private var photoService: PhotoService {
        PhotoService(accessTokenProvider: { [authManager] in
            try await authManager.validAccessToken()
        })
    }
    
    
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 3),
        GridItem(.flexible(minimum: 0), spacing: 3),
        GridItem(.flexible(minimum: 0), spacing: 3),
    ]
    
    var body: some View {
        PageScaffold(showsPageHeader: false) {
            VStack(alignment: .leading, spacing: 16) {
                if let loadError {
                    PhotosStatusCard(message: loadError)
                        .padding(.horizontal, 20)
                } else if photos.isEmpty {
                    ContentUnavailableView(
                        "No chapter media yet",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Use the add button to share the first photo or video.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .padding(.horizontal, 20)
                }
                
                // A dense, full-width three-column gallery keeps every thumbnail easy to scan.
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(photos) { photo in
                        AuthenticatedPhotoTile(
                            photo: photo,
                            photoService: photoService,
                            select: { selectedMedia = photo }
                        )
                    }
                }
            }
            .padding(.bottom, 92)
        }
        // The dismiss control occupies its own top safe-area region, so the first photo
        // cannot receive a tap intended for the back control.
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsCloseButton {
                HStack {
                    Button(action: { dismiss() }) {
                        PhotoCloseButtonLabel()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Return to home")

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(PhotosDesign.galleryBackground(for: colorScheme))
            }
        }
        // A downward swipe beginning in the gallery header is an alternate exit for
        // the full-screen presentation. Keeping it out of the grid preserves normal
        // vertical scrolling and photo selection.
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard showsCloseButton,
                          value.startLocation.y < 210,
                          value.translation.height > 110,
                          abs(value.translation.height) > abs(value.translation.width) * 1.5
                    else {
                        return
                    }

                    dismiss()
                }
        )
        .overlay(alignment: .bottomLeading) {
            addPhotoButton
                .padding(.leading, 20)
                .padding(.bottom, 20)
                .zIndex(999)
        }
        .task {
            await loadPhotos()
        }
        .sheet(item: $selectedMedia) { photo in
            AuthenticatedMediaViewer(photo: photo, photoService: photoService)
        }
    }
    
    @MainActor
    private func loadPhotos() async {
#if DEBUG
        if isPreview {
            photos = PhotoItem.previewSamples
            loadError = nil
            return
        }
#endif
        
        do {
            photos = try await photoService.fetchPhotos()
            loadError = nil
        } catch {
            photos = []
            loadError = photosErrorMessage(for: error)
        }
    }
    
    
    private var addPhotoButton: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: 10,
            matching: .any(of: [.images, .videos]),
            preferredItemEncoding: .current
        ) {
            PhotoUploadButtonLabel(isUploading: isUploading)
        }
        .fixedSize()
        .disabled(isUploading)
        .buttonStyle(.plain)
        .onChange(of: selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await uploadPhotos(from: newItems)
            }
        }
    }

    @MainActor
    private func uploadPhotos(from items: [PhotosPickerItem]) async {
        isUploading = true
        defer {
            isUploading = false
            selectedItems = []
        }

        do {
            var uploadedPhotos: [PhotoItem] = []
            for item in items {
                let data: Data
                let contentType: UTType

                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    guard let video = try await item.loadTransferable(type: PickedVideo.self) else {
                        throw PhotoTransferError.unreadableMedia
                    }
                    defer { try? FileManager.default.removeItem(at: video.url) }
                    data = try Data(contentsOf: video.url)
                    contentType = mediaContentType(for: video.url, fallback: .mpeg4Movie)
                } else {
                    // Request an image file instead of generic Data. Some library items
                    // (notably HEIC and Live Photos) don't expose a generic data
                    // representation even though they have a usable image file.
                    guard let image = try await item.loadTransferable(type: PickedImage.self) else {
                        throw PhotoTransferError.unreadableMedia
                    }
                    defer { try? FileManager.default.removeItem(at: image.url) }
                    data = try Data(contentsOf: image.url)
                    contentType = mediaContentType(for: image.url, fallback: .jpeg)
                }

                let mimeType = contentType.preferredMIMEType ?? "image/jpeg"
                let fileExtension = contentType.preferredFilenameExtension ?? "jpg"
                let title = contentType.conforms(to: .movie) ? "Chapter Video" : "Chapter Photo"
                let uploadedPhoto = try await photoService.uploadPhoto(
                    data: data,
                    fileName: "ktp-media-\(UUID().uuidString).\(fileExtension)",
                    mimeType: mimeType,
                    title: title
                )
                uploadedPhotos.append(uploadedPhoto)
            }

            photos.insert(contentsOf: uploadedPhotos.reversed(), at: 0)
            loadError = nil
        } catch {
            loadError = photosErrorMessage(for: error)
        }
    }

    private func mediaContentType(for url: URL, fallback: UTType) -> UTType {
        UTType(filenameExtension: url.pathExtension) ?? fallback
    }

    private func photosErrorMessage(for error: Error) -> String {
        if case AuthManagerError.notAuthenticated = error {
            return "Sign in with SSO to load photos."
        }

        if case KTPAPIError.missingAccessToken = error {
            return "Sign in with SSO to load photos."
        }

        if case KTPAPIError.badStatusCode(let statusCode, _) = error {
            if statusCode == 401 || statusCode == 403 {
                return "Your photo access has expired. Sign out and sign in again."
            }

            return "The chapter gallery is temporarily unavailable. Please try again later."
        }

        if case KTPAPIError.decodeFailed(_) = error {
            return "The chapter gallery returned an unsupported response. Please try again later."
        }

        return "Could not load the chapter gallery. Please check your connection and try again."
    }
}

private struct AuthenticatedPhotoTile: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @EnvironmentObject private var thumbnailRepository: GalleryThumbnailRepository
    let photo: PhotoItem
    let photoService: PhotoService
    let select: () -> Void

    @State private var image: UIImage?
    @State private var isDownloading = false
    @State private var downloadError: String?

    var body: some View {
        Button(action: select) {
            PhotosDesign.tileBackground(for: colorScheme)
                .aspectRatio(1, contentMode: .fill)
                .overlay {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if photo.isVideo {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(.black.opacity(0.58), in: Circle())
                            .padding(7)
                    }
                }
                .clipped()
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                Task { await downloadMedia() }
            } label: {
                Label(isDownloading ? "Saving…" : "Save to Photos", systemImage: "arrow.down.to.line")
            }
            .disabled(isDownloading)
        }
        .accessibilityLabel("\(photo.title). Tap to view full size. Long press to save.")
        .background {
            GeometryReader { proxy in
                Color.clear
                    .task(id: thumbnailRequestID(for: proxy.size)) {
                        await loadThumbnail(for: proxy.size)
                    }
            }
        }
        .alert("Couldn’t Save Media", isPresented: Binding(
            get: { downloadError != nil },
            set: { if !$0 { downloadError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(downloadError ?? "")
        }
    }

    private func thumbnailRequestID(for size: CGSize) -> String {
        "\(photo.id)-\(Int((size.width * displayScale).rounded(.up)))"
    }

    @MainActor
    private func loadThumbnail(for size: CGSize) async {
        guard !photo.isVideo, size.width > 0 else {
            image = nil
            return
        }

        let thumbnail = await thumbnailRepository.image(
            for: "gallery-\(photo.id)",
            pointSize: size.width,
            displayScale: displayScale,
            loadData: { try await photoService.fetchMediaData(for: photo) }
        )
        guard !Task.isCancelled else { return }
        image = thumbnail
    }

    @MainActor
    private func downloadMedia() async {
        isDownloading = true
        defer { isDownloading = false }

        do {
            let data = try await photoService.fetchMediaData(for: photo)
            try await PhotoLibrarySaver.save(data: data, isVideo: photo.isVideo)
        } catch {
            downloadError = error.localizedDescription
        }
    }
}

private struct AuthenticatedMediaViewer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let photo: PhotoItem
    let photoService: PhotoService

    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var reportTarget: ReportTarget?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else if let player {
                    VideoPlayer(player: player)
                        .onAppear { player.play() }
                } else if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    ContentUnavailableView(
                        "Media Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage ?? "This media could not be loaded.")
                    )
                    .foregroundStyle(.white)
                }
            }
            .navigationTitle(photo.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveMedia() }
                    } label: {
                        Image(systemName: isSaving ? "hourglass" : "arrow.down.to.line")
                    }
                    .disabled(isSaving || isLoading)
                    .accessibilityLabel("Save to Photos")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Report", role: .destructive) {
                        reportTarget = .photo(photo)
                    }
                }
            }
        }
        .task { await loadMedia() }
        .alert("Couldn’t Save Media", isPresented: Binding(
            get: { errorMessage != nil && !isLoading },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $reportTarget) { target in
            ReportContentSheet(target: target)
        }
        .onDisappear { player?.pause() }
    }

    @MainActor
    private func loadMedia() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await photoService.fetchMediaData(for: photo)
            if photo.isVideo {
                let url = try MediaTemporaryFile.write(data: data, suggestedPath: photo.imagePath)
                player = AVPlayer(url: url)
            } else if let loadedImage = UIImage(data: data) {
                image = loadedImage
            } else {
                errorMessage = "This file is not a supported image."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveMedia() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let data = try await photoService.fetchMediaData(for: photo)
            try await PhotoLibrarySaver.save(data: data, isVideo: photo.isVideo)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum PhotoTransferError: LocalizedError {
    case unreadableMedia

    var errorDescription: String? {
        "Could not read the selected image or video."
    }
}

private struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let fileExtension = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copiedURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)
            try FileManager.default.copyItem(at: received.file, to: copiedURL)
            return PickedVideo(url: copiedURL)
        }
    }
}

private struct PickedImage: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let fileExtension = received.file.pathExtension.isEmpty ? "jpg" : received.file.pathExtension
            let copiedURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)
            try FileManager.default.copyItem(at: received.file, to: copiedURL)
            return PickedImage(url: copiedURL)
        }
    }
}

private enum MediaTemporaryFile {
    static func write(data: Data, suggestedPath: String) throws -> URL {
        let extensionValue = URL(fileURLWithPath: suggestedPath).pathExtension
        let fileExtension = extensionValue.isEmpty ? "mov" : extensionValue
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }
}

private enum PhotoLibrarySaver {
    static func save(data: Data, isVideo: Bool) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoLibrarySaveError.accessDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: isVideo ? .video : .photo, data: data, options: nil)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoLibrarySaveError.unknown)
                }
            }
        }
    }
}

private enum PhotoLibrarySaveError: LocalizedError {
    case accessDenied
    case unknown

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Allow KTP Life to add photos in Settings to save this media."
        case .unknown:
            return "The media could not be saved to your photo library."
        }
    }
}

private struct PhotoUploadButtonLabel: View {
    @Environment(\.colorScheme) private var colorScheme

    let isUploading: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isUploading ? "hourglass" : "square.and.arrow.up")
                .font(.system(size: 16, weight: .semibold))

            Text(isUploading ? "Uploading" : "Upload")
                .font(AppFont.headline())
        }
        .foregroundStyle(PhotosDesign.addButtonForeground(for: colorScheme))
        .padding(.horizontal, 16)
        .frame(height: 44)
        .contentShape(Capsule())
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityLabel(isUploading ? "Uploading media" : "Upload media from photo library")
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(PhotosDesign.tileBorder(for: colorScheme), lineWidth: 1)
        }
    }
}

private struct PhotoCloseButtonLabel: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(systemName: "chevron.left")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(PhotosDesign.addButtonForeground(for: colorScheme))
            .frame(width: 52, height: 52)
            .contentShape(Circle())
            .background(PhotosDesign.closeButtonBackground(for: colorScheme), in: Circle())
    }
}


private struct PhotosStatusCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: String

    var body: some View {
        Text(message)
            .font(AppFont.footnote())
            .foregroundStyle(PhotosDesign.secondaryText(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(PhotosDesign.tileBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PhotosDesign.tileBorder(for: colorScheme), lineWidth: 1)
            }
    }
}

private enum PhotosDesign {
    static func galleryBackground(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.background
    }

    static func tileBackground(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.elevatedBackground
    }

    static func tileBorder(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.separator.opacity(colorScheme == .dark ? 0.60 : 0.35)
    }

    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.secondaryLabel
    }

    static func addButtonForeground(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.primaryLabel
    }

    static func glassTint(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.elevatedBackground.opacity(colorScheme == .dark ? 0.76 : 0.86)
    }

    static func closeButtonBackground(for colorScheme: ColorScheme) -> Color {
        AppSystemColor.elevatedBackground
    }
}
         

#if DEBUG
#Preview("Photos") {
    PhotosView()
        .padding(.horizontal, 20)
        .background(AppTab.photos.theme.previewBackground())
        .environmentObject(AuthManager.previewSignedOut)
        .environmentObject(GalleryThumbnailRepository())
}
#endif
