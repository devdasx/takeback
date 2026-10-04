import SwiftUI

struct CancelView: View {
    @ObservedObject var router: WelcomeRouter
    @ObservedObject var session: SecretSession
    @StateObject var model: CancelModel
    @State private var showsFee = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var phase
    init(router: WelcomeRouter, session: SecretSession, payment: PendingPayment, model: CancelModel? = nil) {
        self.router = router; self.session = session
        #if DEBUG
        _model = StateObject(wrappedValue: model ?? CancelFixtures.uiModel(payment: payment, session: session) ?? CancelModel(payment: payment, session: session))
        #else
        _model = StateObject(wrappedValue: model ?? CancelModel(payment: payment, session: session))
        #endif
    }
    var body: some View {
        LayoutReader { metrics in
            VStack(spacing: 0) {
                AdaptiveLayout(metrics: metrics, actionStyle: true) {
                    VStack(spacing: 24) { modeSwitch; hero(metrics) }
                } content: {
                    VStack(spacing: 24) {
                        rows
                        if let plan = model.plan, !plan.descendants.isEmpty { linked(plan) }
                        if model.mode == .speedUp { NoteCard(symbol: "info.circle", text: "The original is replaced by the faster version. Only one can ever confirm, so the recipient is paid once.") }
                    }
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea()).takebackStyle().nativeNavigation(title: model.mode.title)
        .bottomActions {
            PrimaryButton(title: model.mode.title, symbol: model.authorizer.symbol.isEmpty ? nil : model.authorizer.symbol, isEnabled: model.canCancel, action: model.cancelPayment)
                .accessibilityIdentifier("cancel.submit")
        }
        .sheet(isPresented: $showsFee) { NewFeeSheet(model: model) }
        .alert("Couldn’t verify it’s you", isPresented: $model.authenticationFailed) { Button("OK", role: .cancel) {} } message: { Text("Try again.") }
        .task {
            if let retryMode = router.retryMode { model.mode = retryMode; router.retryMode = nil }
            let openFee = router.feeRequest == model.payment.txid
            await model.load(forFeeRetry: openFee, retryRate: router.feeRateRequest)
            if openFee, model.policy != nil { router.feeRequest = nil; router.feeRateRequest = nil; showsFee = true }
        }
        .task(id: phase) {
            guard phase == .active else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)); try Task.checkCancellation() } catch { return }
                await model.refreshRates()
            }
        }
        .onChange(of: model.signed) { _, value in if let value { router.path.append(.canceling(.init(signed: value, context: .init(model: model)))) } }
        .onChange(of: model.failure) { _, value in if let value { showsFee = false; router.path.append(.cancelError(.preflight(value, model: model))) } }
        .onChange(of: session.wipeGeneration) { _, _ in showsFee = false; router.backToKey() }
        .onDisappear { model.release() }
    }
    private var modeBinding: Binding<PaymentActionMode> {
        Binding(get: { model.mode }, set: { value in
            UISelectionFeedbackGenerator().selectionChanged()
            Task { await model.selectMode(value) }
        })
    }
    @ViewBuilder private var modeSwitch: some View {
        if typeSize >= .accessibility3 {
            Menu {
                Picker("Action", selection: modeBinding) {
                    Label("Speed up", systemImage: "bolt").tag(PaymentActionMode.speedUp)
                    Label("Cancel", systemImage: "arrow.uturn.backward").tag(PaymentActionMode.cancel)
                }
            } label: { Label(model.mode == .speedUp ? "Speed up" : "Cancel", systemImage: "chevron.down").font(Geist.font(14, .semibold)).frame(maxWidth: .infinity, minHeight: 44) }
            .disabled(model.busy).accessibilityIdentifier("action.modeMenu")
        } else {
            ActionModePicker(selection: modeBinding).frame(height: 32)
                .disabled(model.busy).accessibilityIdentifier("action.mode")
        }
    }
    private func hero(_ metrics: LayoutMetrics) -> some View {
        let size: CGFloat = metrics.mode == .compact ? min(52, max(40, metrics.safeSize.width * 0.12)) : 56
        return VStack(alignment: metrics.mode == .split ? .leading : .center, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                Text(PaymentText.amount(model.amount)).fixedSize()
                VStack(spacing: 0) {
                    Text(btc(model.amount)).lineLimit(1).minimumScaleFactor(0.25)
                    Text("BTC")
                }
            }
            .font(Geist.font(size, .medium, relativeTo: .largeTitle)).tracking(-size * 0.05).monospacedDigit()
            .accessibilityElement(children: .ignore).accessibilityLabel(PaymentText.amount(model.amount))
            .accessibilityIdentifier("cancel.amount")
            Text(model.mode == .cancel ? "comes back to you" : model.validFee ? "arrives in \(model.policy?.eta(rate: model.choice?.rate ?? 0) ?? "~10 min")" : "arrives sooner").font(Geist.font(17, .medium))
            Text(model.mode == .speedUp ? "Same payment · still to \(PaymentText.shortened(model.payment.recipient, first: 8, last: 4))" : "\(PaymentText.fiat(model.amount, rate: model.payment.usdRate)) · \(btc(model.plan?.total ?? model.payment.ownedInputSats)) sent − \(btc(model.fee)) fee")
                .font(Geist.font(15)).monospacedDigit().foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
        }.multilineTextAlignment(metrics.mode == .split ? .leading : .center).frame(maxWidth: .infinity, alignment: metrics.mode == .split ? .leading : .center).padding(.top, 16)
            .contentTransition(.opacity).animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.choice).animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.mode)
    }
    private func btc(_ sats: Int64?) -> String { PaymentText.amount(sats).replacingOccurrences(of: " BTC", with: "") }
    private var rows: some View {
        VStack(spacing: 0) {
            if model.mode == .cancel {
            IndexRow(symbol: "arrow.up.right", title: "Original payment",
                     subtitle: "to \(PaymentText.shortened(model.payment.recipient)) · \(PaymentText.waiting(model.payment.firstSeen, now: Date()))",
                     value: PaymentText.rate(model.plan?.originalRate ?? model.payment.feeRate))
            IndexRow(symbol: "wallet.bifold", title: "Goes to", subtitle: model.plan.map { "Your \($0.destination.type.title) address · same key" } ?? "",
                     value: PaymentText.shortened(model.plan?.destination.address, first: 8, last: 6), emphasizedValue: true)
                .onLongPressGesture { if let address = model.plan?.destination.address { UIPasteboard.general.string = address } }
                .accessibilityAction(named: "Copy address") { if let address = model.plan?.destination.address { UIPasteboard.general.string = address } }
                .accessibilityIdentifier("cancel.destination")
            } else {
                IndexRow(symbol: "arrow.up.right", title: "Now", subtitle: "Waiting \(FindingModel.age(model.payment.firstSeen ?? Date())) · could take hours", value: PaymentText.rate(model.plan?.originalRate ?? model.payment.feeRate))
            }
            IndexRow(symbol: "bolt", title: "New fee", subtitle: feeDescription, value: model.choice.map { model.feeText(rate: $0.rate) } ?? "—", emphasizedValue: true) {
                if model.policy != nil { showsFee = true }
            }.disabled(model.policy == nil || model.busy).accessibilityIdentifier("cancel.fee")
            if model.mode == .speedUp {
                IndexRow(symbol: "dollarsign.circle", title: "Paid from", subtitle: model.fromAmount ? "No change in this payment · recipient gets \(PaymentText.amount(model.amount))" : "Your change · recipient gets the full amount", value: model.fromAmount ? "The amount" : "Your change")
            }
        }.contentTransition(.opacity).animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.choice).animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.mode)
    }
    private var feeDescription: String {
        guard let choice = model.choice, let policy = model.policy else { return "—" }
        if model.mode == .speedUp && !model.validFee { return "Choose a fee above \(PaymentText.rate(model.plan?.originalRate ?? model.payment.feeRate))" }
        return "\(choice.speed.title) · \(policy.eta(rate: choice.rate)) · \(PaymentText.rate(choice.rate))"
    }
    private func linked(_ plan: CancellationPlan) -> some View {
        let count = plan.descendants.count
        let body: String
        if count == 1, let child = plan.descendants.first {
            body = "\(PaymentText.amount(child.amount)) to \(PaymentText.shortened(child.recipient))\(child.firstSeen.map { " (sent \(FindingModel.age($0)) ago)" } ?? "") spent coins from this one" + (model.mode == .speedUp ? ". It will be dropped and needs to be sent again." : ", so it can’t confirm either.")
        } else { body = "These \(count) later payments spent coins from this one" + (model.mode == .speedUp ? ". They will be dropped and need to be sent again." : ", so they can’t confirm either.") }
        return WarningCard(text: body, title: count == 1 ? (model.mode == .speedUp ? "This also replaces a later payment" : "This also cancels a later payment") : "This also \(model.mode == .speedUp ? "replaces" : "cancels") \(count) later payments")
            .accessibilityIdentifier("cancel.linked")
    }
}
