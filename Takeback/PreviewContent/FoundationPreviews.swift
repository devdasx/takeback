#if DEBUG
import SwiftUI

/// Component-only fixture. Never linked into the app's navigation or launch path.
struct FoundationPreview: View {
    var body: some View {
        LayoutReader { metrics in
            AdaptiveLayout(metrics: metrics) {
                VStack(alignment: .leading, spacing: 16) {
                    AppLogo()
                    Text("Takeback").font(Geist.font(metrics.mode.titleSize, .semibold, relativeTo: .largeTitle))
                    SectionHeader(title: "Shared components")
                }
            } content: {
                ComponentSamples()
            }
        }
        .background(Theme.bg.ignoresSafeArea()).takebackStyle()
        .toolbar { NativeBottomBar {
            Group {
                    PrimaryButton(title: "Primary button") { }
                    SecondaryButton(title: "Secondary button") { }
                }
        } }
    }
}

private struct ComponentSamples: View {
    @StateObject private var session = SecretSession()
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            IndexRow(symbol: "arrow.up.right", title: "Index row", subtitle: "Supporting text", value: "12,345") { }
            IndexRow(symbol: "checkmark", title: "Static row", subtitle: "Text wraps at accessibility sizes")
            StatusChip(title: "Pending", status: .pending)
            StatusChip(title: "Confirmed", status: .success)
            StatusChip(title: "Error", status: .error)
            NoteCard(symbol: "info.circle", text: "A note using the shared card and text styles.")
            WarningCard(text: "A warning using the specified amber colors.")
            ProgressBar(progress: 0.45)
            Spinner()
            DotQRCode(payload: "bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
                .frame(width: 160, height: 160)
            SecretField(placeholder: "Secret", bytes: session.key, session: session)
            PrimaryButton(title: "Disabled primary", isEnabled: false) { }
            SecondaryButton(title: "Filled secondary", filled: true) { }
            SecondaryButton(title: "Disabled secondary", isEnabled: false) { }
        }
    }
}

#Preview("iPhone SE · light", traits: .fixedLayout(width: 375, height: 667)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 20) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 0) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.light)
}

#Preview("iPhone SE · dark", traits: .fixedLayout(width: 375, height: 667)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 20) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 0) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.dark)
}

#Preview("iPhone 17 Pro · light", traits: .fixedLayout(width: 402, height: 874)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 62) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 34) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.light)
}

#Preview("iPhone 17 Pro · dark", traits: .fixedLayout(width: 402, height: 874)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 62) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 34) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.dark)
}

#Preview("iPhone 17 Pro Max · light", traits: .fixedLayout(width: 440, height: 956)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 62) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 34) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.light)
}

#Preview("iPhone 17 Pro Max · dark", traits: .fixedLayout(width: 440, height: 956)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 62) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 34) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.dark)
}

#Preview("Duo outer · light", traits: .fixedLayout(width: 466, height: 678)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 0) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 34) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 84) }
        .preferredColorScheme(.light)
}

#Preview("Duo outer · dark", traits: .fixedLayout(width: 466, height: 678)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 0) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 34) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 84) }
        .preferredColorScheme(.dark)
}

#Preview("Duo inner · light", traits: .fixedLayout(width: 890, height: 626)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 32) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 20) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.light)
}

#Preview("Duo inner · dark", traits: .fixedLayout(width: 890, height: 626)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 32) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 20) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.dark)
}

#Preview("Duo inner rotated · light", traits: .fixedLayout(width: 626, height: 890)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 32) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 20) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.light)
}

#Preview("Duo inner rotated · dark", traits: .fixedLayout(width: 626, height: 890)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 32) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 20) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.dark)
}

#Preview("iPad mini portrait · light", traits: .fixedLayout(width: 744, height: 1133)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 24) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 20) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.light)
}

#Preview("iPad mini portrait · dark", traits: .fixedLayout(width: 744, height: 1133)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 24) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 20) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.dark)
}

#Preview("iPad mini landscape · light", traits: .fixedLayout(width: 1133, height: 744)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 24) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 20) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.light)
}

#Preview("iPad mini landscape · dark", traits: .fixedLayout(width: 1133, height: 744)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 24) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 20) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.dark)
}

#Preview("iPad Pro 13 landscape · light", traits: .fixedLayout(width: 1376, height: 1032)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 24) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 20) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.light)
}

#Preview("iPad Pro 13 landscape · dark", traits: .fixedLayout(width: 1376, height: 1032)) {
    FoundationPreview()
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 24) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 20) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 0) }
        .preferredColorScheme(.dark)
}

#Preview("AX5 · light", traits: .fixedLayout(width: 375, height: 667)) {
    FoundationPreview().dynamicTypeSize(.accessibility5).preferredColorScheme(.light)
}

#Preview("AX5 · dark", traits: .fixedLayout(width: 375, height: 667)) {
    FoundationPreview().dynamicTypeSize(.accessibility5).preferredColorScheme(.dark)
}

#endif
