import Foundation
import Vision
import ImageIO

/// Public UI metadata only. No decoded payload is observable or printable.
enum ScannerEvent: Equatable, Sendable {
    case scanning, progress(Int, Int), found(String), wrong(String)
}

/// Serial secret owner; lock makes teardown and cancellation safe against an in-flight decode.
final class ScannerPipeline: @unchecked Sendable {
    private let lock = NSLock()
    private let decoder = MultipartQRDecoder()
    private let configuration: ScannerConfiguration
    private var accepted: SecureBytes?
    private var closed = false
    private var photoRequest: VNDetectBarcodesRequest?
    init(configuration: ScannerConfiguration) { self.configuration = configuration }
    var isCleared: Bool { lock.withLock { accepted == nil && decoder.storedByteCount == 0 } }
    func close() { lock.withLock { closed = true; photoRequest?.cancel(); photoRequest = nil; accepted?.wipe(); accepted = nil; decoder.reset() } }
    func takeResult() -> SecureBytes? { lock.withLock { let result = accepted; accepted = nil; return result } }
    func process(_ text: String) -> ScannerEvent {
        lock.withLock {
            guard !closed, accepted == nil else { return .scanning }
            return processLocked(text)
        }
    }
    private func processLocked(_ text: String) -> ScannerEvent {
        guard text.utf8.count <= 16_384 else { return .wrong(configuration.rejection(ScanDecodeError.invalid, nil)) }
        do {
            let input = try ScanBytes.copy(text.utf8); defer { input.wipe() }
            switch try decoder.receive(input) {
            case .progress(let read, let count): return .progress(read,count)
            case .payload(let payload):
                defer { payload.bytes.wipe() }
                do {
                    let result = try configuration.accept(payload)
                    accepted = result.bytes
                    decoder.reset()
                    return .found(result.label)
                } catch { return .wrong(configuration.rejection(error, payload)) }
            }
        } catch { return .wrong(configuration.rejection(error, nil)) }
    }
    func processPhoto(_ source: Data) -> ScannerEvent {
        // Vision, ImageIO and the picker own transient system copies; none is written by us.
        var data = source
        defer { data.withUnsafeMutableBytes { takeback_secure_zero($0.baseAddress, $0.count) } }
        let request = VNDetectBarcodesRequest()
        guard lock.withLock({
            guard !closed, accepted == nil else { return false }
            photoRequest = request; return true
        }) else { return .scanning }
        defer { lock.withLock { if photoRequest === request { photoRequest = nil } } }
        return autoreleasepool {
            do {
                let strings = try ScannerPhotoDecoder.decode(data, request: request)
                return lock.withLock {
                    guard !closed, accepted == nil else { return .scanning }
                    var event: ScannerEvent = .wrong(configuration.rejection(ScanDecodeError.invalid, nil))
                    for text in strings {
                        let next = processLocked(text)
                        if case .found = next { return next }
                        if case .progress = next { event = next }
                        else if case .progress = event { /* retain useful multipart progress */ }
                        else { event = next }
                    }
                    return event
                }
            } catch {
                return lock.withLock { closed ? .scanning : .wrong(configuration.rejection(ScanDecodeError.invalid, nil)) }
            }
        }
    }
    deinit { accepted?.wipe(); decoder.reset() }
}

enum ScannerPhotoDecoder {
    static func decode(_ data: Data, request: VNDetectBarcodesRequest = VNDetectBarcodesRequest()) throws -> [String] {
        guard !data.isEmpty, data.count <= 32*1024*1024,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 24000, height <= 24000,
              Int64(width)*Int64(height) <= 100_000_000,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 4096,
                kCGImageSourceShouldCacheImmediately: false
              ] as CFDictionary) else { throw ScanDecodeError.invalid }
        // Revision 1 handles standard QR without the simulator's unavailable inference context.
        // Changing revision resets symbologies, so restrict to QR afterwards.
        request.revision = VNDetectBarcodesRequestRevision1
        request.symbologies = [.qr]
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).prefix(32).compactMap(\.payloadStringValue)
    }
}
