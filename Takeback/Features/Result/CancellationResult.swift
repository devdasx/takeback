import Foundation
import UIKit

struct BroadcastFailure: Error, Sendable {
    struct Attempt: Hashable, Sendable { let host: String; let message: String }
    let cause: ChainError
    let message: String
    let source: String
    let attempts: [Attempt]
    let definitive: Bool
    var details: String { (["\(source): \(message)"] + attempts.map { "\($0.host): \($0.message)" }).joined(separator: "\n\n") }
    var sameErrorHost: String? { attempts.first { $0.message.trimmingCharacters(in: .whitespacesAndNewlines) == message.trimmingCharacters(in: .whitespacesAndNewlines) }?.host }
    static func describe(_ error: ChainError) -> String {
        switch error {
        case .rpc(_, let message): message
        case .http(let code): "HTTP \(code)"
        case .timeout: "The request timed out."
        case .txidMismatch: "The returned transaction ID did not match."
        case .invalidResponse: "The server returned an invalid response."
        case .connectionRefused: "The connection was refused."
        default: "The server could not be reached."
        }
    }
}
extension ChainError {
    var isHTTPRejection: Bool { if case .http(let code) = self { return (400...499).contains(code) }; return false }
}

/// Public metadata only. No key, passphrase, or key-worker survives this handoff.
struct CancellationContext: Hashable, Sendable {
    let payment: PendingPayment
    let plan: CancellationPlan?
    let rate: Decimal
    let eta: String
    let minimum: Int64
    @MainActor init(model: CancelModel) {
        payment = model.payment; plan = model.plan; rate = model.choice?.rate ?? 0; mode = model.mode
        eta = model.policy?.eta(rate: rate) ?? "~10 min"
        minimum = model.policy?.minimum ?? 0
    }
    let mode: PaymentActionMode
    var fee: Int64? { plan.flatMap { (try? $0.fee(rate: rate)) ?? (try? FeeMath.ceil(rate * Decimal($0.virtualSize))) } }
    var left: Int64? { guard let plan, let fee else { return nil }; return plan.total - plan.fixedOutputValue - fee }
    var canLower: Bool {
        guard let plan, rate > Decimal(minimum) else { return false }
        return (try? plan.validate(rate: Decimal(minimum))) != nil
    }
}
struct CancellationRequest: Hashable, Sendable {
    let signed: SignedCancellation
    let context: CancellationContext
}
struct CancellationProblem: Hashable, Sendable {
    enum Kind: Hashable, Sendable { case alreadyConfirmed, notEnough, rejected }
    let kind: Kind
    let context: CancellationContext
    var confirmations = 1
    var message = ""
    var details = ""
    var source = "Electrum"
    var sameErrorHost: String?
    var definitive = true
    var localAlert: String? = nil
    var blockHeight: Int? = nil
    @MainActor static func preflight(_ error: CancelFailure, model: CancelModel) -> Self {
        let kind: Kind = error == .alreadyConfirmed ? .alreadyConfirmed : error == .notEnough ? .notEnough : .rejected
        return .init(kind: kind, context: .init(model: model), message: "The payment could not be verified for replacement.",
                     details: "Local replacement verification failed: \(error.rawValue)", source: "Takeback", definitive: false, localAlert: error == .invalidReplacement ? "Something doesn’t add up" : nil)
    }
}

