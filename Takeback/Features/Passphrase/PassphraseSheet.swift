import SwiftUI

struct PassphraseSheet: View {
    @StateObject private var model: PassphraseModel
    @Environment(\.dismiss) private var dismiss
    @State private var contentHeight: CGFloat = 360
    @State private var topInset: CGFloat = 56

    init(session: SecretSession, model: PassphraseModel? = nil) {
        _model = StateObject(wrappedValue: model ?? PassphraseModel(session: session))
    }
    var body: some View {
        NativeSheet(title: "Passphrase", detents: [.height(contentHeight + topInset + (model.isEditing ? 80 : 0))],
                    onClose: model.discard, doneEnabled: model.canSave,
                    onDone: { model.save { dismiss() } }) {
            GeometryReader { geometry in
                ScrollView {
                    PassphraseContent(model: model)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            GeometryReader { content in
                                Color.clear.preference(key: PassphraseHeightKey.self, value: content.size.height)
                            }
                        }
                }
                .accessibilityIdentifier("passphrase.content")
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .onAppear { topInset = geometry.safeAreaInsets.top }
                .onChange(of: geometry.safeAreaInsets.top) { _, value in topInset = value }
            }
            .background(Theme.bg.ignoresSafeArea())
            .onPreferenceChange(PassphraseHeightKey.self) { contentHeight = $0 }
            .bottomActions(isVisible: model.isEditing, adaptsToSplit: false) {
                SecondaryButton(title: "Remove passphrase", role: .destructive) { model.remove(); dismiss() }
                    .accessibilityIdentifier("passphrase.remove")
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.discard() }
        .onChange(of: model.isClosed) { _, closed in if closed { dismiss() } }
    }
}

struct PassphraseContent: View {
    @ObservedObject var model: PassphraseModel
    var autofocus = true

    private var fingerprint: String { model.fingerprints.map { WalletFingerprints.formatted($0.withPassphrase) } ?? "—" }
    private var base: String { model.baseFingerprint.map(WalletFingerprints.formatted) ?? "—" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Only if your wallet used one. It’s sometimes called the 25th word.")
                .font(Geist.font(13)).foregroundStyle(Theme.mute)
            VStack(alignment: .leading, spacing: 8) {
                PassphraseField(model: model, autofocus: autofocus)
                if model.startsWithSpace { warning("Starts with a space") }
                if model.endsWithSpace { warning("Ends with a space") }
            }
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fingerprint").font(Geist.font(13)).foregroundStyle(Theme.mute)
                    Text("With this passphrase · \(fingerprint)")
                        .font(Geist.font(15, .semibold)).monospacedDigit()
                        .accessibilityIdentifier("passphrase.fingerprint")
                    Text("Without a passphrase · \(base)")
                        .font(Geist.font(13)).monospacedDigit().foregroundStyle(Theme.mute)
                }
                Text("Only if your wallet used one. Check the fingerprint matches your wallet. Without a passphrase it’s \(base).")
                    .font(Geist.font(13)).foregroundStyle(Theme.mute)
                Text("Every passphrase opens a different wallet. Case, spaces and symbols count.")
                    .font(Geist.font(13)).foregroundStyle(Theme.mute)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

        }
        .fixedSize(horizontal: false, vertical: true)
        .takebackStyle()
    }
    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(Geist.font(13, .medium)).foregroundStyle(Theme.amberText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PassphraseHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
