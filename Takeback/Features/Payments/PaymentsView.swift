import SwiftUI

struct PaymentsView: View {
    @ObservedObject var router: WelcomeRouter
    @ObservedObject var session: SecretSession
    let data: PaymentsListData
    let now: Date
    let label: String
    init(router: WelcomeRouter, session: SecretSession, payments: [PendingPayment], now: Date = Date()) {
        self.router = router; self.session = session; data = PaymentsListData(payments); self.now = now
        let detection = detectKey(session.key)
        label = detection.label(settled: true) + (detection.isPhrase && session.passphrase.count > 0 ? " + passphrase" : "")
    }
    var body: some View {
        LayoutReader { metrics in
            VStack(spacing: 16) {
                AdaptiveLayout(metrics: metrics) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pending payments").font(Geist.font(metrics.mode.titleSize, .semibold, relativeTo: .title)).accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("payments.title")
                        Text(data.subtitle).font(Geist.font(16)).foregroundStyle(Theme.mute).accessibilityIdentifier("payments.subtitle")
                    }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                } content: {
                    VStack(alignment: .leading, spacing: 24) {
                        if data.grouped {
                            group("Can change", data.cancellable)
                            group("Can’t change", data.restricted)
                        } else { rows(data.payments) }
                        NoteCard(symbol: "info.circle", text: "Speed up keeps the payment and pays a higher fee. Cancel sends the coins back to you instead. Either way, only one version can confirm.")
                    }
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea()).takebackStyle().nativeNavigation(title: label)
        .onChange(of: session.wipeGeneration) { _, _ in router.backToKey() }
    }
    private func group(_ title: String, _ payments: [PendingPayment]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            rows(payments)
        }
    }
    private func rows(_ payments: [PendingPayment]) -> some View {
        VStack(spacing: 0) {
            ForEach(payments, id: \.txid) { payment in
                PaymentRow(payment: payment, now: now) { router.openPayment(payment) }
                    .accessibilityIdentifier("payments.row.\(payment.txid)")
            }
        }
    }
}
