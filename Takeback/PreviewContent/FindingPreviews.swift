#if DEBUG
import SwiftUI

@MainActor final class FindingPreviewStore: ObservableObject {
    let session = SecretSession()
    let router: WelcomeRouter
    let model: FindingModel
    static let names = ["searching", "fallback", "search100", "foundTwo", "foundOne", "none", "passphraseNone", "confirmed", "offline", "serversDown", "singleNone"]
    init(state: Int) {
        let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        try! session.key.replace(with: (state == 10 ? String(repeating: "0", count: 63) + "1" : phrase).utf8)
        if state == 6 { try! session.passphrase.replace(with: "public preview".utf8) }
        router = WelcomeRouter(session: session)
        model = FindingModel(plan: detectKey(session.key).searchPlan!, session: session)
        let now = Date()
        let payment = PendingPayment(txid: String(repeating: "a", count: 64), types: [.bip84], ownedInputCount: 1, totalInputCount: 1,
            signalsRBF: true, feeSats: 140, virtualSize: 140, firstSeen: now.addingTimeInterval(-10_800), recipient: "public fixture", descendants: [])
        switch state {
        case 0,1,2:
            model.setPreviewGap(state == 2 ? 100 : 20)
            model.progress = .init(rows: AddressStandard.allCases.enumerated().map { i, type in
                .init(type: type, completed: i == 3 ? 0 : i == 0 ? (state == 2 ? 200 : 40) : 12,
                      total: state == 2 ? 200 : 40, started: i != 3)
            }, server: state == 1 ? "electrum.blockstream.info" : "mempool.space", isFallback: state == 1)
        case 3,4:
            var payments = [payment]
            if state == 3 { payments.append(.init(txid: String(repeating: "b", count: 64), types: [.bip84], ownedInputCount: 1,
                totalInputCount: 1, signalsRBF: true, feeSats: 500, virtualSize: 150, firstSeen: now.addingTimeInterval(-3600), recipient: "public fixture", descendants: [])) }
            model.outcome = .found(.init(payments: payments, lastConfirmed: nil, server: "mempool.space", checkedAt: now))
        case 5,6,10: model.outcome = .none
        case 7: model.outcome = .confirmed(now.addingTimeInterval(-7200))
        case 8: model.outcome = .offline
        default: model.outcome = .serversDown([.init(server: "mempool.space", detail: "No response after 5 seconds"),
            .init(server: "electrum.blockstream.info", detail: "No response after 8 seconds"),
            .init(server: "fulcrum.sethforprivacy.com", detail: "Connection refused")])
        }
    }
}
struct FindingFixturePreview: View {
    let device: WelcomeDeviceFixture
    let scheme: ColorScheme
    @StateObject private var store: FindingPreviewStore
    init(device: WelcomeDeviceFixture, state: Int, scheme: ColorScheme) {
        self.device = device; self.scheme = scheme
        _store = StateObject(wrappedValue: FindingPreviewStore(state: state))
    }
    var body: some View {
        FindingView(router: store.router, session: store.session, plan: store.model.plan, model: store.model, automaticallyStart: false)
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: device.top) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: device.bottom) }
            .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: device.trailing) }
            .preferredColorScheme(scheme)
    }
}
#Preview("iPhone SE · light · searching", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 0, scheme: .light)
}

#Preview("iPhone SE · light · fallback", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 1, scheme: .light)
}

#Preview("iPhone SE · light · search100", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 2, scheme: .light)
}

#Preview("iPhone SE · light · foundTwo", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 3, scheme: .light)
}

#Preview("iPhone SE · light · foundOne", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 4, scheme: .light)
}

#Preview("iPhone SE · light · none", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 5, scheme: .light)
}

#Preview("iPhone SE · light · passphraseNone", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 6, scheme: .light)
}

#Preview("iPhone SE · light · confirmed", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 7, scheme: .light)
}

#Preview("iPhone SE · light · offline", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 8, scheme: .light)
}

#Preview("iPhone SE · light · serversDown", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 9, scheme: .light)
}

#Preview("iPhone SE · light · singleNone", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 10, scheme: .light)
}

#Preview("iPhone SE · dark · searching", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 0, scheme: .dark)
}

#Preview("iPhone SE · dark · fallback", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 1, scheme: .dark)
}

#Preview("iPhone SE · dark · search100", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 2, scheme: .dark)
}

#Preview("iPhone SE · dark · foundTwo", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 3, scheme: .dark)
}

#Preview("iPhone SE · dark · foundOne", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 4, scheme: .dark)
}

