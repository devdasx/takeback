import Foundation

struct SearchTransaction: Decodable, Sendable {
    struct Output: Decodable, Sendable {
        let scriptpubkey: String
        let scriptpubkey_address: String?
        let value: Int64
    }
    struct Input: Decodable, Sendable {
        let txid: String
        let vout: Int
        let sequence: UInt32
        let prevout: Output?
    }
    struct Status: Decodable, Sendable {
        let confirmed: Bool
        let block_time: Int?
    }
    let txid: String
    let vin: [Input]
    let vout: [Output]
    let fee: Int64
    let weight: Int
    let status: Status

    func validate() throws {
        guard TransactionID.isValid(txid), !vin.isEmpty, !vout.isEmpty, fee >= 0, fee <= 2_100_000_000_000_000, weight > 0, weight <= 4_000_000,
              vout.allSatisfy({ $0.value >= 0 && Data(hex: $0.scriptpubkey) != nil }),
              vin.allSatisfy({ TransactionID.isValid($0.txid) && $0.vout >= 0 && ($0.prevout == nil ? $0.txid == String(repeating: "0", count: 64) : ($0.prevout!.value >= 0 && Data(hex: $0.prevout!.scriptpubkey) != nil)) }),
              !status.confirmed || (status.block_time ?? 0) > 0 else { throw ChainError.invalidResponse }
    }
}

struct PendingPayment: Hashable, Sendable {
    let txid: String
    let types: [AddressStandard]
    let ownedInputCount: Int
    let totalInputCount: Int
    let signalsRBF: Bool
    let feeSats: Int64
    let virtualSize: Int
    var signingAddresses: [SigningAddress] = []
    var feeRate: Decimal { Decimal(feeSats) / Decimal(virtualSize) }
    var firstSeen: Date?
    let recipient: String?
    /// nil means the server could not provide this metadata; [] means checked and none.
    var descendants: [String]?
    var amountSats: Int64? = nil
    var ownedInputSats: Int64? = nil
    var otherInputSats: Int64? = nil
    var usdRate: Decimal? = nil
    var fullRBF = false
    var inheritedRBF = false
    var cancellation: PaymentCancellation? = nil
    var mempoolAPIURL = URL(string: "https://mempool.space/api")!
    var electrumServers = ElectrumServer.defaults
    var explorerBaseURL = URL(string: "https://mempool.space")!
}

/// Strict wire decoder used for Electrum. Input values are resolved from verified parent transactions.
struct WireTransaction: Sendable {
    struct Input: Sendable { let txid: String; let index: Int; let sequence: UInt32 }
    let txid: String
    let inputs: [Input]
    let outputs: [SearchTransaction.Output]
    let weight: Int
    let version: UInt32
    let locktime: UInt32
    init(_ raw: Data) throws {
        txid = try TransactionID.compute(raw: raw)
        var cursor = WireCursor(raw)
        version = UInt32(try cursor.number(4))
        locktime = raw.suffix(4).enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * $1.offset) }
        let witness = raw[4] == 0
        if witness { _ = try cursor.take(2) }
        let start = cursor.offset
        let inputCount = try cursor.variable()
        var inputs: [Input] = []
        for _ in 0..<inputCount {
            let txid = try cursor.take(32).reversed().hex
            let index = try cursor.number(4)
            _ = try cursor.take(cursor.variable())
            inputs.append(.init(txid: txid, index: Int(index), sequence: UInt32(try cursor.number(4))))
        }
        let count = try cursor.variable()
        var outputs: [SearchTransaction.Output] = []
        for _ in 0..<count {
            let value = try cursor.number(8)
            guard value <= 2_100_000_000_000_000 else { throw ChainError.invalidTransaction }
            let script = try cursor.take(cursor.variable())
            outputs.append(.init(scriptpubkey: script.hex, scriptpubkey_address: BitcoinAddress.encode(script: script), value: Int64(value)))
        }
        self.inputs = inputs; self.outputs = outputs
        let strippedSize = 4 + cursor.offset - start + 4
        weight = strippedSize * 3 + raw.count
    }
}
struct WireCursor {
    let data: Data
    var offset = 0
    init(_ data: Data) { self.data = data }
    mutating func take(_ count: Int) throws -> Data {
        guard count >= 0, count <= data.count - offset else { throw ChainError.invalidTransaction }
        defer { offset += count }
        return data.subdata(in: offset..<(offset+count))
    }
    mutating func number(_ count: Int) throws -> UInt64 {
        try take(count).enumerated().reduce(UInt64(0)) { $0 | UInt64($1.element) << ($1.offset * 8) }
    }
    mutating func variable() throws -> Int {
        let tag = try number(1)
        let value = tag < 253 ? tag : try number(tag == 253 ? 2 : tag == 254 ? 4 : 8)
        guard value <= UInt64(data.count) else { throw ChainError.invalidTransaction }
        return Int(value)
    }
}
