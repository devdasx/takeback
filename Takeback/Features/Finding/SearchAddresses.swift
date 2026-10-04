import Foundation
import CryptoKit

extension AddressStandard {
    var title: String { switch self { case .bip86: "Taproot"; case .bip84: "Native SegWit"; case .bip49: "Nested SegWit"; case .bip44: "Legacy" } }
    var subtitle: String { switch self { case .bip86: "P2TR · bc1p…"; case .bip84: "P2WPKH · bc1q…"; case .bip49: "P2SH · 3…"; case .bip44: "P2PKH · 1…" } }
}
extension KeySearchPlan {
    var types: [AddressStandard] {
        origin == .single ? singleAddresses.map { switch $0 { case .p2tr: .bip86; case .p2wpkh: .bip84; case .p2shP2wpkh: .bip49; case .p2pkh: .bip44 } } : standards
    }
}
struct SearchAddress: Sendable {
    let type: AddressStandard
    let branch: UInt32
    let index: UInt32
    let chain: ChainAddress
    var searchPath: SearchPath? = nil
    var derivation: [UInt32]? = nil
    var compressed = true
    var rowID: String { searchPath?.id ?? "type-\(type.rawValue)" }
    var signing: SigningAddress {
        .init(type: type, path: derivation ?? [], script: chain.scriptPubKey, compressed: compressed, searchPath: searchPath)
    }
}

/// Worker-owned secret copies are zeroed after public-node preparation, including failures.
final class SearchDerivationWork: @unchecked Sendable {
    private let lock = NSLock()
    private let key = SecureBytes(), phrase = SecureBytes()
    private var cancelled = false
    init(key: SecureBytes, passphrase: SecureBytes) throws {
        try key.withUnsafeBytes { try self.key.replace(with: $0) }
        try passphrase.withUnsafeBytes { try phrase.replace(with: $0) }
    }
    func cancel() { lock.withLock { cancelled = true; key.wipe(); phrase.wipe() } }
    var isCleared: Bool { lock.withLock { key.count == 0 && phrase.count == 0 } }
    func prepare(plan: KeySearchPlan, selection: SearchSelection = .init()) throws -> PublicScanPlan {
        try lock.withLock {
            defer { key.wipe(); phrase.wipe() }
            guard !cancelled else { throw CancellationError() }
            let detection = detectKey(key)
            guard detection.searchPlan == plan, (1...10).contains(selection.accounts),
                  [20,50,100,200].contains(selection.addressesPerPath), selection.isValid(for: plan) else { throw ChainError.invalidConfiguration }
            let root = try KeyMaterial.root(key: key, passphrase: phrase)
            defer { root.wipe() }
            if plan.origin == .single {
                let single = try selection.enabledTypes(for: plan).map { type -> SearchAddress in
                    let address = try CancellationKeyWork.address(root: root, plan: plan, type: type, branch: 0, index: 0, compressed: detection.compressed)
                    return .init(type: type, branch: 0, index: 0, chain: .init(address: address.address, scriptPubKey: address.script), derivation: [], compressed: detection.compressed)
                }
                return .init(keyPlan: plan, accounts: [:], single: single)
            }
            let paths = selection.paths(for: plan)
            var accounts: [AddressStandard: Data] = [:], nodes: [String: Data] = [:]
            for item in paths {
                try Task.checkCancellation()
                guard (1...6).contains(item.components.count) else { throw ChainError.invalidConfiguration }
                let path = plan.isAccount ? [] : item.components
                var pub = [UInt8](repeating: 0, count: 65)
                let ok = root.withUnsafeBytes { takeback_account_public($0.bindMemory(to: UInt8.self).baseAddress, path, path.count, &pub) }
                guard ok == 1 else { throw ChainError.invalidConfiguration }
                nodes[item.id] = Data(pub)
                if accounts[item.scriptType] == nil { accounts[item.scriptType] = Data(pub) }
            }
            return .init(keyPlan: plan, accounts: accounts, single: [], paths: paths, nodes: nodes)
        }
    }
    func derive(plan: KeySearchPlan, gap: Int) throws -> [SearchAddress] { try prepare(plan: plan).initial(gap: gap) }
    static func compute(_ work: SearchDerivationWork, plan: KeySearchPlan, gap: Int) async throws -> [SearchAddress] {
        let task = Task.detached(priority: .userInitiated) { try work.derive(plan: plan, gap: gap) }
        return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel(); work.cancel() }
    }
}

extension KeySearchPlan {
    var isAccount: Bool { if case .account = origin { true } else { false } }
}

