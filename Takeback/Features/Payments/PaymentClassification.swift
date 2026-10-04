import Foundation

struct PaymentCancellation: Hashable, Sendable {
    let originalTxid: String
    let originalRecipient: String?
    let originalAmountSats: Int64
    let originalFeeRate: Decimal
    let originalFirstSeen: Date?
    let replacementTxid: String
    let replacementFeeRate: Decimal
    let replacementFirstSeen: Date?
}

enum PaymentKind: String, CaseIterable, Sendable {
    case normal, linked, notOwned, canceling, notReplaceable
    var canCancel: Bool { self == .normal || self == .linked || self == .notReplaceable }
    var symbol: String { switch self { case .normal, .linked, .notReplaceable: "arrow.up.right"; case .notOwned: "lock"; case .canceling: "clock" } }
    var tag: String? {
        switch self {
        case .normal: nil
        case .linked: "Linked payment"
        case .notOwned: "Some coins aren’t yours"
        case .canceling: "Canceling · pending"
        case .notReplaceable: nil
        }
    }
    var amber: Bool { self == .linked || self == .canceling }
}

extension PendingPayment {
    var kind: PaymentKind {
        if cancellation != nil { return .canceling }
        if ownedInputCount != totalInputCount { return .notOwned }
        if !signalsRBF && (descendants ?? []).isEmpty { return .notReplaceable }
        if !(descendants ?? []).isEmpty { return .linked }
        return .normal
    }
    var displayedAmountSats: Int64? { cancellation?.originalAmountSats ?? amountSats }
    var displayedRecipient: String? { cancellation?.originalRecipient ?? recipient }
    var sortDate: Date? { cancellation?.originalFirstSeen ?? firstSeen }
    var replacementURL: URL? {
        guard let cancellation, TransactionID.isValid(cancellation.replacementTxid),
              explorerBaseURL.scheme == "https", explorerBaseURL.host != nil,
              explorerBaseURL.user == nil, explorerBaseURL.password == nil else { return nil }
        return explorerBaseURL.appendingPathComponent("tx").appendingPathComponent(cancellation.replacementTxid)
    }
}

struct PaymentsListData {
    let payments: [PendingPayment]
    init(_ payments: [PendingPayment]) {
        self.payments = payments.sorted {
            if $0.kind.canCancel != $1.kind.canCancel { return $0.kind.canCancel }
            if $0.sortDate != $1.sortDate { return ($0.sortDate ?? .distantFuture) < ($1.sortDate ?? .distantFuture) }
            return $0.txid < $1.txid
        }
    }
    var cancellable: [PendingPayment] { payments.filter { $0.kind.canCancel } }
    var restricted: [PendingPayment] { payments.filter { !$0.kind.canCancel } }
    var grouped: Bool { !restricted.isEmpty }
    var subtitle: String {
        let intro = payments.count == 1 ? "1 payment from this key is waiting to confirm. " : "\(payments.count) payments from this key are waiting to confirm. "
        return intro + (grouped ? "\(cancellable.count) can be changed." : "Pick one to speed up or cancel.")
    }
}

