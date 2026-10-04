import SwiftUI

/// Static, noninteractive example. No clock or animation state belongs to Welcome.
struct WelcomeHero: View {
    let mode: LayoutMode
    let isShort: Bool
    @Environment(\.colorScheme) private var scheme
    private var amountSize: CGFloat { isShort && mode == .compact ? 30 : mode == .compact ? 34 : mode == .wide ? 40 : 36 }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 7) {
                    Circle().fill(Color(hex: 0xE5A100)).frame(width: 6, height: 6)
                    Text("Stuck · 3 hours").font(Geist.font(12, .medium))
                        .foregroundStyle(Color(hex: scheme == .dark ? 0xF5B83D : 0x9A5B00))
                }.padding(.horizontal, 10).frame(minHeight: 26)
                    .background(Color(hex: 0xE5A100).opacity(0.14), in: RoundedRectangle(cornerRadius: 13))
                Spacer(minLength: 0)
                Text("8 sat/vB").font(Geist.font(12)).monospacedDigit().foregroundStyle(Theme.mute)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("0.04210 BTC").font(Geist.font(amountSize, .medium)).tracking(-0.04 * amountSize).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                Text("Sent to bc1qx9…7tkd").font(Geist.font(13)).foregroundStyle(Theme.mute)
            }
        }.padding(16).padding(6).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Example: a payment stuck for 3 hours").accessibilityIdentifier("welcome.hero")
    }
}