/// Extended public nodes and scripts only; never private scalars.
struct PublicScanPlan: Sendable {
    let keyPlan: KeySearchPlan
    let accounts: [AddressStandard: Data]
    let single: [SearchAddress]
    var paths: [SearchPath] = []
    var nodes: [String: Data] = [:]
    var effectivePaths: [SearchPath] { paths.isEmpty ? SearchSelection().paths(for: keyPlan) : paths }
    func address(type: AddressStandard, branch: UInt32, index: UInt32) throws -> SearchAddress {
        guard let path = effectivePaths.first(where: { $0.scriptType == type }) else { throw ChainError.invalidConfiguration }
        return try address(path: path, branch: branch, index: index)
    }
    func address(path: SearchPath, branch: UInt32, index: UInt32) throws -> SearchAddress {
        guard let account = nodes[path.id] ?? (nodes.isEmpty ? accounts[path.scriptType] : nil),
              path.branches.contains(branch) else { throw ChainError.invalidConfiguration }
        var script = [UInt8](repeating: 0, count: 34), count = 0
        guard takeback_public_script([UInt8](account), path.fixedChain ? UInt32.max : branch, index, Int32(path.scriptType.rawValue), &script, &count) == 1 else { throw ChainError.invalidConfiguration }
        let data = Data(script.prefix(count))
        guard let address = BitcoinAddress.encode(script: data) else { throw ChainError.invalidConfiguration }
        return .init(type: path.scriptType, branch: branch, index: index, chain: .init(address: address, scriptPubKey: data),
                     searchPath: path, derivation: path.childPath(branch: branch, index: index, accountRoot: keyPlan.isAccount))
    }
    func initial(gap: Int) throws -> [SearchAddress] {
        guard (1...1000).contains(gap) else { throw ChainError.invalidConfiguration }
        if !single.isEmpty { return single }
        return try effectivePaths.flatMap { path in try path.branches.flatMap { branch in
            try (0..<gap).map { try address(path: path, branch: branch, index: UInt32($0)) }
        } }
    }
    func rows(gap: Int) -> [SearchRow] {
        if !single.isEmpty { return single.map { .init(type: $0.type, total: 1) } }
        return effectivePaths.map { .init(type: $0.scriptType, total: gap * $0.branches.count, searchPath: $0) }
    }
}

enum BitcoinAddress {
    static func encode(script: Data) -> String? {
        let b = [UInt8](script)
        if b.count == 25, b.prefix(3) == [0x76,0xa9,20], b.suffix(2) == [0x88,0xac] { return base58([0] + b[3..<23]) }
        if b.count == 23, b.prefix(2) == [0xa9,20], b.last == 0x87 { return base58([5] + b[2..<22]) }
        if b.count == 22, b.prefix(2) == [0,20] { return witness(version: 0, program: Array(b.dropFirst(2))) }
        if b.count == 34, b.prefix(2) == [0x51,32] { return witness(version: 1, program: Array(b.dropFirst(2))) }
        return nil
    }
    private static func base58(_ payload: [UInt8]) -> String {
        let checksum = Array(SHA256.hash(data: Data(SHA256.hash(data: Data(payload)))).prefix(4))
        let bytes = payload + checksum
        var digits = [Int](repeating: 0, count: 1)
        for byte in bytes {
            var carry = Int(byte)
            for i in digits.indices { carry += digits[i] << 8; digits[i] = carry % 58; carry /= 58 }
            while carry > 0 { digits.append(carry % 58); carry /= 58 }
        }
        let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        return String(repeating: "1", count: bytes.prefix(while: { $0 == 0 }).count) + String(digits.reversed().map { alphabet[$0] })
    }
    private static func witness(version: UInt8, program: [UInt8]) -> String {
        var values = [version], accumulator = 0, bits = 0
        for byte in program {
            accumulator = ((accumulator << 8) | Int(byte)) & 0xffff
            bits += 8
            while bits >= 5 { bits -= 5; values.append(UInt8((accumulator >> bits) & 31)) }
        }
        if bits > 0 { values.append(UInt8((accumulator << (5-bits)) & 31)) }
        var checksum: UInt32 = 1
        for value in [UInt8(3),3,0,2,3] + values + [UInt8](repeating: 0, count: 6) {
            let top = checksum >> 25; checksum = ((checksum & 0x1ffffff) << 5) ^ UInt32(value)
            for (i, generator) in [UInt32(0x3b6a57b2),0x26508e6d,0x1ea119fa,0x3d4233dd,0x2a1462b3].enumerated() where (top >> i) & 1 != 0 { checksum ^= generator }
        }
        checksum ^= version == 0 ? 1 : 0x2bc830a3
        values += (0..<6).map { UInt8((checksum >> (5 * (5-$0))) & 31) }
        let alphabet = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")
        return "bc1" + String(values.map { alphabet[Int($0)] })
    }
}