enum PaymentText {
    static func amount(_ sats: Int64?) -> String { sats.map { decimal(Money.bitcoin(sats: $0), minimum: 5, maximum: 8) + " BTC" } ?? "— BTC" }
    static func rate(_ value: Decimal) -> String { decimal(value, minimum: 0, maximum: 2) + " sat/vB" }
    static func fiat(_ sats: Int64?, rate: Decimal?) -> String {
        guard UserDefaults.standard.object(forKey: "showUSD") as? Bool ?? true, let sats, let rate, rate > 0, !rate.isNaN else { return "" }
        let formatter = NumberFormatter(); formatter.locale = Locale(identifier: "en_US"); formatter.numberStyle = .currency
        formatter.currencyCode = "USD"; formatter.minimumFractionDigits = 2; formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: Money.usd(sats: sats, rate: rate))) ?? "—"
    }
    static func shortened(_ text: String?, first: Int = 8, last: Int = 4) -> String {
        guard let text else { return "—" }
        return text.count > first + last ? "\(text.prefix(first))…\(text.suffix(last))" : text
    }
    static func waiting(_ date: Date?, now: Date) -> String { date.map { "waiting \(FindingModel.age($0, now: now))" } ?? "waiting" }
    static func sent(_ date: Date?, now: Date) -> String? { date.map { "sent \(FindingModel.age($0, now: now)) ago" } }
    static func subtitle(_ payment: PendingPayment, now: Date) -> String {
        let to = payment.displayedRecipient.map { "to \(shortened($0))" } ?? "To yourself"
        switch payment.kind {
        case .normal: return "\(to) · \(waiting(payment.firstSeen, now: now)) · \(rate(payment.feeRate))"
        case .linked:
            let count = payment.descendants?.count ?? 0
            return "\(to) · also cancels \(count) later \(count == 1 ? "payment" : "payments")"
        case .notOwned: return "\(to) · this key signed \(payment.ownedInputCount) of \(payment.totalInputCount) inputs"
        case .canceling:
            guard let cancel = payment.cancellation else { return "" }
            return (["Replacement waiting", rate(cancel.replacementFeeRate)] + [sent(cancel.replacementFirstSeen, now: now)].compactMap { $0 }).joined(separator: " · ")
        case .notReplaceable: return "Didn’t signal replacement · most nodes accept it"
        }
    }
    private static func decimal(_ value: Decimal, minimum: Int, maximum: Int) -> String {
        let f = NumberFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.numberStyle = .decimal
        f.usesGroupingSeparator = false; f.minimumFractionDigits = minimum; f.maximumFractionDigits = maximum
        return f.string(from: NSDecimalNumber(decimal: value)) ?? "—"
    }
}

/// Public transaction data only. Ownership is about scripts and exact spent outpoints, never amounts alone.
enum PaymentEvidence {
    static func totals(_ tx: SearchTransaction, owned: Set<String>) throws -> (amount: Int64, ours: Int64, others: Int64) {
        func sum(_ values: [Int64]) throws -> Int64 {
            var result: Int64 = 0
            for value in values {
                let (next, overflow) = result.addingReportingOverflow(value)
                guard value >= 0, !overflow, next <= 2_100_000_000_000_000 else { throw ChainError.invalidResponse }
                result = next
            }
            return result
        }
        let ours = try sum(tx.vin.filter { owned.contains($0.prevout?.scriptpubkey.lowercased() ?? "") }.compactMap { $0.prevout?.value })
        let others = try sum(tx.vin.filter { !owned.contains($0.prevout?.scriptpubkey.lowercased() ?? "") }.compactMap { $0.prevout?.value })
        let oursOut = try sum(tx.vout.filter { owned.contains($0.scriptpubkey.lowercased()) }.map(\.value))
        return (max(0, ours - oursOut), ours, others)
    }
    static func isOwnCancellation(original: SearchTransaction, replacement: SearchTransaction, owned: Set<String>) -> Bool {
        guard original.txid != replacement.txid, !original.status.confirmed, !replacement.status.confirmed,
              !replacement.vin.isEmpty, !replacement.vout.isEmpty,
              original.vout.contains(where: { $0.value > 0 && !owned.contains($0.scriptpubkey.lowercased()) }),
              original.vin.allSatisfy({ owned.contains($0.prevout?.scriptpubkey.lowercased() ?? "") }),
              replacement.vin.allSatisfy({ owned.contains($0.prevout?.scriptpubkey.lowercased() ?? "") }),
              replacement.vout.allSatisfy({ owned.contains($0.scriptpubkey.lowercased()) }),
              replacement.fee > original.fee else { return false }
        let spent = Set(original.vin.map { "\($0.txid):\($0.vout)" })
        return replacement.vin.contains { spent.contains("\($0.txid):\($0.vout)") }
    }
    static func inheritedRBF(_ tx: SearchTransaction, transactions: [String: SearchTransaction]) -> Bool {
        var pending = tx.vin.map(\.txid), seen = Set<String>()
        while let id = pending.popLast() {
            guard seen.insert(id).inserted, let parent = transactions[id], !parent.status.confirmed else { continue }
            if parent.vin.contains(where: { $0.sequence < 0xfffffffe }) { return true }
            pending += parent.vin.map(\.txid)
        }
        return false
    }
    /// Core 29 removed opt-in-only policy. Older/unknown node versions aren't guessed from software defaults.
    static func fullRBF(coreVersion: String) -> Bool {
        guard coreVersion.hasPrefix("/Satoshi:"), coreVersion.hasSuffix("/"),
              let major = Int(coreVersion.dropFirst(9).split(separator: ".").first ?? "") else { return false }
        return major >= 29
    }
}
