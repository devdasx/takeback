#if DEBUG
import SwiftUI

enum PaymentsFixtures {
    static let now = Date(timeIntervalSince1970: 1_780_000_000)
    static let names = ["allCancellable", "mixed", "notOwned", "canceling", "notReplaceable"]
    static func payment(_ kind: PaymentKind, id: String, hours: Double = 3) -> PendingPayment {
        var p = PendingPayment(txid: String(repeating: id, count: 64), types: [.bip84], ownedInputCount: kind == .notOwned ? 3 : 2,
            totalInputCount: kind == .notOwned ? 5 : 2, signalsRBF: kind != .notReplaceable, feeSats: kind == .canceling ? 1680 : 840, virtualSize: 210,
            firstSeen: now.addingTimeInterval(-hours*3600), recipient: "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu",
            descendants: kind == .linked ? [String(repeating: "e", count: 64), String(repeating: "f", count: 64)] : [])
        p.amountSats = 4_210_000; p.ownedInputSats = kind == .notOwned ? 3_000_000 : 4_500_000; p.otherInputSats = kind == .notOwned ? 1_500_000 : 0; p.usdRate = 61_300
        if kind == .canceling {
            p.amountSats = 4_498_320
            p.cancellation = .init(originalTxid: String(repeating: "9", count: 64), originalRecipient: p.recipient,
                originalAmountSats: 4_210_000, originalFeeRate: 2, originalFirstSeen: p.firstSeen,
                replacementTxid: p.txid, replacementFeeRate: 8, replacementFirstSeen: now.addingTimeInterval(-600))
        }
        return p
    }
    static var mixed: [PendingPayment] {
        [payment(.normal, id: "a"), payment(.linked, id: "b", hours: 4), payment(.notOwned, id: "c"), payment(.canceling, id: "d"), payment(.notReplaceable, id: "e")]
    }
    static var all: [PendingPayment] { [payment(.normal, id: "a"), payment(.normal, id: "b", hours: 5), payment(.linked, id: "c")] }
}
@MainActor final class PaymentsPreviewStore: ObservableObject {
    let session = SecretSession()
    let router: WelcomeRouter
    init() {
        try! session.key.replace(with: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about".utf8)
        router = WelcomeRouter(session: session)
    }
}
struct PaymentsFixturePreview: View {
    let device: WelcomeDeviceFixture
    let state: Int
    let scheme: ColorScheme
    @StateObject private var store = PaymentsPreviewStore()
    var body: some View {
        Group {
            if state < 2 {
                PaymentsView(router: store.router, session: store.session, payments: state == 0 ? PaymentsFixtures.all : PaymentsFixtures.mixed, now: PaymentsFixtures.now)
            } else {
                PaymentExplanation(router: store.router, session: store.session,
                    payment: PaymentsFixtures.payment(state == 2 ? .notOwned : state == 3 ? .canceling : .notReplaceable, id: "a"), now: PaymentsFixtures.now)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: device.top) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: device.bottom) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: device.trailing) }
        .preferredColorScheme(scheme)
    }
}
#Preview("iPhone SE · light · allCancellable", traits: .fixedLayout(width: 375, height: 667)) {
    PaymentsFixturePreview(device: .requested[0], state: 0, scheme: .light)
}

#Preview("iPhone SE · light · mixed", traits: .fixedLayout(width: 375, height: 667)) {
    PaymentsFixturePreview(device: .requested[0], state: 1, scheme: .light)
}

#Preview("iPhone SE · light · notOwned", traits: .fixedLayout(width: 375, height: 667)) {
    PaymentsFixturePreview(device: .requested[0], state: 2, scheme: .light)
}

#Preview("iPhone SE · light · canceling", traits: .fixedLayout(width: 375, height: 667)) {
    PaymentsFixturePreview(device: .requested[0], state: 3, scheme: .light)
}

#Preview("iPhone SE · light · notReplaceable", traits: .fixedLayout(width: 375, height: 667)) {
    PaymentsFixturePreview(device: .requested[0], state: 4, scheme: .light)
}

