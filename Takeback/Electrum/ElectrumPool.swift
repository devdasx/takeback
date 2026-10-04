import Foundation
import CryptoKit

/// Why a server is not used. `tried` is the copy for the Finding screen's Tried list.
enum ServerFailure: String, Codable, Sendable {
  case timeout, refused, certificateChanged, untrusted, noBatch, failed
  init(_ error: Error) {
    switch error as? ChainError {
    case .timeout: self = .timeout
    case .connectionRefused: self = .refused
    case .certificateChanged: self = .certificateChanged
    case .untrusted: self = .untrusted
    case .noBatch: self = .noBatch
    default: self = .failed
    }
  }
  var tried: String {
    switch self {
    case .timeout: "No response after 8 seconds"
    case .refused: "Connection refused"
    case .certificateChanged: "Certificate changed"
    case .untrusted: "Certificate not trusted"
    case .noBatch: "Doesn’t support batching"
    case .failed: "Connection failed"
    }
  }
}
struct ServerProbe: Codable, Sendable, Equatable {
  enum State: String, Codable, Sendable { case batch, noBatch, unreachable }
  let state: State
  let maxBatch: Int
  let latencyMS: Double
  let checkedAt: Date
  var failure: ServerFailure?
  var recent: [Bool] = []
  /// Success rate over the last 20 uses × 1 / p50 latency.
  var score: Double {
    Double(recent.filter { $0 }.count) / Double(max(1, recent.count)) / max(1, latencyMS)
  }
  var fresh: Bool {
    let age = Date().timeIntervalSince(checkedAt)
    return age >= 0 && age < 86400
  }
  var label: String {
    switch state {
    case .batch: "Batch · up to \(maxBatch) · \(Int(latencyMS.rounded())) ms"
    case .noBatch: "No batch support"
    case .unreachable: "Unreachable"
    }
  }
}
/// Probes servers for batch support and real batch capacity. Results are cached per endpoint for 24 hours.
actor ElectrumServerPool {
  static let shared = ElectrumServerPool()
  static let storeKey = "electrum.probes.v2"
  /// A foreground request never waits on more than this many unknown servers; the survey continues in the background.
  static let foregroundProbeLimit = 18
  private let transport: any ElectrumTransport
  private let defaults: UserDefaults?
  private var results: [String: ServerProbe]
  private var probing: [String: Task<ServerProbe?, Never>] = [:]
  /// `defaults: nil` keeps results in memory only (test and fixture transports).
  init(transport: any ElectrumTransport = TLSElectrumTransport(), defaults: UserDefaults? = .standard, cached: [String: ServerProbe] = [:]) {
    self.transport = transport
    self.defaults = defaults
    results =
      defaults?.data(forKey: Self.storeKey).flatMap {
        try? JSONDecoder().decode([String: ServerProbe].self, from: $0)
      } ?? cached
  }
  func result(_ server: ElectrumServer) -> ServerProbe? { results[server.id] }
  func allResults() -> [String: ServerProbe] { results }
  private func save() { defaults?.set(try? JSONEncoder().encode(results), forKey: Self.storeKey) }
  func record(_ server: ElectrumServer, success: Bool) {
    guard var probe = results[server.id] else { return }
    probe.recent = Array((probe.recent + [success]).suffix(20))
    results[server.id] = probe
    save()
  }
  /// Background survey: at most six servers at a time. Fresh results are reused unless forced.
  func warmUp(servers: [ElectrumServer] = ElectrumServer.defaults, force: Bool = false) async {
    await withTaskGroup(of: Void.self) { group in
      var cursor = 0
      func add() {
        guard cursor < servers.count else { return }
        let server = servers[cursor]
        cursor += 1
        group.addTask { _ = await self.probe(server, force: force) }
      }
      for _ in 0..<min(6, servers.count) { add() }
      while await group.next() != nil {
        if Task.isCancelled { group.cancelAll(); break }
        add()
      }
    }
  }
  /// A cancelled measurement is never cached as a negative result.
  func probe(_ server: ElectrumServer, force: Bool = false) async -> ServerProbe {
    if !force, let value = results[server.id], value.fresh { return value }
    let task: Task<ServerProbe?, Never>
    if let running = probing[server.id] {
      task = running
    } else {
      let transport = self.transport
      task = Task {
        do { try await ProbeSlots.shared.acquire() } catch { return nil }
        let value = await Self.measure(server, transport: transport)
        await ProbeSlots.shared.release()
        return value
      }
      probing[server.id] = task
    }
    let value = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    if probing[server.id] == task { probing[server.id] = nil }
    guard let value else {
      return ServerProbe(state: .unreachable, maxBatch: 0, latencyMS: 0, checkedAt: .distantPast, failure: .failed)
    }
    // A re-probe keeps the recent success history that feeds the health score.
    var stored = value
    stored.recent = Array(((results[server.id]?.recent ?? []) + value.recent).suffix(20))
    results[server.id] = stored
    save()
    return stored
  }
  /// The server a request would use now, from cached proof only (no probing).
  func best(_ servers: [ElectrumServer], pinned: Bool) -> ElectrumServer? {
    let eligible = servers.filter { results[$0.id]?.fresh == true && results[$0.id]?.state == .batch }
    return pinned ? eligible.first : eligible.max { (results[$0.id]?.score ?? 0) < (results[$1.id]?.score ?? 0) }
  }
  /// Proven batch-capable servers, best first: the user's order when pinned, otherwise by health score.
  /// With no fresh proof, probes run six at a time and the first passing server ends the wait.
  func candidates(_ servers: [ElectrumServer], pinned: Bool = false) async throws -> [ElectrumServer] {
    var eligible = servers.filter { results[$0.id]?.fresh == true && results[$0.id]?.state == .batch }
    if eligible.isEmpty {
      let unknown = Array(servers.filter { results[$0.id]?.fresh != true })
      let (stream, continuation) = AsyncStream<(ElectrumServer, ServerProbe)>.makeStream()
      // Unstructured on purpose: once one server passes, the others finish and fill the cache in the background.
      let survey = Task {
        await withTaskGroup(of: Void.self) { group in
          var cursor = 0
          func add() {
            guard cursor < unknown.count else { return }
            let server = unknown[cursor]
            cursor += 1
            group.addTask { continuation.yield((server, await self.probe(server))) }
          }
          for _ in 0..<min(6, unknown.count) { add() }
          while await group.next() != nil { if Task.isCancelled { group.cancelAll(); break }; add() }
        }
        continuation.finish()
      }
      let first: ElectrumServer? = await withTaskCancellationHandler {
        for await (server, probe) in stream where probe.state == .batch { return Optional(server) }
        return nil as ElectrumServer?
      } onCancel: { survey.cancel(); continuation.finish() }
      if let first { eligible.append(first) }
      try Task.checkCancellation()
    }
    guard !eligible.isEmpty else {
      throw SearchFailure.servers(
        servers.compactMap { server in
          guard let result = results[server.id], result.fresh, result.state != .batch else { return nil }
          return ServerAttempt(host: server.host, reason: (result.failure ?? .failed).tried)
        })
    }
    if pinned { return eligible }
    return eligible.sorted { (results[$0.id]?.score ?? 0) > (results[$1.id]?.score ?? 0) }
  }
  static func emptyHash(_ index: Int) -> String {
    Data(SHA256.hash(data: Data("Takeback public batch capacity probe v1 \(index)".utf8))).hex
  }
  /// Never assumes a capacity: batch support, then 100 → 1,000 → 5,000 → 10,000 unused scripthashes,
  /// then a binary search between the last pass and the first fail. Nil when cancelled.
  static func measure(_ server: ElectrumServer, transport: any ElectrumTransport) async -> ServerProbe? {
    let now = Date()
    func failed(_ state: ServerProbe.State, _ failure: ServerFailure) -> ServerProbe? {
      Task.isCancelled
        ? nil
        : ServerProbe(state: state, maxBatch: 0, latencyMS: 0, checkedAt: now, failure: failure, recent: [false])
    }
    do {
      _ = try await transport.call(
        server: server, method: "server.version", params: [.string("Takeback 1.0"), .string("1.4")], timeout: 8)
    } catch { return failed(.unreachable, ServerFailure(error)) }
    var latencies: [Double] = []
    do {
      let start = ContinuousClock.now
      let replies = try await transport.batch(
        server: server,
        calls: [
          RPCCall(method: "server.ping"), RPCCall(method: "blockchain.headers.subscribe"),
          RPCCall(method: "blockchain.scripthash.get_history", params: [.string(emptyHash(0))]),
        ], timeout: 15)
      guard replies.count == 3 else { throw ChainError.noBatch }
      for reply in replies { _ = try reply.get() }
      latencies.append(milliseconds(start.duration(to: .now)))
    } catch {
      // A TLS problem is reachability. An error, a single object or a disconnect in reply to the array is no batch.
      let failure = ServerFailure(error)
      if failure == .certificateChanged || failure == .untrusted { return failed(.unreachable, failure) }
      return failed(.noBatch, .noBatch)
    }
    // p50 of small round trips; large batches measure throughput, not latency.
    for _ in 0..<3 {
      let start = ContinuousClock.now
      if (try? await transport.call(server: server, method: "server.ping", params: [], timeout: 8)) != nil {
        latencies.append(milliseconds(start.duration(to: .now)))
      }
    }
    var passed = 3
    var failedSize: Int?
    func test(_ size: Int) async -> Bool {
      if Task.isCancelled { return false }
      do {
        let replies = try await transport.batch(
          server: server,
          calls: (0..<size).map {
            RPCCall(method: "blockchain.scripthash.get_history", params: [.string(emptyHash($0))])
          }, timeout: 15)
        guard replies.count == size else { return false }
        for reply in replies {
          guard case .array(let history) = try reply.get(), history.isEmpty else { return false }
        }
        return true
      } catch { return false }
    }
    for size in [100, 1000, 5000, 10000] {
      if await test(size) { passed = size } else { failedSize = size; break }
    }
    if var upper = failedSize {
      // Stop within 10% (at least 25, the client's chunk floor) to bound the load on public servers.
      while upper - passed > max(25, passed / 10), !Task.isCancelled {
        let mid = passed + (upper - passed) / 2
        if await test(mid) { passed = mid } else { upper = mid }
      }
    }
    guard !Task.isCancelled else { return nil }
    let sorted = latencies.sorted()
    return ServerProbe(
      state: .batch, maxBatch: min(passed, 10000), latencyMS: sorted[sorted.count / 2], checkedAt: now, recent: [true])
  }
  private static func milliseconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
  }
}

