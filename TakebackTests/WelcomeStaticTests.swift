import XCTest
import SwiftUI
@testable import Takeback

@MainActor final class WelcomeStaticTests: XCTestCase {
    func testStaticWelcomePixelsDoNotChangeAfterTwoSeconds() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = UIHostingController(rootView: WelcomeView(router: WelcomeRouter(session: SecretSession())).environment(\.colorScheme, .light))
        window.rootViewController = controller; window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        let first = capture(controller.view)
        try await Task.sleep(for: .seconds(2))
        let second = capture(controller.view)
        XCTAssertEqual(first.pngData(), second.pngData())
        let attachment = XCTAttachment(image: second); attachment.name = "welcome-static"; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func capture(_ view: UIView) -> UIImage {
        view.layoutIfNeeded()
        return UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
            XCTAssertTrue(view.drawHierarchy(in: view.bounds, afterScreenUpdates: true))
        }
    }
}
