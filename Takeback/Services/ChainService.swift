import Foundation

/// Batched Electrum discovery, with configured mempool-first action fees, sending and status.
struct ChainService: Sendable {
    let configuration: ChainConfiguration
    let http: any HTTPTransport
    let electrum: any ElectrumTransport
    let client: ElectrumClient
    init(configuration: ChainConfiguration, http: any HTTPTransport = URLSessionTransport(),
         electrum: any ElectrumTransport = TLSElectrumTransport(), client: ElectrumClient? = nil) {
        self.configuration = configuration; self.http = http; self.electrum = electrum
        self.client = client ?? ElectrumClient(configuration: configuration, transport: electrum)
    }
    func fees() async throws -> FeeRecommendations {
        do {
            let response = try await http.send(URLRequest(url: configuration.mempoolURL.appendingPathComponent("v1/fees/recommended"), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10))
            struct Quote: Decodable { let fastestFee, halfHourFee, hourFee, minimumFee: Decimal }
            guard response.status == 200 else { throw ChainError.http(response.status) }
            let q = try JSONDecoder().decode(Quote.self, from: response.data)
            return try .init(nextBlock: q.fastestFee, fast: q.halfHourFee, medium: q.hourFee, minimum: q.minimumFee)
        } catch { try Task.checkCancellation(); return try await electrumFees() }
    }
    func electrumFees() async throws -> FeeRecommendations {
        let values = try await client.batch([1,3,6].map { RPCCall(method: "blockchain.estimatefee", params: [.number(Decimal($0))]) } + [RPCCall(method: "blockchain.relayfee")])
        guard let relay = values[3].decimal, relay >= 0 else { throw ChainError.invalidResponse }
        let floor = max(1, try FeeMath.ceil(relay * 100_000))
        var histogram: [(Decimal, Int)] = []
        if values.prefix(3).contains(where: { ($0.decimal ?? -1) < 0 }) {
            guard case .array(let rows) = try await client.call("mempool.get_fee_histogram") else { throw ChainError.invalidResponse }
            histogram = try rows.map {
                guard case .array(let pair) = $0, pair.count == 2, let rate = pair[0].decimal, rate >= 0,
                      let size = pair[1].integer, size >= 0 else { throw ChainError.invalidResponse }
                return (rate, size)
            }.sorted { $0.0 > $1.0 }
        }
        let rates = try [1,3,6].enumerated().map { index, blocks -> Decimal in
            guard let estimate = values[index].decimal else { throw ChainError.invalidResponse }
            if estimate >= 0 { return Decimal(max(floor, try FeeMath.ceil(estimate * 100_000))) }
            var size = 0, rate = Decimal(floor)
            for row in histogram { size += row.1; rate = row.0; if size >= blocks * 1_000_000 { break } }
            return Decimal(max(floor, try FeeMath.ceil(rate)))
        }
        return try .init(nextBlock: rates[0], fast: rates[1], medium: rates[2], minimum: Decimal(floor))
    }
    func usdPrice() async throws -> Decimal { try await FiatPrice.shared.value(http: http) }
    func history(for address: ChainAddress) async throws -> [TransactionSummary] {
        try await client.histories([address.electrumScriptHash])[0]
    }
    func broadcast(rawTransaction: Data) async throws -> String {
        do { return try await broadcastDetailed(rawTransaction: rawTransaction) }
        catch let failure as BroadcastFailure { throw failure.cause }
    }
    func broadcastDetailed(rawTransaction: Data) async throws -> String {
        let expected = try TransactionID.compute(raw: rawTransaction)
        let host = configuration.mempoolURL.host ?? "mempool.space"
        var attempts: [BroadcastFailure.Attempt] = []
        do {
            var request = URLRequest(url: configuration.mempoolURL.appendingPathComponent("tx"), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
            request.httpMethod = "POST"; request.httpBody = Data(rawTransaction.hex.utf8)
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            let response = try await http.send(request)
            let message = String(data: response.data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Invalid response"
            if ElectrumClient.alreadyKnown(message) { return expected }
            guard (200...299).contains(response.status) else {
                throw BroadcastFailure(cause: .http(response.status), message: message, source: host, attempts: [], definitive: (400...499).contains(response.status))
            }
            guard message.lowercased() == expected else { throw ChainError.txidMismatch }
            return expected
        } catch {
            try Task.checkCancellation()
            let cause = (error as? BroadcastFailure)?.cause ?? (error as? ChainError ?? .network)
            let failure = error as? BroadcastFailure ?? BroadcastFailure(cause: cause, message: BroadcastFailure.describe(cause), source: host, attempts: [], definitive: false)
            guard cause.allowsFallback else { throw failure }
            attempts.append(.init(host: host, message: failure.message))
        }
        let pool = client.pool
        var tried = Set<ElectrumServer>()
        while tried.count < configuration.electrumServers.count {
            try Task.checkCancellation()
            let available = configuration.electrumServers.filter { !tried.contains($0) }
            guard !available.isEmpty else { break }
            guard let server = available.first else { break }
            tried.insert(server)
            do {
                let reply = try await electrum.call(server: server, method: "blockchain.transaction.broadcast", params: [.string(rawTransaction.hex)], timeout: 8)
                guard reply.string?.lowercased() == expected else { throw ChainError.txidMismatch }
                await pool.record(server, success: true)
                return expected
            } catch {
                try Task.checkCancellation()
                let rpc = error as? RPCFailure
                let cause = rpc.map { ChainError.rpc($0.code, $0.message) } ?? (error as? ChainError ?? .network)
                if case .rpc(_, let message) = cause, ElectrumClient.alreadyKnown(message) { return expected }
                let message = BroadcastFailure.describe(cause)
                attempts.append(.init(host: server.host, message: message))
                await pool.record(server, success: false)
                guard cause.allowsFallback else {
                    throw BroadcastFailure(cause: cause, message: message, source: server.host, attempts: Array(attempts.dropLast()), definitive: rpc != nil)
                }
            }
        }
        throw BroadcastFailure(cause: .unavailable, message: attempts.last?.message ?? "No working batch server", source: attempts.last?.host ?? "Electrum", attempts: attempts, definitive: false)
    }
    func confirmationHeight(txid: String) async throws -> Int? {
        guard TransactionID.isValid(txid) else { throw ChainError.invalidTransaction }
        do {
            let response = try await http.send(URLRequest(url: configuration.mempoolURL.appendingPathComponent("tx/\(txid)/status"), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10))
            struct Status: Decodable { let confirmed: Bool; let block_height: Int? }
            guard response.status == 200 else { throw ChainError.http(response.status) }
            let status = try JSONDecoder().decode(Status.self, from: response.data)
            if status.confirmed, let height = status.block_height, height > 0 { return height }
            return nil
        } catch { try Task.checkCancellation() }
        let tx = try await client.transactions([txid])[0]
        let scripts = tx.outputs.compactMap { Data(hex: $0.scriptpubkey) }
        let histories = try await client.histories(scripts.map { ChainAddress(address: "", scriptPubKey: $0).electrumScriptHash })
        return histories.flatMap { $0 }.filter { $0.txid == txid && $0.height > 0 }.map(\.height).max()
    }
    /// Status is proved by script history, never a server-specific verbose transaction response.
    func transactionStatus(txid: String, scripts: [Data] = []) async throws -> Int {
        guard TransactionID.isValid(txid) else { throw ChainError.invalidTransaction }
        do {
            let response = try await http.send(URLRequest(url: configuration.mempoolURL.appendingPathComponent("tx/\(txid)/status"), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10))
            struct Status: Decodable { let confirmed: Bool; let block_height: Int? }
            guard response.status == 200 else { throw ChainError.http(response.status) }
            let status = try JSONDecoder().decode(Status.self, from: response.data)
            if status.confirmed { guard (status.block_height ?? 0) > 0 else { throw ChainError.invalidResponse }; return 1 }
            return 0
        } catch { try Task.checkCancellation() }
        var scripts = scripts
        if scripts.isEmpty {
            let raw = try await client.transactions([txid])[0]
            scripts = raw.outputs.compactMap { Data(hex: $0.scriptpubkey) }
        }
        let histories = try await client.histories(scripts.map { ChainAddress(address: "", scriptPubKey: $0).electrumScriptHash })
        guard let height = histories.flatMap({ $0 }).filter({ $0.txid == txid && $0.height > 0 }).map(\.height).max() else { return 0 }
        let tip = try await client.tip()
        guard tip >= height else { throw ChainError.invalidResponse }
        return tip - height + 1
    }
}

actor FiatPrice {
    static let shared = FiatPrice()
    private var request: Task<Decimal, Error>?
    func value(http: any HTTPTransport) async throws -> Decimal {
        guard UserDefaults.standard.object(forKey: "showUSD") as? Bool ?? true else { throw ChainError.unavailable }
        if let request { return try await request.value }
        let task = Task<Decimal, Error> {
            let response = try await http.send(URLRequest(url: URL(string: "https://mempool.space/api/v1/prices")!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5))
            struct Prices: Decodable { let USD: Decimal }
            guard response.status == 200, let rate = try? JSONDecoder().decode(Prices.self, from: response.data).USD, !rate.isNaN, rate > 0 else { throw ChainError.unavailable }
            return rate
        }
        request = task
        return try await task.value
    }
}
