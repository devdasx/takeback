import SwiftUI

struct PaymentRow: View {
    let payment: PendingPayment
    let now: Date
    var showsTag = true
    var action: (() -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.displayScale) private var displayScale
    var body: some View {
        Group {
            if let action { Button(action: action) { label }.buttonStyle(PaymentRowPressStyle()) }
            else { label }
        }
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1 / displayScale) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1 / displayScale) }
    }
    private var label: some View {
        HStack(spacing: 14) {
            Image(systemName: payment.kind.symbol).font(.system(size: 20)).foregroundStyle(Theme.mute)
                .frame(width: 24).accessibilityHidden(true)
            let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                VStack(alignment: .leading, spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { amount; tag }.fixedSize(horizontal: true, vertical: false)
                        VStack(alignment: .leading, spacing: 6) { amount; tag }
                    }
                    Text(showsTag ? PaymentText.subtitle(payment, now: now) : "to \(PaymentText.shortened(payment.displayedRecipient)) · \(PaymentText.waiting(payment.sortDate, now: now))")
                        .font(Geist.font(13)).foregroundStyle(Theme.mute).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text(PaymentText.fiat(payment.displayedAmountSats, rate: payment.usdRate))
                    .font(Geist.font(15)).foregroundStyle(Theme.mute).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            if action != nil {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.mute).accessibilityHidden(true)
            }
        }
        .multilineTextAlignment(.leading).padding(.vertical, 18).frame(minHeight: 76)
        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
    private var amount: some View {
        Text(PaymentText.amount(payment.displayedAmountSats)).font(Geist.font(16, .medium)).monospacedDigit()
            .foregroundStyle(payment.kind.canCancel ? Theme.fg : Theme.mute).fixedSize(horizontal: false, vertical: true)
    }
    @ViewBuilder private var tag: some View {
        if showsTag, let title = payment.kind.tag {
            HStack(spacing: 5) {
                Circle().fill(payment.kind.amber ? Theme.amber : Theme.mute).frame(width: 6, height: 6)
                Text(title).font(.custom(Geist.Weight.semibold.rawValue, fixedSize: 11))
            }
            .foregroundStyle(payment.kind.amber ? Theme.amberText : Theme.mute)
            .padding(.horizontal, 8).frame(height: 20)
            .background((payment.kind.amber ? Theme.amber : Theme.mute).opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            .fixedSize()
        }
    }
}
private struct PaymentRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.background(configuration.isPressed ? Theme.card.opacity(0.6) : .clear) }
}

struct PaymentDetailRow: View {
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var emphasized = false
    var valueColor: Color? = nil
    var valueWeight: Geist.Weight? = nil
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.displayScale) private var displayScale
    var body: some View {
        let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Geist.font(16))
                if let subtitle { Text(subtitle).font(Geist.font(13)).foregroundStyle(Theme.mute) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(value).font(Geist.font(15, valueWeight ?? (emphasized ? .medium : .regular))).monospacedDigit()
                    .foregroundStyle(valueColor ?? (emphasized ? Theme.fg : Theme.mute))
            }
        }
        .fixedSize(horizontal: false, vertical: true).padding(.vertical, 18)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1 / displayScale) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1 / displayScale) }
    }
}