@MainActor final class CancellationResultModel: ObservableObject {
    enum State: Equatable { case broadcasting, canceled(Int), error(CancellationProblem) }
    @Published private(set) var state: State
    let request: CancellationRequest?
    let context: CancellationContext
    let session: SecretSession
    let service: ChainService
    let minimumDuration: Duration
    let pollInterval: Duration
    private let success: () -> Void
    private var started = false
    private var confirmedOnce = false
    private var broadcastTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var subscriptionTask: Task<Void, Never>?
    private var visible = false
    var fixture = false
    init(request: CancellationRequest? = nil, problem: CancellationProblem? = nil, session: SecretSession,
         service: ChainService? = nil, minimumDuration: Duration = .milliseconds(800), pollInterval: Duration = .seconds(15),
         success: @escaping () -> Void = { UINotificationFeedbackGenerator().notificationOccurred(.success) }) {
        precondition(request != nil || problem != nil)
        self.request = request; context = request?.context ?? problem!.context; self.session = session
        self.service = service ?? ChainService(configuration: try! ChainConfiguration(mempoolURL: context.payment.mempoolAPIURL, electrumServers: context.payment.electrumServers))
        self.minimumDuration = minimumDuration; self.pollInterval = pollInterval; self.success = success
        state = problem.map(State.error) ?? .broadcasting
    }
    func start() {
        guard !started, !fixture else { return }; started = true
        broadcastTask = Task { [weak self] in await self?.run() }
    }
    private func run() async {
        guard let request else {
            if case .error(let problem) = state, problem.kind == .alreadyConfirmed || problem.localAlert != nil || (problem.kind == .notEnough && !problem.context.canLower) { session.wipe() }
            if case .error(var problem) = state, problem.kind == .alreadyConfirmed,
               let count = try? await service.transactionStatus(txid: context.payment.txid), count > 0 {
                problem.confirmations = count; problem.blockHeight = try? await service.confirmationHeight(txid: context.payment.txid); state = .error(problem)
            }
            return
        }
        let start = ContinuousClock.now
        let result: State
        do {
            let id = try await service.broadcastDetailed(rawTransaction: request.signed.raw)
            guard id == request.signed.txid else { throw ChainError.txidMismatch }
            // Wipe on verified acceptance, before animation delays or confirmation polling.
            session.completedCancellation()
            result = .canceled(0)
        } catch {
            if Task.isCancelled { return }
            let failure = error as? BroadcastFailure ?? .init(cause: error as? ChainError ?? .network,
                message: BroadcastFailure.describe(error as? ChainError ?? .network), source: "Electrum", attempts: [], definitive: false)
            let diagnostic = failure.details.lowercased()
            if ["missing", "spent", "conflict", "confirmed"].contains(where: diagnostic.contains),
               let count = try? await service.transactionStatus(txid: context.payment.txid), count > 0 {
                result = .error(.init(kind: .alreadyConfirmed, context: context, confirmations: count, blockHeight: try? await service.confirmationHeight(txid: context.payment.txid)))
            } else if failure.cause == .txidMismatch {
                result = .error(.init(kind: .rejected, context: context, message: failure.message, details: failure.details, source: failure.source, definitive: false, localAlert: "Couldn’t confirm the send"))
            } else if diagnostic.contains("dust") {
                result = .error(.init(kind: .notEnough, context: context))
            } else {
                result = .error(.init(kind: .rejected, context: context, message: failure.message,
                    details: failure.details, source: failure.source, sameErrorHost: failure.sameErrorHost, definitive: failure.definitive))
            }
        }
        let remaining = minimumDuration - start.duration(to: .now)
        if remaining > .zero { try? await Task.sleep(for: remaining) }
        guard !Task.isCancelled else { return }
        if case .error(let problem) = result, problem.kind == .alreadyConfirmed || problem.localAlert != nil || (problem.kind == .notEnough && !problem.context.canLower) { session.wipe() }
        state = result
        if case .canceled = result { success(); updatePolling() }
    }
    func setVisible(_ value: Bool) { visible = value; updatePolling() }
    private func updatePolling() {
        guard visible, !fixture, case .canceled(0) = state, request != nil else {
            pollingTask?.cancel(); pollingTask = nil; subscriptionTask?.cancel(); subscriptionTask = nil; return
        }
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self, pollInterval] in
            while !Task.isCancelled {
                await self?.checkStatus()
                do { try await Task.sleep(for: pollInterval) } catch { return }
            }
        }
        if let script = context.plan?.destination.script {
            subscriptionTask = Task { [weak self, service] in
                guard let stream = try? await service.client.notifications(script: script) else { return }
                for await _ in stream { if Task.isCancelled { break }; await self?.checkStatus() }
            }
        }
    }
    private func checkStatus() async {
        guard let request, case .canceled = state else { return }
        let scripts = context.plan.map { [$0.destination.script] + $0.inputs.map { $0.key.script } } ?? []
        if let original = try? await service.transactionStatus(txid: context.payment.txid, scripts: scripts), original > 0, !Task.isCancelled {
            state = .error(.init(kind: .alreadyConfirmed, context: context, confirmations: original, blockHeight: try? await service.confirmationHeight(txid: context.payment.txid)))
            pollingTask?.cancel(); pollingTask = nil; subscriptionTask?.cancel(); subscriptionTask = nil
            session.wipe()
            return
        }
        if let count = try? await service.transactionStatus(txid: request.signed.txid, scripts: scripts), !Task.isCancelled { received(confirmations: count) }
    }

    func received(confirmations: Int) {
        guard confirmations >= 0, !confirmedOnce, case .canceled = state else { return }
        state = .canceled(confirmations)
        if confirmations > 0, !confirmedOnce { confirmedOnce = true; success(); pollingTask?.cancel(); pollingTask = nil; subscriptionTask?.cancel(); subscriptionTask = nil }
    }
    func copyID(clipboard: any PaymentClipboard = SystemPaymentClipboard()) {
        guard case .canceled = state, let id = request?.signed.txid, TransactionID.isValid(id) else { return }
        clipboard.copyTransactionID(id)
    }
    #if DEBUG
    func showFixture(_ state: State) { fixture = true; self.state = state }
    #endif
    deinit { broadcastTask?.cancel(); pollingTask?.cancel(); subscriptionTask?.cancel() }
}
