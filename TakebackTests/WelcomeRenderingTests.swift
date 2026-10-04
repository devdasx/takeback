import XCTest
import SwiftUI
@testable import Takeback

@MainActor final class WelcomeRenderingTests: XCTestCase {
    func testWelcomeDeviceAndStateMatrix() async throws {
        for device in WelcomeDeviceFixture.requested {
            for scheme in [ColorScheme.light, .dark] {
                for state in [WelcomePreview.State.welcome] {
                    try await render(WelcomeFixturePreview(device: device, state: state, scheme: scheme),
                                     size: CGSize(width: device.width, height: device.height),
                                     name: "\(device.id)-\(scheme)-\(state)", scheme: scheme)
                }
                try await render(WelcomeFixturePreview(device: device, state: .welcome, scheme: scheme)
                    .dynamicTypeSize(.accessibility3),
                    size: CGSize(width: device.width, height: device.height),
                    name: "\(device.id)-\(scheme)-AX3", scheme: scheme)
            }
        }
    }

    func testHowItWorksContentAtPhoneAndTabletWidths() async throws {
        for width: CGFloat in [335, 362, 400, 342, 309, 486, 500, 540] {
            for scheme in [ColorScheme.light, .dark] {
                for ax in [false, true] {
                    let content = HowItWorksContent().padding(20)
                        .dynamicTypeSize(ax ? .accessibility3 : .large)
                        .frame(width: width)
                        .background(Theme.bg)
                        .environment(\.colorScheme, scheme)
                    let controller = UIHostingController(rootView: content)
                    let fit = controller.sizeThatFits(in: CGSize(width: width, height: 10_000))
                    XCTAssertGreaterThan(fit.height, 200)
                    try await render(content, size: fit,
                        name: "Explanation-\(Int(width))-\(scheme)-\(ax ? "AX3" : "standard")", scheme: scheme)
                }
            }
        }
    }

    private func render<V: View>(_ content: V, size: CGSize, name: String, scheme: ColorScheme) async throws {
        let controller = UIHostingController(rootView: content)
        controller.safeAreaRegions = []
        controller.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(60))
        controller.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            XCTAssertTrue(controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true))
        }
        let pixels = try XCTUnwrap(image.cgImage?.dataProvider?.data)
        let bytes = try XCTUnwrap(CFDataGetBytePtr(pixels))
        XCTAssertGreaterThan(Set(UnsafeBufferPointer(start: bytes, count: CFDataGetLength(pixels))).count,
                             16, "The rendered fixture must contain visible content, not a blank surface.")
        let png = try XCTUnwrap(image.pngData())
        XCTAssertGreaterThan(png.count, 1000)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("WelcomeRenders")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: folder.appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
