import Foundation

struct ElectrumUTXO: Equatable, Sendable {
    let txid: String
    let index: Int
    let height: Int
    let value: Int64
}
extension ElectrumClient {
    static func history(_ value: JSONValue) throws -> [TransactionSummary] {
        guard case .array(let entries) = value else { throw ChainError.invalidResponse }
        return try entries.map {
            guard case .object(let o) = $0, let id = o["tx_hash"]?.string, TransactionID.isValid(id),
                  let height = o["height"]?.integer, height >= -1 else { throw ChainError.invalidResponse }
            return .init(txid: id.lowercased(), height: height)
        }
    }
    func histories(_ hashes: [String]) async throws -> [[TransactionSummary]] {
        try await batch(hashes.map { RPCCall(method: "blockchain.scripthash.get_history", params: [.string($0)]) }).map(Self.history)
    }
    func unspent(_ hashes: [String]) async throws -> [[ElectrumUTXO]] {
        try await batch(hashes.map { RPCCall(method: "blockchain.scripthash.listunspent", params: [.string($0)]) }).map { value in
            guard case .array(let entries) = value else { throw ChainError.invalidResponse }
            return try entries.map {
                guard case .object(let o) = $0, let id = o["tx_hash"]?.string, TransactionID.isValid(id),
                      let index = o["tx_pos"]?.integer, index >= 0, index <= UInt32.max,
                      let height = o["height"]?.integer, height >= 0,
                      let amount = o["value"]?.integer, amount >= 0, amount <= 2_100_000_000_000_000 else { throw ChainError.invalidResponse }
                return .init(txid: id.lowercased(), index: index, height: height, value: Int64(amount))
            }
        }
    }
    func transactions(_ ids: [String]) async throws -> [WireTransaction] {
        guard ids.allSatisfy(TransactionID.isValid) else { throw ChainError.invalidTransaction }
        let values = try await batch(ids.map { RPCCall(method: "blockchain.transaction.get", params: [.string($0), .bool(false)]) })
        return try zip(ids, values).map { id, value in
            guard let hex = value.string, let raw = Data(hex: hex) else { throw ChainError.invalidResponse }
            let tx = try WireTransaction(raw)
            guard tx.txid == id else { throw ChainError.txidMismatch }
            return tx
        }
    }
    func tip() async throws -> Int {
        guard case .object(let o) = try await call("blockchain.headers.subscribe"), let height = o["height"]?.integer, height > 0 else { throw ChainError.invalidResponse }
        return height
    }
}
