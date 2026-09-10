import SwiftUI
@preconcurrency import AVFoundation

struct CameraScannerView: View {
    var onImageCaptured: (UIImage) -> Void
    var onCancel: () -> Void
    
    @StateObject private var model = CameraModel()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if model.isCameraAuthorized {
                CameraPreview(session: model.session)
                    .ignoresSafeArea()
                
                // Dimmer overlay during capture for feedback
                if model.isCapturing {
                    Color.black.opacity(0.5).ignoresSafeArea()
                }
                
                VStack {
                    // Top Bar
                    HStack(spacing: 16) {
                        Button(action: onCancel) {
                            Text("取消")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        // Flash Button
                        Button(action: { model.toggleFlash() }) {
                            Image(systemName: model.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.title2)
                                .foregroundColor(model.isFlashOn ? .yellow : .white)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        // Macro Toggle
                        if model.hasUltraWideCamera {
                            Button(action: { model.toggleMacro() }) {
                                Image(systemName: model.isMacroOn ? "loupe" : "camera.macro")
                                    .font(.title2)
                                    .foregroundColor(model.isMacroOn ? .green : .white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16) // Will respect safe area implicitly if in normal VStack, but we ignoresSafeArea on ZStack? Wait, ZStack is ZStack. ZStack ignores, but VStack doesn't. Wait, the ZStack ignoresSafeArea, but VStack inside doesn't have ignoresSafeArea, so VStack respects Safe Area. This is perfect for dynamic island.
                    
                    Spacer()
                    
                    // Hint Text
                    Text("請將效期置於畫面中央，若太近模糊可開啟小花(微距)模式")
                        .font(.caption)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.bottom, 16)
                    
                    // Capture Button
                    HStack {
                        Spacer()
                        Button(action: {
                            model.capturePhoto { image in
                                onImageCaptured(image)
                            }
                        }) {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 60, height: 60)
                                )
                        }
                        .disabled(model.isCapturing)
                        Spacer()
                    }
                    .padding(.bottom, 24)
                }
            } else {
                VStack(spacing: 16) {
                    Text("需要相機權限")
                        .font(.title)
                        .foregroundColor(.white)
                    Button("開啟設定") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("取消", action: onCancel)
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            model.checkPermissionsAndSetup()
        }
        .onDisappear {
            model.stopSession()
        }
    }
}

// MARK: - AVFoundation Camera Logic
@MainActor
final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var isCameraAuthorized = false
    @Published var isFlashOn = false
    @Published var isMacroOn = false
    @Published var hasUltraWideCamera = false
    @Published var isCapturing = false
    
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    private var completion: ((UIImage) -> Void)?
    
    func checkPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
            isCameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupCamera()
                        self.isCameraAuthorized = true
                    } else {
                        self.isCameraAuthorized = false
                    }
                }
            }
        default:
            isCameraAuthorized = false
        }
    }
    
    private func setupCamera() {
        guard !session.isRunning else { return }
        session.beginConfiguration()
        
        session.sessionPreset = .photo
        
        // Setup inputs
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInWideAngleCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .back)
        if let device = discoverySession.devices.first {
            do {
                videoDeviceInput = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(videoDeviceInput!) {
                    session.addInput(videoDeviceInput!)
                }
                
                // Enable Auto Macro (auto focus range restriction)
                try device.lockForConfiguration()
                if device.isAutoFocusRangeRestrictionSupported {
                    device.autoFocusRangeRestriction = .none
                }
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                device.unlockForConfiguration()
                
            } catch {
                print("Failed to add input: \(error)")
            }
        }
        
        // Setup output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        // Check for Ultra Wide
        if let _ = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            hasUltraWideCamera = true
        }
        
        session.commitConfiguration()
        
        let captureSession = self.session
        Task.detached {
            captureSession.startRunning()
        }
    }
    
    func stopSession() {
        if session.isRunning {
            let captureSession = self.session
            Task.detached {
                captureSession.stopRunning()
            }
        }
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
    
    func toggleMacro() {
        guard hasUltraWideCamera else { return }
        isMacroOn.toggle()
        
        // Switch cameras dynamically
        session.beginConfiguration()
        
        if let currentInput = videoDeviceInput {
            session.removeInput(currentInput)
        }
        
        let deviceType: AVCaptureDevice.DeviceType = isMacroOn ? .builtInUltraWideCamera : .builtInWideAngleCamera
        
        if let newDevice = AVCaptureDevice.default(deviceType, for: .video, position: .back) {
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                    videoDeviceInput = newInput
                }
                
                // Set auto focus for macro
                try newDevice.lockForConfiguration()
                if newDevice.isFocusModeSupported(.continuousAutoFocus) {
                    newDevice.focusMode = .continuousAutoFocus
                }
                newDevice.unlockForConfiguration()
                
            } catch {
                print("Failed to switch camera")
            }
        }
        
        session.commitConfiguration()
    }
    
    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        guard !isCapturing else { return }
        isCapturing = true
        self.completion = completion
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isFlashOn ? .on : .off
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // Delegate Method
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            Task { @MainActor in self.isCapturing = false }
            return
        }
        
        Task { @MainActor in
            self.isCapturing = false
            self.completion?(image)
        }
    }
}

// MARK: - CameraPreview
@MainActor
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
    }
}

@MainActor
class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
