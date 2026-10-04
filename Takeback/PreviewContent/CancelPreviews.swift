#if DEBUG
import SwiftUI

enum CancelFixtures {
    static let names = ["cancel", "linked", "fee", "custom", "custom-empty", "custom-low", "custom-high"]
    @MainActor static func model(session: SecretSession, linked: Bool = false, payment: PendingPayment? = nil) -> CancelModel {
        var payment = payment ?? PaymentsFixtures.payment(linked ? .linked : .normal, id: "a")
        payment.firstSeen = Date().addingTimeInterval(-10800)
        let model = CancelModel(payment: payment, session: session, defaultSpeed: .fast)
        let script = Data(hex: "0014751e76e8199196d454941c45d1b3a323f1433bd6")!
        let address = SigningAddress(type: .bip84, path: [], script: script, compressed: true)
        model.plan = CancellationPlan(originalID: payment.txid, originalFee: 420, originalVSize: 210,
            inputs: [.init(txid: String(repeating: "b", count: 64), index: 0, value: 4_210_000, key: address)], destination: address,
            descendants: linked ? [.init(txid: String(repeating: "c", count: 64), fee: 200, amount: 2_400_000, recipient: payment.recipient, firstSeen: Date().addingTimeInterval(-3600))] : [], height: 900_000)
        model.recommendations = try! FeeRecommendations(nextBlock: 30, fast: 20, medium: 10, minimum: 1)
        model.choice = .init(speed: .fast, rate: 20); model.fixture = true
        return model
    }
    @MainActor static func uiModel(payment: PendingPayment, session: SecretSession) -> CancelModel? {
        if ProcessInfo.processInfo.arguments.contains("--speed-ui") { return SpeedUpFixtures.action(session: session) }
        guard ProcessInfo.processInfo.arguments.contains("-cancel-ui") || ProcessInfo.processInfo.arguments.contains("-payments-ui") else { return nil }
        return model(session: session, linked: payment.kind == .linked, payment: payment)
    }
}
@MainActor final class CancelPreviewStore: ObservableObject {
    let session = SecretSession()
    let router: WelcomeRouter
    let model: CancelModel
    init(state: Int) {
        router = WelcomeRouter(session: session)
        model = CancelFixtures.model(session: session, linked: state == 1)
        if state >= 3 { model.choice = .init(speed: .custom, rate: 25) }
    }
}
struct CancelFixturePreview: View {
    let device: WelcomeDeviceFixture
    let state: Int
    let scheme: ColorScheme
    @StateObject private var store: CancelPreviewStore
    init(device: WelcomeDeviceFixture, state: Int, scheme: ColorScheme) {
        self.device = device; self.state = state; self.scheme = scheme
        _store = StateObject(wrappedValue: CancelPreviewStore(state: state))
    }
    var body: some View {
        Group {
            if state < 2 { CancelView(router: store.router, session: store.session, payment: store.model.payment, model: store.model) }
            else { NewFeeSheet(model: store.model, initialText: state == 4 ? "" : state == 5 ? "1" : state == 6 ? "91" : nil) }
        }
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: device.top) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: device.bottom) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: device.trailing) }
        .preferredColorScheme(scheme)
    }
}

#Preview("iPhone SE · light · cancel", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 0, scheme: .light)
}

#Preview("iPhone SE · light · linked", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 1, scheme: .light)
}

#Preview("iPhone SE · light · fee", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 2, scheme: .light)
}

#Preview("iPhone SE · light · custom", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 3, scheme: .light)
}

#Preview("iPhone SE · dark · cancel", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 0, scheme: .dark)
}

#Preview("iPhone SE · dark · linked", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 1, scheme: .dark)
}

#Preview("iPhone SE · dark · fee", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 2, scheme: .dark)
}

#Preview("iPhone SE · dark · custom", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 3, scheme: .dark)
}

#Preview("iPhone 17 Pro · light · cancel", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 0, scheme: .light)
}

#Preview("iPhone 17 Pro · light · linked", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 1, scheme: .light)
}

#Preview("iPhone 17 Pro · light · fee", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 2, scheme: .light)
}

#Preview("iPhone 17 Pro · light · custom", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 3, scheme: .light)
}

#Preview("iPhone 17 Pro · dark · cancel", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 0, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · linked", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 1, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · fee", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 2, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · custom", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 3, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · light · cancel", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 0, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · linked", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 1, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · fee", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 2, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · custom", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 3, scheme: .light)
}

#Preview("iPhone 17 Pro Max · dark · cancel", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 0, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · linked", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 1, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · fee", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 2, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · custom", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 3, scheme: .dark)
}

