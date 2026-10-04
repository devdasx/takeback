import XCTest
@testable import Takeback

@MainActor final class FindingTests: XCTestCase {
    private let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private func derive(_ input: String, gap: Int = 20, passphrase: String = "") throws -> [SearchAddress] {
        let key = SecureBytes(), phrase = SecureBytes()
        try key.replace(with: input.utf8); try phrase.replace(with: passphrase.utf8)
        defer { key.wipe(); phrase.wipe() }
        let work = try SearchDerivationWork(key: key, passphrase: phrase)
        let result = try work.derive(plan: XCTUnwrap(detectKey(key).searchPlan), gap: gap)
        XCTAssertTrue(work.isCleared)
        return result
    }
    func testBIP86BIP84BIP49BIP44VectorsAndBothBranches() throws {
        let addresses = try derive(mnemonic)
        let expected: [AddressStandard: String] = [
            .bip86: "bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr",
            .bip84: "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu",
            .bip49: "37VucYSaXLCAsxYyAPfbSi9eh4iEcbShgf",
            .bip44: "1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA"]
        XCTAssertEqual(addresses.count, 160)
        for type in AddressStandard.allCases {
            XCTAssertEqual(addresses.first { $0.type == type }?.chain.address, expected[type])
            for branch: UInt32 in [0,1] {
                XCTAssertEqual(addresses.filter { $0.type == type && $0.branch == branch }.map(\.index), Array(UInt32(0)..<20))
            }
        }

    }
    func testHundredGapAndPassphraseChangesWalletWithoutTrimming() throws {
        let deep = try derive(mnemonic, gap: 100)
        XCTAssertEqual(deep.count, 800)
        XCTAssertEqual(Set(deep.map(\.chain.address)).count, 800)
        for type in AddressStandard.allCases {
            XCTAssertEqual(deep.filter { $0.type == type && $0.branch == 1 }.last?.index, 99)
        }
        let plain = try derive(mnemonic, passphrase: "pass")
        let spaces = try derive(mnemonic, passphrase: " pass ")
        XCTAssertNotEqual(plain[0].chain.address, spaces[0].chain.address)
        XCTAssertEqual(try derive(mnemonic, passphrase: "é")[0].chain.address,
                       try derive(mnemonic, passphrase: "e\u{301}")[0].chain.address)
    }
    func testSingleKeysAndMasterAndAccountImports() throws {
        let hex = String(repeating: "0", count: 63) + "1"
        let singles = try derive(hex)
        XCTAssertEqual(singles.count, 4)
        XCTAssertEqual(singles.last?.chain.address, "1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH")
        let uncompressed = try derive("5HpHagT65TZzG1PH3CSu63k8DbpvD8s5ip4nEB3kEsreAnchuDf")
        XCTAssertEqual(uncompressed.count, 1)
        XCTAssertEqual(uncompressed[0].chain.address, "1EHNa6Q4Jz2uvNExL497mE43ikXhwF6kZm")
        let master = try derive("xprv9s21ZrQH143K3GJpoapnV8SFfukcVBSfeCficPSGfubmSFDxo1kuHnLisriDvSnRRuL2Qrg5ggqHKNVpxR86QEC8w35uxmGoggxtQTPvfUu")
        XCTAssertEqual(master.map(\.chain.address), try derive(mnemonic).map(\.chain.address))
        let account = try derive("xprv9xgqHN7yz9MwCkxsBPN5qetuNdQSUttZNKw1dcYTV4mkaAFiBVGQziHs3NRSWMkCzvgjEe3n9xV8oYywvM8at9yRqyaZVz6TYYhX98VjsUk")
        XCTAssertEqual(account.count, 40)
        XCTAssertTrue(account.allSatisfy { $0.type == .bip44 })
    }
    func testOfflineMakesNoRequests() async throws {
        let http = FindingHTTP(), rpc = FindingRPC()
        let engine = FindingEngine(configuration: try ChainConfiguration(), http: http, electrum: rpc, connectivity: FixedConnectivity(online: false))
        let outcome = try await engine.search(addresses: fixtures()) { _ in }
        guard case .offline = outcome else { return XCTFail("Expected offline") }
        let rpcCalls = await rpc.calls
        XCTAssertEqual(rpcCalls, 0)
    }





