#if DEBUG
import SwiftUI

@MainActor final class PassphrasePreviewStore: ObservableObject {
    enum State: String, CaseIterable { case empty, typed, trailingSpace, set, edit }
    let session = SecretSession()
    let model: PassphraseModel
    let router: WelcomeRouter
    init(state: State) {
        try! session.key.replace(with: EnterKeyFixtures.states[1].input.utf8)
        if state == .edit || state == .set { try! session.passphrase.replace(with: "TREZOR".utf8) }
        model = PassphraseModel(session: session)
        router = WelcomeRouter(session: session)
        if state == .typed || state == .trailingSpace {
            try! model.draft.replace(with: (state == .typed ? "TREZOR" : "TREZOR ").utf8)
            model.edited()
        }
    }
}

/// Live native sheet preview. Every value is public synthetic test data.
struct PassphraseFixturePreview: View {
    let device: WelcomeDeviceFixture
    let state: PassphrasePreviewStore.State
    let scheme: ColorScheme
    @StateObject private var store: PassphrasePreviewStore
    @State private var presented = false
    init(device: WelcomeDeviceFixture, state: PassphrasePreviewStore.State, scheme: ColorScheme) {
        self.device = device; self.state = state; self.scheme = scheme
        _store = StateObject(wrappedValue: PassphrasePreviewStore(state: state))
    }
    var body: some View {
        EnterKeyView(router: store.router, session: store.session)
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: device.top) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: device.bottom) }
            .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: device.trailing) }
            .sheet(isPresented: $presented) { PassphraseSheet(session: store.session, model: store.model) }
            .preferredColorScheme(scheme)
            .onAppear { presented = state != .set }
    }
}

#Preview("iPhone SE · light · empty", traits: .fixedLayout(width: 375, height: 667)) {
    PassphraseFixturePreview(device: .requested[0], state: .empty, scheme: .light)
}

#Preview("iPhone SE · light · typed", traits: .fixedLayout(width: 375, height: 667)) {
    PassphraseFixturePreview(device: .requested[0], state: .typed, scheme: .light)
}

#Preview("iPhone SE · light · trailingSpace", traits: .fixedLayout(width: 375, height: 667)) {
    PassphraseFixturePreview(device: .requested[0], state: .trailingSpace, scheme: .light)
}

#Preview("iPhone SE · light · set", traits: .fixedLayout(width: 375, height: 667)) {
    PassphraseFixturePreview(device: .requested[0], state: .set, scheme: .light)
}

#Preview("iPhone SE · light · edit", traits: .fixedLayout(width: 375, height: 667)) {
    PassphraseFixturePreview(device: .requested[0], state: .edit, scheme: .light)
}

#Preview("iPhone SE · dark · empty", traits: .fixedLayout(width: 375, height: 667)) {
    PassphraseFixturePreview(device: .requested[0], state: .empty, scheme: .dark)
}

#Preview("iPhone SE · dark · typed", traits: .fixedLayout(width: 375, height: 667)) {
    PassphraseFixturePreview(device: .requested[0], state: .typed, scheme: .dark)
}

#Preview("iPhone SE · dark · trailingSpace", traits: .fixedLayout(width: 375, height: 667)) {
    PassphraseFixturePreview(device: .requested[0], state: .trailingSpace, scheme: .dark)
}

#Preview("iPhone SE · dark · set", traits: .fixedLayout(width: 375, height: 667)) {
    PassphraseFixturePreview(device: .requested[0], state: .set, scheme: .dark)
}

#Preview("iPhone SE · dark · edit", traits: .fixedLayout(width: 375, height: 667)) {
    PassphraseFixturePreview(device: .requested[0], state: .edit, scheme: .dark)
}

#Preview("iPhone 17 Pro · light · empty", traits: .fixedLayout(width: 402, height: 874)) {
    PassphraseFixturePreview(device: .requested[1], state: .empty, scheme: .light)
}

#Preview("iPhone 17 Pro · light · typed", traits: .fixedLayout(width: 402, height: 874)) {
    PassphraseFixturePreview(device: .requested[1], state: .typed, scheme: .light)
}

#Preview("iPhone 17 Pro · light · trailingSpace", traits: .fixedLayout(width: 402, height: 874)) {
    PassphraseFixturePreview(device: .requested[1], state: .trailingSpace, scheme: .light)
}

#Preview("iPhone 17 Pro · light · set", traits: .fixedLayout(width: 402, height: 874)) {
    PassphraseFixturePreview(device: .requested[1], state: .set, scheme: .light)
}

#Preview("iPhone 17 Pro · light · edit", traits: .fixedLayout(width: 402, height: 874)) {
    PassphraseFixturePreview(device: .requested[1], state: .edit, scheme: .light)
}

