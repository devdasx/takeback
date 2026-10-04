import SwiftUI

/// Original Takeback controls: opaque capsules, without system glass treatment.
struct PrimaryButton: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    var symbol: String? = nil
    var isEnabled = true
    var height: CGFloat = 60
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
                Text(title)
            }
            .font(typeSize.isAccessibilitySize ? .custom(Geist.Weight.medium.rawValue, fixedSize: 17) : Geist.font(17, .medium))
            .lineLimit(1).minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity).frame(height: height)
            .foregroundStyle(Theme.bg)
            .background(Theme.fg, in: Capsule())
            .contentShape(Capsule())
        }
        .accessibilityLabel(title)
        .buttonStyle(TakebackPressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
    }
}

struct SecondaryButton: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    var symbol: String? = nil
    var filled = false
    var isEnabled = true
    var plain = false
    var height: CGFloat = 52
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 10) {
                if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
                Text(title)
            }
                .font(typeSize.isAccessibilitySize ? .custom(Geist.Weight.medium.rawValue, fixedSize: plain ? 16 : 17) : Geist.font(plain ? 16 : 17, .medium))
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity).frame(height: height)
                .foregroundStyle(role == .destructive ? Theme.red : Theme.fg)
                .background(filled ? Theme.card : .clear, in: Capsule())
                .overlay { if !plain && !filled { Capsule().strokeBorder(Theme.line, lineWidth: 1) } }
                .contentShape(Capsule())
        }
        .accessibilityLabel(title)
        .buttonStyle(TakebackPressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
    }
}

private struct TakebackPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct BottomActions<Actions: View>: ViewModifier {
    let isVisible: Bool
    let welcome: Bool
    let adaptsToSplit: Bool
    @ViewBuilder let actions: () -> Actions

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let mode = LayoutMode.mode(
                fullW: proxy.size.width + insets.leading + insets.trailing,
                fullH: proxy.size.height + insets.top + insets.bottom,
                W: proxy.size.width)
            content.safeAreaInset(edge: .bottom, spacing: 0) {
                if isVisible {
                    HStack(spacing: 0) {
                        if mode == .split && adaptsToSplit { Color.clear.frame(maxWidth: .infinity).frame(height: 1) }
                        VStack(spacing: welcome ? 6 : 12) { actions() }
                            .frame(maxWidth: mode == .compact ? .infinity : welcome ? (mode == .split ? 380 : 420) : (mode == .split && adaptsToSplit ? 440 : 520))
                            .padding(.horizontal, welcome ? 24 : mode.horizontalPadding)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 12).padding(.bottom, 16)
                    .background(Theme.bg)
                }
            }
        }
    }
}

extension View {
    /// Safe-area placement keeps the original controls above the home indicator and keyboard.
    func bottomActions<Actions: View>(isVisible: Bool = true, welcome: Bool = false,
                                     adaptsToSplit: Bool = true, @ViewBuilder content: @escaping () -> Actions) -> some View {
        modifier(BottomActions(isVisible: isVisible, welcome: welcome, adaptsToSplit: adaptsToSplit, actions: content))
    }
}
