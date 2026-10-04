import SwiftUI

struct NewFeeSheet: View {
    @ObservedObject var model: CancelModel
    var initialText: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var custom = false
    @State private var text = ""
    @State private var fitted: CGFloat = 430
    @FocusState private var focused: Bool
    @ScaledMetric(relativeTo: .body) private var inputSize: CGFloat = 20
    private var doneAction: (() -> Void)? { custom ? { done() } : nil }
    var body: some View {
        NativeSheet(title: "New fee", detents: [.height(fitted)], doneEnabled: model.policy?.parse(text) != nil,
                    doneIdentifier: "fee.done", onDone: doneAction) {
            ScrollViewReader { proxy in
                ScrollView {
                    content
                        .padding(.horizontal, 20).padding(.bottom, 24)
                        .background { GeometryReader { proxy in Color.clear.preference(key: FeeHeight.self, value: proxy.size.height + 64) } }
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Theme.bg)
                .onPreferenceChange(FeeHeight.self) { fitted = max(220, $0) }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                    if custom { withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo("fee.footer", anchor: .bottom) } }
                }
                .onChange(of: text) { _, _ in
                    if custom { withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo("fee.footer", anchor: .bottom) } }
                }
            }
        }
        .onAppear {
            if model.choice?.speed == .custom { custom = true; text = initialText ?? model.choice.map { NSDecimalNumber(decimal: $0.rate).stringValue } ?? "" }
        }
    }
    var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.mode == .speedUp ? "Extra cost to confirm it sooner" : "Higher fees confirm the cancel sooner").font(Geist.font(13)).foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 4).padding(.bottom, 20)
            if let policy = model.policy {
                ForEach(policy.options, id: \.speed) { choice in
                    row(title: choice.speed.title + (choice.speed == model.defaultSpeed ? " · Default" : ""),
                        subtitle: "\(choice.speed.eta) · \(PaymentText.rate(choice.rate))",
                        fiat: model.feeText(rate: choice.rate),
                        selected: !custom && model.choice?.speed == choice.speed) {
                        withAnimation(.easeInOut(duration: 0.2)) { model.apply(choice) }
                        UISelectionFeedbackGenerator().selectionChanged(); dismiss()
                    }.accessibilityIdentifier("fee.\(choice.speed.rawValue)")
                }
                row(title: "Custom", subtitle: "At least \(policy.minimum) sat/vB", fiat: customFiat(policy), selected: custom) {
                    custom = true; focused = true
                }.accessibilityIdentifier("fee.custom")
                if custom {
                    HStack(spacing: 12) {
                        TextField("", text: $text).font(.custom(Geist.Weight.medium.rawValue, fixedSize: min(32, inputSize))).monospacedDigit()
                            .keyboardType(.decimalPad).focused($focused).accessibilityLabel("Custom fee rate")
                            .accessibilityIdentifier("fee.field").autocorrectionDisabled()
                            .task { focused = true }
                        Text("sat/vB").font(Geist.font(15)).foregroundStyle(Theme.mute)
                    }
                    .padding(.horizontal, 16).frame(height: 56).background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(!text.isEmpty && policy.parse(text) == nil ? Theme.red : Theme.fg, lineWidth: 1) }
                    .padding(.top, 16)
                    Text(statusText(policy)).font(Geist.font(13)).monospacedDigit()
                        .foregroundStyle(statusColor(policy))
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 8).accessibilityIdentifier("fee.status").id("fee.footer")
                }
            }
        }
    }
    private func customFiat(_ policy: CancelFeePolicy) -> String? {
        guard custom, let rate = policy.parse(text) else { return nil }
        return model.feeText(rate: rate)
    }
    private func statusText(_ policy: CancelFeePolicy) -> String {
        guard let rate = policy.parse(text), rate <= policy.fees.nextBlock * 3 else { return policy.status(text, usd: model.payment.usdRate) }
        return policy.eta(rate: rate) + " · " + model.feeText(rate: rate)
    }
    private func statusColor(_ policy: CancelFeePolicy) -> Color {
        if !text.isEmpty && policy.parse(text) == nil { return Theme.red }
        if let rate = policy.parse(text), rate > policy.fees.nextBlock * 3 { return Theme.amberText }
        return Theme.mute
    }
    private func done() {
        guard let rate = model.policy?.parse(text) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { model.apply(.init(speed: .custom, rate: rate)) }
        dismiss()
    }
    private func row(title: String, subtitle: String, fiat: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "checkmark").frame(width: 22, height: 22).opacity(selected ? 1 : 0).accessibilityHidden(true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { rowText(title, subtitle); if let fiat { Text(fiat).font(Geist.font(15, .medium)).monospacedDigit().fixedSize() } }
                    VStack(alignment: .leading, spacing: 6) { rowText(title, subtitle); if let fiat { Text(fiat).font(Geist.font(15, .medium)).monospacedDigit() } }
                }
            }
            .foregroundStyle(Theme.fg).multilineTextAlignment(.leading).padding(.vertical, 12).frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
    private func rowText(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(Geist.font(16))
            Text(subtitle).font(Geist.font(13)).monospacedDigit().foregroundStyle(Theme.mute)
        }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct FeeHeight: PreferenceKey {
    static let defaultValue: CGFloat = 430
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
