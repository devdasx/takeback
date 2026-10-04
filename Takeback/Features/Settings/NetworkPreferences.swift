import Foundation
import Network
import SwiftUI

struct BackupServer: Codable, Hashable, Identifiable, Sendable {
    let server: ElectrumServer
    var enabled = true
    var id: String { server.endpoint }
    var isDefault: Bool { ElectrumServer.defaults.contains(server) }
}

/// Only public preferences belong here. This store never receives a secret session.
@MainActor final class NetworkPreferences: ObservableObject {
    static let shared = NetworkPreferences()
    static let defaultURL = URL(string: "https://mempool.space/api")!
    static let storageKey = "electrumPreferences.v1"
    private struct Saved: Codable { var own: Bool; var url: String; var backups: [BackupServer] }
    private let defaults: UserDefaults
    @Published private(set) var usesOwnServer = false
    @Published private(set) var ownURL = ""
    @Published private(set) var backups = ElectrumServer.defaults.map { BackupServer(server: $0) }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey), let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            ownURL = ServerAddress.api(saved.url)?.absoluteString ?? ""
            usesOwnServer = saved.own
            backups = saved.backups
            for server in ElectrumServer.defaults where !backups.contains(where: { $0.server == server }) { backups.append(.init(server: server)) }

        }
    }
    var configuration: ChainConfiguration {
        #if DEBUG
        if ProcessInfo.processInfo.environment["TAKEBACK_REGTEST"] == "1" { return try! .init(mempoolURL: URL(string: "https://127.0.0.1:1/api")!, electrumServers: [.init(host: "127.0.0.1", port: 52002)]) }
        #endif
        var config = try! ChainConfiguration(mempoolURL: usesOwnServer ? ServerAddress.api(ownURL) ?? Self.defaultURL : Self.defaultURL, electrumServers: backups.filter(\.enabled).map(\.server))
        config.pinnedServers = usesOwnServer
        return config
    }
    func setMode(onlyMine: Bool) { usesOwnServer = onlyMine; persist() }
    func move(from: IndexSet, to: Int) { backups.move(fromOffsets: from, toOffset: to); persist() }
    func useDefault() { usesOwnServer = false; persist() }
    func saveOwn(_ url: URL) {
        guard let valid = ServerAddress.api(url.absoluteString) else { return }
        ownURL = valid.absoluteString; usesOwnServer = true; persist()
    }
    func setEnabled(_ item: BackupServer, _ value: Bool) {
        guard let i = backups.firstIndex(where: { $0.id == item.id }) else { return }
        backups[i].enabled = value; persist()
    }
    @discardableResult func add(_ server: ElectrumServer) -> Bool {
        guard !backups.contains(where: { $0.server == server }), ServerAddress.electrum(server.endpoint) != nil && (!server.useTCP || server.host.hasSuffix(".onion")) else { return false }
        backups.append(.init(server: server)); persist(); return true
    }
    func delete(_ item: BackupServer) {
        guard !item.isDefault else { return }; backups.removeAll { $0.id == item.id }; persist()
    }
    #if DEBUG
    func resetForUITest() { usesOwnServer = false; ownURL = ""; backups = ElectrumServer.defaults.map { .init(server: $0) }; defaults.removeObject(forKey: Self.storageKey) }
    #endif
    private func persist() {
        if let data = try? JSONEncoder().encode(Saved(own: usesOwnServer, url: ownURL, backups: backups)) { defaults.set(data, forKey: Self.storageKey) }
    }
}

enum ServerAddress {
    static func allowedTransport(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), !host.isEmpty, url.user == nil, url.password == nil else { return false }
        return url.scheme == "https" || (url.scheme == "http" && host.hasSuffix(".onion"))
    }
    static func api(_ text: String) -> URL? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: { $0.isWhitespace }), var parts = URLComponents(string: text),
              let url = parts.url, allowedTransport(url), parts.query == nil, parts.fragment == nil,
              parts.port == nil || (1...65535).contains(parts.port!) else { return nil }
        while parts.path.hasSuffix("/") { parts.path.removeLast() }
        guard parts.path.hasSuffix("/api") else { return nil }
        return parts.url
    }
    static func electrum(_ text: String) -> ElectrumServer? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.contains(where: { $0.isWhitespace }), !value.contains("/"), !value.contains("@"),
              let split = value.lastIndex(of: ":"), let port = UInt16(value[value.index(after: split)...]), port > 0 else { return nil }
        let host = String(value[..<split])
        if host.hasPrefix("["), host.hasSuffix("]"), IPv6Address(String(host.dropFirst().dropLast())) != nil {
            return .init(host: String(host.dropFirst().dropLast()), port: port)
        }
        guard !host.isEmpty, host.count <= 253,
              host.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 46 }),
              host.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && $0.count <= 63 && !$0.hasPrefix("-") && !$0.hasSuffix("-") }) else { return nil }
        return .init(host: host, port: port)
    }
}