#Preview("iPhone SE · dark · allCancellable", traits: .fixedLayout(width: 375, height: 667)) {
    PaymentsFixturePreview(device: .requested[0], state: 0, scheme: .dark)
}

#Preview("iPhone SE · dark · mixed", traits: .fixedLayout(width: 375, height: 667)) {
    PaymentsFixturePreview(device: .requested[0], state: 1, scheme: .dark)
}

#Preview("iPhone SE · dark · notOwned", traits: .fixedLayout(width: 375, height: 667)) {
    PaymentsFixturePreview(device: .requested[0], state: 2, scheme: .dark)
}

#Preview("iPhone SE · dark · canceling", traits: .fixedLayout(width: 375, height: 667)) {
    PaymentsFixturePreview(device: .requested[0], state: 3, scheme: .dark)
}

#Preview("iPhone SE · dark · notReplaceable", traits: .fixedLayout(width: 375, height: 667)) {
    PaymentsFixturePreview(device: .requested[0], state: 4, scheme: .dark)
}

#Preview("iPhone 17 Pro · light · allCancellable", traits: .fixedLayout(width: 402, height: 874)) {
    PaymentsFixturePreview(device: .requested[1], state: 0, scheme: .light)
}

#Preview("iPhone 17 Pro · light · mixed", traits: .fixedLayout(width: 402, height: 874)) {
    PaymentsFixturePreview(device: .requested[1], state: 1, scheme: .light)
}

#Preview("iPhone 17 Pro · light · notOwned", traits: .fixedLayout(width: 402, height: 874)) {
    PaymentsFixturePreview(device: .requested[1], state: 2, scheme: .light)
}

#Preview("iPhone 17 Pro · light · canceling", traits: .fixedLayout(width: 402, height: 874)) {
    PaymentsFixturePreview(device: .requested[1], state: 3, scheme: .light)
}

#Preview("iPhone 17 Pro · light · notReplaceable", traits: .fixedLayout(width: 402, height: 874)) {
    PaymentsFixturePreview(device: .requested[1], state: 4, scheme: .light)
}