#Preview("iPhone SE · dark · none", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 5, scheme: .dark)
}

#Preview("iPhone SE · dark · passphraseNone", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 6, scheme: .dark)
}

#Preview("iPhone SE · dark · confirmed", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 7, scheme: .dark)
}

#Preview("iPhone SE · dark · offline", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 8, scheme: .dark)
}

#Preview("iPhone SE · dark · serversDown", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 9, scheme: .dark)
}

#Preview("iPhone SE · dark · singleNone", traits: .fixedLayout(width: 375, height: 667)) {
    FindingFixturePreview(device: .requested[0], state: 10, scheme: .dark)
}

#Preview("iPhone 17 Pro · light · searching", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 0, scheme: .light)
}

#Preview("iPhone 17 Pro · light · fallback", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 1, scheme: .light)
}

#Preview("iPhone 17 Pro · light · search100", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 2, scheme: .light)
}

#Preview("iPhone 17 Pro · light · foundTwo", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 3, scheme: .light)
}

#Preview("iPhone 17 Pro · light · foundOne", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 4, scheme: .light)
}

#Preview("iPhone 17 Pro · light · none", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 5, scheme: .light)
}

#Preview("iPhone 17 Pro · light · passphraseNone", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 6, scheme: .light)
}

#Preview("iPhone 17 Pro · light · confirmed", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 7, scheme: .light)
}

#Preview("iPhone 17 Pro · light · offline", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 8, scheme: .light)
}

#Preview("iPhone 17 Pro · light · serversDown", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 9, scheme: .light)
}

#Preview("iPhone 17 Pro · light · singleNone", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 10, scheme: .light)
}

#Preview("iPhone 17 Pro · dark · searching", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 0, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · fallback", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 1, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · search100", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 2, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · foundTwo", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 3, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · foundOne", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 4, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · none", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 5, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · passphraseNone", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 6, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · confirmed", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 7, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · offline", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 8, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · serversDown", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 9, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · singleNone", traits: .fixedLayout(width: 402, height: 874)) {
    FindingFixturePreview(device: .requested[1], state: 10, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · light · searching", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 0, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · fallback", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 1, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · search100", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 2, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · foundTwo", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 3, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · foundOne", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 4, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · none", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 5, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · passphraseNone", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 6, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · confirmed", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 7, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · offline", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 8, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · serversDown", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 9, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · singleNone", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 10, scheme: .light)
}

#Preview("iPhone 17 Pro Max · dark · searching", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 0, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · fallback", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 1, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · search100", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 2, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · foundTwo", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 3, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · foundOne", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 4, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · none", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 5, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · passphraseNone", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 6, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · confirmed", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 7, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · offline", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 8, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · serversDown", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 9, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · singleNone", traits: .fixedLayout(width: 440, height: 956)) {
    FindingFixturePreview(device: .requested[2], state: 10, scheme: .dark)
}

#Preview("Duo outer · light · searching", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 0, scheme: .light)
}

#Preview("Duo outer · light · fallback", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 1, scheme: .light)
}

#Preview("Duo outer · light · search100", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 2, scheme: .light)
}

#Preview("Duo outer · light · foundTwo", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 3, scheme: .light)
}

#Preview("Duo outer · light · foundOne", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 4, scheme: .light)
}

#Preview("Duo outer · light · none", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 5, scheme: .light)
}

#Preview("Duo outer · light · passphraseNone", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 6, scheme: .light)
}

#Preview("Duo outer · light · confirmed", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 7, scheme: .light)
}

#Preview("Duo outer · light · offline", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 8, scheme: .light)
}

#Preview("Duo outer · light · serversDown", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 9, scheme: .light)
}

#Preview("Duo outer · light · singleNone", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 10, scheme: .light)
}

#Preview("Duo outer · dark · searching", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 0, scheme: .dark)
}

#Preview("Duo outer · dark · fallback", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 1, scheme: .dark)
}

#Preview("Duo outer · dark · search100", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 2, scheme: .dark)
}

#Preview("Duo outer · dark · foundTwo", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 3, scheme: .dark)
}

#Preview("Duo outer · dark · foundOne", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 4, scheme: .dark)
}

#Preview("Duo outer · dark · none", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 5, scheme: .dark)
}

#Preview("Duo outer · dark · passphraseNone", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 6, scheme: .dark)
}

#Preview("Duo outer · dark · confirmed", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 7, scheme: .dark)
}

#Preview("Duo outer · dark · offline", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 8, scheme: .dark)
}

