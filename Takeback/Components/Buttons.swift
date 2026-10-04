import SwiftUI

/// Toolbar actions use the platform's control sizing, typography and appearance.
/// No fixed-height label, capsule drawing, or custom pressed/disabled styling.
struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Toolbar presentation can collapse Label to an icon even when its
            // labelStyle is titleAndIcon. Keep the named action visible.
            HStack {
                if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
                Text(title)
            }
        }
        .accessibilityLabel(title)
        .font(.body.weight(.semibold))
        .buttonStyle(.automatic)
        .disabled(!isEnabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var filled = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.body)
            .buttonStyle(.automatic)
            .disabled(!isEnabled)
    }
}

struct NativeBottomBar<Actions: View>: ToolbarContent {
    @ViewBuilder let actions: () -> Actions

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            actions()
        }
    }
}