#Preview("iPhone 17 Pro · dark · allCancellable", traits: .fixedLayout(width: 402, height: 874)) {
    PaymentsFixturePreview(device: .requested[1], state: 0, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · mixed", traits: .fixedLayout(width: 402, height: 874)) {
    PaymentsFixturePreview(device: .requested[1], state: 1, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · notOwned", traits: .fixedLayout(width: 402, height: 874)) {
    PaymentsFixturePreview(device: .requested[1], state: 2, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · canceling", traits: .fixedLayout(width: 402, height: 874)) {
    PaymentsFixturePreview(device: .requested[1], state: 3, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · notReplaceable", traits: .fixedLayout(width: 402, height: 874)) {
    PaymentsFixturePreview(device: .requested[1], state: 4, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · light · allCancellable", traits: .fixedLayout(width: 440, height: 956)) {
    PaymentsFixturePreview(device: .requested[2], state: 0, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · mixed", traits: .fixedLayout(width: 440, height: 956)) {
    PaymentsFixturePreview(device: .requested[2], state: 1, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · notOwned", traits: .fixedLayout(width: 440, height: 956)) {
    PaymentsFixturePreview(device: .requested[2], state: 2, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · canceling", traits: .fixedLayout(width: 440, height: 956)) {
    PaymentsFixturePreview(device: .requested[2], state: 3, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · notReplaceable", traits: .fixedLayout(width: 440, height: 956)) {
    PaymentsFixturePreview(device: .requested[2], state: 4, scheme: .light)
}

#Preview("iPhone 17 Pro Max · dark · allCancellable", traits: .fixedLayout(width: 440, height: 956)) {
    PaymentsFixturePreview(device: .requested[2], state: 0, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · mixed", traits: .fixedLayout(width: 440, height: 956)) {
    PaymentsFixturePreview(device: .requested[2], state: 1, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · notOwned", traits: .fixedLayout(width: 440, height: 956)) {
    PaymentsFixturePreview(device: .requested[2], state: 2, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · canceling", traits: .fixedLayout(width: 440, height: 956)) {
    PaymentsFixturePreview(device: .requested[2], state: 3, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · notReplaceable", traits: .fixedLayout(width: 440, height: 956)) {
    PaymentsFixturePreview(device: .requested[2], state: 4, scheme: .dark)
}

#Preview("Duo outer · light · allCancellable", traits: .fixedLayout(width: 466, height: 678)) {
    PaymentsFixturePreview(device: .requested[3], state: 0, scheme: .light)
}

#Preview("Duo outer · light · mixed", traits: .fixedLayout(width: 466, height: 678)) {
    PaymentsFixturePreview(device: .requested[3], state: 1, scheme: .light)
}

#Preview("Duo outer · light · notOwned", traits: .fixedLayout(width: 466, height: 678)) {
    PaymentsFixturePreview(device: .requested[3], state: 2, scheme: .light)
}

#Preview("Duo outer · light · canceling", traits: .fixedLayout(width: 466, height: 678)) {
    PaymentsFixturePreview(device: .requested[3], state: 3, scheme: .light)
}

#Preview("Duo outer · light · notReplaceable", traits: .fixedLayout(width: 466, height: 678)) {
    PaymentsFixturePreview(device: .requested[3], state: 4, scheme: .light)
}

#Preview("Duo outer · dark · allCancellable", traits: .fixedLayout(width: 466, height: 678)) {
    PaymentsFixturePreview(device: .requested[3], state: 0, scheme: .dark)
}

#Preview("Duo outer · dark · mixed", traits: .fixedLayout(width: 466, height: 678)) {
    PaymentsFixturePreview(device: .requested[3], state: 1, scheme: .dark)
}

#Preview("Duo outer · dark · notOwned", traits: .fixedLayout(width: 466, height: 678)) {
    PaymentsFixturePreview(device: .requested[3], state: 2, scheme: .dark)
}

#Preview("Duo outer · dark · canceling", traits: .fixedLayout(width: 466, height: 678)) {
    PaymentsFixturePreview(device: .requested[3], state: 3, scheme: .dark)
}

#Preview("Duo outer · dark · notReplaceable", traits: .fixedLayout(width: 466, height: 678)) {
    PaymentsFixturePreview(device: .requested[3], state: 4, scheme: .dark)
}

#Preview("Duo inner · light · allCancellable", traits: .fixedLayout(width: 890, height: 626)) {
    PaymentsFixturePreview(device: .requested[4], state: 0, scheme: .light)
}

#Preview("Duo inner · light · mixed", traits: .fixedLayout(width: 890, height: 626)) {
    PaymentsFixturePreview(device: .requested[4], state: 1, scheme: .light)
}

#Preview("Duo inner · light · notOwned", traits: .fixedLayout(width: 890, height: 626)) {
    PaymentsFixturePreview(device: .requested[4], state: 2, scheme: .light)
}

#Preview("Duo inner · light · canceling", traits: .fixedLayout(width: 890, height: 626)) {
    PaymentsFixturePreview(device: .requested[4], state: 3, scheme: .light)
}

#Preview("Duo inner · light · notReplaceable", traits: .fixedLayout(width: 890, height: 626)) {
    PaymentsFixturePreview(device: .requested[4], state: 4, scheme: .light)
}

#Preview("Duo inner · dark · allCancellable", traits: .fixedLayout(width: 890, height: 626)) {
    PaymentsFixturePreview(device: .requested[4], state: 0, scheme: .dark)
}

#Preview("Duo inner · dark · mixed", traits: .fixedLayout(width: 890, height: 626)) {
    PaymentsFixturePreview(device: .requested[4], state: 1, scheme: .dark)
}

#Preview("Duo inner · dark · notOwned", traits: .fixedLayout(width: 890, height: 626)) {
    PaymentsFixturePreview(device: .requested[4], state: 2, scheme: .dark)
}

#Preview("Duo inner · dark · canceling", traits: .fixedLayout(width: 890, height: 626)) {
    PaymentsFixturePreview(device: .requested[4], state: 3, scheme: .dark)
}

