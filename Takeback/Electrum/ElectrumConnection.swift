import Foundation
import Network
import Security
import CryptoKit

/// Shared transport owns one reusable, serialized connection per endpoint.
struct TLSElectrumTransport: ElectrumTransport {
  private static let connections = ElectrumConnections()
  func notifications(server: ElectrumServer, script: Data) async -> AsyncStream<Void> {
    let socket = await Self.connections.connection(server)
    return socket.notifications(script: script)
  }
  func call(server: ElectrumServer, method: String, params: [JSONValue], timeout: TimeInterval = 8) async throws -> JSONValue {
    let socket = await Self.connections.connection(server)
    return try await socket.request([RPCCall(method: method, params: params)], batch: false, timeout: timeout)[0].get()
  }
  func batch(server: ElectrumServer, calls: [RPCCall], timeout: TimeInterval) async throws -> [Result<JSONValue, RPCFailure>] {
    guard !calls.isEmpty, calls.count <= 10000 else { throw ChainError.invalidResponse }
    let socket = await Self.connections.connection(server)
    return try await socket.request(calls, batch: true, timeout: timeout)
  }
  /// Closes the reused connection so the next request performs a fresh TLS handshake and pin check.
  static func close(_ server: ElectrumServer) async { await connections.close(server) }
}
private actor ElectrumConnections {
  var sockets: [ElectrumServer: ElectrumConnection] = [:]
  func connection(_ server: ElectrumServer) -> ElectrumConnection {
    if let socket = sockets[server], !socket.isClosed { return socket }
    let socket = ElectrumConnection(server: server)
    sockets[server] = socket
    return socket
  }
  func close(_ server: ElectrumServer) { sockets.removeValue(forKey: server)?.close() }
}
/// Public certificate pins only. A changed pinned certificate fails even if the new leaf is system-trusted.
final class ElectrumPins: @unchecked Sendable {
  static let shared = ElectrumPins()
  private let lock = NSLock()
  private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) { self.defaults = defaults }
  func pin(_ endpoint: String) -> String? { lock.withLock { defaults.string(forKey: "electrum.pin." + endpoint) } }
  func accept(_ hash: String, endpoint: String) -> Bool {
    lock.withLock {
      let key = "electrum.pin." + endpoint
      if let existing = defaults.string(forKey: key) { return existing == hash }
      defaults.set(hash, forKey: key)
      return true
    }
  }
}
/// The serial queue owns the socket, buffer and continuations; a batch is always one JSON array.
final class ElectrumConnection: @unchecked Sendable {
  private struct Work {
    let id: UUID
    let calls: [RPCCall], batch: Bool, timeout: TimeInterval
    let continuation: CheckedContinuation<[Result<JSONValue, RPCFailure>], Error>
  }
  private let queue = DispatchQueue(label: "app.takeback.electrum.connection")
  private let stateLock = NSLock()
  private var closed = false
  var isClosed: Bool { stateLock.withLock { closed } }
  private let server: ElectrumServer
  private var connection: NWConnection?
  private var waiting: [Work] = [], active: Work?
  private var buffer = Data(), nextID = 1, ids: [Int] = []
  private var ready = false, negotiated = false
  private var versionReply: JSONValue?
  private var deadline: DispatchWorkItem?, idle: DispatchWorkItem?
  private var pendingPin: String?, trustFailure: ChainError?
  private var withdrawn: Set<UUID> = []
  private var listeners: [UUID: AsyncStream<Void>.Continuation] = [:]
  func notifications(script: Data) -> AsyncStream<Void> {
    let id = UUID()
    return AsyncStream { continuation in
      queue.async { self.listeners[id] = continuation }
      let task = Task {
        do {
          _ = try await self.request([RPCCall(method: "blockchain.scripthash.subscribe", params: [.string(ChainAddress(address: "", scriptPubKey: script).electrumScriptHash)])], batch: false, timeout: 8)
          _ = try await self.request([RPCCall(method: "blockchain.headers.subscribe")], batch: false, timeout: 8)
          while !Task.isCancelled {
            try await Task.sleep(for: .seconds(60))
            _ = try await self.request([RPCCall(method: "server.ping")], batch: false, timeout: 8)
          }
        } catch { continuation.finish() }
      }
      continuation.onTermination = { [weak self] _ in
        task.cancel()
        self?.queue.async { [weak self] in self?.listeners.removeValue(forKey: id) }
      }
    }
  }
  init(server: ElectrumServer) { self.server = server }
  func request(_ calls: [RPCCall], batch: Bool, timeout: TimeInterval) async throws -> [Result<JSONValue, RPCFailure>] {
    let id = UUID()
    return try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        queue.async {
          guard !self.isClosed else { continuation.resume(throwing: ChainError.unavailable); return }
          if self.withdrawn.remove(id) != nil { continuation.resume(throwing: CancellationError()); return }
          self.waiting.append(Work(id: id, calls: calls, batch: batch, timeout: timeout, continuation: continuation))
          self.advance()
        }
      }
    } onCancel: { self.cancel(id) }
  }
  /// A queued request is withdrawn; cancelling the request on the wire closes the socket.
  func close() { queue.async { self.finish(ChainError.unavailable) } }
  func cancel(_ id: UUID) {
    queue.async {
      if let index = self.waiting.firstIndex(where: { $0.id == id }) {
        self.waiting.remove(at: index).continuation.resume(throwing: CancellationError())
      } else if self.active?.id == id {
        self.finish(CancellationError())
      } else {
        self.withdrawn.insert(id)
      }
    }
  }
  private func advance() {
    guard active == nil, !waiting.isEmpty, !isClosed else { return }
    idle?.cancel()
    active = waiting.removeFirst()
    let deadline = DispatchWorkItem { self.finish(ChainError.timeout) }
    self.deadline = deadline
    queue.asyncAfter(deadline: .now() + (active?.timeout ?? 8), execute: deadline)
    if connection == nil { connect() }
    else if ready { send() }
  }
  private func connect() {
    guard let port = NWEndpoint.Port(rawValue: server.port), !server.host.isEmpty else { finish(ChainError.invalidConfiguration); return }
    let parameters: NWParameters
    if server.useTCP { parameters = .tcp }
    else {
      let tls = NWProtocolTLS.Options()
      sec_protocol_options_set_tls_server_name(tls.securityProtocolOptions, server.host)
      sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { [weak self] _, trust, complete in
        guard let self else { complete(false); return }
        let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
        guard let chain = SecTrustCopyCertificateChain(secTrust) as? [SecCertificate], let leaf = chain.first else { complete(false); return }
        let hash = Data(SHA256.hash(data: SecCertificateCopyData(leaf) as Data)).hex
        if let pin = ElectrumPins.shared.pin(self.server.id), pin != hash {
          self.trustFailure = .certificateChanged; complete(false); return
        }
        if SecTrustEvaluateWithError(secTrust, nil) { complete(true); return }
        // TOFU is restricted to a self-issued single-certificate chain; it is not a bypass for an invalid CA chain.
        guard chain.count == 1,
          SecCertificateCopyNormalizedIssuerSequence(leaf) == SecCertificateCopyNormalizedSubjectSequence(leaf)
        else { self.trustFailure = .untrusted; complete(false); return }
        // Electrum self-signed leaves often have neither DNS names nor TLS EKU.
        // TOFU binds their public certificate to this endpoint; still verify dates and chain integrity.
        SecTrustSetPolicies(secTrust, SecPolicyCreateBasicX509())
        SecTrustSetAnchorCertificates(secTrust, [leaf] as CFArray)
        SecTrustSetAnchorCertificatesOnly(secTrust, true)
        guard SecTrustEvaluateWithError(secTrust, nil) else { self.trustFailure = .untrusted; complete(false); return }
        self.pendingPin = hash
        complete(true)
      }, queue)
      parameters = NWParameters(tls: tls)
    }
    let socket = NWConnection(host: NWEndpoint.Host(server.host), port: port, using: parameters)
    connection = socket
    socket.stateUpdateHandler = { [weak self] state in
      guard let self, !self.isClosed else { return }
      switch state {
      case .ready: self.ready = true; self.send(); self.receive()
      case .failed(let error), .waiting(let error):
        if let failure = self.trustFailure { self.finish(failure) }
        else if case .posix(.ECONNREFUSED) = error { self.finish(ChainError.connectionRefused) }
        else { self.finish(ChainError.unavailable) }
      case .cancelled: self.finish(ChainError.unavailable)
      default: break
      }
    }
    socket.start(queue: queue)
  }
  private func envelope(_ call: RPCCall, id: Int) -> JSONValue {
    .object(["jsonrpc": .string("2.0"), "id": .number(Decimal(id)), "method": .string(call.method), "params": .array(call.params)])
  }
  private func send() {
    guard let active else { return }
    do {
      let request: JSONValue
      if !negotiated {
        request = envelope(RPCCall(method: "server.version", params: [.string("Takeback 1.0"), .string("1.4")]), id: 0)
      } else {
        ids = active.calls.map { _ in defer { nextID += 1 }; return nextID }
        let requests = zip(active.calls, ids).map { envelope($0, id: $1) }
        request = active.batch ? .array(requests) : requests[0]
        if !active.batch, active.calls.count == 1, active.calls[0].method == "server.version", let versionReply {
          try handle(.object(["id": .number(Decimal(ids[0])), "result": versionReply])); return
        }
      }
      var bytes = try JSONEncoder().encode(request); bytes.append(10)
      connection?.send(content: bytes, completion: .contentProcessed { [weak self] error in
        if error != nil { self?.finish(ChainError.unavailable) }
      })
    } catch { finish(error) }
  }
  private func receive() {
    connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, done, error in
      guard let self, !self.isClosed else { return }
      if let data { self.buffer.append(data) }
      guard self.buffer.count <= 64_000_000 else { self.finish(ChainError.invalidResponse); return }
      do {
        while let end = self.buffer.firstIndex(of: 10) {
          let line = Data(self.buffer.prefix(upTo: end)); self.buffer.removeSubrange(...end)
          if line.isEmpty { continue }
          try self.handle(JSONDecoder().decode(JSONValue.self, from: line))
        }
      } catch { self.finish(error); return }
      if done || error != nil { self.finish(ChainError.unavailable) }
      else { self.receive() }
    }
  }
  static func result(_ value: JSONValue) throws -> (Int, Result<JSONValue, RPCFailure>) {
    guard case .object(let item) = value, let number = item["id"]?.decimal,
      number >= 0, number <= Decimal(Int.max), number == Decimal(NSDecimalNumber(decimal: number).intValue)
    else { throw ChainError.invalidResponse }
    let id = NSDecimalNumber(decimal: number).intValue
    if case .object(let error) = item["error"], let message = error["message"]?.string {
      return (id, .failure(RPCFailure(code: NSDecimalNumber(decimal: error["code"]?.decimal ?? 0).intValue, message: message)))
    }
    guard let result = item["result"] else { throw ChainError.invalidResponse }
    return (id, .success(result))
  }
  private func handle(_ value: JSONValue) throws {
    if case .object(let notification) = value, let method = notification["method"]?.string, notification["id"] == nil {
      if method == "blockchain.scripthash.subscribe" || method == "blockchain.headers.subscribe" { for listener in listeners.values { listener.yield(()) } }
      return
    }
    guard let active else { throw ChainError.invalidResponse }
    if !negotiated {
      let (id, reply) = try Self.result(value)
      guard id == 0, case .array(let version) = try reply.get(), version.count == 2,
        version[1].string?.hasPrefix("1.4") == true else { throw ChainError.invalidResponse }
      if let pin = pendingPin, !ElectrumPins.shared.accept(pin, endpoint: server.id) { throw ChainError.certificateChanged }
      versionReply = try reply.get(); negotiated = true; send(); return
    }
    let values: [JSONValue]
    if active.batch {
      guard case .array(let array) = value else {
        // One error object for the whole array is a size limit from a batch-capable server.
        if case .object(let reply) = value, reply["error"] != nil, reply["error"] != .null { throw ChainError.batchLimit }
        throw ChainError.noBatch
      }
      values = array
    } else { values = [value] }
    guard values.count == ids.count else { throw ChainError.invalidResponse }
    let expectedIDs = Set(ids)
    var mapped: [Int: Result<JSONValue, RPCFailure>] = [:]
    for value in values {
      let (id, reply) = try Self.result(value)
      guard expectedIDs.contains(id), mapped.updateValue(reply, forKey: id) == nil else { throw ChainError.invalidResponse }
    }
    let replies = try ids.map { id in guard let reply = mapped[id] else { throw ChainError.invalidResponse }; return reply }
    deadline?.cancel(); deadline = nil
    self.active = nil
    active.continuation.resume(returning: replies)
    advance()
    if self.active == nil && listeners.isEmpty {
      // Long enough for a screen's 60-second refresh to reuse the connection.
      let idle = DispatchWorkItem { [weak self] in self?.finish(ChainError.unavailable) }
      self.idle = idle; queue.asyncAfter(deadline: .now() + 90, execute: idle)
    }
  }
  private func finish(_ error: Error) {
    guard !isClosed else { return }
    stateLock.withLock { closed = true }
    deadline?.cancel(); idle?.cancel(); withdrawn.removeAll()
    connection?.stateUpdateHandler = nil; connection?.cancel(); connection = nil
    active?.continuation.resume(throwing: error); active = nil
    for work in waiting { work.continuation.resume(throwing: error) }
    waiting.removeAll(); buffer.removeAll()
    let streams = listeners.values; listeners.removeAll(); for stream in streams { stream.finish() }
  }
}
