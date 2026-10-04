import XCTest
@testable import Takeback

@MainActor final class SearchPathsTests: XCTestCase {
    let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    func testNormalizationLimitsAndDuplicates() throws {
        let expected: [UInt32] = [0x80000054,0x80000000,0x80000001]
        for text in ["m/84'/0'/1'", "m/84h/0H/1’", "m/084H/00h/01'"] { XCTAssertEqual(try DerivationPath.parse(text), expected) }
        XCTAssertEqual(DerivationPath.format(expected), "m/84'/0'/1'")
        for text in ["", "m", "M/0", "m//0", "m/-1", "m/1.2", "m/1''", "m/１", "m/1/", "m/ 1", "m/1 "] { expect(.syntax, text) }
        expect(.depth, "m/0/1/2/3/4/5/6"); expect(.index, "m/2147483648"); expect(.index, "m/99999999999999999999'")
        XCTAssertEqual(try DerivationPath.parse("m/2147483647'")[0], UInt32.max)
        let custom = SearchPath(components: expected, scriptType: .bip84)
        XCTAssertThrowsError(try DerivationPath.validate(custom.path, type: .bip84, customs: [custom], accounts: 1)) { XCTAssertEqual($0 as? DerivationPath.Problem, .duplicate) }
        XCTAssertNoThrow(try DerivationPath.validate(custom.path, type: .bip84, customs: [custom], accounts: 1, editing: custom.id))
        XCTAssertNoThrow(try DerivationPath.validate(custom.path, type: .bip44, customs: [custom], accounts: 1))
        for type in AddressStandard.allCases {
            XCTAssertThrowsError(try DerivationPath.validate(SearchPath.standard(type, account: 0).path, type: type, customs: [], accounts: 1)) { XCTAssertEqual($0 as? DerivationPath.Problem, .standard) }
            XCTAssertThrowsError(try DerivationPath.validate(SearchPath.standard(type, account: 2).path, type: type, customs: [], accounts: 3))
        }
    }
    func testTotalsEmptySelectionAndKeyRestrictions() throws {
        let hd = KeyDetection.phrase(words: 12, checksumValid: true).searchPlan!
        var selection = SearchSelection(accounts: 2, addressesPerPath: 50)
        XCTAssertEqual(selection.total(for: hd), 800)
        selection.enabled = [.bip84]
        selection.custom = [try path("m/0'", type: .bip86), try path("m/0'/0'", type: .bip49, change: false), try path("m/44'/0'/0'/0", type: .bip44)]
        XCTAssertEqual(selection.total(for: hd), 400); XCTAssertEqual(selection.paths(for: hd).count, 5)
        XCTAssertEqual(selection.paths(for: hd).first?.title, "Native SegWit · Account 0")
        selection.custom = []; selection.enabled = []
        XCTAssertFalse(selection.isValid(for: hd))
        let single = KeyDetection.wif(compressed: false).searchPlan!
        XCTAssertEqual(SearchSelection().total(for: single), 1)
        XCTAssertEqual(SearchSelection().enabledTypes(for: single), [.bip44])
        XCTAssertFalse(SearchSelection(enabled: [.bip84]).isValid(for: single))
        for (prefix, type) in [(ExtendedPrivatePrefix.xprv,AddressStandard.bip44),(.yprv,.bip49),(.zprv,.bip84)] {
            let plan = KeyDetection.extended(prefix: prefix, depth: 3, childNumber: 0x80000002).searchPlan!
            let paths = SearchSelection(accounts: 10, custom: [try path("m/0'", type: .bip84)]).paths(for: plan)
            XCTAssertEqual(paths.count, 1); XCTAssertEqual(paths[0].scriptType, type)
            XCTAssertEqual(paths[0].components.last, 0x80000002)
        }
    }
    func testIndependentCustomDerivationVectorsAndPrivateSigning() throws {
        struct Vector: Decodable { let passphrase: String; let path: String; let branch: UInt32; let type: Int; let script: String; let address: String }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "CustomPathVectors", withExtension: "json"))
        let vectors = try JSONDecoder().decode([Vector].self, from: Data(contentsOf: url))
        XCTAssertEqual(vectors.count, 64)
        for vector in vectors {
            let session = try session(passphrase: vector.passphrase); defer { session.wipe() }
            let item = try path(vector.path, type: XCTUnwrap(AddressStandard(rawValue: vector.type)))
            let work = try SearchDerivationWork(key: session.key, passphrase: session.passphrase)
            let pub = try work.prepare(plan: XCTUnwrap(detectKey(session.key).searchPlan), selection: .init(enabled: [], custom: [item]))
            XCTAssertTrue(work.isCleared)
            let address = try pub.address(path: item, branch: vector.branch, index: 0)
            XCTAssertEqual(address.chain.address, vector.address, vector.path)
            XCTAssertEqual(address.chain.scriptPubKey.hex, vector.script, vector.path)
            let signer = try CancellationKeyWork(sessionKey: session.key, passphrase: session.passphrase)
            let destination = try pub.address(path: item, branch: 0, index: 1).signing
            let plan = CancellationPlan(originalID: String(repeating: "a", count: 64), originalFee: 200, originalVSize: 120,
                inputs: [.init(txid: String(repeating: "b", count: 64), index: 0, value: 200_000, key: address.signing)], destination: destination, descendants: [], height: 800000)
            let signed = try signer.sign(plan, rate: 10)
            XCTAssertTrue(signer.isCleared)
            let parsed = try WireTransaction(signed.raw)
            XCTAssertEqual(parsed.outputs[0].scriptpubkey, destination.script.hex)
            XCTAssertEqual(destination.searchPath, item)
        }
    }
    func testDefaultsSeedOnceAndClearWipesChoices() throws {
        let suite = "paths-test-" + UUID().uuidString
        let store = UserDefaults(suiteName: suite)!; defer { store.removePersistentDomain(forName: suite) }
        let prefs = SearchDefaults(defaults: store)
        XCTAssertEqual(prefs.accounts, 1); XCTAssertEqual(prefs.addresses, 20)
        prefs.accounts = 3; prefs.addresses = 100
        let s = try session(); defer { s.wipe() }
        s.searchSelection = prefs.selection
        s.searchSelection?.custom = [try path("m/0'", type: .bip84)]
        prefs.accounts = 4
        XCTAssertEqual(s.searchSelection?.accounts, 3)
        XCTAssertEqual(SearchDefaults(defaults: store).accounts, 4)
        XCTAssertEqual(Set(store.persistentDomain(forName: suite)!.keys), ["search.accounts", "search.addresses"])
        let model = EnterKeyModel(session: s)
        s.searchSelection?.enabled = []; s.searchSelection?.custom = []
        XCTAssertFalse(model.canFind)
        model.clear(); XCTAssertNil(s.searchSelection); XCTAssertNil(s.publicScanPlan)
        try s.key.replace(with: mnemonic.utf8); model.refresh()
        s.searchSelection?.custom = [try path("m/0'", type: .bip84)]
        s.wipe(); XCTAssertNil(s.searchSelection)
    }
    func testUnionBatchSplittingExtensionCapFailoverAndRows() async throws {
        let s = try session(); defer { s.wipe() }
        let item = try path("m/0'", type: .bip84)
        let fixed = try path("m/0'/0/0/0", type: .bip86)
        let overlap = try path("m/84'/0'/0'/0", type: .bip84)
        let selection = SearchSelection(enabled: [.bip84], custom: [item, fixed, overlap])
        let pub = try SearchDerivationWork(key: s.key, passphrase: s.passphrase).prepare(plan: XCTUnwrap(detectKey(s.key).searchPlan), selection: selection)
        let rpc = PathsRPC()
        let used = try pub.address(path: item, branch: 1, index: 19).chain.electrumScriptHash
        await rpc.markUsed(used)
        let recorder = PathProgressRecorder()
        let result = try await GapScanner.scan(plan: pub, gap: 20, client: rpc.client()) { await recorder.append($0) }
        XCTAssertEqual(result.addresses.count, 140)
        XCTAssertEqual(result.addresses.filter { $0.searchPath?.id == item.id && $0.branch == 1 }.last?.index, 39)
        let expected = Set(result.addresses.map { $0.chain.electrumScriptHash })
        let history = await rpc.history, unspent = await rpc.unspent, sizes = await rpc.sizes
        XCTAssertEqual(Set(history), expected); XCTAssertEqual(history.count, expected.count)
        XCTAssertEqual(Set(unspent), expected); XCTAssertEqual(unspent.count, expected.count)
        XCTAssertTrue(sizes.allSatisfy { $0 <= 25 })
        let updates = await recorder.values
        XCTAssertEqual(updates.last?.rows.count, 4)
        XCTAssertTrue(updates.contains { $0.failedHost == "down.invalid" })
        XCTAssertEqual(Set(updates.last!.rows.map(\.id)).count, 4)
        var row = SearchRow(type: .bip84, total: 20, searchPath: item)
        XCTAssertEqual(row.status, "Waiting"); row.started = true
        XCTAssertEqual(row.status, "Checking 0 of 20"); row.completed = 20
        XCTAssertEqual(row.status, "Nothing pending"); row.pending = 2; XCTAssertEqual(row.status, "2 pending")
        let one = try SearchDerivationWork(key: s.key, passphrase: s.passphrase).prepare(plan: XCTUnwrap(detectKey(s.key).searchPlan), selection: .init(enabled: [], custom: [try path("m/0'", type: .bip84, change: false)]))
        let allUsed = PathsRPC(alwaysUsed: true)
        let capped = try await GapScanner.scan(plan: one, gap: 200, client: allUsed.client())
        XCTAssertEqual(capped.addresses.count, 1000)
        XCTAssertEqual(capped.addresses.last?.index, 999)
    }
    private func expect(_ error: DerivationPath.Problem, _ text: String) {
        XCTAssertThrowsError(try DerivationPath.parse(text)) { XCTAssertEqual($0 as? DerivationPath.Problem, error) }
    }
    private func path(_ text: String, type: AddressStandard, change: Bool = true) throws -> SearchPath { .init(components: try DerivationPath.parse(text), scriptType: type, includeChange: change) }
    private func session(passphrase: String = "") throws -> SecretSession {
        let session = SecretSession(); try session.key.replace(with: mnemonic.utf8); try session.passphrase.replace(with: passphrase.utf8); return session
    }
}
private actor PathProgressRecorder {
    var values: [SearchProgress] = []
    func append(_ value: SearchProgress) { values.append(value) }
}
private actor PathsRPC: ElectrumTransport {
    var used = Set<String>(), history: [String] = [], unspent: [String] = [], sizes: [Int] = []
    let alwaysUsed: Bool
    init(alwaysUsed: Bool = false) { self.alwaysUsed = alwaysUsed }
    func markUsed(_ hash: String) { used.insert(hash) }
    func call(server: ElectrumServer, method: String, params: [JSONValue], timeout: TimeInterval) async throws -> JSONValue { .null }
    func batch(server: ElectrumServer, calls: [RPCCall], timeout: TimeInterval) async throws -> [Result<JSONValue, RPCFailure>] {
        if server.host == "down.invalid" { throw ChainError.unavailable }
        sizes.append(calls.count)
        return calls.map { call in
            let hash = call.params[0].string!
            if call.method == "blockchain.scripthash.get_history" {
                history.append(hash)
                return .success(.array(alwaysUsed || used.contains(hash) ? [.object(["tx_hash": .string(String(repeating: "a", count: 64)), "height": .number(1)])] : []))
            }
            unspent.append(hash); return .success(.array([]))
        }
    }
    nonisolated func client() throws -> ElectrumClient {
        let servers = [ElectrumServer(host: "down.invalid", port: 50002), ElectrumServer(host: "up.invalid", port: 50002)]
        var config = try ChainConfiguration(electrumServers: servers); config.pinnedServers = true
        return ElectrumClient(configuration: config, transport: self, pool: ElectrumServerPool(transport: self, defaults: nil, cached: Dictionary(uniqueKeysWithValues: servers.map { ($0.id, ServerProbe(state: .batch, maxBatch: 25, latencyMS: 1, checkedAt: Date(), recent: [true])) })))
    }
}
