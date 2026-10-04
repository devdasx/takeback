#if DEBUG
import SwiftUI

enum ResultFixtures {
    static let names = ["canceling", "pending", "confirmed", "already-confirmed", "not-enough", "rejected", "lower-fee"]
    static let raw = Data(hex: "010000000100000000000000000000000000000000000000000000000000000000000000000000000000ffffffff010100000000000000015100000000")!
    @MainActor static func request(state: Int = 1, session: SecretSession) -> CancellationRequest {
        var payment = PaymentsFixtures.payment(.normal, id: "a")
        if state == 4 || state == 6 { payment.amountSats = state == 4 ? 580 : 2080 }
        let model = CancelFixtures.model(session: session, payment: payment)
        if state == 4 || state == 6, let p = model.plan {
            model.plan = .init(originalID: p.originalID, originalFee: p.originalFee, originalVSize: p.originalVSize,
                inputs: p.inputs.map { .init(txid: $0.txid, index: $0.index, value: state == 4 ? 1000 : 2500, key: $0.key) },
                destination: p.destination, descendants: [], height: p.height)
        }
        let context = CancellationContext(model: model)
        let signed = SignedCancellation(originalID: context.payment.txid, raw: raw, txid: try! TransactionID.compute(raw: raw),
            destination: model.plan!.destination.address, fee: context.fee!, amount: context.left!)
        model.release()
        return .init(signed: signed, context: context)
    }
    @MainActor static func model(state: Int, session: SecretSession, request: CancellationRequest? = nil) -> CancellationResultModel {
        let request = request ?? self.request(state: state, session: session)
        let model = CancellationResultModel(request: request, session: session)
        switch state {
        case 0: model.showFixture(.broadcasting)
        case 1: model.showFixture(.canceled(0))
        case 2: model.showFixture(.canceled(1))
        case 3: model.showFixture(.error(.init(kind: .alreadyConfirmed, context: request.context)))
        case 4, 6: model.showFixture(.error(.init(kind: .notEnough, context: request.context)))
        default: model.showFixture(.error(.init(kind: .rejected, context: request.context, message: "insufficient fee", details: "insufficient fee")))
        }
        return model
    }
    static var uiState: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-result-ui"), args.indices.contains(index + 1), let state = Int(args[index + 1]), (0...7).contains(state) else { return nil }
        return state
    }
    @MainActor static func uiModel(request: CancellationRequest, session: SecretSession) -> CancellationResultModel? {
        guard let state = uiState else { return nil }
        if state == 7 {
            return .init(request: request, session: session,
                service: .init(configuration: try! ChainConfiguration(), http: ResultFixtureHTTP(txid: request.signed.txid), electrum: ResultFixtureElectrum()), pollInterval: .milliseconds(400))
        }
        return model(state: state, session: session, request: request)
    }
    @MainActor static func route(_ router: WelcomeRouter) {
        guard let state = uiState else { return }
        try! SecretSession.shared.key.replace(with: Data(String(repeating: "0", count: 63).appending("1").utf8))
        let request = request(state: state, session: .shared)
        router.path = [.enterKey, .review(request.context.payment), .canceling(request)]
        if state == 1 || state == 2 { SecretSession.shared.completedCancellation() }
    }
}
private actor ResultFixtureHTTP: HTTPTransport {
    let txid: String
    var reads = 0
    init(txid: String) { self.txid = txid }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let text: String
        if request.httpMethod == "POST" { text = txid }
        else if request.url!.path.hasSuffix("status") {
            reads += 1
            text = reads < 3 ? "{\"confirmed\":false}" : "{\"confirmed\":true,\"block_height\":100}"
        } else { text = "100" }
        return .init(status: 200, data: Data(text.utf8))
    }
}
private struct ResultFixtureElectrum: ElectrumTransport {
    func call(server: ElectrumServer, method: String, params: [JSONValue], timeout: TimeInterval) async throws -> JSONValue { throw ChainError.unavailable }
}
@MainActor final class ResultPreviewStore: ObservableObject {
    let session = SecretSession()
    let router: WelcomeRouter
    let model: CancellationResultModel
    init(state: Int) {
        router = WelcomeRouter(session: session)
        model = ResultFixtures.model(state: state, session: session)
    }
}
struct ResultFixturePreview: View {
    let device: WelcomeDeviceFixture
    let scheme: ColorScheme
    @StateObject private var store: ResultPreviewStore
    init(device: WelcomeDeviceFixture, state: Int, scheme: ColorScheme) {
        self.device = device; self.scheme = scheme
        _store = StateObject(wrappedValue: ResultPreviewStore(state: state))
    }
    var body: some View {
        CancellationResultView(router: store.router, model: store.model)
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: device.top) }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: device.bottom) }
            .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: device.trailing) }
            .preferredColorScheme(scheme)
    }
}
#Preview("Pending") { ResultFixturePreview(device: .requested[1], state: 1, scheme: .light) }
#Preview("Confirmed") { ResultFixturePreview(device: .requested[1], state: 2, scheme: .dark) }
#Preview("Already confirmed") { ResultFixturePreview(device: .requested[0], state: 3, scheme: .light) }
#Preview("Not enough") { ResultFixturePreview(device: .requested[0], state: 4, scheme: .dark) }
#Preview("Rejected") { ResultFixturePreview(device: .requested[4], state: 5, scheme: .light) }
#endif
