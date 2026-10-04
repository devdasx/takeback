#if DEBUG
import Foundation

enum PaymentsUITestSupport {
    static var result: SearchResult? {
        guard ProcessInfo.processInfo.arguments.contains("-payments-ui") else { return nil }
        return .init(payments: PaymentsFixtures.mixed, lastConfirmed: nil, server: "mempool.space", checkedAt: PaymentsFixtures.now)
    }
}
#endif
