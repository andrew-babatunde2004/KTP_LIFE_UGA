//
//  PhotosView.swift
//  KTPLIFE
//

import SwiftUI
import PhotosUI

struct PhotosView: View {
    @State private var photos: [PhotoItem] = []
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: Image? = nil
    
    private let photoService = PhotoService()
    
    
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
    
    private func imageURL(for photo: PhotoItem) -> URL {
        APIConfig.absoluteURL(for: photo.imagePath)
    }
    
    @MainActor
    private func loadPhotos() async {
        if isPreview {
            photos = PhotoItem.previewSamples
            return
        }
        
        photos = (try? await photoService.fetchPhotos()) ?? []
    }
    
    
    private var addPhotoButton: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Label("Upload", systemImage: "photo.badge.plus")
                .font(AppFont.footnote(weight: .bold))
                .appTextOnCard()
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(AppSurfaceColor.primaryControl, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(AppSurfaceColor.cardBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self) else {
                        print("Failed to load image: no data returned")
                        return
                    }
                    guard let uiImage = UIImage(data: data) else {
                        print("Failed to load image: could not decode image data")
                        return
                    }
                    selectedImage = Image(uiImage: uiImage)
                } catch {
                    print("Failed to load image: \(error.localizedDescription)")
                }
            }
        }
    }
}
         

#Preview("Photos") {
    PhotosView()
        .padding(.horizontal, 20)
        .background(AppTab.photos.theme.previewBackground())
}
