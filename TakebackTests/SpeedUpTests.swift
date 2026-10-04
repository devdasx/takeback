import XCTest
@testable import Takeback

@MainActor final class SpeedUpTests: XCTestCase {
    private func session() throws -> SecretSession {
        let session = SecretSession(); try session.key.replace(with: (String(repeating: "0", count: 63) + "1").utf8); return session
    }
    private func worker(_ session: SecretSession) throws -> CancellationKeyWork { try .init(sessionKey: session.key, passphrase: session.passphrase) }
    private func plan(_ session: SecretSession, type: AddressStandard = .bip84, fromAmount: Bool = false, change: Int64 = 50_000, linked: Int64 = 0) throws -> CancellationPlan {
        let work = try worker(session); defer { work.cancel() }
        let key = try XCTUnwrap(work.addresses().first { $0.type == type })
        let recipient = Data(hex: "001406afd46bcdfd22ef94ac122aa11f241244a37ecc")!
        let outputs: [ReplacementOutput] = fromAmount ? [.init(value: 99_600, script: recipient)] : [.init(value: 100_000, script: recipient), .init(value: change, script: key.script)]
        return .init(originalID: String(repeating: "a", count: 64), originalFee: 400, originalVSize: 140,
            inputs: [.init(txid: String(repeating: "b", count: 64), index: 0, value: outputs.reduce(400) { $0 + $1.value }, key: key)], destination: key,
            descendants: linked == 0 ? [] : [.init(txid: String(repeating: "c", count: 64), fee: linked, amount: 10000, recipient: nil, firstSeen: nil)], height: 123,
            speedUpOutputs: outputs, changeIndex: fromAmount ? 0 : 1, fromAmount: fromAmount, recipientIndexes: [0])
    }
    func testAllFourSignaturesPreserveInputsRecipientsLocktimeAndReduceChange() throws {
        for type in AddressStandard.allCases {
            let session = try session(); defer { session.wipe() }
            let p = try plan(session, type: type), signed = try worker(session).sign(p, rate: 24), tx = try WireTransaction(signed.raw)
            XCTAssertEqual(tx.inputs.map(\.txid), p.inputs.map(\.txid)); XCTAssertEqual(tx.inputs.map(\.sequence), [0xfffffffd])
            XCTAssertEqual(tx.locktime, 123); XCTAssertEqual(tx.outputs[0].value, 100_000)
            XCTAssertEqual(tx.outputs[0].scriptpubkey, p.speedUpOutputs![0].script.hex)
            XCTAssertEqual(tx.outputs[1].value, 50_000 - (signed.fee - 400)); XCTAssertEqual(signed.amount, 100_000)
            let verifier = try worker(session); defer { verifier.cancel() }
            try verifier.withRoot { try ReplacementCheck.validate(raw: signed.raw, plan: p, rate: 24, root: $0) }
        }
    }
    func testDustChangeIsDroppedAndAbsorbedWithoutTouchingRecipient() throws {
        let session = try session(); defer { session.wipe() }
        let p = try plan(session, change: 1000), signed = try worker(session).sign(p, rate: 8), tx = try WireTransaction(signed.raw)
        XCTAssertEqual(tx.outputs.count, 1); XCTAssertEqual(tx.outputs[0].value, 100_000)
        XCTAssertEqual(signed.fee, 1400); XCTAssertEqual(signed.amount, 100_000)
        XCTAssertEqual(p.total - tx.outputs.reduce(0) { $0 + $1.value }, signed.fee)
    }
    func testSingleRecipientReductionAndDustGuard() throws {
        let session = try session(); defer { session.wipe() }
        let p = try plan(session, fromAmount: true), signed = try worker(session).sign(p, rate: 24), tx = try WireTransaction(signed.raw)
        XCTAssertEqual(tx.outputs.count, 1); XCTAssertEqual(tx.outputs[0].value, 99_600 - (signed.fee - 400))
        XCTAssertEqual(signed.amount, tx.outputs[0].value); XCTAssertEqual(tx.outputs[0].scriptpubkey, p.speedUpOutputs![0].script.hex)
        XCTAssertThrowsError(try p.validate(rate: 1000)) { XCTAssertEqual($0 as? CancelFailure, .notEnough) }
    }
    func testMultipleRecipientsWithoutChangeCannotBeReduced() throws {
        let session = try session(); defer { session.wipe() }
        var p = try plan(session); p.fromAmount = true; p.changeIndex = -1
        XCTAssertThrowsError(try p.validate(rate: 24)) { XCTAssertEqual($0 as? CancelFailure, .notEnough) }
        p.speedUpOutputs = nil; p.fromAmount = false; p.changeIndex = 0
        XCTAssertNoThrow(try p.validate(rate: 24))
    }
    func testDescendantFloorPresetsAndExactCustomMinimum() throws {
        let session = try session(); defer { session.wipe() }
        let p = try plan(session, linked: 2400), minimum = p.minimumRate
        let policy = CancelFeePolicy(plan: p, fees: try .init(nextBlock: Decimal(minimum + 5), fast: Decimal(minimum), medium: Decimal(minimum - 1), minimum: 1))
        XCTAssertEqual(policy.options.map(\.speed), [.nextBlock]); XCTAssertEqual(policy.parse(String(minimum)), Decimal(minimum))
        XCTAssertNil(policy.parse(String(minimum - 1)))
        XCTAssertGreaterThanOrEqual(try p.validate(rate: Decimal(minimum)), p.replacedFee + Int64(p.virtualSize))
        XCTAssertThrowsError(try p.validate(rate: Decimal(minimum - 1)))
    }
    func testDustAbsorptionUsesSmallestValidIntegerFloor() throws {
        let session = try session(); defer { session.wipe() }
        let p = try plan(session, change: 600, linked: 400)
        XCTAssertEqual(p.minimumRate, 4)
        XCTAssertThrowsError(try p.validate(rate: 3)); XCTAssertEqual(try p.validate(rate: 4), 1000)
        XCTAssertNoThrow(try worker(session).sign(p, rate: 4))
    }
    func testConfiguredMempoolPreferenceIsUsed() {
        let name = "SpeedUpTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = NetworkPreferences(defaults: defaults)
        let url = URL(string: "https://custom.invalid/api")!
        preferences.saveOwn(url); XCTAssertEqual(preferences.configuration.mempoolURL, url)
        preferences.useDefault(); XCTAssertEqual(preferences.configuration.mempoolURL, NetworkPreferences.defaultURL)
    }
    func testSelfCheckRejectsRecipientAmountInputAndFeeTampering() throws {
        let session = try session(); defer { session.wipe() }
        let p = try plan(session), signed = try worker(session).sign(p, rate: 24), verifier = try worker(session)
        defer { verifier.cancel() }
        try verifier.withRoot { root in
            var wrongRecipient = p; var outputs = p.speedUpOutputs!; outputs[0] = .init(value: outputs[0].value, script: p.destination.script); wrongRecipient.speedUpOutputs = outputs
            var wrongAmount = p; outputs = p.speedUpOutputs!; outputs[0] = .init(value: outputs[0].value + 1, script: outputs[0].script); wrongAmount.speedUpOutputs = outputs
            for wrong in [wrongRecipient, wrongAmount] { XCTAssertThrowsError(try ReplacementCheck.validate(raw: signed.raw, plan: wrong, rate: 24, root: root)) }
            var missing = signed.raw; missing[6] = 0
            XCTAssertThrowsError(try ReplacementCheck.validate(raw: missing, plan: p, rate: 24, root: root))
            XCTAssertThrowsError(try ReplacementCheck.validate(raw: signed.raw, plan: p, rate: 25, root: root))
        }
    }
    func testModeDefaultRatePreservationAndExtraVersusTotal() async throws {
        UserDefaults.standard.set(true, forKey: "showUSD")
        let session = try session(); defer { session.wipe() }
        let model = CancelFixtures.model(session: session), rate = try XCTUnwrap(model.choice?.rate)
        XCTAssertEqual(model.mode, .cancel)
        let cancelFee = model.feeText(rate: rate)
        XCTAssertFalse(cancelFee.hasPrefix("+"))
        model.cachedPlans[.speedUp] = try plan(session)
        await model.selectMode(.speedUp)
        XCTAssertEqual(model.choice?.rate, rate); XCTAssertTrue(model.feeText(rate: rate).hasPrefix("+"))
        XCTAssertEqual(model.feeText(rate: rate), "+" + PaymentText.fiat(try model.plan!.fee(rate: rate) - model.plan!.originalFee, rate: model.payment.usdRate))
        await model.selectMode(.cancel)
        XCTAssertEqual(model.choice?.rate, rate); XCTAssertEqual(model.feeText(rate: rate), cancelFee)
    }
    func testLiveSpeedUpCopyChangesAndFinalSelfCheckErrorWipes() async throws {
        let store = SpeedUpPreviewStore(state: 8)
        let view = CancellationResultView(router: store.router, model: store.result)
        XCTAssertEqual(view.title, "Sped up"); XCTAssertEqual(view.subtitle, "Now arriving in ~10 min.")
        store.result.received(confirmations: 1)
        XCTAssertEqual(view.title, "Payment confirmed"); XCTAssertTrue(view.subtitle.contains("reached"))
        store.result.received(confirmations: 0); XCTAssertEqual(store.result.state, .canceled(1))
        let seeded = try session(), model = SpeedUpFixtures.action(session: seeded, state: 1)
        let problem = CancellationProblem.preflight(.invalidReplacement, model: model)
        let result = CancellationResultModel(problem: problem, session: seeded, service: try TestElectrum().service())
        result.start(); try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(seeded.key.count, 0); XCTAssertEqual(problem.localAlert, "Something doesn’t add up")
    }
    func testBackgroundExpiryAtSixtySecondsAndFinalErrorWipe() async throws {
        let session = try session(); try session.passphrase.replace(with: " test ".utf8)
        session.enteredBackground(now: 100, requestExecutionTime: false); session.becameActive(now: 159)
        XCTAssertGreaterThan(session.key.count, 0)
        session.enteredBackground(now: 200, requestExecutionTime: false); session.becameActive(now: 261)
        XCTAssertEqual(session.key.count, 0); XCTAssertEqual(session.passphrase.count, 0)
        let seeded = try self.session(), model = CancelFixtures.model(session: seeded)
        let problem = CancellationProblem.preflight(.alreadyConfirmed, model: model)
        let result = CancellationResultModel(problem: problem, session: seeded, service: try TestElectrum().service())
        result.start(); try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(seeded.key.count, 0)
    }
}

