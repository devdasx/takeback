import Foundation

struct ScanAcceptance {
    let bytes: SecureBytes
    let label: String
}
struct ScannerConfiguration: Sendable {
    let instruction: String
    let accept: @Sendable (ScanPayload) throws -> ScanAcceptance
    var rejection: @Sendable (Error, ScanPayload?) -> String = { KeyScanRouter.rejection($0, payload: $1) }
    static let privateKey = ScannerConfiguration(instruction: "Point at a QR code with your key", accept: KeyScanRouter.accept)
}

enum KeyScanRouter {
    static let addressMessage = "That’s an address, not a key. Scan the QR of your private key or recovery phrase."
    static func accept(_ payload: ScanPayload) throws -> ScanAcceptance {
        let key: SecureBytes
        switch payload.format {
        case .text, .bbqr("U"):
            let normalized = try KeyValidation.normalized(payload.bytes)
            defer { normalized.wipe() }
            let isPayment = normalized.withUnsafeBytes { raw in
                raw.prefix(8).map { (65...90).contains($0) ? $0+32 : $0 }.elementsEqual("bitcoin:".utf8)
            }
            if isPayment { throw ScanDecodeError.publicKey }
            key = try payload.bytes.withUnsafeBytes(ScanBytes.copy)
        case .ur("crypto-seed"), .ur("seed"):
            let node = try ScanCBOR.decode(payload.bytes).untagged([300,40300])
            guard let range = node.map?[1]?.byteRange else { throw ScanDecodeError.invalid }
            key = try mnemonic(entropy: payload.bytes, range: range)
        case .ur("crypto-hdkey"), .ur("hdkey"):
            key = try hdKey(payload.bytes)
        default: throw ScanDecodeError.unsupported
        }
        let detection = detectKey(key)
        guard detection.isValid else {
            key.wipe()
            if detection == .publicOnly { throw ScanDecodeError.publicKey }
            if detection == .testnet { throw ScanDecodeError.testnet }
            throw ScanDecodeError.invalid
        }
        let label: String
        if case .phrase(let count, true) = detection { label = "Recovery phrase found · \(count) words" }
        else { label = detection.label(settled: true) }
        return ScanAcceptance(bytes: key, label: label)
    }
    static func rejection(_ error: Error, payload: ScanPayload? = nil) -> String {
        if case ScanDecodeError.publicKey = error {
            if let payload, payload.format == .text || payload.format == .bbqr("U") {
                let normalized = try? KeyValidation.normalized(payload.bytes)
                defer { normalized?.wipe() }
                let address = (normalized ?? payload.bytes).withUnsafeBytes { raw -> Bool in
                    if KeyValidation.isWitnessAddress(raw) { return true }
                    if let base58 = KeyValidation.base58Check(raw) {
                        defer { base58.wipe() }; return base58.count == 21
                    }
                    // Bitcoin payment URIs are public addresses, never private imports.
                    return raw.prefix(8).map { (65...90).contains($0) ? $0+32 : $0 }.elementsEqual("bitcoin:".utf8)
                }
                if address { return addressMessage }
            }
            return KeyDetection.publicOnly.label(settled: true)
        }
        if case ScanDecodeError.testnet = error { return KeyDetection.testnet.label(settled: true) }
        return KeyDetection.unrecognized.label(settled: true)
    }
    static func mnemonic(entropy: SecureBytes, range: Range<Int>) throws -> SecureBytes {
        guard [16,20,24,28,32].contains(range.count) else { throw ScanDecodeError.invalid }
        let raw = try entropy.withUnsafeBytes { try ScanBytes.copy($0[range]) }
        defer { raw.wipe() }
        let checksum = KeyValidation.sha256(raw); defer { checksum.wipe() }
        let output = SecureBytes()
        try raw.withUnsafeBytes { bytes in try checksum.withUnsafeBytes { digest in
            let bitCount = bytes.count*8 + bytes.count/4
            for start in stride(from: 0, to: bitCount, by: 11) {
                var index = 0
                for offset in start..<start+11 {
                    let byte = offset < bytes.count*8 ? bytes[offset/8] : digest[0]
                    let bit = offset < bytes.count*8 ? 7-offset%8 : 7-(offset-bytes.count*8)
                    index = index << 1 | Int((byte >> bit) & 1)
                }
                if output.count > 0 { try output.append(32) }
                for byte in KeyValidation.words[index] { try output.append(byte) }
            }
        } }
        return output
    }
    private static func hdKey(_ source: SecureBytes) throws -> SecureBytes {
        guard let map = try ScanCBOR.decode(source).untagged([303,40303]).map else { throw ScanDecodeError.invalid }
        let master = map[1]?.boolean ?? false
        guard master || map[2]?.boolean == true else { throw ScanDecodeError.publicKey }
        guard map[2]?.boolean != false, let key = map[3]?.byteRange, key.count == 33,
              let chain = map[4]?.byteRange, chain.count == 32,
              source.withUnsafeBytes({ $0[key.lowerBound] == 0 && KeyValidation.validScalar(UnsafeRawBufferPointer(rebasing: $0[(key.lowerBound+1)..<key.upperBound])) }) else { throw ScanDecodeError.invalid }
        var version: UInt32 = 0x0488ade4, depth: UInt8 = 0, child: UInt32 = 0, parent: UInt32 = 0
        if let coinNode = map[5] {
            guard let coin = try coinNode.untagged([305,40305]).map, (coin[1]?.uint ?? 0) == 0 else { throw ScanDecodeError.unsupported }
            if (coin[2]?.uint ?? 0) != 0 { throw ScanDecodeError.testnet }
        }
        if master {
            guard map[6] == nil, map[8] == nil else { throw ScanDecodeError.invalid }
        } else {
            guard let originNode = map[6], let origin = try originNode.untagged([304,40304]).map,
                  let path = origin[1]?.array, path.count > 0, path.count % 2 == 0,
                  (origin[3]?.uint ?? UInt64(path.count/2)) == 3,
                  path.count/2 <= 3 else { throw ScanDecodeError.unsupported }
            var children: [UInt32] = [] // Public derivation indexes only.
            for i in stride(from: 0, to: path.count, by: 2) {
                guard let index = path[i].uint, index < 0x80000000, let hardened = path[i+1].boolean else { throw ScanDecodeError.invalid }
                children.append(UInt32(index) | (hardened ? 0x80000000 : 0))
            }
            guard let parentValue = map[8]?.uint ?? (path.count == 2 ? origin[2]?.uint : nil), parentValue <= UInt32.max else { throw ScanDecodeError.invalid }
            parent = UInt32(parentValue); depth = 3; child = children.last!
            if children.count == 3 {
                guard children[1] == 0x80000000 else { throw ScanDecodeError.unsupported }
                if children[0] == 0x80000031 { version = 0x049d7878 }
                if children[0] == 0x80000054 { version = 0x04b2430c }
            }
        }
        let binary = SecureBytes(capacity: 82); defer { binary.wipe() }
        func append32(_ value: UInt32) throws {
            for shift in [24,16,8,0] { try binary.append(UInt8(truncatingIfNeeded: value >> shift)) }
        }
        try append32(version); try binary.append(depth); try append32(parent); try append32(child)
        try source.withUnsafeBytes { raw in
            for byte in raw[chain] { try binary.append(byte) }
            for byte in raw[key] { try binary.append(byte) }
        }
        let one = KeyValidation.sha256(binary), two = KeyValidation.sha256(one)
        defer { one.wipe(); two.wipe() }
        try two.withUnsafeBytes { for byte in $0.prefix(4) { try binary.append(byte) } }
        return try base58(binary)
    }
    private static func base58(_ source: SecureBytes) throws -> SecureBytes {
        let digits = SecureBytes(capacity: 128); defer { digits.wipe() }
        try digits.replace(with: repeatElement(UInt8(0), count: 128))
        var length = 0
        source.withUnsafeBytes { bytes in
            for byte in bytes {
                var carry = Int(byte)
                digits.withUnsafeMutableBytes { target in
                    for i in 0..<length { carry += Int(target[i])*256; target[i] = UInt8(carry%58); carry /= 58 }
                    while carry > 0 { target[length] = UInt8(carry%58); length += 1; carry /= 58 }
                }
            }
        }
        let output = SecureBytes(capacity: 128)
        try source.withUnsafeBytes { for _ in $0.prefix(while: { $0 == 0 }) { try output.append(49) } }
        try digits.withUnsafeBytes { for i in (0..<length).reversed() { try output.append(KeyValidation.base58Alphabet[Int($0[i])]) } }
        return output
    }
}
