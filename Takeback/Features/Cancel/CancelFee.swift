import Foundation

enum FeeSpeed: String, CaseIterable, Sendable {
    case nextBlock, fast, medium, custom
    var title: String { switch self { case .nextBlock: "Next block"; case .fast: "Fast"; case .medium: "Medium"; case .custom: "Custom" } }
    var eta: String { switch self { case .nextBlock: "next block"; case .fast: "~10 min"; case .medium: "~30 min"; case .custom: "~30 min" } }
    func rate(_ fees: FeeRecommendations) -> Decimal? {
        switch self { case .nextBlock: fees.nextBlock; case .fast: fees.fast; case .medium: fees.medium; case .custom: nil }
    }
}
@MainActor enum FeePreference {
    static var defaultSpeed: FeeSpeed {
        get { let value = UserDefaults.standard.string(forKey: "defaultFee").flatMap(FeeSpeed.init(rawValue:)); return value == .custom ? .fast : value ?? .fast }
        set { guard newValue != .custom else { return }; UserDefaults.standard.set(newValue.rawValue, forKey: "defaultFee") }
    }
}
struct FeeChoice: Equatable, Sendable { let speed: FeeSpeed; let rate: Decimal }
struct CancelFeePolicy {
    let plan: CancellationPlan
    let fees: FeeRecommendations
    var minimum: Int64 { max(plan.minimumRate, (try? FeeMath.ceil(fees.minimum)) ?? plan.minimumRate) }
    var options: [FeeChoice] {
        [FeeSpeed.nextBlock,.fast,.medium].compactMap { speed in
            guard let rate = speed.rate(fees), rate > Decimal(minimum) else { return nil }; return .init(speed: speed, rate: rate)
        }
    }
    func initial(defaultSpeed: FeeSpeed) -> FeeChoice {
        options.first { $0.speed == defaultSpeed } ?? options.min { $0.rate < $1.rate } ?? .init(speed: .custom, rate: Decimal(minimum))
    }
    func parse(_ text: String) -> Decimal? {
        guard !text.isEmpty, text.count <= 15, text.utf8.allSatisfy({ (48...57).contains($0) || $0 == 46 }), text.filter({ $0 == "." }).count <= 1,
              let rate = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), !rate.isNaN, rate >= Decimal(minimum),
              (try? plan.fee(rate: rate)) != nil else { return nil }
        return rate
    }
    func eta(rate: Decimal) -> String {
        if rate >= fees.nextBlock { return "next block" }
        if rate >= fees.fast { return "~10 min" }
        if rate >= fees.medium { return "~30 min" }
        return "~1 hour"
    }
    func status(_ text: String, usd: Decimal?) -> String {
        guard !text.isEmpty else { return "Enter a fee rate" }
        guard let rate = parse(text) else { return "Must be higher than \(minimum - 1) sat/vB" }
        if rate > fees.nextBlock * 3 { return "Much higher than needed" }
        let fiat = PaymentText.fiat(try? plan.fee(rate: rate), rate: usd)
        return eta(rate: rate) + (fiat.isEmpty ? "" : " · " + fiat)
    }
}
