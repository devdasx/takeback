import Foundation

@MainActor final class CancelModel: ObservableObject {
    let payment: PendingPayment
    let session: SecretSession
    let engine: CancellationEngine
    let authorizer: any CancellationAuthorizing
    @Published var mode: PaymentActionMode = .cancel
    @Published var plan: CancellationPlan?
    @Published var recommendations: FeeRecommendations?
    @Published var choice: FeeChoice?
    @Published var busy = false
    @Published var authenticationFailed = false
    @Published var failure: CancelFailure?
    @Published var signed: SignedCancellation?
    let defaultSpeed: FeeSpeed
    private var work: CancellationKeyWork?
    private var clearHandler: UUID?
    private var generation = UUID()
    private var action: Task<Void, Never>?
    var fixture = false
    var cachedPlans: [PaymentActionMode: CancellationPlan] = [:]
    init(payment: PendingPayment, session: SecretSession, engine: CancellationEngine? = nil,
         authorizer: any CancellationAuthorizing = SigningAuthorization(), defaultSpeed: FeeSpeed? = nil) {
        self.payment = payment; self.session = session
        self.engine = engine ?? CancellationEngine(configuration: try! ChainConfiguration(mempoolURL: payment.mempoolAPIURL, electrumServers: payment.electrumServers))
        self.authorizer = authorizer; self.defaultSpeed = defaultSpeed ?? FeePreference.defaultSpeed
        clearHandler = session.registerEditorClear { [weak self] in self?.clear() }
    }
    var policy: CancelFeePolicy? { guard let plan, let recommendations else { return nil }; return .init(plan: plan, fees: recommendations) }
    var fee: Int64? { guard let plan, let choice else { return nil }; return try? plan.fee(rate: choice.rate) }
    var amount: Int64? { guard let plan, let choice else { return nil }; return try? plan.recipientAmount(rate: choice.rate) }
    var canCancel: Bool { guard !busy, let policy, let choice else { return false }; return choice.rate >= Decimal(policy.minimum) }
    var validFee: Bool { guard let plan, let choice else { return false }; return (try? plan.validate(rate: choice.rate)) != nil }
    var fromAmount: Bool { mode == .speedUp && plan?.fromAmount == true }
    func feeText(rate: Decimal) -> String {
        guard let plan, (try? plan.validate(rate: rate)) != nil, let fee = try? plan.fee(rate: rate) else { return "—" }
        let value = PaymentText.fiat(mode == .speedUp ? fee - plan.originalFee : fee, rate: payment.usdRate)
        return value.isEmpty ? "—" : (mode == .speedUp ? "+" : "") + value
    }
    func selectMode(_ value: PaymentActionMode) async {
        guard mode != value, !busy else { return }
        if let plan { cachedPlans[mode] = plan }
        mode = value; plan = cachedPlans[value]
        await load()
    }
    private func prepare(_ worker: CancellationKeyWork) async throws -> CancellationPlan {
        if mode == .speedUp { return try await engine.prepareSpeedUp(payment: payment, work: worker) }
        return try await engine.prepare(payment: payment, work: worker)
    }
    func load(forFeeRetry: Bool = false, retryRate: Decimal? = nil) async {
        guard !fixture, plan == nil, !busy else { return }
        if clearHandler == nil { clearHandler = session.registerEditorClear { [weak self] in self?.clear() } }
        busy = true; let id = generation
        defer { if generation == id { busy = false }; work?.cancel(); work = nil }
        do {
            let worker = try CancellationKeyWork(sessionKey: session.key, passphrase: session.passphrase); work = worker
            let result = try await withTaskCancellationHandler { try await prepare(worker) } onCancel: { worker.cancel() }
            let rates = try await engine.service.fees()
            try Task.checkCancellation(); guard id == generation else { return }
            plan = result; recommendations = rates
            let policy = CancelFeePolicy(plan: result, fees: rates)
            if forFeeRetry {
                choice = retryRate.map { .init(speed: .custom, rate: max(Decimal(policy.minimum), $0)) }
                    ?? policy.options.first { $0.speed == .nextBlock } ?? policy.initial(defaultSpeed: .nextBlock)
            } else if choice == nil { choice = policy.initial(defaultSpeed: defaultSpeed) }
        } catch {
            guard !Task.isCancelled, id == generation else { return }
            failure = error as? CancelFailure ?? .unavailable
        }
    }
    func refreshRates() async {
        guard !fixture, !busy else { return }
        let id = generation
        do {
            let rates = try await engine.service.fees()
            guard !Task.isCancelled, id == generation else { return }
            recommendations = rates
            if let policy, let choice, choice.speed != .custom {
                self.choice = policy.options.first { $0.speed == choice.speed } ?? policy.initial(defaultSpeed: defaultSpeed)
            }
        } catch { /* The last successful quote remains visible; signing rechecks current rates. */ }
    }
    func apply(_ choice: FeeChoice) {
        guard let policy, choice.rate >= Decimal(policy.minimum) else { return }
        self.choice = choice
    }
    func cancelPayment() {
        guard canCancel, let plan, let choice else { return }
        do { _ = try plan.validate(rate: choice.rate) } catch { failure = error as? CancelFailure ?? .invalidReplacement; return }
        busy = true; let id = generation
        action = Task { [weak self] in
            guard let self else { return }
            defer { if id == self.generation { self.busy = false }; self.work?.cancel(); self.work = nil }
            do { try await authorizer.authorize(reason: mode == .speedUp ? "Speed up this payment" : "Cancel this payment") }
            catch {
                if id == generation, !SigningAuthorization.isCancellation(error) { authenticationFailed = true }
                return
            }
            guard !Task.isCancelled, id == generation, session.key.count > 0 else { return }
            do {
                let worker = try CancellationKeyWork(sessionKey: session.key, passphrase: session.passphrase); work = worker
                let current = try await withTaskCancellationHandler { try await prepare(worker) } onCancel: { worker.cancel() }
                guard current.inputs == plan.inputs, current.destination == plan.destination,
                      current.originalFee == plan.originalFee, current.originalVSize == plan.originalVSize,
                      current.speedUpOutputs == plan.speedUpOutputs, current.changeIndex == plan.changeIndex,
                      current.fromAmount == plan.fromAmount, (mode == .cancel || current.height == plan.height),
                      current.descendants.map(\.txid) == plan.descendants.map(\.txid), current.replacedFee == plan.replacedFee else { throw CancelFailure.invalidReplacement }
                let latestFees = try await engine.service.fees()
                guard choice.rate >= latestFees.minimum else { throw CancelFailure.invalidReplacement }
                try Task.checkCancellation(); guard id == generation else { return }
                let task = Task.detached(priority: .userInitiated) { try worker.sign(current, rate: choice.rate) }
                let result = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel(); worker.cancel() }
                guard !Task.isCancelled, id == generation else { return }
                signed = result
            } catch { if !Task.isCancelled, id == generation { failure = error as? CancelFailure ?? .unavailable } }
        }
    }
    func clear() { generation = UUID(); action?.cancel(); action = nil; work?.cancel(); work = nil; plan = nil; cachedPlans.removeAll(); signed = nil; recommendations = nil; choice = nil; failure = nil; authenticationFailed = false; busy = false }
    func release() { clear(); if let clearHandler { session.unregisterEditorClear(clearHandler); self.clearHandler = nil } }
    deinit { action?.cancel(); work?.cancel() }
}
