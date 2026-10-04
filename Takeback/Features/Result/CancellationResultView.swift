import SwiftUI

struct CancellationResultView: View {
    @ObservedObject var router: WelcomeRouter
    @StateObject var model: CancellationResultModel
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var appeared = false
    @State private var detailsExpanded = false
    @State private var showsExplorer = false
    @State private var explorerURL: URL?
    @State private var copied = false
    @State private var localAlert: String?
    private var speedUp: Bool { model.context.mode == .speedUp }
    private var confirmed: Bool { if case .canceled(let count) = model.state { return count > 0 }; return false }
    var body: some View {
        LayoutReader { metrics in
            if model.state == .broadcasting {
                VStack(spacing: 24) {
                    Circle().fill(Theme.card).frame(width: 88, height: 88).overlay { Spinner() }
                    Text(model.context.mode.busyTitle).font(Geist.font(metrics.mode.titleSize, .medium, relativeTo: .title))
                        .accessibilityIdentifier("result.canceling")
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if case .error(let problem) = model.state, problem.localAlert != nil {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                AdaptiveLayout(metrics: metrics) {
                    hero(metrics)
                } content: {
                    rows
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea()).takebackStyle()
        .nativeNavigation(backEnabled: model.state != .broadcasting)
        .toolbar { NativeBottomBar {
            if model.state != .broadcasting { actions }
        } }
        .interactiveDismissDisabled(model.state == .broadcasting)
        .sheet(isPresented: $showsExplorer) { if let explorerURL { SourceBrowser(url: explorerURL).ignoresSafeArea() } }
        .sheet(isPresented: $detailsExpanded) {
            NativeSheet(title: "View details") { ScrollView { if case .error(let problem) = model.state { Text(problem.details).font(Geist.font(13)).textSelection(.enabled).padding(20) } } }
        }
        .overlay(alignment: .bottom) { if copied { Text("Copied").font(Geist.font(13)).padding(12).background(Theme.card, in: Capsule()).padding(.bottom, 150) } }
        .alert(localAlert ?? "", isPresented: Binding(get: { localAlert != nil }, set: { if !$0 { localAlert = nil } })) {
            Button("Done", action: router.returnToWelcome)
        } message: { if localAlert == "Something doesn’t add up" { Text("Nothing was sent.") } }
        .onChange(of: model.state) { _, state in if case .error(let problem) = state { localAlert = problem.localAlert } }
        .onAppear { appeared = true; model.start(); model.setVisible(phase == .active); if case .error(let problem) = model.state { localAlert = problem.localAlert } }
        .onDisappear { appeared = false; model.setVisible(false) }
        .onChange(of: phase) { _, phase in model.setVisible(appeared && phase == .active) }
    }
    private func hero(_ metrics: LayoutMetrics) -> some View {
        VStack(spacing: 20) {
            if case .canceled = model.state { ResultSuccessMark(animate: !model.fixture, speedUp: speedUp) }
            else {
                Image(systemName: symbol).font(.system(size: 28)).foregroundStyle(Theme.red)
                    .frame(width: 72, height: 72).overlay { Circle().stroke(Theme.red, lineWidth: 1.5) }.accessibilityHidden(true)
            }
            Text(title).font(Geist.font(metrics.mode.titleSize, .medium, relativeTo: .title))
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("result.title")
            Text(subtitle).font(Geist.font(15)).foregroundStyle(Theme.mute)
                .accessibilityIdentifier("result.subtitle")
            if case .canceled(let count) = model.state {
                StatusChip(title: count == 0 ? "Pending · 0 confirmations" : "Confirmed · \(confirmationText(count))",
                           status: count == 0 ? .pending : .success, resultStyle: true)
                    .accessibilityIdentifier("result.status")
            }
        }
        .contentTransition(.opacity).animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.state)
        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity).padding(.top, 24)
    }
    @ViewBuilder private var rows: some View {
        if case .canceled = model.state, let signed = model.request?.signed {
            VStack(spacing: 24) {
                VStack(spacing: 0) {
                    if speedUp {
                        PaymentDetailRow(title: confirmed ? "Paid to" : "Still going to", subtitle: PaymentText.amount(signed.amount), value: PaymentText.shortened(signed.destination, first: 8, last: 4), emphasized: true)
                        PaymentDetailRow(title: "New fee", subtitle: "\(PaymentText.rate(model.context.rate)) · was \(PaymentText.rate(model.context.plan?.originalRate ?? model.context.payment.feeRate))", value: PaymentText.fiat(signed.fee, rate: model.context.payment.usdRate))
                    } else {
                    PaymentDetailRow(title: "Comes back to you", subtitle: PaymentText.fiat(signed.amount, rate: model.context.payment.usdRate), value: PaymentText.amount(signed.amount), emphasized: true, valueWeight: .semibold)
                    PaymentDetailRow(title: "New fee", value: "\(PaymentText.rate(model.context.rate)) · \(PaymentText.fiat(signed.fee, rate: model.context.payment.usdRate))")
                    }
                    Button { model.copyID(); copied = true; Task { try? await Task.sleep(for: .seconds(2)); copied = false } } label: {
                        PaymentDetailRow(title: "Transaction ID", subtitle: "Tap to copy", value: PaymentText.shortened(signed.txid, first: 6, last: 6))
                    }.buttonStyle(.plain).accessibilityIdentifier("result.copy").accessibilityHint("Copies the full transaction ID")
                }
                NoteCard(symbol: speedUp ? "lock" : "checkmark.shield", text: speedUp ? "Your key was wiped from memory." : "Your key was wiped from this iPhone.")
            }
        } else if case .error(let problem) = model.state {
            VStack(spacing: 0) {
                switch problem.kind {
                case .alreadyConfirmed:
                    PaymentDetailRow(title: "Confirmed payment", subtitle: "to \(PaymentText.shortened(model.context.payment.recipient)) · block \(problem.blockHeight.map(String.init) ?? "—")", value: PaymentText.amount(model.context.payment.amountSats))
                case .notEnough:
                    PaymentDetailRow(title: "Fee needed", value: PaymentText.amount(model.context.fee), emphasized: true)
                    PaymentDetailRow(title: speedUp && model.context.plan?.fromAmount == true ? "Left for recipient" : "Left for you", value: "Below 546 sats", valueColor: Theme.red)
                case .rejected:
                    if let host = problem.sameErrorHost { PaymentDetailRow(title: "Also tried", subtitle: "Same error", value: host) }
                    EmptyView()
                }
            }
        }
    }
    @ViewBuilder private var actions: some View {
        Group {
            switch model.state {
            case .broadcasting: EmptyView()
            case .canceled:
                explorer(model.request!.signed.txid)
                done
            case .error(let problem):
                switch problem.kind {
                case .alreadyConfirmed: explorer(model.context.payment.txid); done
                case .notEnough:
                    if model.context.canLower {
                        SecondaryButton(title: "Choose a lower fee") { retry(showFee: true) }.accessibilityIdentifier("result.lowerFee")
                    }
                    done
                case .rejected:
                    if problem.localAlert == nil {
                        SecondaryButton(title: "View details") { detailsExpanded = true }.accessibilityIdentifier("result.details")
                        PrimaryButton(title: "Try a higher fee") { retry(showFee: false) }.accessibilityIdentifier("result.higherFee")
                    } else { done }
                }
            }
        }
    }
    private var done: some View { PrimaryButton(title: "Done", action: router.returnToWelcome).accessibilityIdentifier("result.done") }
    private func explorer(_ txid: String) -> some View {
        SecondaryButton(title: "View on mempool.space ↗") {
            explorerURL = model.context.payment.explorerBaseURL.appendingPathComponent("tx").appendingPathComponent(txid); showsExplorer = true
        }.accessibilityIdentifier("result.explorer")
    }
    private func retry(showFee: Bool) {
        let rate: Decimal?
        if case .error(let problem) = model.state, problem.kind == .notEnough { rate = Decimal(model.context.minimum) }
        else { rate = nil }
        router.retryCancellation(model.context.payment, showFee: true, rate: rate, mode: model.context.mode)
    }
    private func confirmationText(_ count: Int) -> String { "\(count) \(count == 1 ? "confirmation" : "confirmations")" }
    private func sats(_ value: Int64?) -> String { value.map { "\($0) sats" } ?? "—" }
    var title: String {
        switch model.state {
        case .broadcasting: model.context.mode.busyTitle
        case .canceled: speedUp ? (confirmed ? "Payment confirmed" : "Sped up") : "Canceled"
        case .error(let problem):
            switch problem.kind {
            case .alreadyConfirmed: "It already confirmed"
            case .notEnough: "Not enough left to pay the higher fee"
            case .rejected: "The network rejected it"
            }
        }
    }
    private var symbol: String {
        guard case .error(let problem) = model.state else { return "checkmark" }
        switch problem.kind { case .alreadyConfirmed: return "clock"; case .notEnough: return "dollarsign.circle"; case .rejected: return "xmark" }
    }
    var subtitle: String {
        switch model.state {
        case .broadcasting: return ""
        case .canceled(let count):
            if speedUp {
                if count > 0, let signed = model.request?.signed { return "\(PaymentText.amount(signed.amount)) reached \(PaymentText.shortened(signed.destination, first: 8, last: 4))." }
                return "Now arriving in \(model.context.eta)."
            }
            if count > 0 { return "Back in your wallet." }
            return model.context.eta == "next block" ? "Back to your wallet in the next block." : "Back to your wallet in \(model.context.eta)."
        case .error(let problem):
            switch problem.kind {
            case .alreadyConfirmed: return speedUp ? "The payment confirmed before the faster version reached the network, so there was nothing to speed up. No extra fee was paid." : "The original payment confirmed before the cancel reached the network. Confirmed payments are final."
            case .notEnough: return "This payment is only \(PaymentText.amount(model.context.payment.amountSats)). A fee high enough to replace it would leave less than the network allows."
            case .rejected:
                if problem.definitive { return "\(problem.source) returned: “\(problem.message)”. Nothing was sent, and the original payment is unchanged." }
                return "\(problem.source) returned: “\(problem.message)”."
            }
        }
    }
}
private struct ResultSuccessMark: View {
    var animate = true
    var speedUp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    var body: some View {
        Image(systemName: speedUp ? "bolt.fill" : "checkmark").font(.system(size: speedUp ? 32 : 38)).foregroundStyle(Theme.bg)
            .frame(width: speedUp ? 80 : 88, height: speedUp ? 80 : 88).background(Theme.fg, in: Circle())
            .scaleEffect(visible || reduceMotion || !animate ? 1 : 0.6).accessibilityHidden(true)
            .onAppear { withAnimation(reduceMotion || !animate ? nil : .spring(response: 0.45, dampingFraction: 0.7)) { visible = true } }
    }
}