#Preview("Duo outer · light · cancel", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 0, scheme: .light)
}

#Preview("Duo outer · light · linked", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 1, scheme: .light)
}

#Preview("Duo outer · light · fee", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 2, scheme: .light)
}

#Preview("Duo outer · light · custom", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 3, scheme: .light)
}

#Preview("Duo outer · dark · cancel", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 0, scheme: .dark)
}

#Preview("Duo outer · dark · linked", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 1, scheme: .dark)
}

#Preview("Duo outer · dark · fee", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 2, scheme: .dark)
}

#Preview("Duo outer · dark · custom", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 3, scheme: .dark)
}

#Preview("Duo inner · light · cancel", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 0, scheme: .light)
}

#Preview("Duo inner · light · linked", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 1, scheme: .light)
}

#Preview("Duo inner · light · fee", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 2, scheme: .light)
}

#Preview("Duo inner · light · custom", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 3, scheme: .light)
}

#Preview("Duo inner · dark · cancel", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 0, scheme: .dark)
}

#Preview("Duo inner · dark · linked", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 1, scheme: .dark)
}

#Preview("Duo inner · dark · fee", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 2, scheme: .dark)
}

#Preview("Duo inner · dark · custom", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 3, scheme: .dark)
}

#Preview("Duo rotated · light · cancel", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 0, scheme: .light)
}

#Preview("Duo rotated · light · linked", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 1, scheme: .light)
}

#Preview("Duo rotated · light · fee", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 2, scheme: .light)
}

#Preview("Duo rotated · light · custom", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 3, scheme: .light)
}

#Preview("Duo rotated · dark · cancel", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 0, scheme: .dark)
}

#Preview("Duo rotated · dark · linked", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 1, scheme: .dark)
}

#Preview("Duo rotated · dark · fee", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 2, scheme: .dark)
}

#Preview("Duo rotated · dark · custom", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 3, scheme: .dark)
}

#Preview("iPad mini portrait · light · cancel", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 0, scheme: .light)
}

#Preview("iPad mini portrait · light · linked", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 1, scheme: .light)
}

#Preview("iPad mini portrait · light · fee", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 2, scheme: .light)
}

#Preview("iPad mini portrait · light · custom", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 3, scheme: .light)
}

#Preview("iPad mini portrait · dark · cancel", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 0, scheme: .dark)
}

#Preview("iPad mini portrait · dark · linked", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 1, scheme: .dark)
}

#Preview("iPad mini portrait · dark · fee", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 2, scheme: .dark)
}

#Preview("iPad mini portrait · dark · custom", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 3, scheme: .dark)
}

#Preview("iPad mini landscape · light · cancel", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 0, scheme: .light)
}

#Preview("iPad mini landscape · light · linked", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 1, scheme: .light)
}

#Preview("iPad mini landscape · light · fee", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 2, scheme: .light)
}

#Preview("iPad mini landscape · light · custom", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 3, scheme: .light)
}

#Preview("iPad mini landscape · dark · cancel", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 0, scheme: .dark)
}

#Preview("iPad mini landscape · dark · linked", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 1, scheme: .dark)
}

#Preview("iPad mini landscape · dark · fee", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 2, scheme: .dark)
}

#Preview("iPad mini landscape · dark · custom", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 3, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · light · cancel", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 0, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · linked", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 1, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · fee", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 2, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · custom", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 3, scheme: .light)
}

#Preview("iPad Pro 13 landscape · dark · cancel", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 0, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · linked", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 1, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · fee", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 2, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · custom", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 3, scheme: .dark)
}


#Preview("iPhone SE · light · Custom empty", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 4, scheme: .light)
}

#Preview("iPhone SE · light · Custom low", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 5, scheme: .light)
}

#Preview("iPhone SE · light · Custom high", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 6, scheme: .light)
}

#Preview("iPhone SE · dark · Custom empty", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 4, scheme: .dark)
}

#Preview("iPhone SE · dark · Custom low", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 5, scheme: .dark)
}

#Preview("iPhone SE · dark · Custom high", traits: .fixedLayout(width: 375, height: 667)) {
    CancelFixturePreview(device: .requested[0], state: 6, scheme: .dark)
}

#Preview("iPhone 17 Pro · light · Custom empty", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 4, scheme: .light)
}

#Preview("iPhone 17 Pro · light · Custom low", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 5, scheme: .light)
}

#Preview("iPhone 17 Pro · light · Custom high", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 6, scheme: .light)
}

