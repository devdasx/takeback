#if DEBUG
import Foundation

/// Deterministic, read-only transport fixtures for native UI tests; absent from Release.
enum FindingUITestSupport {
    static var engine: FindingEngine? {
        let modes = ["-finding-ui-none", "-finding-ui-offline", "-finding-ui-slow", "-finding-ui-servers"]
        guard let mode = modes.first(where: ProcessInfo.processInfo.arguments.contains) else { return nil }
        return FindingEngine(configuration: try! ChainConfiguration(), http: FixtureHTTP(mode: mode),
                             electrum: FixtureRPC(mode: mode), connectivity: FixtureConnectivity(online: mode != "-finding-ui-offline"))
    }
    private struct FixtureConnectivity: SearchConnectivity {
        let online: Bool
        func isOnline() async throws -> Bool { online }
    }
    private struct FixtureHTTP: HTTPTransport {
        let mode: String
        func send(_ request: URLRequest) async throws -> HTTPResponse {
            if mode == "-finding-ui-slow" { try await Task.sleep(for: .seconds(60)) }
            if mode == "-finding-ui-servers" { throw ChainError.timeout }
            return .init(status: 200, data: Data("[]".utf8))
        }
    }
    private struct FixtureRPC: ElectrumTransport {
        let mode: String
        func call(server: ElectrumServer, method: String, params: [JSONValue], timeout: TimeInterval) async throws -> JSONValue {
            if mode == "-finding-ui-slow" { try await Task.sleep(for: .seconds(60)) }
            guard mode == "-finding-ui-none" else { throw ChainError.timeout }
            return try reply(method)
        }
        func batch(server: ElectrumServer, calls: [RPCCall], timeout: TimeInterval) async throws -> [Result<JSONValue, RPCFailure>] {
            if mode == "-finding-ui-slow" { try await Task.sleep(for: .seconds(60)) }
            guard mode == "-finding-ui-none" else { throw ChainError.timeout }
            return try calls.map { .success(try reply($0.method)) }
        }
        private func reply(_ method: String) throws -> JSONValue {
            switch method {
            case "server.version": .array([.string("Takeback UI fixture"), .string("1.4")])
            case "server.ping": .null
            case "blockchain.headers.subscribe": .object(["height": .number(900_000)])
            case "blockchain.scripthash.get_history", "blockchain.scripthash.listunspent": .array([])
            default: throw ChainError.invalidResponse
            }
        }
    }
}
#endif
