#if DEBUG
import SwiftUI

@MainActor enum SpeedUpFixtures {
    static let names = ["Cancel", "Speed up", "New fee", "From amount", "Speed up linked", "Cancel linked", "Invalid custom", "Speeding up", "Sped up", "Payment confirmed", "Already confirmed speed", "Already confirmed cancel", "Not enough", "Rejected", "All changeable", "Mixed", "Default fee", "Welcome"]
    static let devices = WelcomeDeviceFixture.requested + [
        .init(id: "iPhone 16e", width: 390, height: 844, top: 47, bottom: 34),
        .init(id: "iPhone Air", width: 420, height: 912, top: 62, bottom: 34)
    ]
    static func action(session: SecretSession, state: Int = 0) -> CancelModel {
        var payment = PendingPayment(txid: String(repeating: "a", count: 64), types: [.bip84], ownedInputCount: 1, totalInputCount: 1, signalsRBF: true, feeSats: 880, virtualSize: 110, firstSeen: Date().addingTimeInterval(-10800), recipient: "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu", descendants: state == 4 || state == 5 ? [String(repeating: "c", count: 64)] : [])
        payment.amountSats = 4_210_000; payment.usdRate = 64_210
        payment.firstSeen = Date().addingTimeInterval(-10800)
        let model = CancelFixtures.model(session: session, payment: payment)
        let key = model.plan!.destination
        let recipient = Data(hex: "001406afd46bcdfd22ef94ac122aa11f241244a37ecc")!
        let fromAmount = state == 3 || state == 12
        let linked: [LinkedPayment] = state == 4 || state == 5 ? [.init(txid: String(repeating: "c", count: 64), fee: 660, amount: 1_180_000, recipient: "bc1q7m…r4wz", firstSeen: Date().addingTimeInterval(-3600))] : []
        let inputs = [ReplacementInput(txid: String(repeating: "b", count: 64), index: 0, value: state == 12 ? 1500 : fromAmount ? 4_210_880 : 4_500_000, key: key)]
        let cancel = CancellationPlan(originalID: payment.txid, originalFee: 880, originalVSize: 110, inputs: inputs, destination: key, descendants: linked, height: 123)
        var speed = cancel
        speed.speedUpOutputs = fromAmount ? [.init(value: inputs[0].value - 880, script: recipient)] : [.init(value: 4_210_000, script: recipient), .init(value: 289_120, script: key.script)]
        speed.changeIndex = fromAmount ? 0 : 1; speed.fromAmount = fromAmount; speed.recipientIndexes = [0]
        model.cachedPlans = [.cancel: cancel, .speedUp: speed]
        model.mode = [0,5,11].contains(state) ? .cancel : .speedUp
        model.plan = model.cachedPlans[model.mode]
        model.recommendations = try! .init(nextBlock: 52, fast: 24, medium: 14, minimum: 1)
        model.choice = .init(speed: state == 6 ? .custom : .fast, rate: 24)
        return model
    }
}
@MainActor final class SpeedUpPreviewStore: ObservableObject {
    let session = SecretSession()
    let router: WelcomeRouter
    let action: CancelModel
    let result: CancellationResultModel
    init(state: Int) {
        router = WelcomeRouter(session: session)
        action = SpeedUpFixtures.action(session: session, state: state)
        let context = CancellationContext(model: action)
        let signed = SignedCancellation(originalID: action.payment.txid, raw: ResultFixtures.raw, txid: try! TransactionID.compute(raw: ResultFixtures.raw), destination: action.payment.recipient ?? "", fee: context.fee ?? 2640, amount: action.amount ?? 0)
        result = CancellationResultModel(request: .init(signed: signed, context: context), session: session)
        switch state {
        case 7: result.showFixture(.broadcasting)
        case 8: result.showFixture(.canceled(0))
        case 9: result.showFixture(.canceled(1))
        case 10,11: result.showFixture(.error(.init(kind: .alreadyConfirmed, context: context)))
        case 12: result.showFixture(.error(.init(kind: .notEnough, context: context)))
        default: result.showFixture(.error(.init(kind: .rejected, context: context, message: "insufficient fee, rejecting replacement", details: "insufficient fee, rejecting replacement", source: "mempool.space", sameErrorHost: "electrum.example")))
        }
    }
}
struct SpeedUpFixturePreview: View {
    let state: Int
    @StateObject private var store: SpeedUpPreviewStore
    init(state: Int) { self.state = state; _store = StateObject(wrappedValue: SpeedUpPreviewStore(state: state)) }
    var body: some View {
        Group {
            if state == 2 || state == 6 { NewFeeSheet(model: store.action, initialText: state == 6 ? "1" : nil) }
            else if state < 7 { CancelView(router: store.router, session: store.session, payment: store.action.payment, model: store.action) }
            else if state < 14 { CancellationResultView(router: store.router, model: store.result) }
            else if state < 16 { PaymentsView(router: store.router, session: store.session, payments: state == 14 ? PaymentsFixtures.all : PaymentsFixtures.mixed) }
            else if state == 16 { DefaultFeeView(router: store.router, previewRates: store.action.recommendations) }
            else { WelcomeView(router: store.router) }
        }.takebackStyle()
    }
}
/// Each requested device preview exposes every state, in both appearances, without running a device matrix.
struct SpeedUpPreviewCatalog: View {
    let device: WelcomeDeviceFixture
    let scheme: ColorScheme
    @State private var state = 1
    var body: some View {
        SpeedUpFixturePreview(state: state).id(state)
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: device.top) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: device.bottom) }
            .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: device.trailing) }
            .preferredColorScheme(scheme)
            .contextMenu { ForEach(SpeedUpFixtures.names.indices, id: \.self) { i in Button(SpeedUpFixtures.names[i]) { state = i } } }
    }
}

