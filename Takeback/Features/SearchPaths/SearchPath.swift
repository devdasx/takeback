import Foundation

struct SearchPath: Hashable, Identifiable, Sendable {
    enum Source: Hashable, Sendable { case standard(purpose: Int, account: Int), custom }
    var id: String = UUID().uuidString
    var name: String = ""
    var components: [UInt32]
    var scriptType: AddressStandard
    var includeChange = true
    var source: Source = .custom
    var path: String { DerivationPath.format(components) }
    var fixedChain: Bool { components.count >= 4 }
    var branches: [UInt32] { fixedChain || !includeChange ? [0] : [0, 1] }
    var title: String { name.isEmpty ? path : name }
    var subtitle: String { "\(path) · \(scriptType.title)" + (!includeChange && !fixedChain ? " · receive only" : "") }
    func childPath(branch: UInt32, index: UInt32, accountRoot: Bool = false) -> [UInt32] {
        (accountRoot ? [] : components) + (fixedChain ? [index] : [branch, index])
    }
    static func standard(_ type: AddressStandard, account: Int, showAccount: Bool = false) -> Self {
        .init(id: "standard-\(type.rawValue)-\(account)", name: type.title + (showAccount ? " · Account \(account)" : ""),
              components: [UInt32(type.rawValue) | 0x80000000, 0x80000000, UInt32(account) | 0x80000000],
              scriptType: type, source: .standard(purpose: type.rawValue, account: account))
    }
}

enum DerivationPath {
    enum Problem: String, Error {
        case syntax = "Not a valid path. Use numbers, slashes and ’ for hardened, like m/84’/0’/1’."
        case depth = "Too deep. Use at most 6 levels."
        case index = "Each level must be below 2147483648."
        case duplicate = "This path is already in your search list"
        case standard = "This is already a standard path. Turn it on in Standard instead."
    }
    static func parse(_ text: String) throws -> [UInt32] {
        let normalized = text.replacingOccurrences(of: "h", with: "'").replacingOccurrences(of: "H", with: "'").replacingOccurrences(of: "’", with: "'")
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count > 1, parts[0] == "m" else { throw Problem.syntax }
        for part in parts.dropFirst() {
            let digits = part.last == "'" ? part.dropLast() : part[...]
            guard !digits.isEmpty, digits.utf8.allSatisfy({ (48...57).contains($0) }) else { throw Problem.syntax }
        }
        guard parts.count <= 7 else { throw Problem.depth }
        return try parts.dropFirst().map { part in
            let hardened = part.last == "'"
            guard let index = UInt32(hardened ? part.dropLast() : part[...]), index < 0x80000000 else { throw Problem.index }
            return index | (hardened ? 0x80000000 : 0)
        }
    }
    static func format(_ components: [UInt32]) -> String {
        "m" + components.map { "/\($0 & 0x7fffffff)" + ($0 & 0x80000000 != 0 ? "'" : "") }.joined()
    }
    static func validate(_ text: String, type: AddressStandard, customs: [SearchPath], accounts: Int, editing: String? = nil) throws -> [UInt32] {
        let components = try parse(text)
        if (0..<accounts).contains(where: { SearchPath.standard(type, account: $0).components == components }) { throw Problem.standard }
        if customs.contains(where: { $0.id != editing && $0.components == components && $0.scriptType == type }) { throw Problem.duplicate }
        return components
    }
}

struct SearchSelection: Equatable, Sendable {
    var enabled = Set(AddressStandard.allCases)
    var accounts = 1
    var addressesPerPath = 20
    var custom: [SearchPath] = []
    func enabledTypes(for plan: KeySearchPlan) -> [AddressStandard] { plan.types.filter { enabled.contains($0) } }
    func paths(for plan: KeySearchPlan) -> [SearchPath] {
        guard plan.origin != .single else { return [] }
        if case .account(let child) = plan.origin {
            return enabledTypes(for: plan).map { .standard($0, account: Int(child & 0x7fffffff)) }
        }
        return enabledTypes(for: plan).flatMap { type in (0..<accounts).map { SearchPath.standard(type, account: $0, showAccount: accounts > 1) } } + custom
    }
    func total(for plan: KeySearchPlan) -> Int {
        plan.origin == .single ? enabledTypes(for: plan).count : paths(for: plan).reduce(0) { $0 + $1.branches.count * addressesPerPath }
    }
    func isValid(for plan: KeySearchPlan) -> Bool { total(for: plan) > 0 }
    func summary(for plan: KeySearchPlan) -> String {
        let k = enabledTypes(for: plan).count
        if plan.origin == .single { return k == 4 ? "All 4" : "\(k) of 4" }
        if !custom.isEmpty { return "Standard + \(custom.count)" }
        return k == 4 ? "Standard" : "\(k) of 4"
    }
}

/// Only these two numeric defaults are persisted. Per-key paths never enter this store.
@MainActor final class SearchDefaults: ObservableObject {
    static let shared = SearchDefaults()
    static let depths = [20, 50, 100, 200]
    private let defaults: UserDefaults
    @Published var accounts: Int { didSet { defaults.set(accounts, forKey: "search.accounts") } }
    @Published var addresses: Int { didSet { defaults.set(addresses, forKey: "search.addresses") } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let n = defaults.integer(forKey: "search.accounts"), d = defaults.integer(forKey: "search.addresses")
        accounts = (1...10).contains(n) ? n : 1
        addresses = Self.depths.contains(d) ? d : 20
    }
    var selection: SearchSelection { .init(accounts: accounts, addressesPerPath: addresses) }
}
