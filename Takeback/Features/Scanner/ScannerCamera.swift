import SwiftUI
@preconcurrency import AVFoundation
import VisionKit

struct ScannerCamera: UIViewControllerRepresentable {
    @ObservedObject var model: ScannerModel
    let guide: CGRect
    func makeUIViewController(context: Context) -> ScannerCameraController {
        let controller = ScannerCameraController(model: model)
        model.stopCamera = { [weak controller] in controller?.stop() }
        model.setTorch = { [weak controller] enabled in controller?.torch(enabled) ?? false }
        return controller
    }
    func updateUIViewController(_ controller: ScannerCameraController, context: Context) {
        controller.update(running: model.shouldRunCamera, guide: guide)
    }
    static func dismantleUIViewController(_ controller: ScannerCameraController, coordinator: ()) { controller.dispose() }
}

@MainActor final class ScannerCameraController: UIViewController, DataScannerViewControllerDelegate {
    private weak var model: ScannerModel?
    private var scanner: DataScannerViewController?
    private var capture: ScannerCapture?
    private var preview: AVCaptureVideoPreviewLayer?
    private var running = false
    private var disposed = false
    private var guide = CGRect.zero
    init(model: ScannerModel) { self.model = model; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .black
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                qualityLevel: .balanced, recognizesMultipleItems: true, isHighFrameRateTrackingEnabled: false,
                isPinchToZoomEnabled: false, isGuidanceEnabled: false, isHighlightingEnabled: false)
            scanner.delegate = self; self.scanner = scanner
            addChild(scanner); view.addSubview(scanner.view); scanner.didMove(toParent: self)
            let hasTorch = Self.device?.hasTorch == true
            Task { @MainActor [weak self] in
                guard let self, !self.disposed else { return }
                self.model?.cameraReady(torch: hasTorch)
            }
        } else { installFallback() }
    }
    private static var device: AVCaptureDevice? { AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) }
    private func installFallback() {
        guard !disposed, capture == nil else { return }
        scanner?.stopScanning(); scanner?.willMove(toParent: nil); scanner?.view.removeFromSuperview()
        scanner?.removeFromParent(); scanner = nil
        let capture = ScannerCapture { [weak self] text in self?.model?.receive(text) }
        self.capture = capture
        let preview = AVCaptureVideoPreviewLayer(session: capture.session)
        preview.videoGravity = .resizeAspectFill; view.layer.insertSublayer(preview, at: 0); self.preview = preview
        capture.configure { [weak self] ready, torch in
            guard let self, !self.disposed else { return }
            if ready { self.model?.cameraReady(torch: torch); self.view.setNeedsLayout() }
            else { self.model?.cameraUnavailable() }
        }
        capture.setRunning(running)
    }
    func update(running: Bool, guide: CGRect) {
        guard !disposed else { return }
        loadViewIfNeeded(); self.running = running; self.guide = guide
        view.setNeedsLayout()
        if let scanner {
            if running && !scanner.isScanning {
                do { try scanner.startScanning() } catch { installFallback() }
            } else if !running { scanner.stopScanning() }
        }
        capture?.setRunning(running)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scanner?.view.frame = view.bounds
        if !guide.isEmpty { scanner?.regionOfInterest = guide.intersection(view.bounds) }
        preview?.frame = view.bounds
        if let preview {
            let angle: CGFloat
            switch view.window?.windowScene?.interfaceOrientation {
            case .landscapeLeft: angle = 0
            case .landscapeRight: angle = 180
            case .portraitUpsideDown: angle = 270
            default: angle = 90
            }
            if preview.connection?.isVideoRotationAngleSupported(angle) == true { preview.connection?.videoRotationAngle = angle }
            if !guide.isEmpty { capture?.setRegion(preview.metadataOutputRectConverted(fromLayerRect: guide.intersection(view.bounds))) }
        }
    }
    func stop() { running = false; scanner?.stopScanning(); capture?.setRunning(false); _ = torch(false) }
    func dispose() { stop(); disposed = true; scanner?.delegate = nil; capture?.dispose(); capture = nil; preview?.session = nil }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); stop() }
    func torch(_ on: Bool) -> Bool {
        guard let device = Self.device, device.hasTorch, device.isTorchAvailable else { return false }
        do {
            try device.lockForConfiguration(); defer { device.unlockForConfiguration() }
            if on { try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel) }
            else { device.torchMode = .off }
            return on
        } catch { return false }
    }
    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) { receive(addedItems) }
    func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) { receive(updatedItems) }
    private func receive(_ items: [RecognizedItem]) {
        guard running, !disposed else { return }
        for case .barcode(let code) in items { if let text = code.payloadStringValue { model?.receive(text) } }
    }
    func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) { installFallback() }
}

/// All capture mutations and callbacks run on one queue. No frames are recorded or saved.
private final class ScannerCapture: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.takeback.scanner.capture", qos: .userInitiated)
    private let output = AVCaptureMetadataOutput()
    private var disposed = false
    private var configured = false
    private var running = false
    private let receive: @MainActor @Sendable (String) -> Void
    init(receive: @escaping @MainActor @Sendable (String) -> Void) { self.receive = receive }
    func configure(completion: @escaping @MainActor @Sendable (Bool, Bool) -> Void) {
        queue.async { [self] in
            guard !disposed else { return }
            session.beginConfiguration(); session.sessionPreset = .high
            var device: AVCaptureDevice?
            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input), session.canAddOutput(output) {
                session.addInput(input); session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: queue)
                if output.availableMetadataObjectTypes.contains(.qr) { output.metadataObjectTypes = [.qr]; configured = true; device = camera }
            }
            session.commitConfiguration()
            let ready = configured, torch = device?.hasTorch == true
            Task { @MainActor in completion(ready, torch) }
            if running && configured { session.startRunning() }
        }
    }
    func setRunning(_ value: Bool) {
        queue.async { [self] in
            guard !disposed else { return }; running = value
            if value && configured && !session.isRunning { session.startRunning() }
            else if !value && session.isRunning { session.stopRunning() }
        }
    }
    func setRegion(_ rect: CGRect) { queue.async { [self] in if !disposed && configured { output.rectOfInterest = rect } } }
    func dispose() {
        queue.async { [self] in
            guard !disposed else { return }; disposed = true; running = false
            if session.isRunning { session.stopRunning() }
            output.setMetadataObjectsDelegate(nil, queue: nil)
            session.beginConfiguration()
            for input in session.inputs { session.removeInput(input) }
            for output in session.outputs { session.removeOutput(output) }
            session.commitConfiguration()
        }
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard running, !disposed else { return }
        for case let code as AVMetadataMachineReadableCodeObject in objects where code.type == .qr {
            if let text = code.stringValue { Task { @MainActor [receive] in receive(text) } }
        }
    }
}
