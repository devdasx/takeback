import Foundation

@MainActor final class ServerSettingsModel: ObservableObject {
    enum Status: Equatable { case idle, checking, connected(Int), unavailable, invalidAPI }
    @Published var own: Bool
    @Published var text: String
    @Published private(set) var status: Status = .idle
    @Published private(set) var adding = false
    @Published var addError: String?
    @Published var probes: [String: ServerProbe] = [:]
    @Published var checking = Set<String>()
    let preferences: NetworkPreferences
    let pool: ElectrumServerPool
    var fixture = false
    private var task: Task<Void, Never>?
    private var addition: Task<Void, Never>?
    init(preferences: NetworkPreferences = .shared, http: any HTTPTransport = URLSessionTransport(), electrum: any ElectrumTransport = TLSElectrumTransport(), debounce: Duration = .milliseconds(600)) {
        self.preferences = preferences
        pool = electrum is TLSElectrumTransport ? .shared : ElectrumServerPool(transport: electrum, defaults: nil)
        own = preferences.usesOwnServer; text = ""
    }
    var canSave: Bool { false }
    func save() -> Bool { false }
    func changed() { preferences.setMode(onlyMine: own) }
    func checkAll(force: Bool = false) {
        guard !fixture else { return }
        task?.cancel()
        let servers = preferences.backups.map(\.server)
        task = Task {
            probes = await pool.allResults()
            checking = Set(servers.filter { force || probes[$0.id]?.fresh != true }.map(\.id))
            await withTaskGroup(of: (ElectrumServer, ServerProbe).self) { group in
                var cursor = 0
                func add() { guard cursor < servers.count else { return }; let server = servers[cursor]; cursor += 1
                    group.addTask { (server, await self.pool.probe(server, force: force)) }
                }
                for _ in 0..<min(6, servers.count) { add() }
                while let (server, result) = await group.next() {
                    probes[server.id] = result; checking.remove(server.id)
                    if Task.isCancelled { group.cancelAll(); break }; add()
                }
            }
        }
    }
    func add(_ text: String, useTCP: Bool = false) {
        guard !adding else { return }
        guard var server = ServerAddress.electrum(text), !useTCP || server.host.hasSuffix(".onion") else { addError = "Couldn’t connect"; return }
        server.useTCP = useTCP
        guard !preferences.backups.contains(where: { $0.server == server }) else { addError = "This server is already in the list."; return }
        adding = true; addError = nil
        addition = Task {
            let result = await pool.probe(server, force: true)
            guard !Task.isCancelled else { return }
            adding = false
            if result.state == .batch { preferences.add(server); probes[server.id] = result }
            else { addError = result.state == .noBatch ? "This server doesn’t support batch requests" : result.failure == .certificateChanged ? "This server’s certificate changed" : "Couldn’t connect" }
        }
    }
    func stop() { task?.cancel(); addition?.cancel(); adding = false }
    #if DEBUG
    func showFixture(_ state: Status) { fixture = true; status = state }
    #endif
    deinit { task?.cancel(); addition?.cancel() }
}
