import XCTest

@testable import Takeback

/// Socket-level batching against Scripts/electrum-mock.py (TLS with the self-signed regtest
/// certificate on 52102/52103, plain TCP on 52104). The mock answers batches in reverse id order, drops
/// the connection for echo batches above 25, fails `test.item` on 52102 only, and holds `test.wait`.
/// Opt-in: TAKEBACK_MASTER_TRANSPORT=1.
@MainActor final class MasterTransportTests: XCTestCase {
  func testRealLocalTLSShuffledIDsHalvingItemFailoverCancellationAndPinning() async throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["TAKEBACK_MASTER_TRANSPORT"] == "1")
    let a = ElectrumServer(host: "localhost", port: 52102), b = ElectrumServer(host: "localhost", port: 52103)
    // The local test certificate can be regenerated; start unpinned so first use is exercised.
    for server in [a, b] {
      UserDefaults.standard.removeObject(forKey: "electrum.pin." + server.id)
      await TLSElectrumTransport.close(server)
    }
    let transport = TLSElectrumTransport()
    let pool = ElectrumServerPool(transport: transport, defaults: nil)
    let probe = await pool.probe(a)
    XCTAssertEqual(probe.state, .batch)
    XCTAssertEqual(probe.maxBatch, 10000)
    let pin = try XCTUnwrap(ElectrumPins.shared.pin(a.id), "First use pins the self-signed leaf")

    // Replies arrive in reverse order and are matched by id; >25-call chunks disconnect, so chunks halve to 25.
    let client = ElectrumClient(configuration: try ChainConfiguration(electrumServers: [a, b]), transport: transport, pool: pool, pinned: true)
    let echoed = try await client.batch((0..<127).map { RPCCall(method: "test.echo", params: [.number(Decimal($0))]) })
    XCTAssertEqual(echoed, (0..<127).map { .number(Decimal($0)) })
    let count = await client.batchCount
    XCTAssertGreaterThan(count, 6)

    // A per-item error is retried on the other server.
    let recovered = try await client.batch([RPCCall(method: "test.item", params: [.string("recovered")])])
    XCTAssertEqual(recovered, [.string("recovered")])

    // Cancelling an in-flight request closes the socket promptly.
    let started = ContinuousClock.now
    let task = Task { try await transport.batch(server: a, calls: [RPCCall(method: "test.wait")], timeout: 30) }
    try await Task.sleep(for: .milliseconds(100))
    task.cancel()
    do {
      _ = try await task.value
      XCTFail("Cancellation did not close the socket")
    } catch { XCTAssertTrue(error is CancellationError) }
    XCTAssertLessThan(started.duration(to: .now), .seconds(2))

    // Plain TCP framing (allowed in the app only for onion hosts).
    let tcp = ElectrumServer(host: "localhost", port: 52104, useTCP: true)
    let shuffled = try await transport.batch(server: tcp, calls: (0..<12).map { RPCCall(method: "test.echo", params: [.number(Decimal($0))]) }, timeout: 5)
    XCTAssertEqual(try shuffled.map { try $0.get() }, (0..<12).map { .number(Decimal($0)) })

    // An unreachable server is never chosen over a proven one.
    let failover = ElectrumClient(
      configuration: try ChainConfiguration(electrumServers: [ElectrumServer(host: "localhost", port: 1), b]), transport: transport, pool: pool, pinned: true)
    let answer = try await failover.call("test.echo", [.number(42)])
    XCTAssertEqual(answer, .number(42))

    // TOFU: a different leaf for a pinned endpoint is refused and reported.
    UserDefaults.standard.set(String(repeating: "f", count: 64), forKey: "electrum.pin." + a.id)
    await TLSElectrumTransport.close(a)
    let changed = await ElectrumServerPool.measure(a, transport: transport)
    XCTAssertEqual(changed?.state, .unreachable)
    XCTAssertEqual(changed?.failure, .certificateChanged)
    UserDefaults.standard.set(pin, forKey: "electrum.pin." + a.id)
    await TLSElectrumTransport.close(a)
    let restored = await ElectrumServerPool.measure(a, transport: transport)
    XCTAssertEqual(restored?.state, .batch)
  }
}