#Preview("iPhone 17 Pro · dark · empty", traits: .fixedLayout(width: 402, height: 874)) {
    PassphraseFixturePreview(device: .requested[1], state: .empty, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · typed", traits: .fixedLayout(width: 402, height: 874)) {
    PassphraseFixturePreview(device: .requested[1], state: .typed, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · trailingSpace", traits: .fixedLayout(width: 402, height: 874)) {
    PassphraseFixturePreview(device: .requested[1], state: .trailingSpace, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · set", traits: .fixedLayout(width: 402, height: 874)) {
    PassphraseFixturePreview(device: .requested[1], state: .set, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · edit", traits: .fixedLayout(width: 402, height: 874)) {
    PassphraseFixturePreview(device: .requested[1], state: .edit, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · light · empty", traits: .fixedLayout(width: 440, height: 956)) {
    PassphraseFixturePreview(device: .requested[2], state: .empty, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · typed", traits: .fixedLayout(width: 440, height: 956)) {
    PassphraseFixturePreview(device: .requested[2], state: .typed, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · trailingSpace", traits: .fixedLayout(width: 440, height: 956)) {
    PassphraseFixturePreview(device: .requested[2], state: .trailingSpace, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · set", traits: .fixedLayout(width: 440, height: 956)) {
    PassphraseFixturePreview(device: .requested[2], state: .set, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · edit", traits: .fixedLayout(width: 440, height: 956)) {
    PassphraseFixturePreview(device: .requested[2], state: .edit, scheme: .light)
}

#Preview("iPhone 17 Pro Max · dark · empty", traits: .fixedLayout(width: 440, height: 956)) {
    PassphraseFixturePreview(device: .requested[2], state: .empty, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · typed", traits: .fixedLayout(width: 440, height: 956)) {
    PassphraseFixturePreview(device: .requested[2], state: .typed, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · trailingSpace", traits: .fixedLayout(width: 440, height: 956)) {
    PassphraseFixturePreview(device: .requested[2], state: .trailingSpace, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · set", traits: .fixedLayout(width: 440, height: 956)) {
    PassphraseFixturePreview(device: .requested[2], state: .set, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · edit", traits: .fixedLayout(width: 440, height: 956)) {
    PassphraseFixturePreview(device: .requested[2], state: .edit, scheme: .dark)
}

#Preview("Duo outer · light · empty", traits: .fixedLayout(width: 466, height: 678)) {
    PassphraseFixturePreview(device: .requested[3], state: .empty, scheme: .light)
}

#Preview("Duo outer · light · typed", traits: .fixedLayout(width: 466, height: 678)) {
    PassphraseFixturePreview(device: .requested[3], state: .typed, scheme: .light)
}

#Preview("Duo outer · light · trailingSpace", traits: .fixedLayout(width: 466, height: 678)) {
    PassphraseFixturePreview(device: .requested[3], state: .trailingSpace, scheme: .light)
}

#Preview("Duo outer · light · set", traits: .fixedLayout(width: 466, height: 678)) {
    PassphraseFixturePreview(device: .requested[3], state: .set, scheme: .light)
}

#Preview("Duo outer · light · edit", traits: .fixedLayout(width: 466, height: 678)) {
    PassphraseFixturePreview(device: .requested[3], state: .edit, scheme: .light)
}

#Preview("Duo outer · dark · empty", traits: .fixedLayout(width: 466, height: 678)) {
    PassphraseFixturePreview(device: .requested[3], state: .empty, scheme: .dark)
}

#Preview("Duo outer · dark · typed", traits: .fixedLayout(width: 466, height: 678)) {
    PassphraseFixturePreview(device: .requested[3], state: .typed, scheme: .dark)
}

#Preview("Duo outer · dark · trailingSpace", traits: .fixedLayout(width: 466, height: 678)) {
    PassphraseFixturePreview(device: .requested[3], state: .trailingSpace, scheme: .dark)
}

#Preview("Duo outer · dark · set", traits: .fixedLayout(width: 466, height: 678)) {
    PassphraseFixturePreview(device: .requested[3], state: .set, scheme: .dark)
}

#Preview("Duo outer · dark · edit", traits: .fixedLayout(width: 466, height: 678)) {
    PassphraseFixturePreview(device: .requested[3], state: .edit, scheme: .dark)
}

#Preview("Duo inner · light · empty", traits: .fixedLayout(width: 890, height: 626)) {
    PassphraseFixturePreview(device: .requested[4], state: .empty, scheme: .light)
}

#Preview("Duo inner · light · typed", traits: .fixedLayout(width: 890, height: 626)) {
    PassphraseFixturePreview(device: .requested[4], state: .typed, scheme: .light)
}

