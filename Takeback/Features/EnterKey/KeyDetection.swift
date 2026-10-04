import Foundation

/// Only public classification metadata leaves the detector. No secret strings, hashes or payloads.
enum ExtendedPrivatePrefix: String, Hashable { case xprv, yprv, zprv }
enum AddressStandard: Int, CaseIterable, Hashable { case bip86 = 86, bip84 = 84, bip49 = 49, bip44 = 44 }
enum SingleAddressKind: String, Hashable { case p2tr, p2wpkh, p2shP2wpkh, p2pkh }

struct KeySearchPlan: Hashable {
    enum Origin: Hashable { case mnemonic, master, account(childNumber: UInt32), single }
    let origin: Origin
    let standards: [AddressStandard]
    let singleAddresses: [SingleAddressKind]
    /// HD plans search both branches. Account keys start directly at /0 and /1.
    var branches: [UInt32] { origin == .single ? [] : [0, 1] }
}

enum KeyDetection: Equatable {
    case empty
    case phrase(words: Int, checksumValid: Bool)
    case wif(compressed: Bool)
    case mini(length: Int)
    case hex
    case extended(prefix: ExtendedPrivatePrefix, depth: UInt8, childNumber: UInt32)
    case publicOnly, testnet, unrecognized

    static let phraseCounts = [12, 15, 18, 21, 24]
    var compressed: Bool { switch self { case .wif(false), .mini: false; default: true } }
    var isPhrase: Bool { if case .phrase = self { true } else { false } }
    var isValid: Bool { searchPlan != nil }
    var searchPlan: KeySearchPlan? {
        switch self {
        case .phrase(_, true):
            return .init(origin: .mnemonic, standards: AddressStandard.allCases, singleAddresses: [])
        case .extended(let prefix, let depth, let child):
            let standards: [AddressStandard] = depth == 0 ? AddressStandard.allCases : prefix == .yprv ? [.bip49] : prefix == .zprv ? [.bip84] : [.bip44]
            return .init(origin: depth == 0 ? .master : .account(childNumber: child), standards: standards, singleAddresses: [])
        case .wif(false), .mini: return .init(origin: .single, standards: [], singleAddresses: [.p2pkh])
        case .wif(true), .hex:
            return .init(origin: .single, standards: [], singleAddresses: [.p2tr, .p2wpkh, .p2shP2wpkh, .p2pkh])
        default: return nil
        }
    }
    func isError(settled: Bool) -> Bool {
        switch self {
        case .publicOnly, .testnet: true
        case .phrase(_, false), .unrecognized: settled
        default: false
        }
    }
    func label(settled: Bool) -> String {
        switch self {
        case .empty: "Paste, scan or type to begin"
        case .phrase(let count, true): "Recovery phrase · \(count) words"
        case .phrase(let count, false):
            if !Self.phraseCounts.contains(count) {
                settled ? "Recovery phrases have 12, 15, 18, 21 or 24 words" : "Recovery phrase · \(count) words so far"
            } else { settled ? "Not a recovery phrase or private key" : "" }
        case .wif(let compressed): "Private key · WIF · \(compressed ? "compressed" : "uncompressed")"
        case .mini(let length): "Mini private key · \(length) characters"
        case .hex: "Private key · hex · 64 characters"
        case .extended(let prefix, _, _): "Extended private key · \(prefix.rawValue)"
        case .publicOnly: "That’s public. Canceling needs the private key or recovery phrase."
        case .testnet: "This is a testnet key"
        case .unrecognized: settled ? "Not a recovery phrase or private key" : ""
        }
    }
}

/// Pure, synchronous classification. Normalization and decoding use zeroed scratch allocations.
func detectKey(_ input: SecureBytes) -> KeyDetection {
    guard let normalized = try? KeyValidation.normalized(input) else { return .unrecognized }
    defer { normalized.wipe() }
    guard normalized.count > 0 else { return .empty }
    return normalized.withUnsafeBytes { bytes in
        if let phrase = KeyValidation.phrase(bytes) { return phrase }
        if KeyValidation.publicDescriptor(bytes) { return .publicOnly }
        if let hex = KeyValidation.hex(bytes) {
            defer { hex.wipe() }
            return hex.withUnsafeBytes { KeyValidation.validScalar($0) } ? .hex : .unrecognized
        }
        if (bytes.count == 66 && (bytes[0] == 48 && [50,51].contains(bytes[1]))) ||
            (bytes.count == 130 && bytes[0] == 48 && bytes[1] == 52) {
            if bytes.allSatisfy({ KeyValidation.hexNibble($0) != nil }) { return .publicOnly }
        }
        if KeyValidation.isWitnessAddress(bytes) { return .publicOnly }
        if bytes[0] == 83, [22,26,30].contains(bytes.count), bytes.allSatisfy({ KeyValidation.base58Alphabet.contains($0) }) {
            let checked = SecureBytes(capacity: bytes.count + 1)
            defer { checked.wipe() }
            try? checked.replace(with: bytes)
            try? checked.append(63)
            let digest = KeyValidation.sha256(checked)
            defer { digest.wipe() }
            if digest.withUnsafeBytes({ $0[0] == 0 }) { return .mini(length: bytes.count) }
            return .unrecognized
        }
        guard let decoded = KeyValidation.base58Check(bytes) else { return .unrecognized }
        defer { decoded.wipe() }
        return decoded.withUnsafeBytes { payload in
            if payload.count == 21, [0,5,111,196].contains(payload[0]) { return .publicOnly }
            if [33,34].contains(payload.count), [0x80,0xef].contains(payload[0]) {
                let compressed = payload.count == 34
                guard (!compressed || payload[33] == 1),
                      KeyValidation.validScalar(UnsafeRawBufferPointer(rebasing: payload[1..<33])) else { return .unrecognized }
                return payload[0] == 0xef ? .testnet : .wif(compressed: compressed)
            }
            guard payload.count == 78 else { return .unrecognized }
            let version = KeyValidation.uint32(payload, at: 0)
            let publicVersions: Set<UInt32> = [0x0488b21e,0x049d7cb2,0x04b24746,0x043587cf,0x044a5262,0x045f1cf6]
            if publicVersions.contains(version), [2,3].contains(payload[45]) { return .publicOnly }
            let prefixes: [UInt32: ExtendedPrivatePrefix] = [0x0488ade4:.xprv,0x049d7878:.yprv,0x04b2430c:.zprv]
            let testnetVersions: Set<UInt32> = [0x04358394,0x044a4e28,0x045f18bc]
            guard prefixes[version] != nil || testnetVersions.contains(version), payload[45] == 0,
                  KeyValidation.validScalar(UnsafeRawBufferPointer(rebasing: payload[46..<78])) else { return .unrecognized }
            let depth = payload[4]
            let child = KeyValidation.uint32(payload, at: 9)
            guard depth != 0 || (child == 0 && payload[5..<9].allSatisfy { $0 == 0 }) else { return .unrecognized }
            if testnetVersions.contains(version) { return .testnet }
            guard depth == 0 || depth == 3, let prefix = prefixes[version] else { return .unrecognized }
            return .extended(prefix: prefix, depth: depth, childNumber: child)
        }
    }
}
