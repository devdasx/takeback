import Foundation
import CryptoKit

/// Computes the Bitcoin txid, excluding SegWit marker/flag and witness (not the wtxid).
/// This is framing validation, not script verification or a transaction signer.
enum TransactionID {
    static func compute(raw: Data) throws -> String {
        guard raw.count <= 4_000_000 else { throw ChainError.invalidTransaction }
        var cursor = Cursor(data: raw)
        var stripped = try cursor.take(4)
        let witness = try cursor.peek() == 0
        if witness {
            guard try cursor.take(2) == Data([0, 1]) else { throw ChainError.invalidTransaction }
        }
        let inputStart = cursor.offset
        let inputs = try cursor.varInt()
        guard inputs > 0, inputs <= raw.count / 41 else { throw ChainError.invalidTransaction }
        for _ in 0..<inputs {
            _ = try cursor.take(36)
            _ = try cursor.take(cursor.varInt())
            _ = try cursor.take(4)
        }
        let outputs = try cursor.varInt()
        guard outputs > 0, outputs <= raw.count / 9 else { throw ChainError.invalidTransaction }
        for _ in 0..<outputs {
            _ = try cursor.take(8)
            _ = try cursor.take(cursor.varInt())
        }
        stripped.append(raw[inputStart..<cursor.offset])
        if witness {
            var hasWitness = false
            for _ in 0..<inputs {
                let items = try cursor.varInt()
                guard items <= raw.count else { throw ChainError.invalidTransaction }
                hasWitness = hasWitness || items > 0
                for _ in 0..<items { _ = try cursor.take(cursor.varInt()) }
            }
            guard hasWitness else { throw ChainError.invalidTransaction }
        }
        stripped.append(try cursor.take(4))
        guard cursor.offset == raw.count else { throw ChainError.invalidTransaction }
        return SHA256.hash(data: Data(SHA256.hash(data: stripped))).reversed().hex
    }

    static func isValid(_ txid: String) -> Bool { txid.count == 64 && Data(hex: txid)?.count == 32 }

    private struct Cursor {
        let data: Data
        var offset = 0
        func peek() throws -> UInt8 {
            guard offset < data.count else { throw ChainError.invalidTransaction }
            return data[offset]
        }
        mutating func take(_ count: Int) throws -> Data {
            guard count >= 0, count <= data.count - offset else { throw ChainError.invalidTransaction }
            defer { offset += count }
            return data.subdata(in: offset..<(offset + count))
        }
        mutating func varInt() throws -> Int {
            let tag = try take(1)[0]
            if tag < 253 { return Int(tag) }
            let count = tag == 253 ? 2 : tag == 254 ? 4 : 8
            let bytes = try take(count)
            let value = bytes.enumerated().reduce(UInt64(0)) { $0 | UInt64($1.element) << ($1.offset * 8) }
            let minimum: UInt64 = tag == 253 ? 253 : tag == 254 ? 65_536 : 4_294_967_296
            guard value >= minimum, value <= UInt64(Int.max) else { throw ChainError.invalidTransaction }
            return Int(value)
        }
    }
}