#Preview("Duo inner · dark · notReplaceable", traits: .fixedLayout(width: 890, height: 626)) {
    PaymentsFixturePreview(device: .requested[4], state: 4, scheme: .dark)
}

#Preview("Duo rotated · light · allCancellable", traits: .fixedLayout(width: 626, height: 890)) {
    PaymentsFixturePreview(device: .requested[5], state: 0, scheme: .light)
}

#Preview("Duo rotated · light · mixed", traits: .fixedLayout(width: 626, height: 890)) {
    PaymentsFixturePreview(device: .requested[5], state: 1, scheme: .light)
}

#Preview("Duo rotated · light · notOwned", traits: .fixedLayout(width: 626, height: 890)) {
    PaymentsFixturePreview(device: .requested[5], state: 2, scheme: .light)
}

#Preview("Duo rotated · light · canceling", traits: .fixedLayout(width: 626, height: 890)) {
    PaymentsFixturePreview(device: .requested[5], state: 3, scheme: .light)
}

#Preview("Duo rotated · light · notReplaceable", traits: .fixedLayout(width: 626, height: 890)) {
    PaymentsFixturePreview(device: .requested[5], state: 4, scheme: .light)
}

#Preview("Duo rotated · dark · allCancellable", traits: .fixedLayout(width: 626, height: 890)) {
    PaymentsFixturePreview(device: .requested[5], state: 0, scheme: .dark)
}

#Preview("Duo rotated · dark · mixed", traits: .fixedLayout(width: 626, height: 890)) {
    PaymentsFixturePreview(device: .requested[5], state: 1, scheme: .dark)
}

#Preview("Duo rotated · dark · notOwned", traits: .fixedLayout(width: 626, height: 890)) {
    PaymentsFixturePreview(device: .requested[5], state: 2, scheme: .dark)
}

#Preview("Duo rotated · dark · canceling", traits: .fixedLayout(width: 626, height: 890)) {
    PaymentsFixturePreview(device: .requested[5], state: 3, scheme: .dark)
}

#Preview("Duo rotated · dark · notReplaceable", traits: .fixedLayout(width: 626, height: 890)) {
    PaymentsFixturePreview(device: .requested[5], state: 4, scheme: .dark)
}

#Preview("iPad mini portrait · light · allCancellable", traits: .fixedLayout(width: 744, height: 1133)) {
    PaymentsFixturePreview(device: .requested[6], state: 0, scheme: .light)
}

#Preview("iPad mini portrait · light · mixed", traits: .fixedLayout(width: 744, height: 1133)) {
    PaymentsFixturePreview(device: .requested[6], state: 1, scheme: .light)
}

#Preview("iPad mini portrait · light · notOwned", traits: .fixedLayout(width: 744, height: 1133)) {
    PaymentsFixturePreview(device: .requested[6], state: 2, scheme: .light)
}

#Preview("iPad mini portrait · light · canceling", traits: .fixedLayout(width: 744, height: 1133)) {
    PaymentsFixturePreview(device: .requested[6], state: 3, scheme: .light)
}

#Preview("iPad mini portrait · light · notReplaceable", traits: .fixedLayout(width: 744, height: 1133)) {
    PaymentsFixturePreview(device: .requested[6], state: 4, scheme: .light)
}

#Preview("iPad mini portrait · dark · allCancellable", traits: .fixedLayout(width: 744, height: 1133)) {
    PaymentsFixturePreview(device: .requested[6], state: 0, scheme: .dark)
}

#Preview("iPad mini portrait · dark · mixed", traits: .fixedLayout(width: 744, height: 1133)) {
    PaymentsFixturePreview(device: .requested[6], state: 1, scheme: .dark)
}

#Preview("iPad mini portrait · dark · notOwned", traits: .fixedLayout(width: 744, height: 1133)) {
    PaymentsFixturePreview(device: .requested[6], state: 2, scheme: .dark)
}