actor SpeedHTTP: HTTPTransport {
    var replies: [HTTPResponse]; var requests: [URLRequest] = []
    init(_ replies: [HTTPResponse]) { self.replies = replies }
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request); guard !replies.isEmpty else { throw ChainError.timeout }; return replies.removeFirst()
    }
}
@MainActor final class SpeedUpNetworkTests: XCTestCase {
    private let raw = ResultFixtures.raw
    private func response(_ status: Int, _ body: String) -> HTTPResponse { .init(status: status, data: Data(body.utf8)) }
    private func service(_ http: SpeedHTTP, _ rpc: TestElectrum) throws -> ChainService {
        .init(configuration: try ChainConfiguration(mempoolURL: URL(string: "https://custom.invalid/api")!, electrumServers: [.init(host: "electrum.invalid", port: 50002)]), http: http, electrum: rpc)
    }
    func testPrimaryAndFallbackTimeoutsAndExactID() async throws {
        let id = try TransactionID.compute(raw: raw), rpc = TestElectrum(), http = SpeedHTTP([response(200, try TransactionID.compute(raw: raw))])
        let primary = try await service(http, rpc).broadcastDetailed(rawTransaction: raw); XCTAssertEqual(primary, id)
        let requests = await http.requests; XCTAssertEqual(requests[0].url?.absoluteString, "https://custom.invalid/api/tx"); XCTAssertEqual(requests[0].timeoutInterval, 10)
        let calls = await rpc.calls; XCTAssertTrue(calls.isEmpty)
        let down = SpeedHTTP([response(503, "maintenance")]); await rpc.broadcasts([.success(.string(id))])
        let fallback = try await service(down, rpc).broadcastDetailed(rawTransaction: raw); XCTAssertEqual(fallback, id)
        let fallbackCalls = await rpc.calls; XCTAssertEqual(fallbackCalls.last?.timeout, 8)
    }
    func testFourXXNeverFallsBackAndPreservesReason() async throws {
        let rpc = TestElectrum(), http = SpeedHTTP([response(400, "insufficient fee")])
        do { _ = try await service(http, rpc).broadcastDetailed(rawTransaction: raw); XCTFail() }
        catch let error as BroadcastFailure { XCTAssertEqual(error.message, "insufficient fee"); XCTAssertTrue(error.definitive) }
        let calls = await rpc.calls; XCTAssertTrue(calls.isEmpty)
    }
    func testKnownSuccessAndMismatchedIDNeverRetries() async throws {
        let rpc = TestElectrum(), known = SpeedHTTP([response(400, "txn-already-known")])
        let id = try await service(known, rpc).broadcastDetailed(rawTransaction: raw); XCTAssertEqual(id, try TransactionID.compute(raw: raw))
        let wrong = SpeedHTTP([response(200, String(repeating: "b", count: 64))])
        do { _ = try await service(wrong, rpc).broadcastDetailed(rawTransaction: raw); XCTFail() }
        catch let error as BroadcastFailure { XCTAssertEqual(error.cause, .txidMismatch) }
        let calls = await rpc.calls; XCTAssertTrue(calls.isEmpty)
    }
    func testOriginalConfirmedAtBroadcastShowsSpeedSpecificErrorAndWipes() async throws {
        let store = SpeedUpPreviewStore(state: 8)
        try store.session.key.replace(with: "public fixture".utf8)
        let http = SpeedHTTP([response(400, "bad-txns-inputs-missingorspent"), response(200, "{\"confirmed\":true,\"block_height\":123}"), response(200, "{\"confirmed\":true,\"block_height\":123}")])
        let model = CancellationResultModel(request: store.result.request, session: store.session, service: try service(http, TestElectrum()), minimumDuration: .zero)
        model.start()
        for _ in 0..<100 where model.state == .broadcasting { try await Task.sleep(for: .milliseconds(10)) }
        guard case .error(let problem) = model.state else { return XCTFail() }
        XCTAssertEqual(problem.kind, .alreadyConfirmed); XCTAssertEqual(problem.blockHeight, 123); XCTAssertEqual(store.session.key.count, 0)
        let view = CancellationResultView(router: store.router, model: model)
        XCTAssertEqual(view.subtitle, "The payment confirmed before the faster version reached the network, so there was nothing to speed up. No extra fee was paid.")
    }
    func testElectrumFallbackTriesConfiguredOrderBeyondThreeServers() async throws {
        let rpc = TestElectrum(), id = try TransactionID.compute(raw: raw)
        await rpc.broadcasts([.failure(.timeout), .failure(.network), .failure(.timeout), .success(.string(id))])
        let servers = (1...4).map { ElectrumServer(host: "server\($0).invalid", port: 50002) }
        let chain = ChainService(configuration: try .init(electrumServers: servers), http: NoHTTP(), electrum: rpc)
        let result = try await chain.broadcastDetailed(rawTransaction: raw); XCTAssertEqual(result, id)
        let calls = await rpc.calls; XCTAssertEqual(calls.map(\.host), servers.map(\.host))
    }
    func testDroppedChangeRejectionIsNotMisclassifiedAsDust() async throws {
        let store = SpeedUpPreviewStore(state: 8)
        let original = store.action.plan!
        var plan = original
        plan.speedUpOutputs = [.init(value: original.total - 1400, script: original.speedUpOutputs![0].script), .init(value: 520, script: original.destination.script)]
        store.action.plan = plan; store.action.choice = .init(speed: .custom, rate: 9)
        let context = CancellationContext(model: store.action)
        XCTAssertEqual(context.left, 0)
        let request = CancellationRequest(signed: store.result.request!.signed, context: context)
        let rpc = TestElectrum(); await rpc.reject("insufficient fee")
        let model = CancellationResultModel(request: request, session: store.session, service: try rpc.service(), minimumDuration: .zero)
        model.start()
        for _ in 0..<100 where model.state == .broadcasting { try await Task.sleep(for: .milliseconds(10)) }
        guard case .error(let problem) = model.state else { return XCTFail() }
        XCTAssertEqual(problem.kind, .rejected)
    }
    func testRecommendedFeesAndPendingConfirmedRESTStatus() async throws {
        let rpc = TestElectrum(), http = SpeedHTTP([response(200, "{\"fastestFee\":52,\"halfHourFee\":24,\"hourFee\":14,\"minimumFee\":1}"),response(200,"{\"confirmed\":false}"),response(200,"{\"confirmed\":true,\"block_height\":123}")])
        let service = try service(http, rpc), id = try TransactionID.compute(raw: raw)
        let fees = try await service.fees(); XCTAssertEqual(fees, try .init(nextBlock: 52, fast: 24, medium: 14, minimum: 1))
        let pending = try await service.transactionStatus(txid: id), confirmed = try await service.transactionStatus(txid: id)
        XCTAssertEqual(pending, 0); XCTAssertEqual(confirmed, 1)
        let calls = await rpc.calls; XCTAssertTrue(calls.isEmpty)
    }
}
