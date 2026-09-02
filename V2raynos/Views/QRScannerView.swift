import SwiftUI
import AVFoundation
import PhotosUI

/// 相机二维码扫描器（v2rayNG 同款入口）
struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    var onResult: (String) -> Void

    @State private var cameraDenied = false
    @State private var showAlbum = false
    @State private var albumImage: PhotosPickerItem? = nil
    @State private var albumError = false

    var body: some View {
        NavigationStack {
            ZStack {
                if cameraDenied {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.badge.ellipsis").font(.system(size: 44)).foregroundColor(.secondary)
                        Text("相机不可用，请用相册识别").font(.subheadline).foregroundColor(.secondary)
                        Button("打开相册识别") { showAlbum = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    CameraPreview(onCode: handleCode, onDenied: { cameraDenied = true })
                        .ignoresSafeArea()
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button { showAlbum = true } label: {
                                Label("相册", systemImage: "photo.on.rectangle")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("扫码添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showAlbum, onDismiss: { if albumImage != nil && !albumError { } }) {
                PhotosPicker(selection: $albumImage, matching: .images) {
                    Text("选择二维码图片")
                }
                .onChange(of: albumImage) { item in
                    guard let item = item else { return }
                    item.loadTransferable(type: Data.self) { res in
                        switch res {
                        case .success(let data):
                            if let d = data, let img = UIImage(data: d), let code = QRRecognizer.recognize(img) {
                                handleCode(code)
                            } else {
                                albumError = true
                            }
                        case .failure:
                            albumError = true
                        }
                    }
                }
            }
            .alert("识别失败", isPresented: $albumError) {
                Button("好", role: .cancel) {}
            } message: {
                Text("图片中未识别到二维码内容")
            }
        }
    }

    func handleCode(_ code: String) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onResult(code) }
    }
}

/// 实时相机取景
struct CameraPreview: View {
    var onCode: (String) -> Void
    var onDenied: () -> Void
    @State private var session = AVCaptureSession()
    @State private var previewLayer: AVCaptureVideoPreviewLayer?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let layer = previewLayer {
                    CameraLayerView(layer: layer)
                }
            }
            .onAppear { setupCamera(geo: geo) }
            .onDisappear { session.stopRunning() }
        }
    }

    func setupCamera(geo: GeometryProxy) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { ok ? startSession() : onDenied() }
            }
        default: onDenied()
        }
    }

    func startSession() {
        DispatchQueue.global().async {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                DispatchQueue.main.async { onDenied() }
                return
            }
            session.beginConfiguration()
            if session.inputs.isEmpty { session.addInput(input) }
            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            DispatchQueue.main.async {
                previewLayer = layer
                session.startRunning()
            }
            output.setMetadataObjectsDelegate(QRDelegate(onCode: onCode), queue: .main)
            output.metadataObjectTypes = [.qr]
        }
    }
}

struct CameraLayerView: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.layer.addSublayer(layer)
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        layer.frame = uiView.bounds
    }
}

final class QRDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    let onCode: (String) -> Void
    init(onCode: @escaping (String) -> Void) { self.onCode = onCode }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr, let code = obj.stringValue else { return }
        onCode(code)
    }
}

/// CIFilter 识别静态图片二维码
enum QRRecognizer {
    static func recognize(_ image: UIImage) -> String? {
        guard let ci = CIImage(image: image) else { return nil }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        guard let features = detector?.features(in: ci) as? [CIQRCodeFeature] else { return nil }
        return features.first?.messageString
    }
}
