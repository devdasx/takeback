import SwiftUI
import AVFoundation
import AudioToolbox

@MainActor protocol ScannerCameraPermission {
    var status: AVAuthorizationStatus { get }
    func request() async -> Bool
}
@MainActor struct SystemScannerPermission: ScannerCameraPermission {
    var status: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .video) }
    func request() async -> Bool { await AVCaptureDevice.requestAccess(for: .video) }
}
@MainActor protocol ScannerFeedback { func success(); func error() }
@MainActor final class SystemScannerFeedback: ScannerFeedback {
    private var sound: SystemSoundID = 0
    init() {
        if let url = Bundle.main.url(forResource: "ScannerSuccess", withExtension: "wav") {
            AudioServicesCreateSystemSoundID(url as CFURL, &sound)
        }
    }
    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if sound != 0 { AudioServicesPlaySystemSound(sound) }
    }
    func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    deinit { if sound != 0 { AudioServicesDisposeSystemSoundID(sound) } }
}

@MainActor final class ScannerModel: ObservableObject {
    enum Access: Equatable { case waiting, ready, unavailable }
    @Published private(set) var access: Access = .waiting
    @Published private(set) var event: ScannerEvent = .scanning
    @Published private(set) var isClosed = false
    @Published var choosingPhoto = false
    @Published private(set) var decodingPhoto = false
    @Published private(set) var active = true
    @Published private(set) var hasTorch = false
    @Published private(set) var torchOn = false
    let configuration: ScannerConfiguration
    private let pipeline: ScannerPipeline
    private let permission: any ScannerCameraPermission
    private let feedback: any ScannerFeedback
    private let session: SecretSession
    private var permissionTask: Task<Void, Never>?
    private var decodeTask: Task<Void, Never>?
    private var completionTask: Task<Void, Never>?
    private var permissionPending = false
    private var processing = false
    private var generation = 0
    private var clearID: UUID?
    private var lastErrorTime = Date.distantPast
    var stopCamera: (() -> Void)?
    var setTorch: ((Bool) -> Bool)?
    var cancelPhotoLoad: (() -> Void)?
    var onResult: ((SecureBytes) -> Void)?
    var shouldRunCamera: Bool {
        active && !isClosed && access == .ready && !choosingPhoto && !decodingPhoto && !isFound
    }
    var isFound: Bool { if case .found = event { true } else { false } }
    init(session: SecretSession, configuration: ScannerConfiguration = .privateKey,
         permission: any ScannerCameraPermission = SystemScannerPermission(), feedback: (any ScannerFeedback)? = nil) {
        self.session = session; self.configuration = configuration; self.permission = permission
        self.feedback = feedback ?? SystemScannerFeedback()
        pipeline = ScannerPipeline(configuration: configuration)
        clearID = session.registerEditorClear { [weak self] in self?.close() }
    }
    func activate() {
        guard !isClosed else { return }; active = true
        switch permission.status {
        case .authorized: access = .ready
        case .denied, .restricted: access = .unavailable
        case .notDetermined:
            guard !permissionPending else { return }; permissionPending = true
            permissionTask = Task { [weak self] in
                guard let self else { return }
                let granted = await self.permission.request()
                guard !Task.isCancelled, !self.isClosed else { return }
                self.permissionPending = false; self.access = granted ? .ready : .unavailable
            }
        @unknown default: access = .unavailable
        }
    }
    func pause() { active = false; turnTorchOff(); stopCamera?() }
    func cameraReady(torch: Bool) { hasTorch = torch }
    func cameraUnavailable() { access = .unavailable; hasTorch = false; turnTorchOff() }
    func toggleTorch() { torchOn = setTorch?(!torchOn) ?? false }
    func turnTorchOff() { _ = setTorch?(false); torchOn = false }
    func choosePhoto() { turnTorchOff(); stopCamera?(); choosingPhoto = true }
    func receive(_ text: String) {
        guard shouldRunCamera, !processing else { return }
        processing = true
        let expected = generation, pipeline = pipeline
        decodeTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { pipeline.process(text) }.value
            guard let self, !self.isClosed, expected == self.generation else { return }
            self.processing = false; self.apply(result)
        }
    }
    func receivePhoto(_ data: Data?) {
        guard !isClosed, choosingPhoto else { return }
        cancelPhotoLoad?(); cancelPhotoLoad = nil
        choosingPhoto = false
        guard let data else { return }
        decodingPhoto = true; turnTorchOff(); stopCamera?()
        let expected = generation, pipeline = pipeline
        decodeTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { pipeline.processPhoto(data) }.value
            guard let self, !self.isClosed, expected == self.generation else { return }
            self.decodingPhoto = false; self.apply(result)
        }
    }
    func photoFailed() { choosingPhoto = false; apply(.wrong(configuration.rejection(ScanDecodeError.invalid, nil))) }
    private func apply(_ value: ScannerEvent) {
        guard !isClosed, !isFound else { return }
        event = value
        switch value {
        case .found:
            turnTorchOff(); stopCamera?(); feedback.success()
            completionTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
                guard let self, !self.isClosed else { return }
                if let bytes = self.pipeline.takeResult() {
                    defer { bytes.wipe() }; self.onResult?(bytes)
                }
                self.close()
            }
        case .wrong:
            if Date().timeIntervalSince(lastErrorTime) > 1 { lastErrorTime = Date(); feedback.error() }
        default: break
        }
    }
    func close() {
        guard !isClosed else { return }
        isClosed = true; generation &+= 1
        turnTorchOff(); stopCamera?(); stopCamera = nil; setTorch = nil
        cancelPhotoLoad?(); cancelPhotoLoad = nil
        permissionTask?.cancel(); decodeTask?.cancel(); completionTask?.cancel()
        pipeline.close(); choosingPhoto = false; decodingPhoto = false
        onResult = nil
        if let clearID { session.unregisterEditorClear(clearID); self.clearID = nil }
    }
    deinit { permissionTask?.cancel(); decodeTask?.cancel(); completionTask?.cancel(); pipeline.close() }
    #if DEBUG
    func preview(access: Access, event: ScannerEvent, torch: Bool = true) {
        self.access = access; self.event = event; self.hasTorch = torch
    }
    #endif
}
