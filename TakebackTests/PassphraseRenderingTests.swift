import XCTest
import SwiftUI
@testable import Takeback

@MainActor final class PassphraseRenderingTests: XCTestCase {
    func testEveryStateAndDeviceInLightAndDark() async throws {
        for device in WelcomeDeviceFixture.requested {
            for scheme in [ColorScheme.light, .dark] {
                for state in PassphrasePreviewStore.State.allCases {
                    try await render(device: device, state: state, scheme: scheme, ax: false)
                }
            }
        }
    }
    func testAllDeviceLayoutsAtAccessibilitySize() async throws {
        for device in WelcomeDeviceFixture.requested {
            for scheme in [ColorScheme.light, .dark] {
                try await render(device: device, state: .edit, scheme: scheme, ax: true)
            }
        }
    }
    private func render(device: WelcomeDeviceFixture, state: PassphrasePreviewStore.State,
                        scheme: ColorScheme, ax: Bool) async throws {
        let store = PassphrasePreviewStore(state: state)
        store.model.start()
        defer { store.model.discard(); store.session.wipe() }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let content = PassphraseRenderLayout(store: store, state: state, device: device)
            .dynamicTypeSize(ax ? .accessibility5 : .large)
            .environment(\.colorScheme, scheme)
        let controller = UIHostingController(rootView: content)
        controller.safeAreaRegions = []
        let window = UIWindow(windowScene: scene)
        let container = UIViewController()
        window.rootViewController = container
        window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        container.addChild(controller); container.view.addSubview(controller.view)
        controller.view.autoresizingMask = []
        controller.view.frame = CGRect(x: 0, y: 0, width: device.width, height: device.height)
        controller.didMove(toParent: container)
        controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertNotNil(store.model.fingerprints)
        controller.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: controller.view.bounds.size, format: format).image { _ in
            XCTAssertTrue(controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true))
        }
        let data = try XCTUnwrap(image.cgImage?.dataProvider?.data)
        let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
        XCTAssertGreaterThan(Set(UnsafeBufferPointer(start: bytes, count: CFDataGetLength(data))).count, 16)
        let name = "\(device.id)-\(scheme)-\(state)-\(ax ? "AX5" : "standard")"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PassphraseRenders")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}

/// Content layout fixtures. Actual native sheet, keyboard and detents are checked in UI tests.
private struct PassphraseRenderLayout: View {
    @ObservedObject var store: PassphrasePreviewStore
    let state: PassphrasePreviewStore.State
    let device: WelcomeDeviceFixture
    var body: some View {
        Group {
            if state == .set {
                EnterKeyView(router: store.router, session: store.session)
            } else {
                NativeSheet(title: "Passphrase", doneEnabled: store.model.canSave, onDone: { }) {
                    ScrollView {
                        PassphraseContent(model: store.model, autofocus: false)
                            .padding(20).frame(maxWidth: 520)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }.background(Theme.bg)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: device.top) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: device.bottom) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: device.trailing) }
        .background(Theme.bg)
    }
}
