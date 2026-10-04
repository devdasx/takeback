import Foundation
import Network

protocol SearchConnectivity: Sendable { func isOnline() async throws -> Bool }
struct PathConnectivity: SearchConnectivity {
    func isOnline() async throws -> Bool {
        let probe = PathProbe()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { probe.start($0) }
        } onCancel: { probe.cancel() }
    }
}
private final class PathProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let monitor = NWPathMonitor()
    private var continuation: CheckedContinuation<Bool, Error>?
    private var finished = false
    func start(_ continuation: CheckedContinuation<Bool, Error>) {
        lock.withLock {
            guard !finished else { continuation.resume(throwing: CancellationError()); return }
            self.continuation = continuation
            monitor.pathUpdateHandler = { [weak self] path in self?.finish(.success(path.status == .satisfied)) }
            monitor.start(queue: DispatchQueue(label: "app.takeback.path"))
        }
    }
    func cancel() { finish(.failure(CancellationError())) }
    private func finish(_ result: Result<Bool, Error>) {
        lock.withLock {
            guard !finished else { return }; finished = true
            monitor.cancel(); monitor.pathUpdateHandler = nil
            continuation?.resume(with: result); continuation = nil
        }
    }
}

struct SearchAttempt: Equatable, Sendable {
    let server: String
    let detail: String
    init(server: String, error: Error, timeout: Int) {
        self.server = server
        switch error as? ChainError {
        case .certificateChanged: detail = "Certificate changed"
        case .noBatch: detail = "Doesn’t support batching"
        case .connectionRefused: detail = "Connection refused"
        case .timeout: detail = "No response after \(timeout) seconds"
        case .http(let status): detail = "Server returned \(status)"
        case .invalidResponse, .invalidTransaction, .txidMismatch: detail = "Invalid response"
        default: detail = "Connection failed"
        }
    }
    init(server: String, detail: String) { self.server = server; self.detail = detail }
}