    func testReasonListsAndRoutingAndWipe() throws {
        for phrase in [true, false] {
            let session = SecretSession()
            try session.key.replace(with: (phrase ? mnemonic : String(repeating: "0", count: 63) + "1").utf8)
            if phrase { try session.passphrase.replace(with: "fixture".utf8) }
            let plan = try XCTUnwrap(detectKey(session.key).searchPlan)
            let model = FindingModel(plan: plan, session: session)
            XCTAssertEqual(model.reasons.count, phrase ? 4 : 2)
            XCTAssertEqual(model.reasons.first?.0, phrase ? "Check the passphrase" : "It may have already confirmed")
            let router = WelcomeRouter(session: session); router.cancelTransaction(); router.findPendingPayments(plan)
            router.openServerSettings(); XCTAssertEqual(router.path.last, .serverSettings)
            router.backToKey(); XCTAssertEqual(router.path, [.enterKey]); XCTAssertGreaterThan(session.key.count, 0)
            session.wipe(); XCTAssertEqual(session.key.count, 0); model.release()
        }
    }
    func testElectrumResolvesInputsAndConfirmedHeaderWithoutInventingAge() async throws {
        for confirmed in [false, true] {
            let rpc = try WireFixtureRPC(confirmed: confirmed)
            let engine = FindingEngine(configuration: try ChainConfiguration(), http: FindingHTTP(fail: true), electrum: rpc, connectivity: FixedConnectivity(online: true))
            let outcome = try await engine.search(addresses: fixtures(), now: Date(timeIntervalSince1970: 100_000)) { _ in }
            if confirmed {
                guard case .confirmed(let date) = outcome else { return XCTFail("Expected confirmed Electrum result") }
                XCTAssertEqual(date, Date(timeIntervalSince1970: 92_800))
            } else {
                guard case .found(let result) = outcome else { return XCTFail("Expected Electrum payment") }
                XCTAssertEqual(result.payments.count, 1)
                XCTAssertEqual(result.payments[0].ownedInputCount, 1)
                XCTAssertEqual(result.payments[0].feeSats, 100)
                XCTAssertNil(result.payments[0].firstSeen)
                XCTAssertEqual(result.payments[0].descendants, [])
                XCTAssertEqual(FindingModel.foundBody(result), "From your Taproot address.")
                let router = WelcomeRouter(session: SecretSession())
                router.showPayments(result.payments)
                XCTAssertEqual(router.path.last, .review(result.payments[0]))
                router.showPayments(result.payments + result.payments)
                XCTAssertEqual(router.path.last, .payments(result.payments + result.payments))
            }
        }
    }
    func testCancelledDerivationWipesCopiesAndRejectsWork() throws {
        let key = SecureBytes(), pass = SecureBytes()
        try key.replace(with: mnemonic.utf8); try pass.replace(with: "synthetic".utf8)
        let plan = try XCTUnwrap(detectKey(key).searchPlan)
        let work = try SearchDerivationWork(key: key, passphrase: pass)
        work.cancel(); XCTAssertTrue(work.isCleared)
        XCTAssertThrowsError(try work.derive(plan: plan, gap: 20))
        XCTAssertGreaterThan(key.count, 0)
    }


