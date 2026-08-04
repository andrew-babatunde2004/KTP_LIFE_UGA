import AVFoundation
import SwiftUI
import Vision
import VisionKit

/// A self-contained camera presentation for QR scanning. The view owns camera
/// permission and dismissal so Home only receives a validated payload string.
struct QRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var scannerError: String?

    let didScan: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                scannerContent
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppFont.subheadline(weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .task {
            await requestCameraAccessIfNeeded()
        }
    }

    @ViewBuilder
    private var scannerContent: some View {
        switch authorizationStatus {
        case .authorized:
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                QRDataScanner(
                    didScan: handleScan,
                    becameUnavailable: { message in scannerError = message }
                )
                .ignoresSafeArea()
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.82), lineWidth: 2)
                        .frame(width: 252, height: 252)
                        .shadow(color: .black.opacity(0.28), radius: 10)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    Label("Center the event QR code", systemImage: "viewfinder")
                        .font(AppFont.subheadline(weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .glassEffect(.clear.tint(.black.opacity(0.46)), in: Capsule())
                        .padding(.bottom, 30)
                }
            } else {
                scannerUnavailableView(
                    message: scannerError ?? "QR scanning is not available on this device."
                )
            }
        case .denied, .restricted:
            scannerUnavailableView(
                message: "Camera access is off. Enable it in Settings to scan QR codes.",
                showsSettingsButton: authorizationStatus == .denied
            )
        case .notDetermined:
            ProgressView("Requesting camera access...")
                .tint(.white)
                .foregroundStyle(.white)
        @unknown default:
            scannerUnavailableView(message: "The camera is currently unavailable.")
        }
    }

    private func scannerUnavailableView(message: String, showsSettingsButton: Bool = false) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text(message)
                .font(AppFont.subheadline())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if showsSettingsButton,
               let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") {
                    openURL(settingsURL)
                }
                .font(AppFont.subheadline(weight: .semibold))
                .buttonStyle(.glassProminent)
            }
        }
        .padding(28)
    }

    @MainActor
    private func requestCameraAccessIfNeeded() async {
        guard authorizationStatus == .notDetermined else { return }
        _ = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    @MainActor
    private func handleScan(_ payload: String) {
        didScan(payload)
        dismiss()
    }
}

private struct QRDataScanner: UIViewControllerRepresentable {
    let didScan: (String) -> Void
    let becameUnavailable: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(didScan: didScan, becameUnavailable: becameUnavailable)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator

        Task { @MainActor in
            try? controller.startScanning()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let didScan: (String) -> Void
        private let becameUnavailable: (String) -> Void
        private var hasDeliveredResult = false

        init(didScan: @escaping (String) -> Void, becameUnavailable: @escaping (String) -> Void) {
            self.didScan = didScan
            self.becameUnavailable = becameUnavailable
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !hasDeliveredResult,
                  let payload = addedItems.compactMap(qrPayload(from:)).first
            else {
                return
            }

            hasDeliveredResult = true
            didScan(payload)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard !hasDeliveredResult, let payload = qrPayload(from: item) else { return }
            hasDeliveredResult = true
            didScan(payload)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            becameUnavailable("QR scanning became unavailable. Please check camera access and try again.")
        }

        private func qrPayload(from item: RecognizedItem) -> String? {
            guard case .barcode(let barcode) = item else { return nil }
            return barcode.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
