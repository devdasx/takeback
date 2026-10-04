import XCTest
import SwiftUI
@testable import Takeback

@MainActor final class FindingRenderingTests: XCTestCase {
    func testEveryDetectionStateInLightAndDark() async throws {
        for state in FindingPreviewStore.names.indices {
            for scheme in [ColorScheme.light, .dark] {
                try await render(device: .requested[1], state: state, scheme: scheme, ax: false)
            }
        }
    }
    func testAllStatesAtEveryDeviceSize() async throws {
        for device in WelcomeDeviceFixture.requested where device.id != WelcomeDeviceFixture.requested[1].id {
            for state in FindingPreviewStore.names.indices {
                for scheme in [ColorScheme.light, .dark] {
                    try await render(device: device, state: state, scheme: scheme, ax: false)
                }
            }
        }
    }
    func testAllLayoutFixturesWithAccessibilityText() async throws {
        for device in WelcomeDeviceFixture.requested {
            for scheme in [ColorScheme.light, .dark] {
                for state in [1,6,9] { try await render(device: device, state: state, scheme: scheme, ax: true) }
            }
        }
    }
    private func render(device: WelcomeDeviceFixture, state: Int, scheme: ColorScheme, ax: Bool) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let content = FindingFixturePreview(device: device, state: state, scheme: scheme)
            .dynamicTypeSize(ax ? .accessibility5 : .large)
            .environment(\.colorScheme, scheme)
        let controller = UIHostingController(rootView: content)
        controller.safeAreaRegions = []
        let window = UIWindow(windowScene: scene)
        // Keep the real window at the host's dimensions. A manually sized child
        // prevents UIKit from shifting larger fixtures to the host phone's safe area.
        let container = UIViewController()
        window.rootViewController = container
        window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        container.addChild(controller)
        container.view.addSubview(controller.view)
        controller.view.autoresizingMask = []
        controller.view.frame = CGRect(x: 0, y: 0, width: device.width, height: device.height)
        controller.didMove(toParent: container)
        controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(80))
        controller.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: controller.view.bounds.size, format: format).image { _ in
            XCTAssertTrue(controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true))
        }
        let data = try XCTUnwrap(image.cgImage?.dataProvider?.data)
        let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
        XCTAssertGreaterThan(Set(UnsafeBufferPointer(start: bytes, count: CFDataGetLength(data))).count, 16)
        let name = "\(device.id)-\(scheme)-\(FindingPreviewStore.names[state])-\(ax ? "AX5" : "standard")"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("FindingRenders")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