#Preview("Duo outer · dark · serversDown", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 9, scheme: .dark)
}

#Preview("Duo outer · dark · singleNone", traits: .fixedLayout(width: 466, height: 678)) {
    FindingFixturePreview(device: .requested[3], state: 10, scheme: .dark)
}

#Preview("Duo inner · light · searching", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 0, scheme: .light)
}

#Preview("Duo inner · light · fallback", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 1, scheme: .light)
}

#Preview("Duo inner · light · search100", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 2, scheme: .light)
}

#Preview("Duo inner · light · foundTwo", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 3, scheme: .light)
}

#Preview("Duo inner · light · foundOne", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 4, scheme: .light)
}

#Preview("Duo inner · light · none", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 5, scheme: .light)
}

#Preview("Duo inner · light · passphraseNone", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 6, scheme: .light)
}

#Preview("Duo inner · light · confirmed", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 7, scheme: .light)
}

#Preview("Duo inner · light · offline", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 8, scheme: .light)
}

#Preview("Duo inner · light · serversDown", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 9, scheme: .light)
}

#Preview("Duo inner · light · singleNone", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 10, scheme: .light)
}

#Preview("Duo inner · dark · searching", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 0, scheme: .dark)
}

#Preview("Duo inner · dark · fallback", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 1, scheme: .dark)
}

#Preview("Duo inner · dark · search100", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 2, scheme: .dark)
}

#Preview("Duo inner · dark · foundTwo", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 3, scheme: .dark)
}

#Preview("Duo inner · dark · foundOne", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 4, scheme: .dark)
}

#Preview("Duo inner · dark · none", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 5, scheme: .dark)
}

#Preview("Duo inner · dark · passphraseNone", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 6, scheme: .dark)
}

#Preview("Duo inner · dark · confirmed", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 7, scheme: .dark)
}

#Preview("Duo inner · dark · offline", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 8, scheme: .dark)
}

#Preview("Duo inner · dark · serversDown", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 9, scheme: .dark)
}

#Preview("Duo inner · dark · singleNone", traits: .fixedLayout(width: 890, height: 626)) {
    FindingFixturePreview(device: .requested[4], state: 10, scheme: .dark)
}

#Preview("Duo rotated · light · searching", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 0, scheme: .light)
}

#Preview("Duo rotated · light · fallback", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 1, scheme: .light)
}

#Preview("Duo rotated · light · search100", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 2, scheme: .light)
}

#Preview("Duo rotated · light · foundTwo", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 3, scheme: .light)
}

#Preview("Duo rotated · light · foundOne", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 4, scheme: .light)
}

#Preview("Duo rotated · light · none", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 5, scheme: .light)
}

#Preview("Duo rotated · light · passphraseNone", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 6, scheme: .light)
}

#Preview("Duo rotated · light · confirmed", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 7, scheme: .light)
}

#Preview("Duo rotated · light · offline", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 8, scheme: .light)
}

#Preview("Duo rotated · light · serversDown", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 9, scheme: .light)
}

#Preview("Duo rotated · light · singleNone", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 10, scheme: .light)
}

#Preview("Duo rotated · dark · searching", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 0, scheme: .dark)
}

#Preview("Duo rotated · dark · fallback", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 1, scheme: .dark)
}

#Preview("Duo rotated · dark · search100", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 2, scheme: .dark)
}

#Preview("Duo rotated · dark · foundTwo", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 3, scheme: .dark)
}

#Preview("Duo rotated · dark · foundOne", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 4, scheme: .dark)
}

#Preview("Duo rotated · dark · none", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 5, scheme: .dark)
}

#Preview("Duo rotated · dark · passphraseNone", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 6, scheme: .dark)
}

#Preview("Duo rotated · dark · confirmed", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 7, scheme: .dark)
}

#Preview("Duo rotated · dark · offline", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 8, scheme: .dark)
}

#Preview("Duo rotated · dark · serversDown", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 9, scheme: .dark)
}

#Preview("Duo rotated · dark · singleNone", traits: .fixedLayout(width: 626, height: 890)) {
    FindingFixturePreview(device: .requested[5], state: 10, scheme: .dark)
}

#Preview("iPad mini portrait · light · searching", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 0, scheme: .light)
}

#Preview("iPad mini portrait · light · fallback", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 1, scheme: .light)
}

#Preview("iPad mini portrait · light · search100", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 2, scheme: .light)
}

#Preview("iPad mini portrait · light · foundTwo", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 3, scheme: .light)
}

#Preview("iPad mini portrait · light · foundOne", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 4, scheme: .light)
}

