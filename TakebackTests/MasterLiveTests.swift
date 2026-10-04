import XCTest
@testable import Takeback

@MainActor final class MasterLiveTests: XCTestCase {
    func testReadOnlySurveyHistoryUTXOsLargeBatchAndFailover() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TAKEBACK_MASTER_LIVE"] == "1")
        let transport = ReadOnlyElectrum(), pool = ElectrumServerPool(transport: ReadOnlyElectrum(), defaults: nil)
        await pool.warmUp(force: true)
        let probes = await pool.allResults(), servers = ElectrumServer.defaults
        let capable = servers.filter { probes[$0.id]?.state == .batch }
        var report: [String: Any] = ["commit": ElectrumSeed.bundled.commit, "probes": servers.map { server -> [String: Any] in
            let p = probes[server.id]
            return ["host": server.endpoint, "state": p?.state.rawValue ?? "missing", "maxBatch": p?.maxBatch ?? 0, "p50ms": p?.latencyMS ?? 0, "reason": p?.failure?.tried ?? ""]
        }]
        func attach() {
            let attachment = XCTAttachment(data: try! JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
            attachment.name = "master-live-report"; attachment.lifetime = .keepAlways; add(attachment)
        }
        attach()
        defer { attach() }
        print("TAKEBACK PROBE SUMMARY passed=\(capable.count) capacity10000=\(capable.filter { probes[$0.id]?.maxBatch == 10000 }.count)")
        XCTAssertGreaterThanOrEqual(capable.count, 3)
        let config = try ChainConfiguration(electrumServers: capable)
        let key = SecureBytes(), pass = SecureBytes()
        try key.replace(with: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about".utf8)
        defer { key.wipe(); pass.wipe() }
        let plan = try SearchDerivationWork(key: key, passphrase: pass).prepare(plan: XCTUnwrap(detectKey(key).searchPlan))
        var scans: [[String: Any]] = []
        for gap in [20,100] {
            let client = ElectrumClient(configuration: config, transport: transport, pool: pool)
            let result = try await GapScanner.scan(plan: plan, gap: gap, client: client)
            let index = try XCTUnwrap(result.addresses.firstIndex { $0.chain.address == "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu" })
            XCTAssertFalse(result.histories[index].isEmpty)
            XCTAssertGreaterThanOrEqual(result.addresses.count, gap * 8)
            let total = result.unspent.flatMap { $0 }.reduce(Int64(0)) { $0 + $1.value }
            XCTAssertGreaterThanOrEqual(total, 0)
            scans.append(["gap": gap, "scripthashes": result.addresses.count, "batches": result.batches, "elapsedSeconds": result.elapsed, "server": result.host, "usedScripts": result.histories.filter { !$0.isEmpty }.count, "utxos": result.unspent.flatMap { $0 }.count, "utxoSats": total])
            print("TAKEBACK READ-ONLY SCAN gap=\(gap) hashes=\(result.addresses.count) batches=\(result.batches) seconds=\(result.elapsed) server=\(result.host)")
        }
        report["scans"] = scans
        attach()
        let best = try XCTUnwrap(capable.max { (probes[$0.id]?.maxBatch ?? 0) < (probes[$1.id]?.maxBatch ?? 0) })
        let calls = (20000..<30000).map { RPCCall(method: "blockchain.scripthash.get_history", params: [.string(ElectrumServerPool.emptyHash($0))]) }
        print("TAKEBACK LARGE BATCH START host=\(best.host) measured=\(probes[best.id]?.maxBatch ?? 0)")
        do {
            let values = try await transport.batch(server: best, calls: calls, timeout: 30)
            XCTAssertEqual(values.count, 10000)
            for value in values { XCTAssertEqual(try value.get(), .array([])) }
            report["largeBatch"] = ["host": best.endpoint, "direct10000": "pass"]
        } catch {
            var largeConfig = try ChainConfiguration(electrumServers: capable.sorted { (probes[$0.id]?.maxBatch ?? 0) > (probes[$1.id]?.maxBatch ?? 0) })
            largeConfig.pinnedServers = true
            let client = ElectrumClient(configuration: largeConfig, transport: transport, pool: pool)
            let values = try await client.batch(calls)
            XCTAssertEqual(values.count, 10000)
            report["largeBatch"] = ["host": best.endpoint, "direct10000": "fail", "adaptive": "pass", "batches": await client.batchCount]
        }
        attach()
        print("TAKEBACK LARGE BATCH COMPLETE; FAILOVER START")
        let down = ElectrumServer(host: "127.0.0.1", port: 1)
        var seeded = probes
        seeded[down.id] = .init(state: .batch, maxBatch: 10000, latencyMS: 1, checkedAt: Date(), recent: [true])
        let defaults = UserDefaults(suiteName: "takeback.live.\(UUID())")!
        defaults.set(try JSONEncoder().encode(seeded), forKey: ElectrumServerPool.storeKey)
        let failover = ElectrumClient(configuration: try .init(electrumServers: [down] + capable), transport: transport, pool: ElectrumServerPool(transport: transport, defaults: defaults), pinned: true)
        let recovered = try await GapScanner.scan(plan: plan, gap: 20, client: failover)
        let change = await failover.failedOver
        XCTAssertEqual(change?.from, down.host)
        XCTAssertFalse(recovered.histories.allSatisfy(\.isEmpty))
        report["failover"] = ["first": down.endpoint, "completedOn": recovered.host, "scripthashes": recovered.addresses.count]
        let fees = try await ChainService(configuration: config, client: ElectrumClient(configuration: config, transport: transport, pool: pool)).fees()
        XCTAssertGreaterThan(fees.medium, 0)
        report["fees"] = ["nextBlock": "\(fees.nextBlock)", "fast": "\(fees.fast)", "medium": "\(fees.medium)", "relay": "\(fees.minimum)"]
    }
}

/// Mainnet tests cannot invoke a write method, even accidentally.
private struct ReadOnlyElectrum: ElectrumTransport {
    let underlying = TLSElectrumTransport()
    func call(server: ElectrumServer, method: String, params: [JSONValue], timeout: TimeInterval) async throws -> JSONValue {
        guard method != "blockchain.transaction.broadcast" else { throw ChainError.invalidConfiguration }
        return try await underlying.call(server:server,method:method,params:params,timeout:timeout)
    }
    func batch(server: ElectrumServer, calls: [RPCCall], timeout: TimeInterval) async throws -> [Result<JSONValue,RPCFailure>] {
        guard !calls.contains(where: { $0.method == "blockchain.transaction.broadcast" }) else { throw ChainError.invalidConfiguration }
        return try await underlying.batch(server:server,calls:calls,timeout:timeout)
    }
}
