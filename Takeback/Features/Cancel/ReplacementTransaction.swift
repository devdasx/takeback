import Foundation
import CryptoKit

enum CancelFailure: String, Error, Hashable { case alreadyConfirmed, notEnough, unavailable, invalidReplacement }
struct SigningAddress: Hashable, Sendable {
    let type: AddressStandard
    let path: [UInt32]
    let script: Data
    let compressed: Bool
    var searchPath: SearchPath? = nil
    var address: String { BitcoinAddress.encode(script: script) ?? "" }
}
struct ReplacementInput: Hashable, Sendable {
    let txid: String
    let index: UInt32
    let value: Int64
    let key: SigningAddress
    var outpoint: Data { Data(Data(hex: txid)!.reversed()) + BitcoinWire.number(index) }
}
struct LinkedPayment: Hashable, Sendable {
    let txid: String
    let fee: Int64
    let amount: Int64
    let recipient: String?
    let firstSeen: Date?
}
struct ReplacementOutput: Hashable, Sendable { let value: Int64; let script: Data }
enum PaymentActionMode: String, CaseIterable, Hashable, Sendable {
    case speedUp, cancel
    var title: String { self == .speedUp ? "Speed up payment" : "Cancel payment" }
    var busyTitle: String { self == .speedUp ? "Speeding up…" : "Canceling…" }
}
struct CancellationPlan: Hashable, Sendable {
    let originalID: String
    let originalFee: Int64
    let originalVSize: Int
    let inputs: [ReplacementInput]
    let destination: SigningAddress
    let descendants: [LinkedPayment]
    let height: UInt32
    var incrementalRelayRate: Decimal = 1
    /// The original outputs are the immutable commitment used by the self-check.
    var speedUpOutputs: [ReplacementOutput]? = nil
    var changeIndex: Int = 0
    var fromAmount = false
    var recipientIndexes: [Int]? = nil
    var mode: PaymentActionMode { speedUpOutputs == nil ? .cancel : .speedUp }
    var fixedOutputValue: Int64 { speedUpOutputs?.enumerated().filter { $0.offset != changeIndex }.reduce(0) { $0 + $1.element.value } ?? 0 }
    func outputs(amount: Int64) -> [ReplacementOutput] {
        guard let speedUpOutputs else { return [.init(value: amount, script: destination.script)] }
        return speedUpOutputs.enumerated().compactMap { index, output in
            guard index == changeIndex else { return output }
            if !fromAmount && amount < 546 { return nil }
            return .init(value: amount, script: output.script)
        }
    }
    var total: Int64 { inputs.reduce(0) { $0 + $1.value } }
    var replacedFee: Int64 { originalFee + descendants.reduce(0) { $0 + $1.fee } }
    var originalRate: Decimal { Decimal(originalFee) / Decimal(originalVSize) }
    private func estimatedSize(amount: Int64) -> Int {
        transaction(amount: amount, signatures: inputs.map { Data(repeating: 1, count: $0.key.type == .bip86 ? 64 : (mode == .cancel ? 73 : 71)) }, publicKeys: inputs.map { Data(repeating: 1, count: $0.key.compressed ? 33 : 65) }).vsize
    }
    var virtualSize: Int { estimatedSize(amount: 546) }
    func fee(rate: Decimal) throws -> Int64 {
        let target = try FeeMath.ceil(rate * Decimal(virtualSize))
        // Spend the remaining change as fee when it would be dust. Recipients never change.
        if mode == .speedUp && !fromAmount && changeIndex >= 0 && total - fixedOutputValue - target < 546 {
            guard total - fixedOutputValue >= (try FeeMath.ceil(rate * Decimal(estimatedSize(amount: 0)))) else { throw CancelFailure.notEnough }
            return total - fixedOutputValue
        }
        return target
    }
    func recipientAmount(rate: Decimal) throws -> Int64 {
        guard let original = speedUpOutputs else { return total - (try fee(rate: rate)) }
        if changeIndex < 0 { return original.reduce(0) { $0 + $1.value } }
        if fromAmount { return max(0, total - (try fee(rate: rate))) }
        let indexes = recipientIndexes ?? original.indices.filter { $0 != changeIndex }
        return indexes.reduce(0) { $0 + original[$1].value }
    }
    var minimumRate: Int64 {
        let strictRate = originalFee / Int64(originalVSize) + 1
        let normal = max((try? FeeMath.ceil(Decimal(replacedFee) / Decimal(virtualSize) + incrementalRelayRate)) ?? Int64.max, strictRate)
        guard mode == .speedUp, !fromAmount, changeIndex >= 0 else { return normal }
        let available = total - fixedOutputValue
        let droppedSize = estimatedSize(amount: 0)
        let dustStart = max(strictRate, max(0, available - 546) / Int64(virtualSize) + 1)
        if available >= replacedFee + ((try? FeeMath.ceil(incrementalRelayRate * Decimal(droppedSize))) ?? Int64.max),
           available >= ((try? FeeMath.ceil(Decimal(dustStart) * Decimal(droppedSize))) ?? Int64.max),
           Decimal(available) / Decimal(droppedSize) > originalRate {
            return min(normal, dustStart)
        }
        return normal
    }
    func validate(rate: Decimal) throws -> Int64 {
        guard !rate.isNaN, rate > originalRate, rate >= Decimal(minimumRate) else { throw CancelFailure.invalidReplacement }
        if mode == .speedUp && changeIndex < 0 { throw CancelFailure.notEnough }
        let fee = try fee(rate: rate)
        let amount = total - fixedOutputValue - fee
        let outputList = outputs(amount: amount)
        guard !outputList.isEmpty, outputList.allSatisfy({ $0.value >= 546 }) else { throw CancelFailure.notEnough }
        let size = estimatedSize(amount: amount)
        guard fee >= replacedFee + (try FeeMath.ceil(incrementalRelayRate * Decimal(size))) else { throw CancelFailure.invalidReplacement }
        return fee
    }
    func transaction(amount: Int64, signatures: [Data], publicKeys: [Data]) -> ReplacementWire {
        var scripts: [Data] = [], witness: [[Data]] = []
        for i in inputs.indices {
            let input = inputs[i], sig = signatures[i], pub = publicKeys[i]
            switch input.key.type {
            case .bip44: scripts.append(BitcoinWire.push(sig) + BitcoinWire.push(pub)); witness.append([])
            case .bip49:
                // The public-key hash is re-derived with purpose 84, supplied by scriptCode below.
                scripts.append(BitcoinWire.push(Data([0,20]) + BitcoinWire.hash160(pub))); witness.append([sig,pub])
            case .bip84: scripts.append(Data()); witness.append([sig,pub])
            case .bip86: scripts.append(Data()); witness.append([sig])
            }
        }
        return ReplacementWire(inputs: inputs, scripts: scripts, witness: witness, amount: amount, output: destination.script, height: height, outputList: outputs(amount: amount))
    }
}
enum FeeMath {
    static func ceil(_ value: Decimal) throws -> Int64 {
        guard !value.isNaN, value >= 0, value <= 2_100_000_000_000_000 else { throw CancelFailure.invalidReplacement }
        var value = value, rounded = Decimal(); NSDecimalRound(&rounded, &value, 0, .up)
        return NSDecimalNumber(decimal: rounded).int64Value
    }
}
enum BitcoinWire {
    static func number<T: FixedWidthInteger>(_ value: T) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
    static func variable(_ n: Int) -> Data {
        if n < 253 { return Data([UInt8(n)]) }
        if n <= 65535 { return Data([253]) + number(UInt16(n)) }
        return Data([254]) + number(UInt32(n))
    }
    static func field(_ data: Data) -> Data { variable(data.count) + data }
    static func push(_ data: Data) -> Data { precondition(data.count <= 75); return Data([UInt8(data.count)]) + data }
    static func sha(_ data: Data) -> Data { Data(SHA256.hash(data: data)) }
    static func hash(_ data: Data) -> Data { sha(sha(data)) }
    static func tagged(_ name: String, _ data: Data) -> Data { let tag = sha(Data(name.utf8)); return sha(tag + tag + data) }
    static func hash160(_ data: Data) -> Data {
        var result = [UInt8](repeating: 0, count: 20)
        data.withUnsafeBytes { takeback_hash160($0.bindMemory(to: UInt8.self).baseAddress, $0.count, &result) }
        return Data(result)
    }
}
struct ReplacementWire: Sendable {
    let inputs: [ReplacementInput]
    var scripts: [Data]
    var witness: [[Data]]
    let amount: Int64
    let output: Data
    let height: UInt32
    var outputList: [ReplacementOutput]? = nil
    var sequence: UInt32 = 0xfffffffd
    var hasWitness: Bool { witness.contains { !$0.isEmpty } }
    var resolvedOutputs: [ReplacementOutput] { outputList ?? [.init(value: amount, script: output)] }
    var outputs: Data { resolvedOutputs.reduce(Data()) { $0 + BitcoinWire.number(UInt64($1.value)) + BitcoinWire.field($1.script) } }
    func serialize(witness include: Bool) -> Data {
        var raw = BitcoinWire.number(UInt32(2))
        if include && hasWitness { raw += Data([0,1]) }
        raw += BitcoinWire.variable(inputs.count)
        for i in inputs.indices { raw += inputs[i].outpoint + BitcoinWire.field(scripts[i]) + BitcoinWire.number(sequence) }
        raw += BitcoinWire.variable(resolvedOutputs.count) + outputs
        if include && hasWitness { for stack in witness { raw += BitcoinWire.variable(stack.count); for item in stack { raw += BitcoinWire.field(item) } } }
        raw += BitcoinWire.number(height)
        return raw
    }
    var vsize: Int { (serialize(witness: false).count * 3 + serialize(witness: true).count + 3) / 4 }
    func signatureHash(index: Int, publicKey: Data) throws -> Data {
        let input = inputs[index]
        let sequence = BitcoinWire.number(sequence)
        let outpoints = inputs.reduce(Data()) { $0 + $1.outpoint }
        let sequences = inputs.reduce(Data()) { result, _ in result + sequence }
        let scriptCode = Data([0x76,0xa9,20]) + BitcoinWire.hash160(publicKey) + Data([0x88,0xac])
        switch input.key.type {
        case .bip86:
            return try BitcoinSighash.taproot(WireTransaction(serialize(witness: false)), prevouts: inputs.map { .init(scriptpubkey: $0.key.script.hex, scriptpubkey_address: nil, value: $0.value) }, index: index)
        case .bip49, .bip84:
            return try BitcoinSighash.segwit(WireTransaction(serialize(witness: false)), index: index, amount: input.value, scriptCode: scriptCode)
        case .bip44:
            var unsigned = self; unsigned.scripts = inputs.indices.map { $0 == index ? scriptCode : Data() }; unsigned.witness = inputs.map { _ in [] }
            return BitcoinWire.hash(unsigned.serialize(witness: false) + BitcoinWire.number(UInt32(1)))
        }
    }
}
struct SignedCancellation: Hashable, Sendable {
    let originalID: String
    let raw: Data
    let txid: String
    let destination: String
    let fee: Int64
    let amount: Int64
}
