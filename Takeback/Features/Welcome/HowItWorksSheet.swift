import SwiftUI

struct HowItWorksSheet: View {
    let availableHeight: CGFloat
    @State private var contentHeight: CGFloat = 0
    @State private var topInset: CGFloat = 0

    var sizing: HowItWorksSizing {
        HowItWorksSizing(measuredHeight: contentHeight > 0 ? contentHeight + topInset : 0, availableHeight: availableHeight)
    }

    var body: some View {
        NativeSheet(title: "How it works", detents: sizing.detents) {
            GeometryReader { geometry in
                ScrollView {
                    HowItWorksContent()
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            GeometryReader { content in
                                Color.clear.preference(key: HowItWorksHeightKey.self, value: content.size.height)
                            }
                        }
                }
                .scrollBounceBehavior(.basedOnSize)
                .onAppear { topInset = geometry.safeAreaInsets.top }
                .onChange(of: geometry.safeAreaInsets.top) { _, inset in topInset = inset }
            }
            .onPreferenceChange(HowItWorksHeightKey.self) { contentHeight = $0 }
        }
    }
}

struct HowItWorksContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                step(1, title: "Find the payment", description: "Paste its transaction ID or scan the wallet it came from.")
                step(2, title: "Prove it’s yours", description: "Enter the recovery phrase or key that sent it. It stays on this iPhone.")
                step(3, title: "Send it back with a higher fee", description: "Takeback replaces the payment with one to your own address, so the original can’t confirm.")
            }
            NoteCard(symbol: "info.circle",
                     text: "Once a payment confirms, it’s final. The recipient may still see the original payment briefly before it’s replaced.",
                     title: "When it can’t work")
        }
        .takebackStyle()
    }

    private func step(_ number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number, format: .number)
                .font(.custom(Geist.Weight.semibold.rawValue, fixedSize: 13)).monospacedDigit()
                .foregroundStyle(Theme.bg).frame(width: 28, height: 28)
                .background(Theme.fg, in: Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(Geist.font(16, .semibold))
                Text(description).font(Geist.font(14)).foregroundStyle(Theme.mute)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HowItWorksHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