    func testPublicGapScannerBatchesAllBranchesAndExpandsAfterUse() async throws {
        let rpc = TestElectrum(), key = SecureBytes(), pass = SecureBytes()
        try key.replace(with: mnemonic.utf8); defer { key.wipe(); pass.wipe() }
        let plan = try SearchDerivationWork(key:key,passphrase:pass).prepare(plan:XCTUnwrap(detectKey(key).searchPlan))
        let used = try plan.address(type:.bip84,branch:0,index:19)
        await rpc.set("blockchain.scripthash.get_history:" + used.chain.electrumScriptHash, .array([.object(["tx_hash":.string(String(repeating:"a",count:64)),"height":.number(1)])]))
        let result = try await GapScanner.scan(plan:plan,gap:20,client:rpc.service().client)
        XCTAssertEqual(result.addresses.count,180)
        XCTAssertEqual(result.addresses.filter { $0.type == .bip84 && $0.branch == 0 }.last?.index,39)
        let sizes = await rpc.batchSizes; XCTAssertEqual(sizes,[160,20,180])
        let deep = try await GapScanner.scan(plan:plan,gap:100,client:rpc.service().client)
        XCTAssertEqual(deep.addresses.count,800)
    }
    func testStopCancelsBatchesAndPreservesSession() async throws {
        let session = SecretSession(); try session.key.replace(with:(String(repeating:"0",count:63)+"1").utf8)
        let rpc = TestElectrum(); await rpc.pause(.seconds(30))
        let config = try ChainConfiguration(electrumServers:[.init(host:"fixture.invalid",port:50002)])
        let model = FindingModel(plan:try XCTUnwrap(detectKey(session.key).searchPlan),session:session,engine:FindingEngine(configuration:config,http:NoHTTP(),electrum:rpc,connectivity:FixedConnectivity(online:true)))
        model.start()
        for _ in 0..<100 { if await rpc.active > 0 { break }; try await Task.sleep(for:.milliseconds(10)) }
        model.stop(); try await Task.sleep(for:.milliseconds(100))
        XCTAssertEqual(session.key.count,64)
        let active = await rpc.active; XCTAssertEqual(active,0)
        guard case .searching = model.outcome else { return XCTFail("Stopped search changed outcome") }
        model.release(); session.wipe()
    }
    func testAllServersDownShowsOnlyRealElectrumAttempts() async throws {
        let config = try ChainConfiguration(electrumServers:[.init(host:"fixture.invalid",port:50002)])
        let outcome = try await FindingEngine(configuration:config,http:NoHTTP(),electrum:FindingRPC(fail:true),connectivity:FixedConnectivity(online:true)).search(addresses:fixtures()) { _ in }
        guard case .serversDown(let attempts) = outcome else { return XCTFail() }
        XCTAssertEqual(attempts.map(\.server),["fixture.invalid"])
        XCTAssertEqual(attempts[0].detail,"No response after 8 seconds")
    }
    private func fixtures() -> [SearchAddress] {
        AddressStandard.allCases.enumerated().map { i, type in
            .init(type: type, branch: 0, index: 0, chain: .init(address: "address\(i)", scriptPubKey: Data([UInt8(0x51+i)])))
        }
    }
}
private struct FixedConnectivity: SearchConnectivity {
    let online: Bool
    func isOnline() async throws -> Bool { online }
}
private actor FindingRPC: ElectrumTransport {
    var calls = 0
    let fail: Bool
    init(fail: Bool = false) { self.fail = fail }
    func call(server: ElectrumServer, method: String, params: [JSONValue], timeout: TimeInterval) async throws -> JSONValue {
        calls += 1
        if fail { throw ChainError.timeout }
        return .array([])
    }
}
private struct FindingHTTP: HTTPTransport {
    var fail = false
    func send(_ request: URLRequest) async throws -> HTTPResponse { throw ChainError.unavailable }
}
private actor WireFixtureRPC: ElectrumTransport {
    let confirmed: Bool
    let parent: Data, child: Data, parentID: String, childID: String
    let hash = ChainAddress(address: "", scriptPubKey: Data([0x51])).electrumScriptHash
    init(confirmed: Bool) throws {
        self.confirmed = confirmed
        func transaction(parent: String, value: UInt64, script: UInt8) -> Data {
            var data = Data([1,0,0,0,1])
            data.append(contentsOf: Data(hex: parent)!.reversed())
            data.append(contentsOf: [0,0,0,0,0,0xfd,0xff,0xff,0xff,1])
            for shift in 0..<8 { data.append(UInt8(truncatingIfNeeded: value >> (8*shift))) }
            data.append(contentsOf: [1,script,0,0,0,0]); return data
        }
        parent = transaction(parent: String(repeating: "0", count: 64), value: 1000, script: 0x51)
        parentID = try TransactionID.compute(raw: parent)
        child = transaction(parent: parentID, value: 900, script: 0x60)
        childID = try TransactionID.compute(raw: child)
    }
    func call(server: ElectrumServer, method: String, params: [JSONValue], timeout: TimeInterval) async throws -> JSONValue {
        switch method {
        case "server.version": return .array([.string("fixture"),.string("1.4")])
        case "server.ping": return .null
        case "blockchain.headers.subscribe": return .object(["height":.number(100)])
        case "blockchain.scripthash.listunspent": return .array([])
        case "blockchain.scripthash.get_mempool", "blockchain.scripthash.get_history":
            let wanted = "blockchain.scripthash.get_history"
            if params.first?.string == hash && method == wanted {
                return .array([.object(["tx_hash": .string(childID), "height": .number(confirmed ? 100 : 0)])])
            }
            return .array([])
        case "blockchain.transaction.get":
            return .string(params.first?.string == childID ? child.hex : parent.hex)
        case "blockchain.block.header":
            var header = Data(repeating: 0, count: 80)
            for i in 0..<4 { header[68+i] = UInt8(truncatingIfNeeded: 92_800 >> (8*i)) }
            return .string(header.hex)
        default: throw ChainError.invalidResponse
        }
    }
    func batch(server: ElectrumServer, calls: [RPCCall], timeout: TimeInterval) async throws -> [Result<JSONValue, RPCFailure>] {
        var result: [Result<JSONValue, RPCFailure>] = []
        for item in calls { result.append(.success(try await call(server:server,method:item.method,params:item.params,timeout:timeout))) }
        return result
    }

}