#Preview("iPad mini portrait · light · none", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 5, scheme: .light)
}

#Preview("iPad mini portrait · light · passphraseNone", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 6, scheme: .light)
}

#Preview("iPad mini portrait · light · confirmed", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 7, scheme: .light)
}

#Preview("iPad mini portrait · light · offline", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 8, scheme: .light)
}

#Preview("iPad mini portrait · light · serversDown", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 9, scheme: .light)
}

#Preview("iPad mini portrait · light · singleNone", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 10, scheme: .light)
}

#Preview("iPad mini portrait · dark · searching", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 0, scheme: .dark)
}

#Preview("iPad mini portrait · dark · fallback", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 1, scheme: .dark)
}

#Preview("iPad mini portrait · dark · search100", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 2, scheme: .dark)
}

#Preview("iPad mini portrait · dark · foundTwo", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 3, scheme: .dark)
}

#Preview("iPad mini portrait · dark · foundOne", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 4, scheme: .dark)
}

#Preview("iPad mini portrait · dark · none", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 5, scheme: .dark)
}

#Preview("iPad mini portrait · dark · passphraseNone", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 6, scheme: .dark)
}

#Preview("iPad mini portrait · dark · confirmed", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 7, scheme: .dark)
}

#Preview("iPad mini portrait · dark · offline", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 8, scheme: .dark)
}

#Preview("iPad mini portrait · dark · serversDown", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 9, scheme: .dark)
}

#Preview("iPad mini portrait · dark · singleNone", traits: .fixedLayout(width: 744, height: 1133)) {
    FindingFixturePreview(device: .requested[6], state: 10, scheme: .dark)
}

#Preview("iPad mini landscape · light · searching", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 0, scheme: .light)
}

#Preview("iPad mini landscape · light · fallback", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 1, scheme: .light)
}

#Preview("iPad mini landscape · light · search100", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 2, scheme: .light)
}

#Preview("iPad mini landscape · light · foundTwo", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 3, scheme: .light)
}

#Preview("iPad mini landscape · light · foundOne", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 4, scheme: .light)
}

#Preview("iPad mini landscape · light · none", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 5, scheme: .light)
}

#Preview("iPad mini landscape · light · passphraseNone", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 6, scheme: .light)
}

#Preview("iPad mini landscape · light · confirmed", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 7, scheme: .light)
}

#Preview("iPad mini landscape · light · offline", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 8, scheme: .light)
}

#Preview("iPad mini landscape · light · serversDown", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 9, scheme: .light)
}

#Preview("iPad mini landscape · light · singleNone", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 10, scheme: .light)
}

#Preview("iPad mini landscape · dark · searching", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 0, scheme: .dark)
}

#Preview("iPad mini landscape · dark · fallback", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 1, scheme: .dark)
}

#Preview("iPad mini landscape · dark · search100", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 2, scheme: .dark)
}

#Preview("iPad mini landscape · dark · foundTwo", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 3, scheme: .dark)
}

#Preview("iPad mini landscape · dark · foundOne", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 4, scheme: .dark)
}

#Preview("iPad mini landscape · dark · none", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 5, scheme: .dark)
}

#Preview("iPad mini landscape · dark · passphraseNone", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 6, scheme: .dark)
}

#Preview("iPad mini landscape · dark · confirmed", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 7, scheme: .dark)
}

#Preview("iPad mini landscape · dark · offline", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 8, scheme: .dark)
}

#Preview("iPad mini landscape · dark · serversDown", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 9, scheme: .dark)
}

#Preview("iPad mini landscape · dark · singleNone", traits: .fixedLayout(width: 1133, height: 744)) {
    FindingFixturePreview(device: .requested[7], state: 10, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · light · searching", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 0, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · fallback", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 1, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · search100", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 2, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · foundTwo", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 3, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · foundOne", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 4, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · none", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 5, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · passphraseNone", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 6, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · confirmed", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 7, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · offline", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 8, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · serversDown", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 9, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · singleNone", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 10, scheme: .light)
}

#Preview("iPad Pro 13 landscape · dark · searching", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 0, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · fallback", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 1, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · search100", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 2, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · foundTwo", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 3, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · foundOne", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 4, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · none", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 5, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · passphraseNone", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 6, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · confirmed", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 7, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · offline", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 8, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · serversDown", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 9, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · singleNone", traits: .fixedLayout(width: 1376, height: 1032)) {
    FindingFixturePreview(device: .requested[8], state: 10, scheme: .dark)
}

#endif
