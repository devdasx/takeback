import SwiftUI
import UIKit

@MainActor protocol PaymentClipboard { func copyTransactionID(_ txid: String) }
@MainActor struct SystemPaymentClipboard: PaymentClipboard {
    func copyTransactionID(_ txid: String) { UIPasteboard.general.string = txid }
}
@MainActor enum PaymentActions {
    static func copyReplacement(_ payment: PendingPayment, clipboard: any PaymentClipboard = SystemPaymentClipboard()) {
        guard let id = payment.cancellation?.replacementTxid, TransactionID.isValid(id) else { return }
        clipboard.copyTransactionID(id)
    }
}

struct PaymentExplanation: View {
    @ObservedObject var router: WelcomeRouter
    @ObservedObject var session: SecretSession
    let payment: PendingPayment
    var now = Date()
    @Environment(\.openURL) private var openURL
    var body: some View {
        LayoutReader { metrics in
            AdaptiveLayout(metrics: metrics) {
                VStack(spacing: 20) {
                    Image(systemName: payment.kind == .canceling ? "clock" : "lock")
                        .font(.system(size: 28)).foregroundStyle(payment.kind == .canceling ? Theme.amberText : Theme.fg)
                        .frame(width: 72, height: 72)
                        .background(payment.kind == .canceling ? Theme.amberBackground : Theme.card, in: Circle()).accessibilityHidden(true)
                    Text(title).font(Geist.font(metrics.mode.titleSize, .semibold, relativeTo: .title)).accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("paymentExplanation.title")
                    Text(subtitle).font(Geist.font(16)).foregroundStyle(Theme.mute)
                    if payment.kind == .canceling { StatusChip(title: "Canceling · pending", status: .pending) }
                }
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity).padding(.top, 24)
            } content: {
                if let cancellation = payment.cancellation { cancellationRows(cancellation) }
                else { ownershipRows }
            }
        }
        .background(Theme.bg.ignoresSafeArea()).takebackStyle().nativeNavigation()
        .toolbar {
            NativeBottomBar {
                if payment.cancellation != nil, let url = payment.replacementURL {
                    SecondaryButton(title: "View on mempool.space ↗") { openURL(url) }
                        .accessibilityIdentifier("paymentExplanation.explorer")
                }
                PrimaryButton(title: "Done", action: router.goBack).accessibilityIdentifier("paymentExplanation.done")
            }
        }
        .onChange(of: session.wipeGeneration) { _, _ in router.backToKey() }
    }
    private var title: String {
        switch payment.kind { case .canceling: "Already being canceled"; case .notReplaceable: "Can’t be replaced"; default: "Some coins aren’t yours" }
    }
    private var subtitle: String {
        switch payment.kind {
        case .canceling: "A cancel for this payment is already waiting. It replaces the original as soon as it confirms."
        case .notReplaceable: "This payment didn’t allow replacement, so most nodes won’t accept a cancel. It usually still confirms within a day."
        default: "This payment also spent coins from another wallet, so this key can’t sign the cancel on its own."
        }
    }
    private var ownershipRows: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "This payment")
                VStack(spacing: 0) {
                    PaymentRow(payment: payment, now: now, showsTag: false)
                    PaymentDetailRow(title: "From this key", subtitle: "\(payment.ownedInputCount) of \(payment.totalInputCount) coins",
                        value: PaymentText.amount(payment.ownedInputSats), emphasized: true)
                    if payment.kind == .notOwned {
                        PaymentDetailRow(title: "From another wallet", subtitle: "\(payment.totalInputCount - payment.ownedInputCount) of \(payment.totalInputCount) coins · not signed by this key",
                            value: PaymentText.amount(payment.otherInputSats))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "What you can do")
                VStack(spacing: 0) {
                    if payment.kind == .notOwned {
                        PaymentDetailRow(title: "Use the other wallet", subtitle: "Cancel it from the wallet that holds the other coins")
                    }
                    PaymentDetailRow(title: "Wait", subtitle: "It may still confirm. Most do within a day")
                }
            }
        }
    }
    private func cancellationRows(_ cancellation: PaymentCancellation) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 0) {
                PaymentDetailRow(title: "Original payment", subtitle: "to \(PaymentText.shortened(cancellation.originalRecipient)) · \(PaymentText.waiting(cancellation.originalFirstSeen, now: now))", value: PaymentText.rate(cancellation.originalFeeRate))
                PaymentDetailRow(title: "Replacement", subtitle: (["Back to your address"] + [PaymentText.sent(cancellation.replacementFirstSeen, now: now)].compactMap { $0 }).joined(separator: " · "), value: PaymentText.rate(cancellation.replacementFeeRate), emphasized: true)
                Button { PaymentActions.copyReplacement(payment) } label: {
                    PaymentDetailRow(title: "Transaction ID", subtitle: "Tap to copy", value: PaymentText.shortened(cancellation.replacementTxid, first: 6, last: 6))
                }.buttonStyle(.plain).accessibilityIdentifier("paymentExplanation.copy")
                    .accessibilityHint("Copies the full transaction ID")
            }
            NoteCard(symbol: "info.circle", text: "No need to cancel again. If it’s slow, you can raise its fee once more.")
        }
    }
}
