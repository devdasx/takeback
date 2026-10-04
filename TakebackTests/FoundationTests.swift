import XCTest
import SwiftUI
import UIKit
import CoreImage
@testable import Takeback

final class LayoutTests: XCTestCase {
    func testSpecifiedDeviceModesAndShortHeights() {
        let fixtures: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, LayoutMode)] = [
            (375,667,20,0,0,0,.compact), (375,812,50,34,0,0,.compact),
            (390,844,47,34,0,0,.compact), (393,852,59,34,0,0,.compact),
            (430,932,59,34,0,0,.compact), (402,874,62,34,0,0,.compact),
            (420,912,68,34,0,0,.compact), (440,956,62,34,0,0,.compact),
            (466,678,0,34,0,84,.compact), (890,626,32,20,0,0,.split),
            (626,890,32,20,0,0,.wide), (744,1133,24,20,0,0,.wide),
            (1133,744,24,20,0,0,.split), (820,1180,24,20,0,0,.wide),
            (1180,820,24,20,0,0,.split), (834,1210,24,20,0,0,.wide),
            (1210,834,24,20,0,0,.split), (1024,1366,24,20,0,0,.wide),
            (1366,1024,24,20,0,0,.split), (1032,1376,24,20,0,0,.wide),
            (1376,1032,24,20,0,0,.split)
        ]
        for (w,h,top,bottom,leading,trailing,expected) in fixtures {
            let metrics = LayoutMetrics(fullSize: CGSize(width:w,height:h),
                safeSize: CGSize(width:w-leading-trailing,height:h-top-bottom),
                safeAreaInsets: EdgeInsets(top:top,leading:leading,bottom:bottom,trailing:trailing))
            XCTAssertEqual(metrics.mode, expected, "\(w) × \(h)")
            XCTAssertEqual(metrics.isShort, h-top-bottom < 640)
        }
    }
    func testModeBoundariesAndPaddingClamp() {
        XCTAssertEqual(LayoutMode.mode(fullW: 799, fullH: 600, W: 799), .wide)
        XCTAssertEqual(LayoutMode.mode(fullW: 800, fullH: 600, W: 800), .split)
        XCTAssertEqual(LayoutMode.mode(fullW: 600, fullH: 900, W: 599), .compact)
        XCTAssertEqual(LayoutMode.mode(fullW: 600, fullH: 900, W: 600), .wide)
        XCTAssertEqual(LayoutMode.wide.bottomPadding(safeHeight: 100), 40)
        XCTAssertEqual(LayoutMode.wide.bottomPadding(safeHeight: 1000), 80)
        XCTAssertEqual(LayoutMode.wide.bottomPadding(safeHeight: 2000), 120)
        XCTAssertEqual(LayoutMode.compact.bottomPadding(safeHeight: 900), 16)
        XCTAssertEqual(LayoutMode.split.bottomPadding(safeHeight: 900), 24)
    }
}

final class SecurityTests: XCTestCase {
    func testOwnedMemoryIsZeroedAndDescriptionRedacted() throws {
        let bytes = SecureBytes(capacity: 16)
        try bytes.replace(with: [1,2,3,4])
        XCTAssertEqual(bytes.count, 4)
        bytes.withUnsafeBytes { pointer in
            XCTAssertEqual(Array(pointer), [1,2,3,4])
            bytes.wipe()
            XCTAssertTrue(pointer.allSatisfy { $0 == 0 })
        }
        XCTAssertEqual(bytes.count, 0)
        XCTAssertEqual(bytes.description, "<SecureBytes: redacted>")
    }
    func testOversizedInputDoesNotPartiallyReplaceSecret() throws {
        let bytes = SecureBytes(capacity: 3)
        try bytes.replace(with: [1,2])
        XCTAssertThrowsError(try bytes.replace(with: [3,4,5,6]))
        XCTAssertEqual(bytes.withUnsafeBytes(Array.init), [1,2])
    }
    @MainActor func testEveryExplicitExitWipesBothBuffersAndEditor() throws {
        let session = SecretSession()
        var editorClears = 0
        let id = session.registerEditorClear { editorClears += 1 }
        for reason in 0..<3 {
            try session.key.replace(with: [1,2])
            try session.passphrase.replace(with: [3])
            switch reason {
            case 0: session.returnedToWelcome()
            case 1: session.completedCancellation()
            default: session.applicationWillTerminate()
            }
            XCTAssertEqual(session.key.count, 0)
            XCTAssertEqual(session.passphrase.count, 0)
        }
        XCTAssertEqual(editorClears, 3)
        session.unregisterEditorClear(id)
    }
    @MainActor func testBackgroundDeadlineAndEarlyReturn() throws {
        let session = SecretSession()
        try session.key.replace(with: [1])
        session.enteredBackground(now: 100, requestExecutionTime: false)
        session.becameActive(now: 159)
        XCTAssertEqual(session.key.count, 1)
        session.enteredBackground(now: 500, requestExecutionTime: false)
        session.enteredBackground(now: 600, requestExecutionTime: false) // Does not extend the deadline.
        session.becameActive(now: 800)
        XCTAssertEqual(session.key.count, 0)
    }
    @MainActor func testSecretFieldDisablesCopyAndCut() {
        let field = ProtectedTextField()
        field.text = "synthetic test text"
        XCTAssertFalse(field.canPerformAction(#selector(UIResponderStandardEditActions.copy(_:)), withSender: nil))
        XCTAssertFalse(field.canPerformAction(#selector(UIResponderStandardEditActions.cut(_:)), withSender: nil))
    }
}

final class DesignSystemTests: XCTestCase {
    @MainActor func testAllGeistWeightsAreBundled() {
        for weight in Geist.Weight.allCases {
            let font = UIFont(name: weight.rawValue, size: 17)
            XCTAssertNotNil(font)
            XCTAssertEqual(font?.familyName, "Geist")
        }
    }
    @MainActor func testExactDynamicColorTokens() {
        for (color, light, dark) in [
            (Theme.bg, 0xF7F7F5, 0x0B0B0B), (Theme.fg, 0x121211, 0xF4F4F1),
            (Theme.mute, 0x86867F, 0x808079), (Theme.line, 0xE3E3DE, 0x252524),
            (Theme.card, 0xECECE8, 0x181817)
        ] {
            for (style, expected) in [(UIUserInterfaceStyle.light, light), (.dark, dark)] {
                var environment = EnvironmentValues(); environment.colorScheme = style == .dark ? .dark : .light
                let resolved = color.resolve(in: environment)
                let r = resolved.red, g = resolved.green, b = resolved.blue
                XCTAssertEqual(Int((r*255).rounded()) << 16 | Int((g*255).rounded()) << 8 | Int((b*255).rounded()), expected)
            }
        }
    }
    @MainActor func testRenderedDottedQRCodeDecodes() throws {
        let payload = "bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
        let renderer = ImageRenderer(content: DotQRCode(payload: payload).frame(width: 300, height: 300))
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.cgImage)
        let attachment = XCTAttachment(image:UIImage(cgImage:image)); attachment.name="Dotted-QR"; attachment.lifetime = .keepAlways; add(attachment)
        let detector = try XCTUnwrap(CIDetector(ofType: CIDetectorTypeQRCode,
            context: CIContext(options: [.useSoftwareRenderer: true]),
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
        let features = detector.features(in: CIImage(cgImage: image))
        XCTAssertEqual((features.first as? CIQRCodeFeature)?.messageString, payload)
    }
}
