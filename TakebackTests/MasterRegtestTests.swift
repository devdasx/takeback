import XCTest
@testable import Takeback

/// Public disposable keys only. The RPC guard refuses every chain except regtest before any write.
@MainActor final class MasterRegtestTests: XCTestCase {
    static let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    static let server = ElectrumServer(host: "127.0.0.1", port: 52002)
    let config = try! ChainConfiguration(mempoolURL: URL(string: "https://127.0.0.1:1/api")!, electrumServers: [server])
    var service: ChainService { .init(configuration: config) }
    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TAKEBACK_MASTER_REGTEST"] == "1")
        continueAfterFailure = false
        guard case .object(let info) = try await rpc("getblockchaininfo"), info["chain"]?.string == "regtest" else { throw ChainError.invalidConfiguration }
        UserDefaults.standard.set(false, forKey: "showUSD")
        let probe = await ElectrumServerPool.shared.probe(Self.server)
        XCTAssertEqual(probe.state, .batch, probe.failure?.tried ?? "")
        if case .array(let pending) = try await rpc("getrawmempool"), !pending.isEmpty { try await mine() }
    }
    func testAllFourHDTypesAndSingleKeyImports() async throws {
        for type in AddressStandard.allCases { try await standard(Self.phrase, type: type) }
        try await standard("KwDiBf89QgGbjEhKnhXJuH7LrciVrZi3qYjgd9M7rFU73sVHnoWn", type: .bip84)
        try await standard("5HpHagT65TZzG1PH3CSu63k8DbpvD8s5ip4nEB3kEsreAnchuDf", type: .bip44)
        try await standard("S6c56bnXQiBjk9mqSYE7ykVQ7NzrRy", type: .bip44)
        try await standard("xprv9xgqHN7yz9MwCkxsBPN5qetuNdQSUttZNKw1dcYTV4mkaAFiBVGQziHs3NRSWMkCzvgjEe3n9xV8oYywvM8at9yRqyaZVz6TYYhX98VjsUk", type: .bip44)
    }
    func testNoSignalLinkedForeignInputsDustConfirmedRaceAndRejection() async throws {
        // Full-RBF replacement of a non-signaling transaction.
        try await standard(Self.phrase, type: .bip84, signal: false)
        let owner = try session(Self.phrase), foreign = try session(String(repeating: "0", count: 63) + "2")
        defer { owner.wipe(); foreign.wipe() }
        let worker = try work(owner), foreignWorker = try work(foreign)
        defer { worker.cancel(); foreignWorker.cancel() }
        let address = try worker.address(type: .bip84, index: 0), external = try foreignWorker.address(type: .bip84, index: 0)
        // A later recipient spend is discovered through the recipient's mempool history.
        let input = try await fund(address, sats: 200_000)
        let raw = try await payment([input], workers: [worker], destination: external, fee: 400)
        let original = try await broadcast(raw)
        let childInput = ReplacementInput(txid: original, index: 0, value: input.value - 400, key: external)
        let child = try await broadcast(payment([childInput], workers: [foreignWorker], destination: external, fee: 300))
        let linked = try await found(owner, id: original)
        XCTAssertEqual(linked.kind, .linked); XCTAssertEqual(linked.descendants, [child])
        try await cancel(owner, payment: linked)
        if case .array(let mempool) = try await rpc("getrawmempool") { XCTAssertFalse(mempool.contains(.string(child))) }
        // One foreign prevout blocks cancellation even though our input is discoverable.
        let ours = try await fund(address, sats: 100_000), theirs = try await fund(external, sats: 100_000)
        let mixed = try await broadcast(payment([ours, theirs], workers: [worker, foreignWorker], destination: external, fee: 500))
        let restricted = try await found(owner, id: mixed)
        XCTAssertEqual(restricted.kind, .notOwned); XCTAssertFalse(restricted.kind.canCancel)
        XCTAssertEqual(restricted.ownedInputSats, 100_000); XCTAssertEqual(restricted.otherInputSats, 100_000)
        try await mine()
        // Fee floor consumes a small input, while the original output itself remains non-dust.
        let tiny = try await fund(address, sats: 1500)
        let tinyID = try await broadcast(payment([tiny], workers: [worker], destination: external, fee: 600))
        let dustPayment = try await found(owner, id: tinyID)
        let dustPlan = try await CancellationEngine(configuration: config).prepare(payment: dustPayment, work: worker)
        XCTAssertThrowsError(try dustPlan.validate(rate: 100)) { XCTAssertEqual($0 as? CancelFailure, .notEnough) }
        try await mine()
        do { _ = try await CancellationEngine(configuration: config).prepare(payment: dustPayment, work: worker); XCTFail("Confirmed original must stop preparation") }
        catch { XCTAssertEqual(error as? CancelFailure, .alreadyConfirmed) }
        // A policy rejection is returned verbatim, never retried as if it were a transport error.
        let rejectedInput = try await fund(address, sats: 100_000)
        let id = try await broadcast(payment([rejectedInput], workers: [worker], destination: external, fee: 600))
        _ = try await found(owner, id: id)
        let underpriced = try await payment([rejectedInput], workers: [worker], destination: address, fee: 200)
        do { _ = try await service.broadcastDetailed(rawTransaction: underpriced); XCTFail("Expected fee rejection") }
        catch let failure as BroadcastFailure {
            XCTAssertTrue(failure.definitive); XCTAssertEqual(failure.source, Self.server.host)
            XCTAssertTrue(failure.message.lowercased().contains("fee"), failure.message)
            XCTAssertEqual(failure.attempts.count, 1)
        }
        try await mine()
    }
    func testSpeedUpPreservesRecipientAndCancelTwiceIsClassified() async throws {
        let owner = try session(Self.phrase), foreign = try session(String(repeating: "0", count: 63) + "2")
        defer { owner.wipe(); foreign.wipe() }
        let worker = try work(owner), other = try work(foreign)
        defer { worker.cancel(); other.cancel() }
        let address = try worker.address(type: .bip84, index: 0), external = try other.address(type: .bip84, index: 0)
        let input = try await fund(address, sats: 200_000)
        let outputs = [ReplacementOutput(value: 100_000, script: external.script), ReplacementOutput(value: 99_600, script: address.script)]
        let raw = try await payment([input], workers: [worker], destination: external, fee: 400, outputs: outputs)
        let original = try await broadcast(raw)
        let item = try await found(owner, id: original)
        let planner = CancellationEngine(configuration: config)
        let speedUp = try await planner.prepareSpeedUp(payment: item, work: worker)
        let speedWorker = try work(owner)
        let signed = try speedWorker.sign(speedUp, rate: Decimal(speedUp.minimumRate + 3))
        let parsed = try WireTransaction(signed.raw)
        XCTAssertEqual(parsed.outputs.count, 2)
        XCTAssertEqual(parsed.outputs[0].value, 100_000)
        XCTAssertEqual(parsed.outputs[0].scriptpubkey, external.script.hex)
        XCTAssertEqual(parsed.outputs[1].value, 100_000 - signed.fee)
        let boostedID = try await broadcast(signed.raw)
        XCTAssertEqual(boostedID, signed.txid)
        let boosted = try await found(owner, id: boostedID)
        XCTAssertEqual(boosted.kind, .normal)
        let cancelPlan = try await planner.prepare(payment: boosted, work: worker)
        let cancelWorker = try work(owner)
        let canceled = try cancelWorker.sign(cancelPlan, rate: Decimal(cancelPlan.minimumRate + 3))
        _ = try await broadcast(canceled.raw)
        owner.returnedToWelcome()
        XCTAssertEqual(owner.key.count, 0)
        let reentered = try session(Self.phrase)
        defer { reentered.wipe() }
        let twice = try await found(reentered, id: canceled.txid)
        XCTAssertEqual(twice.kind, .canceling)
        XCTAssertFalse(twice.kind.canCancel)
        do { _ = try await planner.prepare(payment: twice, work: worker); XCTFail("A second cancel must not be offered") }
        catch { XCTAssertEqual(error as? CancelFailure, .invalidReplacement) }
        try await mine()
        let confirmations = try await service.transactionStatus(txid: canceled.txid, scripts: [cancelPlan.destination.script])
        XCTAssertEqual(confirmations, 1)
    }
    func testSpeedUpAllTypesDustNoChangeAndLinkedAcceptedByCore() async throws {
        for type in AddressStandard.allCases {
            let owner = try session(Self.phrase), foreign = try session(String(repeating: "0", count: 63) + "2")
            defer { owner.wipe(); foreign.wipe() }
            let worker = try work(owner), other = try work(foreign)
            defer { worker.cancel(); other.cancel() }
            let address = try worker.address(type: type, index: 0), external = try other.address(type: .bip84, index: 0)
            let noChange = type == .bip84, dustChange = type == .bip49, linked = type == .bip44
            let input = try await fund(address, sats: noChange ? 100_400 : dustChange ? 101_400 : 200_000)
            let outputs: [ReplacementOutput] = noChange ? [.init(value: 100_000, script: external.script)] : [.init(value: 100_000, script: external.script), .init(value: input.value - 100_400, script: address.script)]
            let raw = try await payment([input], workers: [worker], destination: external, fee: 400, outputs: outputs)
            let original = try await broadcast(raw)
            var child: String?
            if linked {
                child = try await broadcast(payment([.init(txid: original, index: 0, value: 100_000, key: external)], workers: [other], destination: external, fee: 300))
            }
            let item = try await found(owner, id: original)
            let plan = try await CancellationEngine(configuration: config).prepareSpeedUp(payment: item, work: worker)
            let rate = Decimal(max(8, plan.minimumRate + 2))
            let signed = try work(owner).sign(plan, rate: rate), parsed = try WireTransaction(signed.raw)
            XCTAssertEqual(parsed.locktime, try WireTransaction(raw).locktime)
            XCTAssertEqual(parsed.inputs.map(\.txid), [input.txid]); XCTAssertEqual(parsed.inputs.map(\.sequence), [0xfffffffd])
            XCTAssertEqual(parsed.outputs[0].scriptpubkey, external.script.hex)
            XCTAssertEqual(parsed.outputs[0].value, noChange ? 100_000 - (signed.fee - 400) : 100_000)
            if dustChange { XCTAssertEqual(parsed.outputs.count, 1); XCTAssertEqual(signed.fee, 1400) }
            if linked { XCTAssertEqual(plan.descendants.map(\.txid), [try XCTUnwrap(child)]); XCTAssertGreaterThanOrEqual(signed.fee, 700 + Int64((parsed.weight + 3) / 4)) }
            guard case .array(let acceptance) = try await rpc("testmempoolaccept", [.array([.string(signed.raw.hex)])]), case .object(let accepted) = acceptance.first else { throw ChainError.invalidResponse }
            XCTAssertEqual(accepted["allowed"], .bool(true))
            let id = try await broadcast(signed.raw); XCTAssertEqual(id, signed.txid)
            guard case .array(let pool) = try await rpc("getrawmempool") else { throw ChainError.invalidResponse }
            XCTAssertTrue(pool.contains(.string(id))); XCTAssertFalse(pool.contains(.string(original)))
            if let child { XCTAssertFalse(pool.contains(.string(child))) }
            try await mine()
            let count = try await service.transactionStatus(txid: id, scripts: [external.script]); XCTAssertEqual(count, 1)
        }
    }
    func testCustomPathDiscoveryCancellationAndSamePathReturn() async throws {
        for (pathText, type, phrase) in [
            ("m/0'", AddressStandard.bip86, ""), ("m/0'/0'", .bip84, " TREZOR "),
            ("m/84'/0'/2147483646'", .bip49, ""), ("m/44'/0'/0'/0", .bip44, ""),
            ("m/1'/2/3'/4/5'/6", .bip86, "")
        ] {
            let owner = try session(Self.phrase), foreign = try session(String(repeating: "0", count: 63) + "2")
            defer { owner.wipe(); foreign.wipe() }
            try owner.passphrase.replace(with: phrase.utf8)
            let path = SearchPath(components: try DerivationPath.parse(pathText), scriptType: type)
            owner.searchSelection = .init(enabled: [], custom: [path])
            let pub = try SearchDerivationWork(key: owner.key, passphrase: owner.passphrase).prepare(plan: XCTUnwrap(detectKey(owner.key).searchPlan), selection: owner.searchSelection!)
            // Exercise change-chain signing too; fixed-chain paths have only their explicit chain.
            let address = try pub.address(path: path, branch: path.fixedChain ? 0 : 1, index: 3).signing
            let worker = try work(owner), other = try work(foreign)
            defer { worker.cancel(); other.cancel() }
            let external = try other.address(type: .bip84, index: 0)
            let input = try await fund(address, sats: 200_000)
            let original = try await broadcast(payment([input], workers: [worker], destination: external, fee: 400))
            let item = try await found(owner, id: original)
            XCTAssertTrue(item.signingAddresses.contains { $0.path == address.path && $0.script == address.script })
            let cancellation = try await CancellationEngine(configuration: config).prepare(payment: item, work: worker)
            XCTAssertEqual(cancellation.destination.searchPath?.components, path.components)
            XCTAssertEqual(Array(cancellation.destination.path.dropLast()), Array(path.childPath(branch: 0, index: 0).dropLast()))
            let signed = try worker.sign(cancellation, rate: Decimal(cancellation.minimumRate + 2))
            let broadcastID = try await service.broadcastDetailed(rawTransaction: signed.raw)
            XCTAssertEqual(broadcastID, signed.txid)
            try await mine()
            let utxos = try await service.client.unspent([ChainAddress(address: "", scriptPubKey: cancellation.destination.script).electrumScriptHash])[0]
            XCTAssertTrue(utxos.contains { $0.txid == signed.txid && $0.value == signed.amount })
        }
    }
    private func standard(_ key: String, type: AddressStandard, signal: Bool = true) async throws {
        let owner = try session(key), foreign = try session(String(repeating: "0", count: 63) + "2")
        defer { owner.wipe(); foreign.wipe() }
        let worker = try work(owner), other = try work(foreign)
        defer { worker.cancel(); other.cancel() }
        let address = try worker.address(type: type, index: 0), external = try other.address(type: .bip84, index: 0)
        let input = try await fund(address, sats: 200_000)
        let raw = try await payment([input], workers: [worker], destination: external, fee: 400, signal: signal)
        let id = try await broadcast(raw)
        let item = try await found(owner, id: id)
        XCTAssertEqual(item.kind, signal ? .normal : .notReplaceable)
        XCTAssertTrue(item.kind.canCancel)
        try await cancel(owner, payment: item)
        print("TAKEBACK REGTEST passed \(type.title) \(detectKey(owner.key).label(settled: true)) signal=\(signal)")
    }
    private func cancel(_ owner: SecretSession, payment: PendingPayment) async throws {
        let worker = try work(owner); defer { worker.cancel() }
        let plan = try await CancellationEngine(configuration: config).prepare(payment: payment, work: worker)
        let signed = try worker.sign(plan, rate: Decimal(plan.minimumRate + 2))
        let id = try await service.broadcastDetailed(rawTransaction: signed.raw)
        XCTAssertEqual(id, signed.txid)
        guard case .array(let pool) = try await rpc("getrawmempool") else { throw ChainError.invalidResponse }
        XCTAssertTrue(pool.contains(.string(id))); XCTAssertFalse(pool.contains(.string(payment.txid)))
        try await mine()
        let confirmations = try await service.transactionStatus(txid: id, scripts: [plan.destination.script])
        XCTAssertEqual(confirmations, 1)
        let utxos = try await service.client.unspent([ChainAddress(address: "", scriptPubKey: plan.destination.script).electrumScriptHash])[0]
        XCTAssertEqual(utxos.first { $0.txid == id }?.value, plan.total - signed.fee)
    }
    private func session(_ text: String) throws -> SecretSession {
        let session = SecretSession(); try session.key.replace(with: text.utf8)
        XCTAssertTrue(detectKey(session.key).isValid); return session
    }
    private func work(_ session: SecretSession) throws -> CancellationKeyWork { try .init(sessionKey: session.key, passphrase: session.passphrase) }
    private func fund(_ address: SigningAddress, sats: Int64) async throws -> ReplacementInput {
        guard case .object(let decoded) = try await rpc("decodescript", [.string(address.script.hex)]), let destination = decoded["address"]?.string else { throw ChainError.invalidResponse }
        let id = try unwrapped(try await rpc("sendtoaddress", [.string(destination), .number(Decimal(sats) / 100_000_000)]).string)
        try await mine()
        let tx = try await service.client.transactions([id])[0]
        let index = try XCTUnwrap(tx.outputs.firstIndex { $0.scriptpubkey == address.script.hex })
        return .init(txid: id, index: UInt32(index), value: sats, key: address)
    }
    private func payment(_ inputs: [ReplacementInput], workers: [CancellationKeyWork], destination: SigningAddress, fee: Int64, signal: Bool = true, outputs: [ReplacementOutput]? = nil) async throws -> Data {
        let pubs = try zip(inputs, workers).map { input, worker in try worker.withRoot { try CancellationKeyWork.publicKey(root: $0, address: input.key) } }
        var wire = ReplacementWire(inputs: inputs, scripts: inputs.map { _ in Data() }, witness: inputs.map { _ in [] }, amount: inputs.reduce(0) { $0 + $1.value } - fee, output: destination.script, height: UInt32(try await service.client.tip()))
        wire.sequence = signal ? 0xfffffffd : 0xffffffff
        wire.outputList = outputs
        var signatures: [Data] = []
        for i in inputs.indices {
            let digest = try wire.signatureHash(index: i, publicKey: pubs[i]), address = inputs[i].key
            let signature = try workers[i].withRoot { root -> Data in
                var bytes = [UInt8](repeating: 0, count: 72), count = 0
                let ok = root.withUnsafeBytes { takeback_sign($0.bindMemory(to: UInt8.self).baseAddress, address.path, address.path.count, address.type == .bip86 ? 1 : 0, [UInt8](digest), &bytes, &count) }
                guard ok == 1 else { throw CancelFailure.invalidReplacement }
                return Data(bytes.prefix(count)) + (address.type == .bip86 ? Data() : Data([1]))
            }
            signatures.append(signature)
        }
        let template = CancellationPlan(originalID: String(repeating: "0", count: 64), originalFee: 0, originalVSize: 1, inputs: inputs, destination: destination, descendants: [], height: wire.height)
        var built = template.transaction(amount: wire.amount, signatures: signatures, publicKeys: pubs)
        built.sequence = wire.sequence
        built.outputList = outputs
        return built.serialize(witness: true)
    }
    private func broadcast(_ raw: Data) async throws -> String { try await service.broadcastDetailed(rawTransaction: raw) }
    private func found(_ owner: SecretSession, id: String) async throws -> PendingPayment {
        let plan = try SearchDerivationWork(key: owner.key, passphrase: owner.passphrase).prepare(plan: XCTUnwrap(detectKey(owner.key).searchPlan), selection: owner.searchSelection ?? .init())
        for _ in 0..<40 {
            let outcome = try await FindingEngine(configuration: config).search(addresses: plan.initial(gap: 20), publicPlan: plan) { _ in }
            if case .found(let result) = outcome, let payment = result.payments.first(where: { $0.txid == id }) { return payment }
            try await Task.sleep(for: .milliseconds(250))
        }
        XCTFail("Pending payment not discovered"); throw ChainError.unavailable
    }
    private func mine() async throws {
        let address = try unwrapped(try await rpc("getnewaddress").string)
        _ = try await rpc("generatetoaddress", [.number(1), .string(address)])
        let height = try unwrapped(try await rpc("getblockcount").integer)
        for _ in 0..<100 {
            if (try? await service.client.tip()) == height { return }
            try await Task.sleep(for: .milliseconds(200))
        }
        XCTFail("Electrum tip did not synchronize")
    }
    private func unwrapped<T>(_ value: T?) throws -> T { try XCTUnwrap(value) }
    private func rpc(_ method: String, _ params: [JSONValue] = []) async throws -> JSONValue {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:52443/wallet/funder")!, timeoutInterval: 20)
        request.httpMethod = "POST"
        // Legacy local-only RPC credential retained to keep the existing regtest server and all its clients compatible; not app branding.
        request.setValue("Basic " + Data("unsend:regtest-only".utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(JSONValue.object(["jsonrpc": .string("1.0"), "id": .number(1), "method": .string(method), "params": .array(params)]))
        let (data, _) = try await URLSession.shared.data(for: request)
        guard case .object(let response) = try JSONDecoder().decode(JSONValue.self, from: data) else { throw ChainError.invalidResponse }
        if case .object(let error) = response["error"] { throw RPCFailure(code: error["code"]?.integer ?? 0, message: error["message"]?.string ?? "RPC error") }
        guard let result = response["result"] else { throw ChainError.invalidResponse }; return result
    }
}