#Preview("Duo inner · light · trailingSpace", traits: .fixedLayout(width: 890, height: 626)) {
    PassphraseFixturePreview(device: .requested[4], state: .trailingSpace, scheme: .light)
}

#Preview("Duo inner · light · set", traits: .fixedLayout(width: 890, height: 626)) {
    PassphraseFixturePreview(device: .requested[4], state: .set, scheme: .light)
}

#Preview("Duo inner · light · edit", traits: .fixedLayout(width: 890, height: 626)) {
    PassphraseFixturePreview(device: .requested[4], state: .edit, scheme: .light)
}

#Preview("Duo inner · dark · empty", traits: .fixedLayout(width: 890, height: 626)) {
    PassphraseFixturePreview(device: .requested[4], state: .empty, scheme: .dark)
}

#Preview("Duo inner · dark · typed", traits: .fixedLayout(width: 890, height: 626)) {
    PassphraseFixturePreview(device: .requested[4], state: .typed, scheme: .dark)
}

#Preview("Duo inner · dark · trailingSpace", traits: .fixedLayout(width: 890, height: 626)) {
    PassphraseFixturePreview(device: .requested[4], state: .trailingSpace, scheme: .dark)
}

#Preview("Duo inner · dark · set", traits: .fixedLayout(width: 890, height: 626)) {
    PassphraseFixturePreview(device: .requested[4], state: .set, scheme: .dark)
}

#Preview("Duo inner · dark · edit", traits: .fixedLayout(width: 890, height: 626)) {
    PassphraseFixturePreview(device: .requested[4], state: .edit, scheme: .dark)
}

#Preview("Duo rotated · light · empty", traits: .fixedLayout(width: 626, height: 890)) {
    PassphraseFixturePreview(device: .requested[5], state: .empty, scheme: .light)
}

#Preview("Duo rotated · light · typed", traits: .fixedLayout(width: 626, height: 890)) {
    PassphraseFixturePreview(device: .requested[5], state: .typed, scheme: .light)
}

#Preview("Duo rotated · light · trailingSpace", traits: .fixedLayout(width: 626, height: 890)) {
    PassphraseFixturePreview(device: .requested[5], state: .trailingSpace, scheme: .light)
}

#Preview("Duo rotated · light · set", traits: .fixedLayout(width: 626, height: 890)) {
    PassphraseFixturePreview(device: .requested[5], state: .set, scheme: .light)
}

#Preview("Duo rotated · light · edit", traits: .fixedLayout(width: 626, height: 890)) {
    PassphraseFixturePreview(device: .requested[5], state: .edit, scheme: .light)
}

#Preview("Duo rotated · dark · empty", traits: .fixedLayout(width: 626, height: 890)) {
    PassphraseFixturePreview(device: .requested[5], state: .empty, scheme: .dark)
}

#Preview("Duo rotated · dark · typed", traits: .fixedLayout(width: 626, height: 890)) {
    PassphraseFixturePreview(device: .requested[5], state: .typed, scheme: .dark)
}

#Preview("Duo rotated · dark · trailingSpace", traits: .fixedLayout(width: 626, height: 890)) {
    PassphraseFixturePreview(device: .requested[5], state: .trailingSpace, scheme: .dark)
}

#Preview("Duo rotated · dark · set", traits: .fixedLayout(width: 626, height: 890)) {
    PassphraseFixturePreview(device: .requested[5], state: .set, scheme: .dark)
}

#Preview("Duo rotated · dark · edit", traits: .fixedLayout(width: 626, height: 890)) {
    PassphraseFixturePreview(device: .requested[5], state: .edit, scheme: .dark)
}

#Preview("iPad mini portrait · light · empty", traits: .fixedLayout(width: 744, height: 1133)) {
    PassphraseFixturePreview(device: .requested[6], state: .empty, scheme: .light)
}

#Preview("iPad mini portrait · light · typed", traits: .fixedLayout(width: 744, height: 1133)) {
    PassphraseFixturePreview(device: .requested[6], state: .typed, scheme: .light)
}

#Preview("iPad mini portrait · light · trailingSpace", traits: .fixedLayout(width: 744, height: 1133)) {
    PassphraseFixturePreview(device: .requested[6], state: .trailingSpace, scheme: .light)
}

#Preview("iPad mini portrait · light · set", traits: .fixedLayout(width: 744, height: 1133)) {
    PassphraseFixturePreview(device: .requested[6], state: .set, scheme: .light)
}

#Preview("iPad mini portrait · light · edit", traits: .fixedLayout(width: 744, height: 1133)) {
    PassphraseFixturePreview(device: .requested[6], state: .edit, scheme: .light)
}

