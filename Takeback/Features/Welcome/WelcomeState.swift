import SwiftUI

@MainActor final class WelcomeRouter: ObservableObject {
    enum Destination: Hashable { case enterKey, scanner, searchPaths, settings, serverSettings, defaultFee, about, privacy, terms, licenses, license(AppLicense), finding(KeySearchPlan), payments([PendingPayment]), review(PendingPayment), canceling(CancellationRequest), cancelError(CancellationProblem), paymentExplanation(PendingPayment) }
    @Published var path: [Destination] = [] {
        didSet {
            if !path.contains(.scanner) { scanResult = nil }
            if path.isEmpty, !oldValue.isEmpty { session.returnedToWelcome() }
        }
    }
    @Published var showsHowItWorks = false
    private let session: SecretSession
    private var scanResult: ((SecureBytes) -> Void)?

    init(session: SecretSession) { self.session = session }
    func cancelTransaction() { path.append(.enterKey) }
    func openSettings() { path.append(.settings) }
    func openScanner(onResult: @escaping (SecureBytes) -> Void) {
        scanResult = onResult
        path.append(.scanner)
    }
    func receiveScan(_ bytes: SecureBytes) {
        guard path.last == .scanner else { return }
        scanResult?(bytes)
    }
    func findPendingPayments(_ plan: KeySearchPlan) { path.append(.finding(plan)) }
    func openServerSettings() { path.append(.serverSettings) }
    func showPayments(_ payments: [PendingPayment]) {
        if payments.count == 1, let payment = payments.first {
            if !payment.kind.canCancel { path.append(.payments(payments)) }
            openPayment(payment)
        }
        else if !payments.isEmpty { path.append(.payments(payments)) }
    }
    func openPayment(_ payment: PendingPayment) {
        path.append(payment.kind.canCancel ? .review(payment) : .paymentExplanation(payment))
    }
    @Published var feeRequest: String?
    var feeRateRequest: Decimal?
    var retryMode: PaymentActionMode?
    func retryCancellation(_ payment: PendingPayment, showFee: Bool, rate: Decimal? = nil, mode: PaymentActionMode = .cancel) {
        guard session.key.count > 0 else { backToKey(force: true); return }
        retryMode = mode
        feeRequest = showFee ? payment.txid : nil
        feeRateRequest = showFee ? rate : nil
        if let index = path.lastIndex(of: .review(payment)) { path = Array(path.prefix(through: index)) }
        else { path.append(.review(payment)) }
    }
    func backToKey(force: Bool = false) {
        // Result routes contain public data and must survive the successful key wipe.
        if !force, let last = path.last {
            switch last { case .canceling, .cancelError: return; default: break }
        }

        if let index = path.lastIndex(of: .enterKey) { path = Array(path.prefix(through: index)) }
    }
    /// Both the system Back button and a completed interactive pop update this binding.
    /// A canceled gesture never commits a new path or wipes the session.
    func navigate(to proposed: [Destination]) {
        if proposed.count < path.count, session.key.count == 0,
           let last = path.last, last.isResult,
           let entry = proposed.firstIndex(of: .enterKey) {
            // A result can outlive its key. Never return to a stale signing screen.
            path = Array(proposed.prefix(through: entry))
        } else { path = proposed }
    }
    func goBack() { if !path.isEmpty { navigate(to: Array(path.dropLast())) } }
    func showHowItWorks() { showsHowItWorks = true }
    func returnToWelcome() { feeRequest = nil; feeRateRequest = nil; path.removeAll() }
}

struct HowItWorksSizing: Equatable {
    let measuredHeight: CGFloat
    let availableHeight: CGFloat
    var usesLargeDetent: Bool { measuredHeight <= 0 || measuredHeight > availableHeight }
    var detents: Set<PresentationDetent> {
        usesLargeDetent ? [.large] : [.height(ceil(measuredHeight))]
    }
}

private extension WelcomeRouter.Destination {
    var isResult: Bool {
        switch self { case .canceling, .cancelError: true; default: false }
    }
}