/// Adaptive batching over proven servers. `lane` lets a scan use up to two servers in parallel.
actor ElectrumClient {
  let servers: [ElectrumServer]
  let transport: any ElectrumTransport
  let pool: ElectrumServerPool
  let pinned: Bool
  private var lanes: [Int: ElectrumServer] = [:]
  private var unhealthy: [ElectrumServer: ServerFailure] = [:]
  private let onSelect: (@Sendable (_ host: String, _ failedHost: String?) async -> Void)?
  private(set) var failedOver: (from: String, to: String)?
  private(set) var batchCount = 0
  private(set) var answered = 0
  var current: ElectrumServer? { lanes[0] ?? lanes.values.first }
  /// Hosts in use, by lane, without repeats.
  var laneHosts: [String] {
    var seen = Set<String>()
    return lanes.sorted { $0.key < $1.key }.map(\.value.host).filter { seen.insert($0).inserted }
  }
  init(
    configuration: ChainConfiguration, transport: any ElectrumTransport = TLSElectrumTransport(),
    pool: ElectrumServerPool? = nil, pinned: Bool? = nil,
    onSelect: (@Sendable (_ host: String, _ failedHost: String?) async -> Void)? = nil
  ) {
    servers = configuration.electrumServers
    self.transport = transport
    self.pool = pool ?? (transport is TLSElectrumTransport ? .shared : ElectrumServerPool(transport: transport, defaults: nil))
    self.pinned = pinned ?? configuration.pinnedServers
    self.onSelect = onSelect
  }
  /// Servers that failed during this client's operation, with the reason shown to the user.
  var attempts: [ServerAttempt] {
    servers.compactMap { server in unhealthy[server].map { ServerAttempt(host: server.host, reason: $0.tried) } }
  }
  private func select(lane: Int) async throws -> ElectrumServer {
    let available = servers.filter { unhealthy[$0] == nil }
    let choices: [ElectrumServer]
    do {
      guard !available.isEmpty else { throw SearchFailure.servers([]) }
      choices = try await pool.candidates(available, pinned: pinned)
    } catch SearchFailure.servers(let more) {
      let known = Set(attempts.map(\.host))
      throw SearchFailure.servers(attempts + more.filter { !known.contains($0.host) })
    }
    guard !choices.isEmpty else { throw SearchFailure.servers(attempts) }
    // A lane stays on its server while it is healthy; scores moving between rounds don't switch it.
    if let current = lanes[lane], choices.contains(current) { return current }
    let server = choices[lane % choices.count]
    if let previous = lanes[lane], previous != server, unhealthy[previous] != nil, lane == 0 {
      failedOver = (previous.host, server.host)
    }
    if lanes[lane] != server {
      lanes[lane] = server
      if lane == 0 { await onSelect?(server.host, failedOver?.from) }
    }
    return server
  }
  private func markUnhealthy(_ server: ElectrumServer, _ failure: ServerFailure) {
    unhealthy[server] = failure
  }
  private static func isResourceLimit(_ message: String) -> Bool {
    let text = message.lowercased()
    return ["excessive", "resource", "limit", "too large", "too many", "batch", "cost"].contains {
      text.contains($0)
    }
  }
  func batch(_ calls: [RPCCall], lane: Int = 0) async throws -> [JSONValue] {
    guard !calls.isEmpty else { return [] }
    var output: [JSONValue] = []
    output.reserveCapacity(calls.count)
    var offset = 0
    while offset < calls.count {
      try Task.checkCancellation()
      let server = try await select(lane: lane)
      let capacity = await pool.result(server)?.maxBatch ?? 0
      guard capacity > 0 else {
        markUnhealthy(server, .noBatch)
        continue
      }
      let floor = min(25, capacity)
      var size = min(capacity, 10000)
      var floorFailures = 0
      chunks: while offset < calls.count {
        try Task.checkCancellation()
        let count = min(size, calls.count - offset)
        let chunk = Array(calls[offset..<offset + count])
        let replies: [Result<JSONValue, RPCFailure>]
        do {
          batchCount += 1
          replies = try await transport.batch(
            server: server, calls: chunk, timeout: min(30, 5 + Double(count) / 1000))
          guard replies.count == count else { throw ChainError.invalidResponse }
          // Every item refused with a resource error is a size limit for the whole chunk.
          if count > 1, replies.allSatisfy({ if case .failure(let e) = $0 { Self.isResourceLimit(e.message) } else { false } }) {
            throw ChainError.batchLimit
          }
        } catch {
          try Task.checkCancellation()
          await pool.record(server, success: false)
          let failure = ServerFailure(error)
          if [.certificateChanged, .untrusted, .refused].contains(failure) {
            markUnhealthy(server, failure)
            break chunks
          }
          if size <= floor { floorFailures += 1 } else { size = max(floor, size / 2) }
          if floorFailures >= 3 {
            markUnhealthy(server, failure)
            break chunks
          }
          continue
        }
        // Only a failing item is retried, individually, on another proven server. Nothing is dropped.
        var resolved: [JSONValue] = []
        resolved.reserveCapacity(count)
        for (index, reply) in replies.enumerated() {
          switch reply {
          case .success(let value): resolved.append(value)
          case .failure(let error):
            resolved.append(try await retryItem(chunk[index], excluding: server, error: error))
          }
        }
        output += resolved
        offset += count
        answered += count
        floorFailures = 0
        await pool.record(server, success: true)
      }
    }
    return output
  }
  private func retryItem(_ call: RPCCall, excluding server: ElectrumServer, error: RPCFailure) async throws -> JSONValue {
    let others = servers.filter { $0 != server && unhealthy[$0] == nil }
    let alternatives = (try? await pool.candidates(others, pinned: pinned)) ?? []
    for other in alternatives.prefix(3) {
      do {
        let retry = try await transport.batch(server: other, calls: [call], timeout: 8)
        guard retry.count == 1 else { throw ChainError.invalidResponse }
        return try retry[0].get()
      } catch { try Task.checkCancellation() }
    }
    throw error
  }
  func call(_ method: String, _ params: [JSONValue] = []) async throws -> JSONValue {
    try await batch([RPCCall(method: method, params: params)])[0]
  }
  func notifications(script: Data) async throws -> AsyncStream<Void> {
    guard let tls = transport as? TLSElectrumTransport else { return AsyncStream { $0.finish() } }
    return await tls.notifications(server: try await select(lane: 0), script: script)
  }
  static func alreadyKnown(_ message: String) -> Bool {
    let text = message.lowercased()
    return ["already in the mempool", "already in mempool", "txn-already-known", "txn-already-in-mempool", "already known"]
      .contains { text.contains($0) }
  }
}

struct ServerAttempt: Equatable, Sendable { let host: String; let reason: String }
enum SearchFailure: Error, Equatable { case servers([ServerAttempt]) }

/// Welcome, Settings and a first scan share the same six-probe ceiling.
private actor ProbeSlots {
  static let shared = ProbeSlots()
  private var active = 0
  private var waiting: [(UUID, CheckedContinuation<Void, Error>)] = []
  func acquire() async throws {
    let id = UUID()
    try Task.checkCancellation()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        if active < 6 { active += 1; continuation.resume() }
        else { waiting.append((id, continuation)) }
      }
    } onCancel: { Task { await self.cancel(id) } }
  }
  func release() {
    if waiting.isEmpty { active -= 1 }
    else { waiting.removeFirst().1.resume() }
  }
  private func cancel(_ id: UUID) {
    if let index = waiting.firstIndex(where: { $0.0 == id }) { waiting.remove(at: index).1.resume(throwing: CancellationError()) }
  }
}