#Preview("iPad mini portrait · dark · empty", traits: .fixedLayout(width: 744, height: 1133)) {
    PassphraseFixturePreview(device: .requested[6], state: .empty, scheme: .dark)
}

#Preview("iPad mini portrait · dark · typed", traits: .fixedLayout(width: 744, height: 1133)) {
    PassphraseFixturePreview(device: .requested[6], state: .typed, scheme: .dark)
}

#Preview("iPad mini portrait · dark · trailingSpace", traits: .fixedLayout(width: 744, height: 1133)) {
    PassphraseFixturePreview(device: .requested[6], state: .trailingSpace, scheme: .dark)
}

#Preview("iPad mini portrait · dark · set", traits: .fixedLayout(width: 744, height: 1133)) {
    PassphraseFixturePreview(device: .requested[6], state: .set, scheme: .dark)
}

#Preview("iPad mini portrait · dark · edit", traits: .fixedLayout(width: 744, height: 1133)) {
    PassphraseFixturePreview(device: .requested[6], state: .edit, scheme: .dark)
}

#Preview("iPad mini landscape · light · empty", traits: .fixedLayout(width: 1133, height: 744)) {
    PassphraseFixturePreview(device: .requested[7], state: .empty, scheme: .light)
}

#Preview("iPad mini landscape · light · typed", traits: .fixedLayout(width: 1133, height: 744)) {
    PassphraseFixturePreview(device: .requested[7], state: .typed, scheme: .light)
}

#Preview("iPad mini landscape · light · trailingSpace", traits: .fixedLayout(width: 1133, height: 744)) {
    PassphraseFixturePreview(device: .requested[7], state: .trailingSpace, scheme: .light)
}

#Preview("iPad mini landscape · light · set", traits: .fixedLayout(width: 1133, height: 744)) {
    PassphraseFixturePreview(device: .requested[7], state: .set, scheme: .light)
}

#Preview("iPad mini landscape · light · edit", traits: .fixedLayout(width: 1133, height: 744)) {
    PassphraseFixturePreview(device: .requested[7], state: .edit, scheme: .light)
}

#Preview("iPad mini landscape · dark · empty", traits: .fixedLayout(width: 1133, height: 744)) {
    PassphraseFixturePreview(device: .requested[7], state: .empty, scheme: .dark)
}

#Preview("iPad mini landscape · dark · typed", traits: .fixedLayout(width: 1133, height: 744)) {
    PassphraseFixturePreview(device: .requested[7], state: .typed, scheme: .dark)
}

#Preview("iPad mini landscape · dark · trailingSpace", traits: .fixedLayout(width: 1133, height: 744)) {
    PassphraseFixturePreview(device: .requested[7], state: .trailingSpace, scheme: .dark)
}

#Preview("iPad mini landscape · dark · set", traits: .fixedLayout(width: 1133, height: 744)) {
    PassphraseFixturePreview(device: .requested[7], state: .set, scheme: .dark)
}

#Preview("iPad mini landscape · dark · edit", traits: .fixedLayout(width: 1133, height: 744)) {
    PassphraseFixturePreview(device: .requested[7], state: .edit, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · light · empty", traits: .fixedLayout(width: 1376, height: 1032)) {
    PassphraseFixturePreview(device: .requested[8], state: .empty, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · typed", traits: .fixedLayout(width: 1376, height: 1032)) {
    PassphraseFixturePreview(device: .requested[8], state: .typed, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · trailingSpace", traits: .fixedLayout(width: 1376, height: 1032)) {
    PassphraseFixturePreview(device: .requested[8], state: .trailingSpace, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · set", traits: .fixedLayout(width: 1376, height: 1032)) {
    PassphraseFixturePreview(device: .requested[8], state: .set, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · edit", traits: .fixedLayout(width: 1376, height: 1032)) {
    PassphraseFixturePreview(device: .requested[8], state: .edit, scheme: .light)
}

#Preview("iPad Pro 13 landscape · dark · empty", traits: .fixedLayout(width: 1376, height: 1032)) {
    PassphraseFixturePreview(device: .requested[8], state: .empty, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · typed", traits: .fixedLayout(width: 1376, height: 1032)) {
    PassphraseFixturePreview(device: .requested[8], state: .typed, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · trailingSpace", traits: .fixedLayout(width: 1376, height: 1032)) {
    PassphraseFixturePreview(device: .requested[8], state: .trailingSpace, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · set", traits: .fixedLayout(width: 1376, height: 1032)) {
    PassphraseFixturePreview(device: .requested[8], state: .set, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · edit", traits: .fixedLayout(width: 1376, height: 1032)) {
    PassphraseFixturePreview(device: .requested[8], state: .edit, scheme: .dark)
}

#endif
