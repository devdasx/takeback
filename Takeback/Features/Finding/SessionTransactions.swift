import Foundation

/// Public evidence for this process only, including another key entry after Done.
/// No disk history or secrets. Electrum does not retain an evicted transaction.
actor SessionTransactions {
    static let shared = SessionTransactions()
    private var transactions: [String: SearchTransaction] = [:]
    func observe(_ values: [SearchTransaction]) -> [SearchTransaction] {
        let previous = Array(transactions.values)
        for tx in values where !tx.status.confirmed { transactions[tx.txid] = tx }
        if transactions.count > 2000 { transactions = Dictionary(uniqueKeysWithValues: values.prefix(2000).map { ($0.txid, $0) }) }
        return previous
    }
    func clear() { transactions.removeAll() }
}
