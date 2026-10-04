import XCTest
import LocalAuthentication
@testable import Takeback

@MainActor final class CancelTests: XCTestCase {
    private func session() throws -> SecretSession {
        let session = SecretSession(); try session.key.replace(with: (String(repeating: "0", count: 63) + "1").utf8); return session
    }
    private func work(_ session: SecretSession) throws -> CancellationKeyWork { try .init(sessionKey: session.key, passphrase: session.passphrase) }
    private func plan(type: AddressStandard = .bip84, value: Int64 = 1_000_000, fee: Int64 = 100, oldSize: Int = 100, linked: Int64 = 0) throws -> CancellationPlan {
        let session = try session(), worker = try work(session); defer { worker.cancel(); session.wipe() }
        let address = try XCTUnwrap(worker.addresses().first { $0.type == type })
        return .init(originalID: String(repeating: "a", count: 64), originalFee: fee, originalVSize: oldSize,
                     inputs: [.init(txid: String(repeating: "b", count: 64), index: 1, value: value, key: address)], destination: address,
                     descendants: linked > 0 ? [.init(txid: String(repeating: "c", count: 64), fee: linked, amount: 1000, recipient: nil, firstSeen: nil)] : [], height: 900_000)
    }
    func testMinimumAbsoluteFeeRateAndDescendants() throws {
        for childFee: Int64 in [0,200,1000,20000] {
            let p = try plan(fee: 151, oldSize: 100, linked: childFee)
            let min = Decimal(p.minimumRate)
            XCTAssertGreaterThan(min, p.originalRate)
            XCTAssertGreaterThanOrEqual(try p.fee(rate: min), p.replacedFee + Int64(p.virtualSize))
            XCTAssertThrowsError(try p.validate(rate: min - 1))
            XCTAssertNoThrow(try p.validate(rate: min))
        }
        let exact = try plan(fee: 220, oldSize: 100)
        XCTAssertEqual(exact.minimumRate, 3)
        XCTAssertEqual(try exact.fee(rate: Decimal(string: "3.01")!), 332)
    }
    func testVSizeForEveryScriptType() throws {
        for (type,size) in [(AddressStandard.bip86,111),(.bip84,110),(.bip49,134),(.bip44,193)] {
            let p = try plan(type: type); XCTAssertEqual(p.virtualSize,size)
            let session = try session(), worker = try work(session)
            let signed = try worker.sign(p,rate:20)
            XCTAssertLessThanOrEqual((try WireTransaction(signed.raw).weight + 3)/4,size)
            XCTAssertEqual(signed.fee,20*Int64(size)); XCTAssertTrue(worker.isCleared)
            session.wipe()
        }
    }
    func testDustBoundaryAndFeeOverflow() throws {
        let dust = try plan(value: 546+330); XCTAssertEqual(try dust.validate(rate: 3),330)
        let short = try plan(value: 545+330)
        XCTAssertThrowsError(try short.validate(rate: 3)) { XCTAssertEqual($0 as? CancelFailure,.notEnough) }
        XCTAssertThrowsError(try FeeMath.ceil(Decimal.greatestFiniteMagnitude))
        XCTAssertThrowsError(try FeeMath.ceil(.nan))
    }
    func testBIP86DestinationVectorAndReceiveBranch() throws {
        let session = SecretSession(); try session.key.replace(with: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about".utf8)
        let worker = try work(session); defer { worker.cancel(); session.wipe() }
        let address = try worker.address(type:.bip86,index:0)
        XCTAssertEqual(address.address,"bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr")
        XCTAssertEqual(address.path,[86|0x80000000,0x80000000,0x80000000,0,0])
        XCTAssertNotEqual(try worker.address(type:.bip86,index:1).script,address.script)
    }
    func testTamperingEveryTransactionRegionIsRejected() throws {
        let p = try plan(type:.bip86), session = try session()
        let signed = try work(session).sign(p,rate:20)
        let verifier = try work(session)
        try verifier.withRoot { root in
            XCTAssertNoThrow(try ReplacementCheck.validate(raw:signed.raw,plan:p,rate:20,root:root))
            for offset in [0,8,40,44,50,65,signed.raw.count-10,signed.raw.count-1] {
                var changed = signed.raw; changed[offset] ^= 1
                XCTAssertThrowsError(try ReplacementCheck.validate(raw:changed,plan:p,rate:20,root:root),"offset \(offset)")
            }
            XCTAssertThrowsError(try ReplacementCheck.validate(raw:signed.raw,plan:p,rate:21,root:root))
        }
        verifier.cancel();session.wipe()
    }
    func testWrongKeyCannotSignOrValidate() throws {
        let p = try plan(); let other = SecretSession();try other.key.replace(with:(String(repeating:"0",count:63)+"2").utf8)
        let worker = try work(other)
        XCTAssertThrowsError(try worker.sign(p,rate:20));XCTAssertTrue(worker.isCleared);other.wipe()
    }
    func testPresetFilteringAndDefaultFallback() throws {
        let p = try plan(fee:1000)
        let fees = try FeeRecommendations(nextBlock:30,fast:20,medium:10,minimum:1)
        let policy = CancelFeePolicy(plan:p,fees:fees)
        XCTAssertEqual(policy.minimum,11)
        XCTAssertEqual(policy.options.map(\.speed),[.nextBlock,.fast])
        XCTAssertEqual(policy.initial(defaultSpeed:.medium),.init(speed:.fast,rate:20))
        XCTAssertEqual(policy.initial(defaultSpeed:.nextBlock).speed,.nextBlock)
        let low = CancelFeePolicy(plan:p,fees:try FeeRecommendations(nextBlock:11,fast:10,medium:9,minimum:1))
        XCTAssertTrue(low.options.isEmpty);XCTAssertEqual(low.initial(defaultSpeed:.fast),.init(speed:.custom,rate:11))
    }
    func testCustomValidationStatusAndHighFeeWarning() throws {
        let p = try plan(fee:1000), policy = CancelFeePolicy(plan:p,fees:try FeeRecommendations(nextBlock:30,fast:20,medium:10,minimum:1))
        XCTAssertEqual(policy.status("",usd:60000),"Enter a fee rate")
        for input in ["10","-1","nan","1e3","1,2",".1","1.2.3"] { XCTAssertNil(policy.parse(input)) }
        XCTAssertEqual(policy.parse("11"),11)
        XCTAssertEqual(policy.status("10",usd:60000),"Must be higher than 10 sat/vB")
        XCTAssertEqual(policy.status("91",usd:60000),"Much higher than needed")
        XCTAssertTrue(policy.status("20",usd:60000).hasPrefix("~10 min"))
    }
    func testModelAppliesFeeAndUpdatesHero() throws {
        let session = try session(), model = CancelFixtures.model(session:session)
        let old = model.amount
        model.apply(.init(speed:.custom,rate:25))
        XCTAssertNotEqual(old,model.amount);XCTAssertEqual(model.fee,2750)
        model.apply(.init(speed:.custom,rate:1));XCTAssertEqual(model.choice?.rate,25)
        session.wipe();XCTAssertNil(model.plan);model.release()
    }
    func testExcessiveAppliedFeeRoutesToNotEnough() throws {
        let session = try session(), model = CancelFixtures.model(session:session)
        model.apply(.init(speed:.custom,rate:100000))
        model.cancelPayment()
        XCTAssertEqual(model.failure,.notEnough);XCTAssertFalse(model.validFee)
        model.release();XCTAssertNil(model.failure);XCTAssertNil(model.choice);session.wipe()
    }
    func testFaceIDCancellationStaysAndFailureAlerts() async throws {
        for cancel in [true,false] {
            let session = try session(), auth = TestAuthorization(cancel:cancel)
            let model = CancelModel(payment:PaymentsFixtures.payment(.normal,id:"a"),session:session,authorizer:auth,defaultSpeed:.fast)
            model.plan = try plan();model.recommendations = try FeeRecommendations(nextBlock:30,fast:20,medium:10,minimum:1);model.choice = .init(speed:.fast,rate:20)
            XCTAssertEqual(auth.calls,0);model.cancelPayment()
            for _ in 0..<20 where model.busy { try await Task.sleep(for:.milliseconds(10)) }
            XCTAssertEqual(auth.calls,1);XCTAssertEqual(auth.reason,"Cancel this payment")
            XCTAssertEqual(model.authenticationFailed,!cancel);XCTAssertNil(model.signed);XCTAssertNil(model.failure)
            session.wipe();model.release()
        }
    }
    func testInvalidFeeNeverInvokesAuthentication() throws {
        let session = try session(), auth = TestAuthorization(cancel:true)
        let model = CancelModel(payment:PaymentsFixtures.payment(.normal,id:"a"),session:session,authorizer:auth)
        model.plan = try plan();model.choice = .init(speed:.custom,rate:0)
        model.cancelPayment();XCTAssertEqual(auth.calls,0);XCTAssertNil(model.signed);model.release();session.wipe()
    }
    func testCanceledWorkerCannotDeriveOrSign() throws {
        let session = try session(), worker = try work(session), p = try plan();worker.cancel()
        XCTAssertTrue(worker.isCleared);XCTAssertThrowsError(try worker.addresses());XCTAssertThrowsError(try worker.sign(p,rate:20));session.wipe()
    }
    func testSchnorrPublishedVerificationVector() throws {
        // BIP340 vector 0, public key scalar 3, zero message. Invalid signature is rejected too.
        let pub = Data(hex:"F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9")!
        let sig = Data(hex:"E907831F80848D1069A5371B402410364BDF1C5F8307B0084C55F1CE2DCA821525F66A4A85EA8B71E482A74F382D2CE5EBEEE8FDB2172F477DF4900D310536C0")!
        XCTAssertEqual(takeback_verify([UInt8](pub),32,[UInt8](repeating:0,count:32),[UInt8](sig),64,1),1)
        var bad = sig;bad[0] ^= 1
        XCTAssertEqual(takeback_verify([UInt8](pub),32,[UInt8](repeating:0,count:32),[UInt8](bad),64,1),0)
    }
    func testCoreRegtestSigning() throws {
        let url = URL(fileURLWithPath:"/tmp/Takeback-Cancel-Regtest/Input.json")
        guard FileManager.default.fileExists(atPath:url.path) else { throw XCTSkip("Run Scripts/cancel-regtest.py prepare first") }
        struct Fixture: Decodable {
            struct Input: Decodable { let txid:String;let index:UInt32;let value:Int64;let purpose:Int;let script:String;let compressed:Bool }
            struct Child: Decodable { let txid:String;let fee:Int64;let amount:Int64;let recipient:String }
            let name:String;let originalID:String;let originalFee:Int64;let originalVSize:Int;let inputs:[Input];let descendants:[Child];let height:UInt32
        }
        let fixtures = try JSONDecoder().decode([Fixture].self,from:Data(contentsOf:url))
        var results: [[String:String]] = []
        for f in fixtures {
            let inputs = try f.inputs.map { i in ReplacementInput(txid:i.txid,index:i.index,value:i.value,key:SigningAddress(type:try XCTUnwrap(AddressStandard(rawValue:i.purpose)),path:[],script:try XCTUnwrap(Data(hex:i.script)),compressed:i.compressed)) }
            let plan = CancellationPlan(originalID:f.originalID,originalFee:f.originalFee,originalVSize:f.originalVSize,inputs:inputs,destination:inputs.max(by:{$0.value < $1.value})!.key,
                descendants:f.descendants.map { .init(txid:$0.txid,fee:$0.fee,amount:$0.amount,recipient:$0.recipient,firstSeen:nil) },height:f.height)
            let session = try session();let signed = try work(session).sign(plan,rate:Decimal(max(30,plan.minimumRate+1)))
            XCTAssertEqual(signed.originalID,f.originalID);XCTAssertEqual(signed.fee,try plan.fee(rate:Decimal(max(30,plan.minimumRate+1))));session.wipe()
            results.append(["name":f.name,"raw":signed.raw.hex,"txid":signed.txid])
        }
        let data = try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys])
        try data.write(to:URL(fileURLWithPath:"/tmp/Takeback-Cancel-Regtest/Signed.json"))
        let attachment = XCTAttachment(data:data,uniformTypeIdentifier:"public.json");attachment.name="Signed-regtest";attachment.lifetime = .keepAlways;add(attachment)
    }
}
@MainActor private final class TestAuthorization: CancellationAuthorizing {
    let cancel:Bool;var calls=0;var reason="";var symbol:String { "faceid" }
    init(cancel:Bool) { self.cancel=cancel }
    func authorize(reason:String) async throws { calls += 1;self.reason=reason;throw LAError(cancel ? .userCancel : .authenticationFailed) }
}
