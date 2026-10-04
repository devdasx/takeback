import XCTest
@testable import Takeback

@MainActor final class PaymentsTests: XCTestCase {
    func testEveryKindAndPrecedence() {
        for kind in PaymentKind.allCases {
            let p = PaymentsFixtures.payment(kind, id: "a")
            XCTAssertEqual(p.kind, kind)
        }
        var p = PaymentsFixtures.payment(.notOwned, id: "a")
        p.descendants = [String(repeating: "b", count: 64)]; p.fullRBF = true
        XCTAssertEqual(p.kind, .notOwned)
        var final = PaymentsFixtures.payment(.notReplaceable, id: "c")
        final.descendants = [String(repeating: "d", count: 64)]
        XCTAssertEqual(final.kind, .linked)
        final.fullRBF = true; XCTAssertEqual(final.kind, .linked)
    }
    func testFullRBFAndInheritedSignal() {
        var p = PaymentsFixtures.payment(.notReplaceable, id: "a")
        p.fullRBF = true; XCTAssertEqual(p.kind, .notReplaceable); XCTAssertTrue(p.kind.canCancel)
        p.fullRBF = false; p.inheritedRBF = true; XCTAssertEqual(p.kind, .notReplaceable)
        XCTAssertTrue(PaymentEvidence.fullRBF(coreVersion: "/Satoshi:29.0.0/"))
        XCTAssertTrue(PaymentEvidence.fullRBF(coreVersion: "/Satoshi:30.1.0/"))
        XCTAssertFalse(PaymentEvidence.fullRBF(coreVersion: "/Satoshi:28.0.0/"))
        XCTAssertFalse(PaymentEvidence.fullRBF(coreVersion: "ElectrumX 29.0"))
        XCTAssertFalse(PaymentEvidence.fullRBF(coreVersion: "?"))
    }
    func testGroupsCountsAndOldestFirst() {
        let all = PaymentsListData(PaymentsFixtures.all)
        XCTAssertFalse(all.grouped)
        XCTAssertEqual(all.subtitle, "3 payments from this key are waiting to confirm. Pick one to cancel.")
        XCTAssertEqual(all.payments[0].txid, String(repeating: "b", count: 64))
        let mixed = PaymentsListData(PaymentsFixtures.mixed.reversed())
        XCTAssertTrue(mixed.grouped); XCTAssertEqual(mixed.cancellable.count, 3); XCTAssertEqual(mixed.restricted.count, 2)
        XCTAssertEqual(mixed.subtitle, "5 payments from this key are waiting to confirm. 3 can be canceled.")
        XCTAssertEqual(mixed.payments[0].kind, .linked)
        XCTAssertTrue(mixed.payments.prefix(2).allSatisfy { $0.kind.canCancel })
    }
    func testRoutingEveryKindDoneAndFindingBack() {
        let router = WelcomeRouter(session: SecretSession())
        let payments = PaymentsFixtures.mixed
        router.path = [.enterKey, .payments(payments)]
        for p in payments {
            router.openPayment(p)
            XCTAssertEqual(router.path.last, p.kind.canCancel ? .review(p) : .paymentExplanation(p))
            router.goBack(); XCTAssertEqual(router.path.last, .payments(payments))
        }
        router.goBack(); XCTAssertEqual(router.path, [.enterKey])
        router.showPayments([payments[2]])
        XCTAssertEqual(Array(router.path.suffix(2)), [.payments([payments[2]]), .paymentExplanation(payments[2])])
    }
    func testLinkedRouteRetainsWarningData() {
        let router = WelcomeRouter(session: SecretSession()), payment = PaymentsFixtures.payment(.linked, id: "a")
        router.openPayment(payment)
        guard case .review(let selected) = router.path.last else { return XCTFail("Expected review") }
        XCTAssertEqual(selected.descendants?.count, 2)
        XCTAssertTrue(PaymentText.subtitle(selected, now: PaymentsFixtures.now).contains("also cancels 2 later payments"))
    }
    func testExactAmountsFiatAndNoInventedUnknowns() {
        let prior = UserDefaults.standard.object(forKey:"showUSD"); UserDefaults.standard.set(true,forKey:"showUSD")
        defer { if let prior { UserDefaults.standard.set(prior,forKey:"showUSD") } else { UserDefaults.standard.removeObject(forKey:"showUSD") } }
        XCTAssertEqual(PaymentText.amount(4_210_000), "0.04210 BTC")
        XCTAssertEqual(PaymentText.amount(1), "0.00000001 BTC")
        XCTAssertEqual(PaymentText.fiat(4_210_000, rate: 61_300), "$2,580.73")
        XCTAssertEqual(PaymentText.fiat(1, rate: nil), "")
        XCTAssertEqual(PaymentText.amount(nil), "— BTC")
        XCTAssertEqual(PaymentText.shortened("1234567890123456789"), "12345678…6789")
        XCTAssertEqual(PaymentText.waiting(nil, now: PaymentsFixtures.now), "waiting")
        XCTAssertNil(PaymentText.sent(nil, now: PaymentsFixtures.now))
    }
    func testCopyFullReplacementIDOnly() {
        let clipboard = PublicClipboard()
        let p = PaymentsFixtures.payment(.canceling, id: "d")
        PaymentActions.copyReplacement(p, clipboard: clipboard)
        XCTAssertEqual(clipboard.copied, String(repeating: "d", count: 64))
        clipboard.copied = nil
        PaymentActions.copyReplacement(PaymentsFixtures.payment(.normal, id: "a"), clipboard: clipboard)
        XCTAssertNil(clipboard.copied)
    }
    func testExplorerUsesConfiguredServerAndReplacementNotOriginal() {
        var p = PaymentsFixtures.payment(.canceling, id: "a")
        p.explorerBaseURL = URL(string: "https://example.org/bitcoin")!
        XCTAssertEqual(p.replacementURL?.absoluteString, "https://example.org/bitcoin/tx/" + String(repeating: "a", count: 64))
        XCTAssertNotEqual(p.cancellation?.originalTxid, p.cancellation?.replacementTxid)
        p.explorerBaseURL = URL(string: "http://example.org")!
        XCTAssertNil(p.replacementURL)
    }
    func testExplanationDataAndSubtitles() {
        let p = PaymentsFixtures.payment(.notOwned, id: "a")
        XCTAssertEqual(p.ownedInputSats, 3_000_000); XCTAssertEqual(p.otherInputSats, 1_500_000)
        XCTAssertTrue(PaymentText.subtitle(p, now: PaymentsFixtures.now).contains("this key signed 3 of 5 inputs"))
        let cancel = PaymentsFixtures.payment(.canceling, id: "d")
        XCTAssertEqual(cancel.displayedAmountSats, 4_210_000)
        XCTAssertEqual(PaymentText.subtitle(cancel, now: PaymentsFixtures.now), "Replacement waiting · 8 sat/vB · sent 10 minutes ago")
    }
    func testOwnCancellationRequiresConflictOwnershipAndBackToSelf() throws {
        let own = Set(["51"])
        let original = tx(id: "a", parent: "1", ownInput: true, selfOutput: false, fee: 100)
        let replacement = tx(id: "b", parent: "1", ownInput: true, selfOutput: true, fee: 200)
        XCTAssertTrue(PaymentEvidence.isOwnCancellation(original: original, replacement: replacement, owned: own))
        XCTAssertFalse(PaymentEvidence.isOwnCancellation(original: original, replacement: tx(id: "b", parent: "2", ownInput: true, selfOutput: true, fee: 200), owned: own))
        XCTAssertFalse(PaymentEvidence.isOwnCancellation(original: original, replacement: tx(id: "b", parent: "1", ownInput: false, selfOutput: true, fee: 200), owned: own))
        XCTAssertFalse(PaymentEvidence.isOwnCancellation(original: original, replacement: tx(id: "b", parent: "1", ownInput: true, selfOutput: false, fee: 200), owned: own))
        XCTAssertFalse(PaymentEvidence.isOwnCancellation(original: replacement, replacement: tx(id: "c", parent: "1", ownInput: true, selfOutput: true, fee: 300), owned: own))
        let sums = try PaymentEvidence.totals(original, owned: own)
        XCTAssertEqual(sums.amount, 1000); XCTAssertEqual(sums.ours, 1000); XCTAssertEqual(sums.others, 0)
    }
    func testBIP125InheritanceStopsAtConfirmedParents() {
        let child = tx(id: "a", parent: "b", ownInput: true, selfOutput: false, fee: 100)
        let parent = tx(id: "b", parent: "1", ownInput: true, selfOutput: true, fee: 100, signal: true)
        XCTAssertTrue(PaymentEvidence.inheritedRBF(child, transactions: [parent.txid: parent]))
        let confirmed = SearchTransaction(txid: parent.txid, vin: parent.vin, vout: parent.vout, fee: parent.fee, weight: parent.weight, status: .init(confirmed: true, block_time: 1))
        XCTAssertFalse(PaymentEvidence.inheritedRBF(child, transactions: [confirmed.txid: confirmed]))
    }
    func testSessionReplacementEvidenceAndClear() async throws {
        let cache = SessionTransactions()
        let original = tx(id:"a",parent:"1",ownInput:true,selfOutput:false,fee:100)
        let replacement = tx(id:"b",parent:"1",ownInput:true,selfOutput:true,fee:300)
        let first = await cache.observe([original]); XCTAssertTrue(first.isEmpty)
        let previous = await cache.observe([replacement]); XCTAssertEqual(previous.map(\.txid),[original.txid])
        XCTAssertTrue(PaymentEvidence.isOwnCancellation(original:previous[0],replacement:replacement,owned:["51"]))
        await cache.clear(); let empty = await cache.observe([]); XCTAssertTrue(empty.isEmpty)
    }
    func testToYourselfAndNetOutIncludesFee() throws {
        let outgoing = tx(id:"a",parent:"1",ownInput:true,selfOutput:false,fee:100)
        let back = tx(id:"b",parent:"1",ownInput:true,selfOutput:true,fee:100)
        XCTAssertEqual(try PaymentEvidence.totals(outgoing,owned:["51"]).amount,1000)
        XCTAssertEqual(try PaymentEvidence.totals(back,owned:["51"]).amount,100)
        let item = PendingPayment(txid:String(repeating:"a",count:64),types:[.bip84],ownedInputCount:1,totalInputCount:1,signalsRBF:true,feeSats:100,virtualSize:100,firstSeen:nil,recipient:nil,descendants:[])
        XCTAssertTrue(PaymentText.subtitle(item,now:Date()).hasPrefix("To yourself"))
        let noSignal = PaymentsFixtures.payment(.notReplaceable,id:"b")
        XCTAssertEqual(PaymentText.subtitle(noSignal,now:Date()),"Didn’t signal replacement · most nodes accept it")
        XCTAssertTrue(item.kind.canCancel)
    }
    private func tx(id: String, parent: String, ownInput: Bool, selfOutput: Bool, fee: Int64, signal: Bool = false) -> SearchTransaction {
        .init(txid: String(repeating: id, count: 64), vin: [.init(txid: String(repeating: parent, count: 64), vout: 0,
            sequence: signal ? 0xfffffffd : UInt32.max, prevout: .init(scriptpubkey: ownInput ? "51" : "60", scriptpubkey_address: nil, value: 1000))],
            vout: [.init(scriptpubkey: selfOutput ? "51" : "60", scriptpubkey_address: "recipient", value: 1000-fee)],
            fee: fee, weight: 400, status: .init(confirmed: false, block_time: nil))
    }
}
@MainActor private final class PublicClipboard: PaymentClipboard {
    var copied: String?
    func copyTransactionID(_ txid: String) { copied = txid }
}