#Preview("iPhone 17 Pro · dark · Custom empty", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 4, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · Custom low", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 5, scheme: .dark)
}

#Preview("iPhone 17 Pro · dark · Custom high", traits: .fixedLayout(width: 402, height: 874)) {
    CancelFixturePreview(device: .requested[1], state: 6, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · light · Custom empty", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 4, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · Custom low", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 5, scheme: .light)
}

#Preview("iPhone 17 Pro Max · light · Custom high", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 6, scheme: .light)
}

#Preview("iPhone 17 Pro Max · dark · Custom empty", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 4, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · Custom low", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 5, scheme: .dark)
}

#Preview("iPhone 17 Pro Max · dark · Custom high", traits: .fixedLayout(width: 440, height: 956)) {
    CancelFixturePreview(device: .requested[2], state: 6, scheme: .dark)
}

#Preview("Duo outer · light · Custom empty", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 4, scheme: .light)
}

#Preview("Duo outer · light · Custom low", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 5, scheme: .light)
}

#Preview("Duo outer · light · Custom high", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 6, scheme: .light)
}

#Preview("Duo outer · dark · Custom empty", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 4, scheme: .dark)
}

#Preview("Duo outer · dark · Custom low", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 5, scheme: .dark)
}

#Preview("Duo outer · dark · Custom high", traits: .fixedLayout(width: 466, height: 678)) {
    CancelFixturePreview(device: .requested[3], state: 6, scheme: .dark)
}

#Preview("Duo inner · light · Custom empty", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 4, scheme: .light)
}

#Preview("Duo inner · light · Custom low", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 5, scheme: .light)
}

#Preview("Duo inner · light · Custom high", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 6, scheme: .light)
}

#Preview("Duo inner · dark · Custom empty", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 4, scheme: .dark)
}

#Preview("Duo inner · dark · Custom low", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 5, scheme: .dark)
}

#Preview("Duo inner · dark · Custom high", traits: .fixedLayout(width: 890, height: 626)) {
    CancelFixturePreview(device: .requested[4], state: 6, scheme: .dark)
}

#Preview("Duo rotated · light · Custom empty", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 4, scheme: .light)
}

#Preview("Duo rotated · light · Custom low", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 5, scheme: .light)
}

#Preview("Duo rotated · light · Custom high", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 6, scheme: .light)
}

#Preview("Duo rotated · dark · Custom empty", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 4, scheme: .dark)
}

#Preview("Duo rotated · dark · Custom low", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 5, scheme: .dark)
}

#Preview("Duo rotated · dark · Custom high", traits: .fixedLayout(width: 626, height: 890)) {
    CancelFixturePreview(device: .requested[5], state: 6, scheme: .dark)
}

#Preview("iPad mini portrait · light · Custom empty", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 4, scheme: .light)
}

#Preview("iPad mini portrait · light · Custom low", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 5, scheme: .light)
}

#Preview("iPad mini portrait · light · Custom high", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 6, scheme: .light)
}

#Preview("iPad mini portrait · dark · Custom empty", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 4, scheme: .dark)
}

#Preview("iPad mini portrait · dark · Custom low", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 5, scheme: .dark)
}

#Preview("iPad mini portrait · dark · Custom high", traits: .fixedLayout(width: 744, height: 1133)) {
    CancelFixturePreview(device: .requested[6], state: 6, scheme: .dark)
}

#Preview("iPad mini landscape · light · Custom empty", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 4, scheme: .light)
}

#Preview("iPad mini landscape · light · Custom low", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 5, scheme: .light)
}

#Preview("iPad mini landscape · light · Custom high", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 6, scheme: .light)
}

#Preview("iPad mini landscape · dark · Custom empty", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 4, scheme: .dark)
}

#Preview("iPad mini landscape · dark · Custom low", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 5, scheme: .dark)
}

#Preview("iPad mini landscape · dark · Custom high", traits: .fixedLayout(width: 1133, height: 744)) {
    CancelFixturePreview(device: .requested[7], state: 6, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · light · Custom empty", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 4, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · Custom low", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 5, scheme: .light)
}

#Preview("iPad Pro 13 landscape · light · Custom high", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 6, scheme: .light)
}

#Preview("iPad Pro 13 landscape · dark · Custom empty", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 4, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · Custom low", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 5, scheme: .dark)
}

#Preview("iPad Pro 13 landscape · dark · Custom high", traits: .fixedLayout(width: 1376, height: 1032)) {
    CancelFixturePreview(device: .requested[8], state: 6, scheme: .dark)
}

#endif
