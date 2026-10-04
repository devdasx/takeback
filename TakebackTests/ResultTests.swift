import XCTest
@testable import Takeback

@MainActor final class ResultTests: XCTestCase {
    private func seeded() throws -> SecretSession {
        let session = SecretSession(); try session.key.replace(with: "public-test-key".utf8); try session.passphrase.replace(with: " test ".utf8); return session
    }
    private func settle(_ model: CancellationResultModel) async throws {
        for _ in 0..<300 { if model.state != .broadcasting { return }; try await Task.sleep(for: .milliseconds(10)) }
        XCTFail("Result did not settle")
    }
    func testVerifiedBroadcastWipesBeforeAnimationAndOnlyOnce() async throws {
        let session = try seeded(), request = ResultFixtures.request(session:session), rpc = TestElectrum()
        await rpc.broadcasts([.success(.string(request.signed.txid))])
        var feedback = 0
        let model = CancellationResultModel(request:request,session:session,service:try rpc.service(),success:{ feedback += 1 })
        model.start(); model.start()
        for _ in 0..<100 where session.key.count > 0 { try await Task.sleep(for:.milliseconds(5)) }
        XCTAssertEqual(session.key.count,0); XCTAssertEqual(session.passphrase.count,0); XCTAssertEqual(model.state,.broadcasting)
        try await settle(model); XCTAssertEqual(model.state,.canceled(0)); XCTAssertEqual(feedback,1)
        let calls = await rpc.calls; XCTAssertEqual(calls.count,1)
    }
    func testClearRejectionPreservesKeyAndRealMessage() async throws {
        let session = try seeded(), request = ResultFixtures.request(session:session), rpc = TestElectrum()
        await rpc.reject("insufficient fee: replacement fee too low")
        let model = CancellationResultModel(request:request,session:session,service:try rpc.service(),minimumDuration:.zero)
        model.start(); try await settle(model)
        guard case .error(let problem) = model.state else { return XCTFail() }
        XCTAssertEqual(problem.kind,.rejected); XCTAssertTrue(problem.definitive)
        XCTAssertTrue(problem.details.contains("replacement fee too low")); XCTAssertEqual(problem.source,"first.invalid")
        XCTAssertGreaterThan(session.key.count,0); XCTAssertGreaterThan(session.passphrase.count,0)
        let calls = await rpc.calls; XCTAssertEqual(calls.count,1); session.wipe()
    }
    func testWrongIDWipesFinalErrorAndNeverRetries() async throws {
        let session = try seeded(), request = ResultFixtures.request(session:session), rpc = TestElectrum()
        await rpc.broadcasts([.success(.string(String(repeating:"b",count:64)))])
        let model = CancellationResultModel(request:request,session:session,service:try rpc.service(),minimumDuration:.zero)
        model.start(); try await settle(model)
        guard case .error(let problem) = model.state else { return XCTFail() }
        XCTAssertTrue(problem.details.contains("did not match")); XCTAssertEqual(session.key.count,0); XCTAssertEqual(problem.localAlert,"Couldn’t confirm the send")
        let calls = await rpc.calls; XCTAssertEqual(calls.count,1); session.wipe()
    }
    func testPollingOnlyVisibleAndFirstConfirmationFeedbackOnce() async throws {
        let session = try seeded(), request = ResultFixtures.request(session:session), rpc = TestElectrum()
        await rpc.broadcasts([.success(.string(request.signed.txid))])
        var feedback = 0
        let model = CancellationResultModel(request:request,session:session,service:try rpc.service(),minimumDuration:.zero,pollInterval:.milliseconds(30),success:{ feedback += 1 })
        model.start(); try await settle(model)
        let hidden = await rpc.calls; XCTAssertEqual(hidden.count,1)
        await rpc.set("blockchain.scripthash.get_history",.array([.object(["tx_hash":.string(request.signed.txid),"height":.number(900000)])]))
        model.setVisible(true)
        for _ in 0..<100 where model.state != .canceled(1) { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertEqual(model.state,.canceled(1)); XCTAssertEqual(feedback,2)
        model.received(confirmations:2); model.received(confirmations:0); model.received(confirmations:1); XCTAssertEqual(feedback,2)
        model.setVisible(false); try await Task.sleep(for:.milliseconds(20))
        let stopped = await rpc.calls.count; try await Task.sleep(for:.milliseconds(100)); let later = await rpc.calls.count
        XCTAssertEqual(stopped,later)
    }
    func testOriginalWinningDuringTrackingRoutesConfirmedError() async throws {
        let session = try seeded(), request = ResultFixtures.request(session:session), rpc = TestElectrum()
        await rpc.broadcasts([.success(.string(request.signed.txid))])
        let model = CancellationResultModel(request:request,session:session,service:try rpc.service(),minimumDuration:.zero,pollInterval:.milliseconds(30))
        model.start(); try await settle(model)
        await rpc.set("blockchain.scripthash.get_history",.array([.object(["tx_hash":.string(request.context.payment.txid),"height":.number(899999)])]))
        model.setVisible(true)
        for _ in 0..<100 { if case .error = model.state { break }; try await Task.sleep(for:.milliseconds(10)) }
        guard case .error(let problem) = model.state else { return XCTFail() }
        XCTAssertEqual(problem.kind,.alreadyConfirmed); XCTAssertEqual(problem.confirmations,2)
        model.setVisible(false)
    }
    func testDustMapsToNotEnough() async throws {
        let session = try seeded(), request = ResultFixtures.request(state:4,session:session), rpc = TestElectrum()
        await rpc.reject("dust")
        let model = CancellationResultModel(request:request,session:session,service:try rpc.service(),minimumDuration:.zero)
        model.start(); try await settle(model)
        guard case .error(let problem) = model.state else { return XCTFail() }
        XCTAssertEqual(problem.kind,.notEnough); XCTAssertEqual(session.key.count,0); session.wipe()
    }
    func testReceiptSurvivesWipeAndRetryRoutesFeeOrEntry() throws {
        let session = try seeded(), request = ResultFixtures.request(session: session)
        let router = WelcomeRouter(session: session)
        router.path = [.enterKey, .review(request.context.payment), .canceling(request)]
        router.retryCancellation(request.context.payment, showFee: true)
        XCTAssertEqual(router.path.last, .review(request.context.payment)); XCTAssertEqual(router.feeRequest, request.context.payment.txid)
        router.path.append(.canceling(request)); session.completedCancellation(); router.backToKey()
        XCTAssertEqual(router.path.last, .canceling(request))
        router.retryCancellation(request.context.payment, showFee: true); XCTAssertEqual(router.path, [.enterKey])
    }
}
