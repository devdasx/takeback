import XCTest
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import AVFoundation
@testable import Takeback

final class ScannerTests: XCTestCase {
    struct Vectors: Decodable {
        let master: String; let masterXprv: String; let seed: String; let seedParts: [String]
        let urParts: [String]; let urHex: String; let bbqr: [String: [String]]
    }
    func vectors() throws -> Vectors {
        try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: XCTUnwrap(Bundle(for: Self.self).url(forResource: "ScannerVectors", withExtension: "json"))))
    }
    let scalar = String(repeating: "0", count: 63) + "1"
    func testAllPrivateKindsRouteThroughExistingDetector() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "KeyVectors", withExtension: "json"))
        let values = try JSONDecoder().decode([KeyDetectionTests.Vector].self, from: Data(contentsOf: url))
        for value in values where value.valid {
            let pipeline = ScannerPipeline(configuration: .privateKey)
            guard case .found = pipeline.process(value.input) else { XCTFail(value.id); continue }
            let result = try XCTUnwrap(pipeline.takeResult()); defer { result.wipe(); pipeline.close() }
            XCTAssertTrue(detectKey(result).isValid, value.id)
        }
    }
    func testPublicAddressAndExtendedKeyRejection() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "KeyVectors", withExtension: "json"))
        let values = try JSONDecoder().decode([KeyDetectionTests.Vector].self, from: Data(contentsOf: url))
        for value in values where value.kind == "public" {
            let pipeline = ScannerPipeline(configuration: .privateKey); defer { pipeline.close() }
            guard case .wrong = pipeline.process(value.input) else { XCTFail(value.id); continue }
            XCTAssertNil(pipeline.takeResult())
        }
        for value in ["1BoatSLRHtKNngkdXEeobR76b53LETtpyT", "bitcoin:1BoatSLRHtKNngkdXEeobR76b53LETtpyT?amount=1", "  BITCOIN:1BoatSLRHtKNngkdXEeobR76b53LETtpyT  ", "  1BoatSLRHtKNngkdXEeobR76b53LETtpyT  "] {
            let pipeline = ScannerPipeline(configuration: .privateKey); defer { pipeline.close() }
            XCTAssertEqual(pipeline.process(value), .wrong(KeyScanRouter.addressMessage))
            XCTAssertEqual(pipeline.process(scalar), .found("Private key · hex · 64 characters"))
        }
    }
    func testOfficialHDKeyAndCryptoSeedURRouting() throws {
        let v = try vectors()
        for text in [v.master, v.master.replacingOccurrences(of: "ur:hdkey", with: "UR:CRYPTO-HDKEY").uppercased()] {
            let pipeline = ScannerPipeline(configuration: .privateKey); defer { pipeline.close() }
            guard case .found = pipeline.process(text) else { return XCTFail("Official hdkey did not decode") }
            let result = try XCTUnwrap(pipeline.takeResult()); defer { result.wipe() }
            XCTAssertTrue(result.withUnsafeBytes { $0.elementsEqual(v.masterXprv.utf8) })
        }
        let pipeline = ScannerPipeline(configuration: .privateKey); defer { pipeline.close() }
        XCTAssertEqual(pipeline.process(v.seed), .found("Recovery phrase found · 12 words"))
        let result = try XCTUnwrap(pipeline.takeResult()); defer { result.wipe() }
        XCTAssertTrue(result.withUnsafeBytes { $0.elementsEqual((Array(repeating: "abandon", count: 11) + ["about"]).joined(separator: " ").utf8) })
    }
    func testMultipartSeedAndDuplicateProgressOutOfOrder() throws {
        let v = try vectors(), pipeline = ScannerPipeline(configuration: .privateKey)
        defer { pipeline.close() }
        XCTAssertEqual(pipeline.process(v.seedParts[2]), .progress(1,3))
        XCTAssertEqual(pipeline.process(v.seedParts[2]), .progress(1,3))
        XCTAssertEqual(pipeline.process(v.seedParts[0]), .progress(2,3))
        XCTAssertEqual(pipeline.process(v.seedParts[1]), .found("Recovery phrase found · 12 words"))
        pipeline.close(); XCTAssertTrue(pipeline.isCleared)
    }
    func testPublishedFountainMixedPartsRecoverMissingSimpleFragments() throws {
        let v = try vectors(), decoder = MultipartQRDecoder()
        // Omit simple part 2; reconstruct it from the reference encoder's mixed equations.
        let order = Array((9..<20).reversed()) + [8,7,6,5,4,3,2,0]
        var completed = false
        for index in order {
            let part = try ScanBytes.copy(v.urParts[index].utf8); defer { part.wipe() }
            if case .payload(let payload) = try decoder.receive(part) {
                defer { payload.bytes.wipe() }
                XCTAssertEqual(payload.bytes.withUnsafeBytes { $0.map { String(format: "%02x", $0) }.joined() }, v.urHex)
                completed = true; break
            }
        }
        XCTAssertTrue(completed); XCTAssertEqual(decoder.storedByteCount, 0)
    }
    func testBBQrAllEncodingsOutOfOrderAndDuplicates() throws {
        for (_, parts) in try vectors().bbqr {
            let pipeline = ScannerPipeline(configuration: .privateKey); defer { pipeline.close() }
            XCTAssertEqual(pipeline.process(parts.last!), .progress(1, parts.count))
            XCTAssertEqual(pipeline.process(parts.last!), .progress(1, parts.count))
            for text in parts.dropLast().reversed() { _ = pipeline.process(text) }
            let result = try XCTUnwrap(pipeline.takeResult()); defer { result.wipe() }
            XCTAssertTrue(result.withUnsafeBytes { $0.elementsEqual(scalar.utf8) })
            XCTAssertTrue(pipeline.isCleared)
        }
    }
    func testMalformedProtocolAndPublicCBORCannotProduceKey() throws {
        let v = try vectors()
        let pipeline = ScannerPipeline(configuration: .privateKey); defer { pipeline.close() }
        for bad in ["ur:crypto-seed/", String(v.seed.dropLast()) + "z", "ur:crypto-seed/999-0/aaaa", "B$HU000041", "B$2U0100B", "B$HU010061", "B$ZU0100AAAA", String(repeating: "A", count: 17000)] {
            guard case .wrong = pipeline.process(bad) else { XCTFail("Malformed QR accepted"); continue }
            XCTAssertNil(pipeline.takeResult())
        }
        let raw = try ScanBytes.copy([UInt8(0xa2), 2, 0xf4, 3, 0x41, 2]); defer { raw.wipe() }
        XCTAssertThrowsError(try KeyScanRouter.accept(.init(format: .ur("crypto-hdkey"), bytes: raw))) {
            guard case ScanDecodeError.publicKey = $0 else { return XCTFail("Expected public rejection") }
        }
    }
    func testConflictingBBQrPartResetsAndCloseWipesPartialAndAccepted() throws {
        let parts = try vectors().bbqr["H"]!, pipeline = ScannerPipeline(configuration: .privateKey)
        XCTAssertEqual(pipeline.process(parts[0]), .progress(1,parts.count)); XCTAssertFalse(pipeline.isCleared)
        let conflict = String(parts[0].dropLast(2)) + "31"
        guard case .wrong = pipeline.process(conflict) else { return XCTFail("Conflict accepted") }
        XCTAssertTrue(pipeline.isCleared)
        _ = pipeline.process(parts[1]); pipeline.close(); XCTAssertTrue(pipeline.isCleared)
        XCTAssertEqual(pipeline.process(scalar), .scanning); XCTAssertNil(pipeline.takeResult())
        let accepted = ScannerPipeline(configuration: .privateKey)
        _ = accepted.process(scalar); XCTAssertFalse(accepted.isCleared)
        accepted.close(); XCTAssertTrue(accepted.isCleared); XCTAssertNil(accepted.takeResult())
    }
    func testPhotoDecodesQRInMemoryAndRejectsNonImage() throws {
        let data = try Self.qrPhoto(scalar)
        XCTAssertTrue(try ScannerPhotoDecoder.decode(data).contains(scalar))
        let pipeline = ScannerPipeline(configuration: .privateKey); defer { pipeline.close() }
        XCTAssertEqual(pipeline.processPhoto(data), .found("Private key · hex · 64 characters"))
        XCTAssertThrowsError(try ScannerPhotoDecoder.decode(Data("not an image".utf8)))
    }
    func testReusableConfigurationCanAcceptFutureNonKeyPayloads() throws {
        let config = ScannerConfiguration(instruction: "future flow", accept: { payload in
            ScanAcceptance(bytes: try payload.bytes.withUnsafeBytes(ScanBytes.copy), label: "Accepted")
        })
        let pipeline = ScannerPipeline(configuration: config); defer { pipeline.close() }
        XCTAssertEqual(pipeline.process("bitcoin:public-address"), .found("Accepted"))
    }
    func testUnrelatedCodeDoesNotDestroyMultipartProgress() throws {
        let parts = try vectors().seedParts, pipeline = ScannerPipeline(configuration: .privateKey)
        defer { pipeline.close() }
        XCTAssertEqual(pipeline.process(parts[0]), .progress(1,3))
        _ = pipeline.process("unrelated")
        XCTAssertEqual(pipeline.process(parts[1]), .progress(2,3))
        XCTAssertEqual(pipeline.process(parts[2]), .found("Recovery phrase found · 12 words"))
    }
    func testClosingDuringPhotoDecodeCannotResurrectResult() async throws {
        let photo = try Self.qrPhoto(scalar), pipeline = ScannerPipeline(configuration: .privateKey)
        let work = Task.detached { pipeline.processPhoto(photo) }
        pipeline.close()
        _ = await work.value
        XCTAssertTrue(pipeline.isCleared); XCTAssertNil(pipeline.takeResult())
    }
    func testPhotoIgnoresNonQRBarcodes() throws {
        let data = try Self.qrPhoto(scalar, filterName: "CIPDF417BarcodeGenerator")
        XCTAssertTrue(try ScannerPhotoDecoder.decode(data).isEmpty)
    }
    static func qrPhoto(_ text: String, filterName: String = "CIQRCodeGenerator") throws -> Data {
        let filter = try XCTUnwrap(CIFilter(name: filterName))
        filter.setValue(Data(text.utf8), forKey: "inputMessage"); if filterName == "CIQRCodeGenerator" { filter.setValue("M", forKey: "inputCorrectionLevel") }
        let qr = try XCTUnwrap(filter.outputImage).transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let image = try XCTUnwrap(CIContext().createCGImage(qr, from: qr.extent))
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil); XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

