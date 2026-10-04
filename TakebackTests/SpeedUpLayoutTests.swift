import XCTest
import SwiftUI
@testable import Takeback

@MainActor final class SpeedUpLayoutTests: XCTestCase {
    func testOuterSafeAreaAndSplitColumnsFixtures() async throws {
        for index in [3,4] {
            let device = SpeedUpFixtures.devices[index]
            let metrics = LayoutMetrics(fullSize: .init(width: device.width, height: device.height), safeSize: .init(width: device.width - device.trailing, height: device.height - device.top - device.bottom), safeAreaInsets: .init(top: device.top, leading: 0, bottom: device.bottom, trailing: device.trailing))
            XCTAssertEqual(metrics.mode, index == 3 ? .compact : .split)
            if index == 4 { XCTAssertEqual((metrics.safeSize.width - 96 - 64) / 2, 365) }
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let content = SpeedUpPreviewCatalog(device: device, scheme: .dark)
            let controller = UIHostingController(rootView: content); controller.safeAreaRegions = []
            let window = UIWindow(windowScene: scene), container = UIViewController()
            window.rootViewController = container; window.overrideUserInterfaceStyle = .dark; window.isHidden = false
            defer { window.isHidden = true; window.rootViewController = nil }
            container.addChild(controller); container.view.addSubview(controller.view)
            controller.view.autoresizingMask = []; controller.view.frame = CGRect(x: 0, y: 0, width: device.width, height: device.height)
            controller.didMove(toParent: container); controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(150))
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let image = UIGraphicsImageRenderer(size: controller.view.bounds.size, format: format).image { _ in
                XCTAssertTrue(controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true))
            }
            let attachment = XCTAttachment(image: image); attachment.name = "speed-" + device.id; attachment.lifetime = .keepAlways; add(attachment)
        }
    }
}
