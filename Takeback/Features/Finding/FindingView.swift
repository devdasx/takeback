import SwiftUI

struct FindingView: View {
    @ObservedObject var router: WelcomeRouter
    @ObservedObject private var session: SecretSession
    @StateObject private var model: FindingModel
    private let automaticallyStart: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(router: WelcomeRouter, session: SecretSession, plan: KeySearchPlan, model: FindingModel? = nil, automaticallyStart: Bool = true) {
        self.router = router; self.session = session; self.automaticallyStart = automaticallyStart
        _model = StateObject(wrappedValue: model ?? FindingModel(plan: plan, session: session))
    }
    var body: some View {
        LayoutReader { metrics in
            VStack(spacing: 16) {
                AdaptiveLayout(metrics: metrics) {
                    introduction(metrics)
                } content: {
                    details
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea()).takebackStyle()
        .nativeNavigation(title: model.label)
        .toolbar { NativeBottomBar {
            actions
        } }
        .onAppear { if automaticallyStart, case .searching = model.outcome { model.start() } }
        .onDisappear { model.release() }
        .onChange(of: session.wipeGeneration) { _, _ in back() }
    }
    private var searching: Bool { if case .searching = model.outcome { true } else { false } }
    private func introduction(_ metrics: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if !searching {
                let size: CGFloat = metrics.isShort ? 56 : 72
                Image(systemName: icon).font(.system(size: size == 56 ? 24 : 28))
                    .foregroundStyle(iconColor).frame(width: size, height: size)
                    .background(iconBackground, in: Circle())
                    .overlay { if case .serversDown = model.outcome { Circle().stroke(Theme.red, lineWidth: 1) } }
                    .accessibilityHidden(true)
            }
            Text(title).font(Geist.font(metrics.mode.titleSize, .semibold))
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("finding.title")
            Text(bodyText).font(Geist.font(16)).foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder private var details: some View {
        switch model.outcome {
        case .searching:
            VStack(spacing: 24) {
                ProgressBar(progress: model.progress.fraction)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.progress.fraction)
                typeRows(model.progress.rows)
                Text(model.progress.isFallback ? "\(model.progress.failedHost ?? model.primaryServer) didn’t respond · using \(model.progress.server)" : "Checking \(model.progress.server)")
                    .font(Geist.font(13, model.progress.isFallback ? .medium : .regular))
                    .foregroundStyle(model.progress.isFallback ? Theme.fg : Theme.mute)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            }
        case .found(let result):
            VStack(spacing: 24) {
                typeRows(model.progress.rows)
                Text("Checked on \(result.server) · just now").font(Geist.font(13)).foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            }
        case .none:
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Why this can happen").padding(.bottom, 16)
                ForEach(Array(model.reasons.enumerated()), id: \.offset) { _, reason in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reason.0).font(Geist.font(16))
                        Text(reason.1).font(Geist.font(13)).foregroundStyle(Theme.mute)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 18)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
                }
            }
        case .confirmed:
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "What you can do")
                Text("Ask the recipient to send it back if it was a mistake.").font(Geist.font(16))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .serversDown(let attempts):
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Tried").padding(.bottom, 16)
                ForEach(Array(attempts.enumerated()), id: \.offset) { _, attempt in
                    IndexRow(symbol: "globe", title: attempt.server, subtitle: attempt.detail)
                }
            }
        case .offline: EmptyView()
        }
    }
    private func typeRows(_ rows: [SearchRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(rows, id: \.id) { row in FindingTypeRow(row: row, single: model.plan.origin == .single) }
        }
    }
    @ViewBuilder private var actions: some View {
        Group {
            switch model.outcome {
            case .searching: SecondaryButton(title: "Stop", action: back).accessibilityIdentifier("finding.stop")
            case .found(let result):
                PrimaryButton(title: result.payments.count == 1 ? "Review payment" : "Show payments") {
                    model.stop(); router.showPayments(result.payments)
                }.accessibilityIdentifier("finding.show")
            case .none:
                // Keep the primary action visible when the system moves secondary
                // actions into the native toolbar overflow menu on narrow screens.
                PrimaryButton(title: "Try a different key", action: differentKey).accessibilityIdentifier("finding.different")
                if model.isPhrase { SecondaryButton(title: "Search 100 addresses") { model.start(gap: 100) }.accessibilityIdentifier("finding.deep") }
            case .confirmed: PrimaryButton(title: "Try a different key", action: differentKey)
            case .offline:
                PrimaryButton(title: "Try again") { model.start() }.accessibilityIdentifier("finding.retry")
                SecondaryButton(title: "Back", action: back)
            case .serversDown:
                PrimaryButton(title: "Try again") { model.start() }.accessibilityIdentifier("finding.retry")
                SecondaryButton(title: "Choose a server") { model.stop(); router.openServerSettings() }
            }
        }
    }
    private func back() { model.stop(); router.backToKey() }
    private func differentKey() { model.stop(); router.backToKey(); session.wipe() }
    private var title: String {
        switch model.outcome {
        case .searching: "Finding pending payments"
        case .found(let result): "Found \(result.payments.count) pending \(result.payments.count == 1 ? "payment" : "payments")"
        case .none: "No pending payments"
        case .confirmed: "Nothing left to cancel"
        case .offline: "You’re offline"
        case .serversDown: "Couldn’t reach the Bitcoin network"
        }
    }
    private var bodyText: String {
        switch model.outcome {
        case .searching:
            model.searchingDescription
        case .found(let result): FindingModel.foundBody(result)
        case .none: "Checked \(model.checkedDescription) and found nothing waiting."
        case .confirmed(let date): "Your last payment from this key confirmed \(FindingModel.age(date)) ago. Confirmed payments are final."
        case .offline: "Connect to Wi-Fi or mobile data to look for pending payments. Your key is still only in memory."
        case .serversDown: "\(model.primaryServer) and the backup Electrum servers didn’t respond."
        }
    }
    private var icon: String {
        switch model.outcome { case .found: "clock"; case .none: "magnifyingglass"; case .confirmed: "checkmark"; case .offline: "wifi.slash"; default: "globe" }
    }
    private var iconColor: Color {
        switch model.outcome { case .found: Theme.amberText; case .confirmed: Theme.green; default: Theme.fg }
    }
    private var iconBackground: Color {
        switch model.outcome { case .found: Theme.amberBackground; case .confirmed: Theme.green.opacity(0.12); default: Theme.card }
    }
}

private struct FindingTypeRow: View {
    let row: SearchRow
    let single: Bool
    @Environment(\.dynamicTypeSize) private var dynamicType
    var body: some View {
        HStack(spacing: 14) {
            Group {
                if row.done && row.pending > 0 { Circle().fill(Theme.amber).frame(width: 7, height: 7) }
                else if row.done { Image(systemName: "checkmark").font(.system(size: 20)).foregroundStyle(Theme.mute) }
                else if row.started { ProgressView().tint(Theme.fg) }
                else { Circle().stroke(Theme.line, lineWidth: 1).frame(width: 18, height: 18) }
            }.frame(width: 24).accessibilityHidden(true)
            let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title).font(Geist.font(16))
                    Text(row.subtitle).font(Geist.font(13)).foregroundStyle(Theme.mute)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text(value).font(Geist.font(15, row.done && row.pending > 0 ? .semibold : .regular))
                    .monospacedDigit().foregroundStyle(row.done && row.pending > 0 ? Theme.fg : Theme.mute)
            }.fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 18).overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
    private var value: String { row.status }
}