/// Raw transactions and their parents are fetched in deduplicated batches and parsed locally.
actor SearchNetwork {
    enum Backend: Sendable { case rest, electrum(ElectrumServer) } // legacy fixture API; neither case performs REST.
    let configuration: ChainConfiguration
    let client: ElectrumClient
    let http: any HTTPTransport
    private var wireCache: [String: WireTransaction] = [:]
    private var headerCache: [Int: Int] = [:]
    init(configuration: ChainConfiguration, backend: Backend = .rest, http: any HTTPTransport = URLSessionTransport(), electrum: any ElectrumTransport = TLSElectrumTransport(), client: ElectrumClient? = nil) {
        self.configuration = configuration; self.http = http
        self.client = client ?? ElectrumClient(configuration: configuration, transport: electrum)
    }
    func histories(_ addresses: [SearchAddress]) async throws -> [[TransactionSummary]] {
        try await client.histories(addresses.map { $0.chain.electrumScriptHash })
    }
    func collected(_ addresses: [SearchAddress], histories: [[TransactionSummary]], since: Date) async throws -> [SearchTransaction] {
        let used = zip(addresses, histories).filter { !$0.1.isEmpty }.map { $0.0.chain.electrumScriptHash }
        _ = try await client.unspent(used)
        var selected: [String: Int?] = [:]
        for entry in histories.flatMap({ $0 }) {
            if entry.height <= 0 { selected[entry.txid] = .some(nil) }
            else {
                let time = try await blockTime(entry.height)
                if Double(time) >= since.timeIntervalSince1970 { selected[entry.txid] = time }
            }
        }
        try await hydrate(Array(selected.keys))
        var result: [SearchTransaction] = []
        for id in selected.keys.sorted() { result.append(try await transaction(id, timestamp: selected[id]!)) }; return result
    }
    func lookup(_ address: ChainAddress, since: Date) async throws -> [SearchTransaction] {
        let list = [SearchAddress(type: .bip44, branch: 0, index: 0, chain: address)]
        let history = try await client.histories([address.electrumScriptHash])
        return try await collected(list, histories: history, since: since)
    }
    func paymentMetadata() async -> (usdRate: Decimal?, fullRBF: Bool) {
        (try? await FiatPrice.shared.value(http: http), true)
    }
    func ownCancellation(_ replacement: SearchTransaction, owned: Set<String>, firstSeen: Date?) async throws -> PaymentCancellation? { nil }
    func firstSeen(_ txid: String) async throws -> Date? { nil }
    func descendants(of original: SearchTransaction) async throws -> [String] {
        var queue = [original], seen = Set([original.txid]), result: [String] = []
        while !queue.isEmpty {
            try Task.checkCancellation()
            let parents = queue; queue = []
            let calls = try parents.flatMap { parent in try parent.vout.map { output -> RPCCall in
                guard let script = Data(hex: output.scriptpubkey) else { throw ChainError.invalidResponse }
                return RPCCall(method: "blockchain.scripthash.get_mempool", params: [.string(ChainAddress(address: "", scriptPubKey: script).electrumScriptHash)])
            } }
            let ids = Set(try await client.batch(calls).flatMap(ElectrumClient.history).filter { $0.height <= 0 }.map(\.txid)).subtracting(seen)
            try await hydrate(Array(ids))
            let parentIDs = Set(parents.map(\.txid))
            for id in ids {
                let tx = try await transaction(id, timestamp: nil)
                if tx.vin.contains(where: { parentIDs.contains($0.txid) }) { seen.insert(id); result.append(id); queue.append(tx) }
            }
            guard seen.count <= 10_000 else { throw ChainError.invalidResponse }
        }
        return result.sorted()
    }
    func verifiedPending(_ id: String) async throws -> SearchTransaction {
        let tx = try await transaction(id, timestamp: nil)
        guard let script = tx.vin.first?.prevout?.scriptpubkey, let data = Data(hex: script) else { throw ChainError.invalidResponse }
        let history = try await client.histories([ChainAddress(address: "", scriptPubKey: data).electrumScriptHash])[0]
        if history.contains(where: { $0.txid == id && $0.height > 0 }) { throw CancelFailure.alreadyConfirmed }
        guard history.contains(where: { $0.txid == id && $0.height <= 0 }) else { throw ChainError.unavailable }
        try tx.validate()
        return tx
    }
    func currentHeight() async throws -> UInt32 { UInt32(try await client.tip()) }
    func used(_ address: SigningAddress) async throws -> Bool {
        try await !client.histories([ChainAddress(address: address.address, scriptPubKey: address.script).electrumScriptHash])[0].isEmpty
    }
    private func hydrate(_ ids: [String]) async throws {
        let missing = Array(Set(ids).subtracting(wireCache.keys)).sorted()
        for tx in try await client.transactions(missing) { wireCache[tx.txid] = tx }
        let parents = Set(ids.flatMap { wireCache[$0]?.inputs.map(\.txid) ?? [] }).subtracting(wireCache.keys).filter { $0 != String(repeating: "0", count: 64) }.sorted()
        for tx in try await client.transactions(parents) { wireCache[tx.txid] = tx }
    }
    private func transaction(_ id: String, timestamp: Int?) async throws -> SearchTransaction {
        let raw = try await wire(id)
        var inputs: [SearchTransaction.Input] = []
        var total: Int64 = 0
        for input in raw.inputs {
            if input.txid == String(repeating: "0", count: 64) {
                inputs.append(.init(txid: input.txid, vout: input.index, sequence: input.sequence, prevout: nil)); continue
            }
            let parent = try await wire(input.txid)
            guard parent.outputs.indices.contains(input.index) else { throw ChainError.invalidResponse }
            let output = parent.outputs[input.index]
            let (next, overflow) = total.addingReportingOverflow(output.value)
            guard !overflow else { throw ChainError.invalidResponse }; total = next
            inputs.append(.init(txid: input.txid, vout: input.index, sequence: input.sequence, prevout: output))
        }
        var spent: Int64 = 0
        for output in raw.outputs {
            let (next, overflow) = spent.addingReportingOverflow(output.value)
            guard !overflow else { throw ChainError.invalidResponse }; spent = next
        }
        let coinbase = inputs.contains { $0.prevout == nil }
        guard coinbase || total >= spent else { throw ChainError.invalidResponse }
        return .init(txid: id, vin: inputs, vout: raw.outputs, fee: coinbase ? 0 : total-spent,
                     weight: raw.weight, status: .init(confirmed: timestamp != nil, block_time: timestamp))
    }
    private func wire(_ id: String) async throws -> WireTransaction {
        if let cached = wireCache[id] { return cached }
        try await hydrate([id])
        guard let value = wireCache[id] else { throw ChainError.invalidResponse }; return value
    }
    private func blockTime(_ height: Int) async throws -> Int {
        if let cached = headerCache[height] { return cached }
        guard let hex = try await client.call("blockchain.block.header", [.number(Decimal(height))]).string,
              let header = Data(hex: hex), header.count == 80 else { throw ChainError.invalidResponse }
        let time = header[68..<72].enumerated().reduce(0) { $0 | Int($1.element) << (8*$1.offset) }
        headerCache[height] = time; return time
    }
}
extension Array where Element: Sendable {
    func asyncMap<T: Sendable>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var result: [T] = []; for item in self { result.append(try await transform(item)) }; return result
    }
}