#Preview("SE · light · hold for states", traits: .fixedLayout(width: 375, height: 667)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[0], scheme: .light)
}

#Preview("SE · dark · hold for states", traits: .fixedLayout(width: 375, height: 667)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[0], scheme: .dark)
}

#Preview("17 Pro · light · hold for states", traits: .fixedLayout(width: 402, height: 874)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[1], scheme: .light)
}

#Preview("17 Pro · dark · hold for states", traits: .fixedLayout(width: 402, height: 874)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[1], scheme: .dark)
}

#Preview("17 Pro Max · light · hold for states", traits: .fixedLayout(width: 440, height: 956)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[2], scheme: .light)
}

#Preview("17 Pro Max · dark · hold for states", traits: .fixedLayout(width: 440, height: 956)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[2], scheme: .dark)
}

#Preview("Fold outer · light · hold for states", traits: .fixedLayout(width: 466, height: 678)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[3], scheme: .light)
}

#Preview("Fold outer · dark · hold for states", traits: .fixedLayout(width: 466, height: 678)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[3], scheme: .dark)
}

#Preview("Fold inner · light · hold for states", traits: .fixedLayout(width: 890, height: 626)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[4], scheme: .light)
}

#Preview("Fold inner · dark · hold for states", traits: .fixedLayout(width: 890, height: 626)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[4], scheme: .dark)
}

#Preview("Fold rotated · light · hold for states", traits: .fixedLayout(width: 626, height: 890)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[5], scheme: .light)
}

#Preview("Fold rotated · dark · hold for states", traits: .fixedLayout(width: 626, height: 890)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[5], scheme: .dark)
}

#Preview("iPad mini portrait · light · hold for states", traits: .fixedLayout(width: 744, height: 1133)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[6], scheme: .light)
}

#Preview("iPad mini portrait · dark · hold for states", traits: .fixedLayout(width: 744, height: 1133)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[6], scheme: .dark)
}

#Preview("iPad mini landscape · light · hold for states", traits: .fixedLayout(width: 1133, height: 744)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[7], scheme: .light)
}

#Preview("iPad mini landscape · dark · hold for states", traits: .fixedLayout(width: 1133, height: 744)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[7], scheme: .dark)
}

#Preview("iPad Pro landscape · light · hold for states", traits: .fixedLayout(width: 1376, height: 1032)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[8], scheme: .light)
}

#Preview("iPad Pro landscape · dark · hold for states", traits: .fixedLayout(width: 1376, height: 1032)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[8], scheme: .dark)
}

#Preview("13 mini · light · hold for states", traits: .fixedLayout(width: 375, height: 812)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[9], scheme: .light)
}

#Preview("13 mini · dark · hold for states", traits: .fixedLayout(width: 375, height: 812)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[9], scheme: .dark)
}

#Preview("iPad Pro portrait · light · hold for states", traits: .fixedLayout(width: 1032, height: 1376)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[10], scheme: .light)
}

#Preview("iPad Pro portrait · dark · hold for states", traits: .fixedLayout(width: 1032, height: 1376)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[10], scheme: .dark)
}

#Preview("16e · light · hold for states", traits: .fixedLayout(width: 390, height: 844)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[11], scheme: .light)
}

#Preview("16e · dark · hold for states", traits: .fixedLayout(width: 390, height: 844)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[11], scheme: .dark)
}

#Preview("Air · light · hold for states", traits: .fixedLayout(width: 420, height: 912)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[12], scheme: .light)
}

#Preview("Air · dark · hold for states", traits: .fixedLayout(width: 420, height: 912)) {
    SpeedUpPreviewCatalog(device: SpeedUpFixtures.devices[12], scheme: .dark)
}

#Preview("SE AX3", traits: .fixedLayout(width: 375, height: 667)) {
    SpeedUpFixturePreview(state: 1).dynamicTypeSize(.accessibility3)
}
#endif
