import Foundation
import CryptoKit

struct FeeRecommendations: Equatable, Sendable {
    let nextBlock: Decimal
    let fast: Decimal
    let medium: Decimal
    let minimum: Decimal

    init(nextBlock: Decimal, fast: Decimal, medium: Decimal, minimum: Decimal) throws {
        guard [nextBlock, fast, medium, minimum].allSatisfy({ !$0.isNaN && $0 >= 0 }),
              nextBlock > 0, fast > 0, medium > 0 else { throw ChainError.invalidResponse }
        self.minimum = minimum
        self.nextBlock = max(nextBlock, minimum)
        self.fast = max(fast, minimum)
        self.medium = max(medium, minimum)
    }

    static func satsPerVByte(btcPerKB: Decimal) throws -> Decimal {
        guard !btcPerKB.isNaN, btcPerKB >= 0 else { throw ChainError.unavailable }
        return btcPerKB * 100_000
    }
}

struct TransactionSummary: Equatable, Sendable {
    let txid: String
    /// Electrum's -1 / 0 are both unconfirmed; REST uses 0 for unconfirmed.
    let height: Int
    var isConfirmed: Bool { height > 0 }
}

struct ChainAddress: Sendable {
    let address: String
    let scriptPubKey: Data
    var electrumScriptHash: String { SHA256.hash(data: scriptPubKey).reversed().hex }
}

struct ElectrumServer: Hashable, Codable, Sendable {
    let host: String
    let port: UInt16
    var endpoint: String { host.contains(":") ? "[\(host)]:\(port)" : "\(host):\(port)" }
    var useTCP = false
    var id: String { "\(endpoint):\(useTCP ? "tcp" : "tls")" }
    static var defaults: [ElectrumServer] { ElectrumSeed.bundled.servers }
    enum CodingKeys: String, CodingKey { case host, port, useTCP }
    init(host: String, port: UInt16, useTCP: Bool = false) { self.host = host; self.port = port; self.useTCP = useTCP }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        host = try c.decode(String.self, forKey: .host); port = try c.decode(UInt16.self, forKey: .port)
        useTCP = try c.decodeIfPresent(Bool.self, forKey: .useTCP) ?? false
    }
}

struct ChainConfiguration: Sendable {
    let mempoolURL: URL
    let electrumServers: [ElectrumServer]
    let fullRBFPolicy: Bool?
    var pinnedServers: Bool = false
    init(mempoolURL: URL = URL(string: "https://mempool.space/api")!,
         electrumServers: [ElectrumServer] = ElectrumServer.defaults, fullRBFPolicy: Bool? = nil) throws {
        guard ServerAddress.allowedTransport(mempoolURL),
              mempoolURL.user == nil, mempoolURL.password == nil,
              mempoolURL.query == nil, mempoolURL.fragment == nil else { throw ChainError.invalidConfiguration }
        guard electrumServers.allSatisfy({ !$0.host.isEmpty && $0.port > 0 }) else { throw ChainError.invalidConfiguration }
        self.mempoolURL = mempoolURL
        self.electrumServers = electrumServers
        self.fullRBFPolicy = fullRBFPolicy
    }
}

enum ChainError: Error, Equatable {
    case invalidConfiguration, invalidResponse, invalidTransaction, txidMismatch
    case network, timeout, unavailable, connectionRefused
    case noBatch, certificateChanged, untrusted, batchLimit
    case http(Int)
    case rejected
    case rpc(Int, String)

    var allowsFallback: Bool {
        switch self {
        case .network, .timeout, .unavailable, .connectionRefused, .certificateChanged, .untrusted: true
        case .http(let status): (500...599).contains(status)
        default: false
        }
    }
}

enum Money {
    static func bitcoin(sats: Int64) -> Decimal { Decimal(sats) / 100_000_000 }
    static func usd(sats: Int64, rate: Decimal) -> Decimal { bitcoin(sats: sats) * rate }
}

extension Sequence where Element == UInt8 {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}

extension Data {
    init?(hex: String) {
        let bytes = Array(hex.utf8)
        guard bytes.count.isMultiple(of: 2) else { return nil }
        self.init()
        reserveCapacity(bytes.count / 2)
        func nibble(_ byte: UInt8) -> UInt8? {
            switch byte { case 48...57: byte - 48; case 65...70: byte - 55; case 97...102: byte - 87; default: nil }
        }
        for index in stride(from: 0, to: bytes.count, by: 2) {
            guard let high = nibble(bytes[index]), let low = nibble(bytes[index + 1]) else { return nil }
            append(high << 4 | low)
        }
    }
}

struct ElectrumSeed: Decodable {
    let source: String, path: String, commit: String, license: String
    let servers: [ElectrumServer]
    static let bundled: Self = {
        guard let url = Bundle.main.url(forResource: "ElectrumServers", withExtension: "json"),
              let data = try? Data(contentsOf: url), let seed = try? JSONDecoder().decode(Self.self, from: data) else {
            preconditionFailure("Missing bundled Electrum server list")
        }
        return seed
    }()
}