#Preview("iPad mini portrait · dark · canceling", traits: .fixedLayout(width: 744, height: 1133)) {
    PaymentsFixturePreview(device: .requested[6], state: 3, scheme: .dark)
}

#Preview("iPad mini portrait · dark · notReplaceable", traits: .fixedLayout(width: 744, height: 1133)) {
    PaymentsFixturePreview(device: .requested[6], state: 4, scheme: .dark)
}

#Preview("iPad mini landscape · light · allCancellable", traits: .fixedLayout(width: 1133, height: 744)) {
    PaymentsFixturePreview(device: .requested[7], state: 0, scheme: .light)
}

#Preview("iPad mini landscape · light · mixed", traits: .fixedLayout(width: 1133, height: 744)) {
    PaymentsFixturePreview(device: .requested[7], state: 1, scheme: .light)
}

#Preview("iPad mini landscape · light · notOwned", traits: .fixedLayout(width: 1133, height: 744)) {
    PaymentsFixturePreview(device: .requested[7], state: 2, scheme: .light)
}

#Preview("iPad mini landscape · light · canceling", traits: .fixedLayout(width: 1133, height: 744)) {
    PaymentsFixturePreview(device: .requested[7], state: 3, scheme: .light)
}

#Preview("iPad mini landscape · light · notReplaceable", traits: .fixedLayout(width: 1133, height: 744)) {
    PaymentsFixturePreview(device: .requested[7], state: 4, scheme: .light)
}

#Preview("iPad mini landscape · dark · allCancellable", traits: .fixedLayout(width: 1133, height: 744)) {
    PaymentsFixturePreview(device: .requested[7], state: 0, scheme: .dark)
}

#Preview("iPad mini landscape · dark · mixed", traits: .fixedLayout(width: 1133, height: 744)) {
    PaymentsFixturePreview(device: .requested[7], state: 1, scheme: .dark)
}

#Preview("iPad mini landscape · dark · notOwned", traits: .fixedLayout(width: 1133, height: 744)) {
    PaymentsFixturePreview(device: .requested[7], state: 2, scheme: .dark)
}

#Preview("iPad mini landscape · dark · canceling", traits: .fixedLayout(width: 1133, height: 744)) {
    PaymentsFixturePreview(device: .requested[7], state: 3, scheme: .dark)
}

#Preview("iPad mini landscape · dark · notReplaceable", traits: .fixedLayout(width: 1133, height: 744)) {
    PaymentsFixturePreview(device: .requested[7], state: 4, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · light · allCancellable", traits: .fixedLayout(width: 1376, height: 1032)) {
    PaymentsFixturePreview(device: .requested[8], state: 0, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · mixed", traits: .fixedLayout(width: 1376, height: 1032)) {
    PaymentsFixturePreview(device: .requested[8], state: 1, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · notOwned", traits: .fixedLayout(width: 1376, height: 1032)) {
    PaymentsFixturePreview(device: .requested[8], state: 2, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · canceling", traits: .fixedLayout(width: 1376, height: 1032)) {
    PaymentsFixturePreview(device: .requested[8], state: 3, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · notReplaceable", traits: .fixedLayout(width: 1376, height: 1032)) {
    PaymentsFixturePreview(device: .requested[8], state: 4, scheme: .light)
}

#Preview("iPad Pro 13 landscape · dark · allCancellable", traits: .fixedLayout(width: 1376, height: 1032)) {
    PaymentsFixturePreview(device: .requested[8], state: 0, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · mixed", traits: .fixedLayout(width: 1376, height: 1032)) {
    PaymentsFixturePreview(device: .requested[8], state: 1, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · notOwned", traits: .fixedLayout(width: 1376, height: 1032)) {
    PaymentsFixturePreview(device: .requested[8], state: 2, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · canceling", traits: .fixedLayout(width: 1376, height: 1032)) {
    PaymentsFixturePreview(device: .requested[8], state: 3, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · notReplaceable", traits: .fixedLayout(width: 1376, height: 1032)) {
    PaymentsFixturePreview(device: .requested[8], state: 4, scheme: .dark)
}

#endif