@MainActor final class ScannerLifecycleTests: XCTestCase {
    final class Permission: ScannerCameraPermission {
        var status: AVAuthorizationStatus = .notDetermined
        var requests = 0
        func request() async -> Bool { requests += 1; status = .authorized; return true }
    }
    final class Feedback: ScannerFeedback {
        var successes = 0; var errors = 0
        func success() { successes += 1 }; func error() { errors += 1 }
    }
    func testPermissionOnlyAtActivationAndDeniedStillAllowsPhoto() async throws {
        let permission = Permission(), session = SecretSession(), feedback = Feedback()
        let model = ScannerModel(session: session, permission: permission, feedback: feedback)
        XCTAssertEqual(permission.requests, 0)
        model.activate(); try await Task.sleep(for: .milliseconds(50))
        model.activate(); XCTAssertEqual(permission.requests, 1)
        permission.status = .denied; model.activate(); XCTAssertEqual(model.access, .unavailable)
        model.choosePhoto(); XCTAssertTrue(model.choosingPhoto)
        model.close(); XCTAssertTrue(model.isClosed); session.wipe()
    }
    func testSuccessWaitsThenImportsExactlyOnceAndStopsCamera() async throws {
        let session = SecretSession(), permission = Permission(), feedback = Feedback()
        permission.status = .authorized
        let model = ScannerModel(session: session, permission: permission, feedback: feedback)
        let entry = EnterKeyModel(session: session)
        var stopped = 0, imported = 0
        model.stopCamera = { stopped += 1 }
        model.onResult = { bytes in imported += 1; entry.importScanned(bytes) }
        model.activate(); model.receive(String(repeating: "0", count: 63) + "1")
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(model.isFound); XCTAssertEqual(imported, 0); XCTAssertEqual(feedback.successes, 1)
        XCTAssertGreaterThan(stopped, 0); XCTAssertFalse(model.shouldRunCamera)
        model.receive("ignored")
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(imported, 1); XCTAssertTrue(entry.canFind); XCTAssertTrue(model.isClosed)
        session.wipe()
    }
    func testDismissAndSessionExpiryCancelPendingResult() async throws {
        for wipe in [false,true] {
            let session = SecretSession(), permission = Permission(), feedback = Feedback()
            permission.status = .authorized
            let model = ScannerModel(session: session, permission: permission, feedback: feedback)
            var imported = false, stopped = false, cancelledPhoto = false
            model.onResult = { _ in imported = true }; model.stopCamera = { stopped = true }
            model.cancelPhotoLoad = { cancelledPhoto = true }
            model.activate(); model.receive(String(repeating: "0", count: 63) + "1")
            try await Task.sleep(for: .milliseconds(150))
            if wipe { session.wipe() } else { model.close() }
            try await Task.sleep(for: .milliseconds(650))
            XCTAssertFalse(imported); XCTAssertTrue(stopped); XCTAssertTrue(cancelledPhoto)
            XCTAssertTrue(model.isClosed); XCTAssertEqual(session.key.count,0)
        }
    }
    func testBackgroundAndPhotoStopCaptureAndTorch() {
        let session = SecretSession(), permission = Permission()
        permission.status = .authorized
        let model = ScannerModel(session: session, permission: permission, feedback: Feedback())
        var stopped = 0, torch = false
        model.stopCamera = { stopped += 1 }; model.setTorch = { torch = $0; return $0 }
        model.activate(); model.toggleTorch(); XCTAssertTrue(torch)
        model.pause(); XCTAssertFalse(torch); XCTAssertFalse(model.shouldRunCamera)
        model.activate(); XCTAssertTrue(model.shouldRunCamera)
        model.choosePhoto(); XCTAssertFalse(model.shouldRunCamera); XCTAssertGreaterThan(stopped, 1)
        var cancelledLoad = false
        model.cancelPhotoLoad = { cancelledLoad = true }
        model.receivePhoto(nil); XCTAssertTrue(model.shouldRunCamera); XCTAssertTrue(cancelledLoad)
        // A provider completion queued before cancellation must not begin decoding later.
        model.receivePhoto(Data("late provider completion".utf8))
        XCTAssertFalse(model.decodingPhoto); XCTAssertFalse(model.choosingPhoto)
        model.close(); session.wipe()
    }
}
