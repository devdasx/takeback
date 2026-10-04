import XCTest
import SwiftUI
@testable import Takeback

@MainActor final class ScannerRenderingTests: XCTestCase {
    func testEveryStateAndSizeBothAppearances() async throws {
        for device in WelcomeDeviceFixture.requested {
            for scheme in [ColorScheme.light, .dark] {
                for state in ScannerPreviewStore.State.allCases { try await render(device, state, scheme, ax: false) }
            }
        }
    }
    func testAccessibilityFiveErrorAndPermissionLayouts() async throws {
        for device in WelcomeDeviceFixture.requested {
            for state in [ScannerPreviewStore.State.wrong, .noCamera] { try await render(device, state, .dark, ax: true) }
        }
    }
    func testPhotoFeedbackWithDeniedCamera() async throws {
        for state in [ScannerPreviewStore.State.found, .wrong] {
            try await render(.requested[0], state, .dark, ax: false, cameraDenied: true)
        }
    }
    private func render(_ device: WelcomeDeviceFixture, _ state: ScannerPreviewStore.State, _ scheme: ColorScheme, ax: Bool, cameraDenied: Bool = false) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let controller = UIHostingController(rootView: ScannerFixturePreview(device: device, state: state, cameraDenied: cameraDenied)
            .environment(\.colorScheme, scheme).dynamicTypeSize(ax ? .accessibility5 : .large))
        controller.safeAreaRegions = []
        let window = UIWindow(windowScene: scene), container = UIViewController()
        window.rootViewController = container; window.isHidden = false
        window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
        defer { window.isHidden = true; window.rootViewController = nil }
        container.addChild(controller); container.view.addSubview(controller.view)
        controller.view.autoresizingMask = []
        controller.view.frame = CGRect(x: 0, y: 0, width: device.width, height: device.height)
        controller.didMove(toParent: container); controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(90))
        controller.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: controller.view.bounds.size, format: format).image { _ in
            XCTAssertTrue(controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true))
        }
        let name = (cameraDenied ? "PhotoDenied-" : "") + "\(device.id)-\(scheme)-\(state.rawValue)-\(ax ? "AX5" : "standard")"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ScannerRenders")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
