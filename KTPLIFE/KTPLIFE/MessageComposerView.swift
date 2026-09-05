import CoreTransferable
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Owns the rapidly-changing composer state so typing, focus, and attachment
/// preparation do not invalidate the entire conversation timeline.
struct MessageComposerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var draftMessage = ""
    @State private var isSending = false
    @State private var sendErrorMessage: String?
    @State private var selectedMediaItem: PhotosPickerItem?
    @State private var pendingAttachment: MessageAttachmentUpload?
    @State private var pendingAttachmentPreview: UIImage?
    @State private var isPreparingAttachment = false
    @FocusState private var isFocused: Bool

    let replyTo: MessageReplyReference?
    let cancelReply: () -> Void
    let send: (String, MessageAttachmentUpload?, MessageReplyReference?) async throws -> Void
    let focusChanged: (Bool) -> Void

    private var canSend: Bool {
        (!draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingAttachment != nil)
            && !isSending
            && !isPreparingAttachment
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let replyTo {
                MessageReplyComposerPreview(replyTo: replyTo, cancel: cancelReply)
            }

            if let pendingAttachment {
                MessageAttachmentDraftPreview(
                    attachment: pendingAttachment,
                    previewImage: pendingAttachmentPreview,
                    remove: clearPendingAttachment
                )
            }

            HStack(spacing: 10) {
                mediaPicker

                TextField("Message", text: $draftMessage, axis: .vertical)
                    .font(AppFont.subheadline())
                    .lineLimit(1...4)
                    .foregroundStyle(MessageDesign.primary(for: colorScheme))
                    .textInputAutocapitalization(.sentences)
                    .focused($isFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .modifier(MessageComposerFieldSurface(colorScheme: colorScheme))

                Button(action: beginSend) {
                    Image(systemName: "paperplane.fill")
                        .font(AppFont.footnote(weight: .semibold))
                        .foregroundStyle(
                            canSend
                                ? MessageDesign.sendForeground
                                : MessageDesign.muted(for: colorScheme)
                        )
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .modifier(MessageSendButtonSurface(canSend: canSend))
                .disabled(!canSend)
                .accessibilityLabel("Send message")
            }
        }
        .padding(4)
        .onChange(of: isFocused) { _, value in focusChanged(value) }
        .onChange(of: selectedMediaItem) { _, item in
            guard let item else { return }
            Task { await prepareAttachment(from: item) }
        }
        .alert("Couldn’t Send Message", isPresented: Binding(
            get: { sendErrorMessage != nil },
            set: { if !$0 { sendErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sendErrorMessage ?? "Please try again.")
        }
    }

    private var mediaPicker: some View {
        PhotosPicker(
            selection: $selectedMediaItem,
            matching: .images,
            preferredItemEncoding: .current
        ) {
            Image(systemName: isPreparingAttachment ? "hourglass" : "photo.on.rectangle.angled")
                .font(AppFont.subheadline(weight: .semibold))
                .foregroundStyle(MessageDesign.primary(for: colorScheme))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .disabled(isPreparingAttachment || isSending)
        .accessibilityLabel("Choose an image or GIF")
    }

    private func beginSend() {
        Task { await sendMessage() }
    }

    @MainActor
    private func sendMessage() async {
        let draftBeforeSending = draftMessage
        let content = draftBeforeSending.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachment = pendingAttachment
        guard (!content.isEmpty || attachment != nil), !isSending else { return }

        isSending = true
        sendErrorMessage = nil
        draftMessage = ""

        do {
            try await send(content, attachment, replyTo)
            clearPendingAttachment()
            cancelReply()
        } catch is CancellationError {
            if draftMessage.isEmpty { draftMessage = draftBeforeSending }
        } catch {
            if draftMessage.isEmpty { draftMessage = draftBeforeSending }
            sendErrorMessage = messageSendErrorMessage(for: error)
        }

        isSending = false
    }

    @MainActor
    private func prepareAttachment(from item: PhotosPickerItem) async {
        isPreparingAttachment = true
        defer {
            isPreparingAttachment = false
            selectedMediaItem = nil
        }

        do {
            guard let selectedImage = try await item.loadTransferable(type: MessagePickedImage.self) else {
                throw MessageAttachmentError.unreadableImage
            }
            defer { try? FileManager.default.removeItem(at: selectedImage.url) }

            let data = try await Task.detached(priority: .utility) {
                try Data(contentsOf: selectedImage.url, options: [.mappedIfSafe])
            }.value
            guard data.count <= MessageAttachmentLimits.maximumBytes else {
                throw MessageAttachmentError.fileTooLarge
            }

            let contentType = UTType(filenameExtension: selectedImage.url.pathExtension) ?? .image
            guard contentType.conforms(to: .image) else {
                throw MessageAttachmentError.unsupportedType
            }

            let uploadImage = try ImageUploadEncoder.encodeForUpload(data: data, contentType: contentType)
            guard uploadImage.data.count <= MessageAttachmentLimits.maximumBytes else {
                throw MessageAttachmentError.fileTooLarge
            }

            pendingAttachment = MessageAttachmentUpload(
                data: uploadImage.data,
                fileName: "ktp-message-\(UUID().uuidString).\(uploadImage.fileExtension)",
                mimeType: uploadImage.mimeType
            )
            pendingAttachmentPreview = await Task.detached(priority: .utility) {
                UIImage(data: data)
            }.value
            sendErrorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            sendErrorMessage = messageAttachmentErrorMessage(for: error)
        }
    }

    private func clearPendingAttachment() {
        pendingAttachment = nil
        pendingAttachmentPreview = nil
    }

    private func messageAttachmentErrorMessage(for error: Error) -> String {
        if let attachmentError = error as? MessageAttachmentError {
            return attachmentError.errorDescription ?? "Couldn’t prepare that attachment."
        }
        return "Couldn’t prepare that image or GIF. Please try again."
    }
}
