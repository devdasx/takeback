import XCTest
@testable import Takeback

private actor SettingsHTTP: HTTPTransport {
    var responses: [Result<HTTPResponse, ChainError>]
    var requests: [URLRequest] = []
    init(_ responses: [Result<HTTPResponse, ChainError>]) { self.responses = responses }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw ChainError.network }
        return try responses.removeFirst().get()
    }
}
private actor SettingsRPC: ElectrumTransport {
    let result: Result<JSONValue, ChainError>
    var calls: [(ElectrumServer, String, [JSONValue], TimeInterval)] = []
    init(_ result: Result<JSONValue, ChainError> = .success(.array([.string("test server"), .string("1.4")]))) { self.result = result }
    func call(server: ElectrumServer, method: String, params: [JSONValue], timeout: TimeInterval) async throws -> JSONValue {
        calls.append((server, method, params, timeout)); return try result.get()
    }
}
@MainActor final class SettingsTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    override func setUp() { suite = "Takeback.SettingsTests.\(UUID())"; defaults = UserDefaults(suiteName: suite)! }
    override func tearDown() { defaults.removePersistentDomain(forName: suite) }
    private func response(_ text: String, status: Int = 200) -> Result<HTTPResponse, ChainError> { .success(.init(status: status, data: Data(text.utf8))) }
    private func settle(_ model: ServerSettingsModel) async throws {
        for _ in 0..<100 { if model.status != .checking && !model.adding { return }; try await Task.sleep(for: .milliseconds(10)) }
        XCTFail("Validation did not finish")
    }
    func testFeePersistsAndCancelUsesItWithoutCustomDefault() throws {
        let old = UserDefaults.standard.object(forKey: "defaultFee")
        defer { if let old { UserDefaults.standard.set(old, forKey:"defaultFee") } else { UserDefaults.standard.removeObject(forKey:"defaultFee") } }
        for speed in [FeeSpeed.nextBlock,.fast,.medium] {
            FeePreference.defaultSpeed = speed
            XCTAssertEqual(UserDefaults.standard.string(forKey:"defaultFee"), speed.rawValue)
            let model = CancelModel(payment: PaymentsFixtures.payment(.normal,id:"a"), session: SecretSession())
            XCTAssertEqual(model.defaultSpeed, speed); model.release()
        }
        FeePreference.defaultSpeed = .custom; XCTAssertEqual(FeePreference.defaultSpeed,.medium)
        UserDefaults.standard.set("custom",forKey:"defaultFee"); XCTAssertEqual(FeePreference.defaultSpeed,.fast)
    }
    func testElectrumEndpointParsingTLSOnlyAndIPv6() {
        XCTAssertEqual(ServerAddress.electrum(" SERVER.EXAMPLE:50002 "), .init(host:"server.example",port:50002))
        XCTAssertEqual(ServerAddress.electrum("[::1]:50002")?.endpoint, "[::1]:50002")
        for invalid in ["server.example", "server.example:0", "server.example:65536", "ssl://node:50002", "node:50001/path", "user@host:50002", "bad..host:50002", "-bad.example:50002"] { XCTAssertNil(ServerAddress.electrum(invalid), invalid) }
    }
    func testModeOrderEnableAddDeleteAndPersistence() throws {
        let prefs = NetworkPreferences(defaults: defaults), count = ElectrumServer.defaults.count
        XCTAssertEqual(prefs.backups.map(\.server), ElectrumServer.defaults)
        XCTAssertGreaterThan(count, 3)
        prefs.setEnabled(prefs.backups[1], false)
        XCTAssertTrue(prefs.add(.init(host: "custom.example", port: 50002)))
        XCTAssertFalse(prefs.add(.init(host: "custom.example", port: 50002)))
        prefs.delete(prefs.backups[0]); XCTAssertEqual(prefs.backups.count, count + 1)
        prefs.setMode(onlyMine: true)
        prefs.move(from: IndexSet(integer: count), to: 0)
        let loaded = NetworkPreferences(defaults: defaults)
        XCTAssertTrue(loaded.configuration.pinnedServers)
        XCTAssertEqual(loaded.configuration.electrumServers.first?.host, "custom.example")
        XCTAssertFalse(loaded.backups.first { $0.server == ElectrumServer.defaults[1] }!.enabled)
        loaded.delete(loaded.backups[0]); XCTAssertEqual(loaded.backups.count, count)
        loaded.useDefault(); XCTAssertFalse(loaded.configuration.pinnedServers)
        let json = String(data: try XCTUnwrap(defaults.data(forKey: NetworkPreferences.storageKey)), encoding: .utf8)!
        XCTAssertFalse(json.contains("passphrase")); XCTAssertFalse(json.contains("privateKey"))
    }
    func testAddRequiresRealBatchProbeAndMeasuresCapacity() async throws {
        let prefs = NetworkPreferences(defaults: defaults), rpc = TestElectrum()
        let model = ServerSettingsModel(preferences: prefs, electrum: rpc)
        let count = prefs.backups.count
        model.add("custom.example:50002")
        XCTAssertEqual(prefs.backups.count, count)
        try await settle(model)
        XCTAssertEqual(prefs.backups.count, count + 1)
        XCTAssertEqual(model.probes.values.first?.maxBatch, 10000)
        let sizes = await rpc.batchSizes
        XCTAssertEqual(sizes, [3,100,1000,5000,10000])
        model.add("custom.example:50002"); XCTAssertNotNil(model.addError)
    }
    func testVersionOnlyServerCannotBeAdded() async throws {
        let prefs = NetworkPreferences(defaults: defaults)
        let model = ServerSettingsModel(preferences: prefs, electrum: SettingsRPC())
        model.add("nobatch.example:50002"); try await settle(model)
        XCTAssertEqual(model.addError, "This server doesn’t support batch requests")
        XCTAssertEqual(prefs.backups.count, ElectrumServer.defaults.count)
    }
    func testTCPRequiresExplicitOnionSelection() async throws {
        let prefs = NetworkPreferences(defaults: defaults), model = ServerSettingsModel(preferences: NetworkPreferences(defaults: defaults), electrum: TestElectrum())
        model.add("clearnet.example:50001", useTCP: true)
        XCTAssertEqual(model.addError, "Couldn’t connect")
        XCTAssertFalse(prefs.add(.init(host: "clearnet.example", port: 50001, useTCP: true)))
        model.add("test.onion:50001", useTCP: true); try await settle(model)
        XCTAssertEqual(model.preferences.backups.last?.server.useTCP, true)
    }
    func testFreshCachedProbeIsReused() async throws {
        let rpc = TestElectrum(), pool = ElectrumServerPool(transport: TestElectrum(), defaults: nil)
        let server = ElectrumServer(host: "fixture.invalid", port: 50002)
        let first = await pool.probe(server), second = await pool.probe(server)
        XCTAssertEqual(first,second)
        let unused = await rpc.calls; XCTAssertTrue(unused.isEmpty)
    }
    func testAboutRepositoryValidationAndBundledLicenses() {
        XCTAssertNil(AppConfiguration.sourceURL(nil)); XCTAssertNil(AppConfiguration.sourceURL("https://example.com/owner/repo"))
        XCTAssertEqual(AppConfiguration.sourceURL("https://github.com/owner/repo")?.host,"github.com")
        XCTAssertNil(AppConfiguration.sourceURL("https://token@github.com/owner/repo"))
        XCTAssertEqual(AppConfiguration.version,"1.0 (1)")
        for license in AppLicense.all { XCTAssertFalse(license.text.isEmpty,license.title) }
        XCTAssertTrue(SettingsTextPage.privacy.contains("Electrum servers see the addresses being checked"))
        XCTAssertEqual(AppLicense.all.count, 6)
    }
    func testTransportRejectsPlainHTTPOutsideOnionBeforeConnecting() async throws {
        do { _ = try await URLSessionTransport().send(URLRequest(url:URL(string:"http://example.com/api")!)); XCTFail() }
        catch { XCTAssertEqual(error as? ChainError,.invalidConfiguration) }
    }
}
