#if DEBUG
import SwiftUI

@MainActor private final class EnterKeyPreviewStore: ObservableObject {
    let session = SecretSession()
    let router: WelcomeRouter
    let model: EnterKeyModel
    init(input: String) {
        try! session.key.replace(with: input.utf8)
        router = WelcomeRouter(session: session)
        model = EnterKeyModel(session: session)
    }
}

struct EnterKeyFixturePreview: View {
    let device: WelcomeDeviceFixture
    let scheme: ColorScheme
    var settled = true
    @StateObject private var store: EnterKeyPreviewStore
    init(device: WelcomeDeviceFixture, state: Int, scheme: ColorScheme, settled: Bool = true) {
        self.device = device; self.scheme = scheme; self.settled = settled
        _store = StateObject(wrappedValue: EnterKeyPreviewStore(input: EnterKeyFixtures.states[state].input))
    }
    var body: some View {
        EnterKeyView(router: store.router, session: store.session, model: store.model)
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: device.top) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: device.bottom) }
            .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: device.trailing) }
            .preferredColorScheme(scheme)
            .task { store.model.classify(settled: settled) }
    }
}

#Preview("iPhone SE · light · empty", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 0, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · phrase", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 1, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · incomplete idle", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 2, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · WIF compressed", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 3, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · WIF uncompressed", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 4, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · mini", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 5, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · hex", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 6, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · xprv", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 7, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · yprv", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 8, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · zprv", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 9, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · public", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 10, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · testnet", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 11, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · unrecognized", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 12, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · prompt phrase invalid", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 13, scheme: .light, settled: true)
}

#Preview("iPhone SE · light · incomplete typing", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 2, scheme: .light, settled: false)
}

#Preview("iPhone SE · dark · empty", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 0, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · phrase", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 1, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · incomplete idle", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 2, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · WIF compressed", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 3, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · WIF uncompressed", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 4, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · mini", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 5, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · hex", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 6, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · xprv", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 7, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · yprv", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 8, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · zprv", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 9, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · public", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 10, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · testnet", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 11, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · unrecognized", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 12, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · prompt phrase invalid", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 13, scheme: .dark, settled: true)
}

#Preview("iPhone SE · dark · incomplete typing", traits: .fixedLayout(width: 375, height: 667)) {
    EnterKeyFixturePreview(device: .requested[0], state: 2, scheme: .dark, settled: false)
}

#Preview("iPhone 17 Pro · light · empty", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 0, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · phrase", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 1, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · incomplete idle", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 2, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · WIF compressed", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 3, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · WIF uncompressed", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 4, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · mini", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 5, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · hex", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 6, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · xprv", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 7, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · yprv", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 8, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · zprv", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 9, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · public", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 10, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · testnet", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 11, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · unrecognized", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 12, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · prompt phrase invalid", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 13, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro · light · incomplete typing", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 2, scheme: .light, settled: false)
}

#Preview("iPhone 17 Pro · dark · empty", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 0, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · phrase", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 1, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · incomplete idle", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 2, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · WIF compressed", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 3, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · WIF uncompressed", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 4, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · mini", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 5, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · hex", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 6, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · xprv", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 7, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · yprv", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 8, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · zprv", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 9, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · public", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 10, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · testnet", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 11, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · unrecognized", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 12, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · prompt phrase invalid", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 13, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro · dark · incomplete typing", traits: .fixedLayout(width: 402, height: 874)) {
    EnterKeyFixturePreview(device: .requested[1], state: 2, scheme: .dark, settled: false)
}

#Preview("iPhone 17 Pro Max · light · empty", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 0, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · phrase", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 1, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · incomplete idle", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 2, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · WIF compressed", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 3, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · WIF uncompressed", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 4, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · mini", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 5, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · hex", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 6, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · xprv", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 7, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · yprv", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 8, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · zprv", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 9, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · public", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 10, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · testnet", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 11, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · unrecognized", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 12, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · prompt phrase invalid", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 13, scheme: .light, settled: true)
}

#Preview("iPhone 17 Pro Max · light · incomplete typing", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 2, scheme: .light, settled: false)
}

#Preview("iPhone 17 Pro Max · dark · empty", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 0, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · phrase", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 1, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · incomplete idle", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 2, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · WIF compressed", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 3, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · WIF uncompressed", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 4, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · mini", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 5, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · hex", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 6, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · xprv", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 7, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · yprv", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 8, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · zprv", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 9, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · public", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 10, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · testnet", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 11, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · unrecognized", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 12, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · prompt phrase invalid", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 13, scheme: .dark, settled: true)
}

