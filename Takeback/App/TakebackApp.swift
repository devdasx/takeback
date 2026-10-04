import SwiftUI

@main struct TakebackApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup {
            TakebackRoot()
                .environmentObject(SecretSession.shared)
        }
    }
}

@MainActor final class AppDelegate: NSObject, UIApplicationDelegate {
    private var privacy: AppPrivacyCoordinator?
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        privacy = AppPrivacyCoordinator(session: .shared)
        return true
    }
    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool { false }
    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool { false }
    func application(_ application: UIApplication, shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool {
        // Recovery material must not be sent to a third-party keyboard extension.
        extensionPointIdentifier != .keyboard
    }
}
