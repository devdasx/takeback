import SwiftUI
import UIKit

/// Attach to any view displaying secret material, including future scanner/passphrase views.
private struct SecretPrivacy: ViewModifier {
    @State private var captured = true
    @State private var isVisible = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var screenshotAlert = false

    func body(content: Content) -> some View {
        content
            .privacySensitive()
            .blur(radius: captured ? 16 : 0, opaque: captured)
            .allowsHitTesting(!captured)
            .accessibilityHidden(captured)
            .background(CaptureObserver(isCaptured: $captured))
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
                guard isVisible, scenePhase == .active else { return }
                screenshotAlert = true
            }
            .alert("Screenshots aren’t safe", isPresented: $screenshotAlert) {
                Button("OK", role: .cancel) { }
            }
    }
}

extension View {
    func secretPrivacy() -> some View { modifier(SecretPrivacy()) }
}

private struct CaptureObserver: UIViewRepresentable {
    @Binding var isCaptured: Bool
    func makeUIView(context: Context) -> CaptureProbe {
        let probe = CaptureProbe()
        probe.changed = { isCaptured = $0 }
        return probe
    }
    func updateUIView(_ uiView: CaptureProbe, context: Context) { }

    final class CaptureProbe: UIView {
        var changed: ((Bool) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            guard let screen = window?.windowScene?.screen else { return }
            changed?(screen.isCaptured)
            NotificationCenter.default.addObserver(self, selector: #selector(captureChanged),
                name: UIScreen.capturedDidChangeNotification, object: screen)
        }
        @objc private func captureChanged() {
            guard let screen = window?.windowScene?.screen else { return }
            changed?(screen.isCaptured)
        }
        deinit { NotificationCenter.default.removeObserver(self) }
    }
}

/// Synchronous native window cover is installed before UIKit captures the app switcher.
/// A window-level cover also obscures presented system sheets, unlike a root-view overlay.
@MainActor final class AppPrivacyCoordinator: NSObject {
    private var covers: [UIWindow] = []
    private let session: SecretSession

    init(session: SecretSession) {
        self.session = session
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(inactive), name: UIApplication.willResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(active), name: UIApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(terminate), name: UIApplication.willTerminateNotification, object: nil)
    }

    @objc private func inactive() {
        guard covers.isEmpty else { return }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            window.rootViewController = UIHostingController(rootView: AppSwitcherCover())
            window.isUserInteractionEnabled = false
            window.isHidden = false
            covers.append(window)
        }
    }
    @objc private func background() { session.enteredBackground() }
    @objc private func active() {
        session.becameActive()
        covers.forEach { $0.isHidden = true }
        covers.removeAll()
    }
    @objc private func terminate() { session.applicationWillTerminate() }
}

struct AppSwitcherCover: View {
    var body: some View {
        ZStack { Theme.bg.ignoresSafeArea(); AppLogo() }.takebackStyle()
    }
}
