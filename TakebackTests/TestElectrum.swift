import XCTest
@testable import Takeback

/// Deterministic in-process Electrum double. Socket framing and probing are exercised separately by MasterTransportTests.
actor TestElectrum: ElectrumTransport {
    struct Call: Sendable { let host: String; let method: String; let params: [JSONValue]; let timeout: TimeInterval }
    var calls: [Call] = []
    var replies: [String: JSONValue] = [:]
    var broadcastReplies: [Result<JSONValue, ChainError>] = []
    var rejection: String?
    var delay: Duration = .zero
    var active = 0, cancellations = 0
    var batchSizes: [Int] = []
    func set(_ key: String, _ value: JSONValue) { replies[key] = value }
    func broadcasts(_ values: [Result<JSONValue, ChainError>]) { broadcastReplies = values }
    func reject(_ message: String?) { rejection = message }
    func pause(_ duration: Duration) { delay = duration }
    func call(server: ElectrumServer, method: String, params: [JSONValue], timeout: TimeInterval) async throws -> JSONValue {
        calls.append(.init(host: server.host, method: method, params: params, timeout: timeout))
        if method == "server.version" { return .array([.string("fixture"), .string("1.4")]) }
        if method == "server.ping" { return .null }
        if method == "blockchain.transaction.broadcast" {
            if let rejection { throw RPCFailure(code: -26, message: rejection) }
            guard !broadcastReplies.isEmpty else { throw ChainError.unavailable }
            return try broadcastReplies.removeFirst().get()
        }
        let argument = params.first?.string ?? params.first?.integer.map(String.init) ?? ""
        if let reply = replies[method + ":" + argument] ?? replies[method] { return reply }
        switch method {
        case "blockchain.headers.subscribe": return .object(["height": .number(900000)])
        case "blockchain.estimatefee": return .number(Decimal(string: "0.0002")!)
        case "blockchain.relayfee": return .number(Decimal(string: "0.00001")!)
        case "blockchain.scripthash.get_history", "blockchain.scripthash.get_mempool", "blockchain.scripthash.listunspent": return .array([])
        default: throw ChainError.invalidResponse
        }
    }
    func batch(server: ElectrumServer, calls: [RPCCall], timeout: TimeInterval) async throws -> [Result<JSONValue, RPCFailure>] {
        batchSizes.append(calls.count); active += 1; defer { active -= 1 }
        do { try await Task.sleep(for: delay) } catch { cancellations += 1; throw error }
        var result: [Result<JSONValue, RPCFailure>] = []
        for item in calls {
            do { result.append(.success(try await call(server: server, method: item.method, params: item.params, timeout: timeout))) }
            catch let failure as RPCFailure { result.append(.failure(failure)) }
        }
        return result
    }
    nonisolated func service() throws -> ChainService {
        let servers = [ElectrumServer(host: "first.invalid", port: 50002), ElectrumServer(host: "second.invalid", port: 50002), ElectrumServer(host: "third.invalid", port: 50002)]
        var config = try ChainConfiguration(electrumServers: servers)
        config.pinnedServers = true
        return ChainService(configuration: config, http: NoHTTP(), electrum: self, client: ElectrumClient(configuration: config, transport: self, pool: ElectrumServerPool(transport: self, defaults: nil, cached: Dictionary(uniqueKeysWithValues: servers.map { ($0.id, ServerProbe(state: .batch, maxBatch: 10000, latencyMS: 1, checkedAt: Date(), recent: [true])) }))))
    }
}
struct NoHTTP: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse { throw ChainError.unavailable }
}
