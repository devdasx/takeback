import Foundation

/// Consensus sighash encodings shared by production signing and published-vector tests.
enum BitcoinSighash {
    static func point(_ input: WireTransaction.Input) -> Data { Data(Data(hex: input.txid)!.reversed()) + BitcoinWire.number(UInt32(input.index)) }
    static func output(_ output: SearchTransaction.Output) -> Data { BitcoinWire.number(UInt64(output.value)) + BitcoinWire.field(Data(hex: output.scriptpubkey)!) }
    static func segwit(_ tx: WireTransaction, index: Int, amount: Int64, scriptCode: Data, hashType: UInt32 = 1) throws -> Data {
        guard tx.inputs.indices.contains(index), amount >= 0 else { throw CancelFailure.invalidReplacement }
        let base = hashType & 31, anyone = hashType & 128 != 0, zero = Data(repeating: 0, count: 32)
        let points = tx.inputs.reduce(Data()) { $0 + point($1) }
        let sequences = tx.inputs.reduce(Data()) { $0 + BitcoinWire.number($1.sequence) }
        let outputs: Data
        if base != 2 && base != 3 { outputs = BitcoinWire.hash(tx.outputs.reduce(Data()) { $0 + output($1) }) }
        else if base == 3 && index < tx.outputs.count { outputs = BitcoinWire.hash(output(tx.outputs[index])) }
        else { outputs = zero }
        let input = tx.inputs[index]
        var message = BitcoinWire.number(tx.version) + (anyone ? zero : BitcoinWire.hash(points))
        message += anyone || base == 2 || base == 3 ? zero : BitcoinWire.hash(sequences)
        message += point(input) + BitcoinWire.field(scriptCode) + BitcoinWire.number(UInt64(amount)) + BitcoinWire.number(input.sequence)
        message += outputs + BitcoinWire.number(tx.locktime) + BitcoinWire.number(hashType)
        return BitcoinWire.hash(message)
    }
    static func taproot(_ tx: WireTransaction, prevouts: [SearchTransaction.Output], index: Int, hashType: UInt8 = 0) throws -> Data {
        guard [0,1,2,3,0x81,0x82,0x83].contains(hashType), tx.inputs.indices.contains(index), prevouts.count == tx.inputs.count, prevouts.allSatisfy({ $0.value >= 0 }) else { throw CancelFailure.invalidReplacement }
        let anyone = hashType & 128 != 0, base = hashType == 0 ? 1 : hashType & 3
        var message = Data([0,hashType]) + BitcoinWire.number(tx.version) + BitcoinWire.number(tx.locktime)
        if !anyone {
            message += BitcoinWire.sha(tx.inputs.reduce(Data()) { $0 + point($1) })
            message += BitcoinWire.sha(prevouts.reduce(Data()) { $0 + BitcoinWire.number(UInt64($1.value)) })
            message += BitcoinWire.sha(prevouts.reduce(Data()) { $0 + BitcoinWire.field(Data(hex: $1.scriptpubkey)!) })
            message += BitcoinWire.sha(tx.inputs.reduce(Data()) { $0 + BitcoinWire.number($1.sequence) })
        }
        if base != 2 && base != 3 { message += BitcoinWire.sha(tx.outputs.reduce(Data()) { $0 + output($1) }) }
        message += Data([0])
        if anyone { message += point(tx.inputs[index]) + BitcoinWire.number(UInt64(prevouts[index].value)) + BitcoinWire.field(Data(hex: prevouts[index].scriptpubkey)!) + BitcoinWire.number(tx.inputs[index].sequence) }
        else { message += BitcoinWire.number(UInt32(index)) }
        if base == 3 {
            guard index < tx.outputs.count else { throw CancelFailure.invalidReplacement }
            message += BitcoinWire.sha(output(tx.outputs[index]))
        }
        return BitcoinWire.tagged("TapSighash", message)
    }
}
