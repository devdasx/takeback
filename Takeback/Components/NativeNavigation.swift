import SwiftUI

/// Keep the system back item and transition machinery intact. Hiding/replacing
/// the back item disables UIKit's interactive pop; no gesture delegate overrides
/// or custom drag recognizers are needed for ordinary pushed screens.
private struct NativeNavigation: ViewModifier {
    let title: String
    let backEnabled: Bool

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(!backEnabled)
            .toolbar(backEnabled ? .visible : .hidden, for: .navigationBar)
    }
}

extension View {
    func nativeNavigation(title: String = "", backEnabled: Bool = true) -> some View {
        modifier(NativeNavigation(title: title, backEnabled: backEnabled))
    }
}

/// UIKit can restore an outgoing text view as first responder after an
/// interactive pop before SwiftUI has restored its keyboard safe area. Key
/// entry deliberately returns out of editing; a tap can begin editing again.
struct NavigationEditingBoundary: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewWillDisappear(_ animated: Bool) {
            view.window?.endEditing(true)
            super.viewWillDisappear(animated)
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            view.window?.endEditing(true)
        }
    }
}