#Preview("iPhone 17 Pro Max · dark · incomplete typing", traits: .fixedLayout(width: 440, height: 956)) {
    EnterKeyFixturePreview(device: .requested[2], state: 2, scheme: .dark, settled: false)
}

#Preview("Duo outer · light · empty", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 0, scheme: .light, settled: true)
}

#Preview("Duo outer · light · phrase", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 1, scheme: .light, settled: true)
}

#Preview("Duo outer · light · incomplete idle", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 2, scheme: .light, settled: true)
}

#Preview("Duo outer · light · WIF compressed", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 3, scheme: .light, settled: true)
}

#Preview("Duo outer · light · WIF uncompressed", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 4, scheme: .light, settled: true)
}

#Preview("Duo outer · light · mini", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 5, scheme: .light, settled: true)
}

#Preview("Duo outer · light · hex", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 6, scheme: .light, settled: true)
}

#Preview("Duo outer · light · xprv", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 7, scheme: .light, settled: true)
}

#Preview("Duo outer · light · yprv", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 8, scheme: .light, settled: true)
}

#Preview("Duo outer · light · zprv", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 9, scheme: .light, settled: true)
}

#Preview("Duo outer · light · public", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 10, scheme: .light, settled: true)
}

#Preview("Duo outer · light · testnet", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 11, scheme: .light, settled: true)
}

#Preview("Duo outer · light · unrecognized", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 12, scheme: .light, settled: true)
}

#Preview("Duo outer · light · prompt phrase invalid", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 13, scheme: .light, settled: true)
}

#Preview("Duo outer · light · incomplete typing", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 2, scheme: .light, settled: false)
}

#Preview("Duo outer · dark · empty", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 0, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · phrase", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 1, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · incomplete idle", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 2, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · WIF compressed", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 3, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · WIF uncompressed", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 4, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · mini", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 5, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · hex", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 6, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · xprv", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 7, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · yprv", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 8, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · zprv", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 9, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · public", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 10, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · testnet", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 11, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · unrecognized", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 12, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · prompt phrase invalid", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 13, scheme: .dark, settled: true)
}

#Preview("Duo outer · dark · incomplete typing", traits: .fixedLayout(width: 466, height: 678)) {
    EnterKeyFixturePreview(device: .requested[3], state: 2, scheme: .dark, settled: false)
}

#Preview("Duo inner · light · empty", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 0, scheme: .light, settled: true)
}

#Preview("Duo inner · light · phrase", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 1, scheme: .light, settled: true)
}

#Preview("Duo inner · light · incomplete idle", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 2, scheme: .light, settled: true)
}

#Preview("Duo inner · light · WIF compressed", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 3, scheme: .light, settled: true)
}

#Preview("Duo inner · light · WIF uncompressed", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 4, scheme: .light, settled: true)
}

#Preview("Duo inner · light · mini", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 5, scheme: .light, settled: true)
}

#Preview("Duo inner · light · hex", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 6, scheme: .light, settled: true)
}

#Preview("Duo inner · light · xprv", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 7, scheme: .light, settled: true)
}

#Preview("Duo inner · light · yprv", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 8, scheme: .light, settled: true)
}

#Preview("Duo inner · light · zprv", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 9, scheme: .light, settled: true)
}

#Preview("Duo inner · light · public", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 10, scheme: .light, settled: true)
}

#Preview("Duo inner · light · testnet", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 11, scheme: .light, settled: true)
}

#Preview("Duo inner · light · unrecognized", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 12, scheme: .light, settled: true)
}

#Preview("Duo inner · light · prompt phrase invalid", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 13, scheme: .light, settled: true)
}

#Preview("Duo inner · light · incomplete typing", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 2, scheme: .light, settled: false)
}

#Preview("Duo inner · dark · empty", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 0, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · phrase", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 1, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · incomplete idle", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 2, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · WIF compressed", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 3, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · WIF uncompressed", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 4, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · mini", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 5, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · hex", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 6, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · xprv", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 7, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · yprv", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 8, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · zprv", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 9, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · public", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 10, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · testnet", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 11, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · unrecognized", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 12, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · prompt phrase invalid", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 13, scheme: .dark, settled: true)
}

#Preview("Duo inner · dark · incomplete typing", traits: .fixedLayout(width: 890, height: 626)) {
    EnterKeyFixturePreview(device: .requested[4], state: 2, scheme: .dark, settled: false)
}

#Preview("Duo rotated · light · empty", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 0, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · phrase", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 1, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · incomplete idle", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 2, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · WIF compressed", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 3, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · WIF uncompressed", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 4, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · mini", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 5, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · hex", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 6, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · xprv", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 7, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · yprv", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 8, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · zprv", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 9, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · public", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 10, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · testnet", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 11, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · unrecognized", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 12, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · prompt phrase invalid", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 13, scheme: .light, settled: true)
}

