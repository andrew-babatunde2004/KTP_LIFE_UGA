//
//  PhotosView.swift
//  KTPLIFE
//

import SwiftUI

struct PhotosView: View {
    @State private var photos: [PhotoItem] = []

    private let photoService = PhotoService()
    private let apiBaseURL = URL(string: "http://192.168.1.174:3000/")!

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
    ]

    var body: some View {
        PageScaffold(showsPageHeader: false) {
            VStack(alignment: .trailing, spacing: 20) {
                addPhotoButton
                    .padding(.trailing, 20)

                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(photos) { photo in
                        AppSurfaceColor.card
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                AsyncImage(url: imageURL(for: photo)) { phase in
                                    if case .success(let image) = phase {
                                        image
                                            .resizable()
                                            .scaledToFit()
                                    }
                                }
                            }
                    }
                }
                .padding(.horizontal, -20)
            }
        }
        .task {
            await loadPhotos()
        }
    }

    private var addPhotoButton: some View {
        Button {} label: {
            Text("+")
                .font(AppFont.footnote(weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(AppSurfaceColor.primaryControl, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(AppSurfaceColor.cardBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func imageURL(for photo: PhotoItem) -> URL {
        URL(string: photo.imagePath, relativeTo: apiBaseURL)?.absoluteURL ?? apiBaseURL
    }

    @MainActor
    private func loadPhotos() async {
        if isPreview {
            photos = PhotoItem.previewSamples
            return
        }

        photos = (try? await photoService.fetchPhotos()) ?? []
    }
}

#Preview("Photos") {
    PhotosView()
        .padding(.horizontal, 20)
        .background(AppTab.photos.theme.backgroundColor)
}