#Preview("Duo rotated · light · incomplete typing", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 2, scheme: .light, settled: false)
}

#Preview("Duo rotated · dark · empty", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 0, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · phrase", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 1, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · incomplete idle", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 2, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · WIF compressed", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 3, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · WIF uncompressed", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 4, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · mini", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 5, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · hex", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 6, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · xprv", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 7, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · yprv", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 8, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · zprv", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 9, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · public", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 10, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · testnet", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 11, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · unrecognized", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 12, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · prompt phrase invalid", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 13, scheme: .dark, settled: true)
}

#Preview("Duo rotated · dark · incomplete typing", traits: .fixedLayout(width: 626, height: 890)) {
    EnterKeyFixturePreview(device: .requested[5], state: 2, scheme: .dark, settled: false)
}

#Preview("iPad mini portrait · light · empty", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 0, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · phrase", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 1, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · incomplete idle", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 2, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · WIF compressed", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 3, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · WIF uncompressed", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 4, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · mini", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 5, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · hex", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 6, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · xprv", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 7, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · yprv", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 8, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · zprv", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 9, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · public", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 10, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · testnet", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 11, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · unrecognized", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 12, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · prompt phrase invalid", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 13, scheme: .light, settled: true)
}

#Preview("iPad mini portrait · light · incomplete typing", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 2, scheme: .light, settled: false)
}

#Preview("iPad mini portrait · dark · empty", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 0, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · phrase", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 1, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · incomplete idle", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 2, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · WIF compressed", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 3, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · WIF uncompressed", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 4, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · mini", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 5, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · hex", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 6, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · xprv", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 7, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · yprv", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 8, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · zprv", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 9, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · public", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 10, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · testnet", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 11, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · unrecognized", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 12, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · prompt phrase invalid", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 13, scheme: .dark, settled: true)
}

#Preview("iPad mini portrait · dark · incomplete typing", traits: .fixedLayout(width: 744, height: 1133)) {
    EnterKeyFixturePreview(device: .requested[6], state: 2, scheme: .dark, settled: false)
}

#Preview("iPad mini landscape · light · empty", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 0, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · phrase", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 1, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · incomplete idle", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 2, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · WIF compressed", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 3, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · WIF uncompressed", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 4, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · mini", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 5, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · hex", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 6, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · xprv", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 7, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · yprv", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 8, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · zprv", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 9, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · public", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 10, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · testnet", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 11, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · unrecognized", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 12, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · prompt phrase invalid", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 13, scheme: .light, settled: true)
}

#Preview("iPad mini landscape · light · incomplete typing", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 2, scheme: .light, settled: false)
}

#Preview("iPad mini landscape · dark · empty", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 0, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · phrase", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 1, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · incomplete idle", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 2, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · WIF compressed", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 3, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · WIF uncompressed", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 4, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · mini", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 5, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · hex", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 6, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · xprv", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 7, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · yprv", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 8, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · zprv", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 9, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · public", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 10, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · testnet", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 11, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · unrecognized", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 12, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · prompt phrase invalid", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 13, scheme: .dark, settled: true)
}

#Preview("iPad mini landscape · dark · incomplete typing", traits: .fixedLayout(width: 1133, height: 744)) {
    EnterKeyFixturePreview(device: .requested[7], state: 2, scheme: .dark, settled: false)
}

#Preview("iPad Pro 13 landscape · light · empty", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 0, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · phrase", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 1, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · incomplete idle", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 2, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · WIF compressed", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 3, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · WIF uncompressed", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 4, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · mini", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 5, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · hex", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 6, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · xprv", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 7, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · yprv", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 8, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · zprv", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 9, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · public", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 10, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · testnet", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 11, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · unrecognized", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 12, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · prompt phrase invalid", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 13, scheme: .light, settled: true)
}

#Preview("iPad Pro 13 landscape · light · incomplete typing", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 2, scheme: .light, settled: false)
}

#Preview("iPad Pro 13 landscape · dark · empty", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 0, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · phrase", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 1, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · incomplete idle", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 2, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · WIF compressed", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 3, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · WIF uncompressed", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 4, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · mini", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 5, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · hex", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 6, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · xprv", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 7, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · yprv", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 8, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · zprv", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 9, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · public", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 10, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · testnet", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 11, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · unrecognized", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 12, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · prompt phrase invalid", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 13, scheme: .dark, settled: true)
}

#Preview("iPad Pro 13 landscape · dark · incomplete typing", traits: .fixedLayout(width: 1376, height: 1032)) {
    EnterKeyFixturePreview(device: .requested[8], state: 2, scheme: .dark, settled: false)
}

#endif
