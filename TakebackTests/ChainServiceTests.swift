import XCTest
@testable import Takeback

private let legacyHex = "010000000100000000000000000000000000000000000000000000000000000000000000000000000000ffffffff010100000000000000015100000000"
private let fixtureID = "490b76e7ee99f7b89f1ea0a70cd6ca6ff72d048e639f3b03a1a9d1cd9de901f4"

@MainActor final class ChainServiceTests: XCTestCase {
    func testElectrumFeeTargetsConversionAndNoHTTP() async throws {
        let rpc = TestElectrum()
        for (target, value) in [(1,"0.00012"),(3,"0.00008"),(6,"0.00004")] { await rpc.set("blockchain.estimatefee:\(target)", .number(Decimal(string:value)!)) }
        let fees = try await rpc.service().fees()
        XCTAssertEqual(fees, try FeeRecommendations(nextBlock:12,fast:8,medium:4,minimum:1))
        let calls = await rpc.calls
        XCTAssertEqual(calls.map(\.params), [[.number(1)],[.number(3)],[.number(6)],[]])
        let sizes = await rpc.batchSizes; XCTAssertEqual(sizes, [4])
    }
    func testHistogramFallbackAndRelayFloor() async throws {
        let rpc = TestElectrum()
        await rpc.set("blockchain.estimatefee", .number(-1))
        await rpc.set("mempool.get_fee_histogram", .array([.array([.number(10),.number(1000000)]),.array([.number(5),.number(2000000)]),.array([.number(2),.number(3000000)])]))
        let fees = try await rpc.service().fees()
        XCTAssertEqual(fees, try FeeRecommendations(nextBlock:10,fast:5,medium:2,minimum:1))
    }
    func testBroadcastTransportFailoverExactIDAndTimeout() async throws {
        let rpc = TestElectrum(); await rpc.broadcasts([.failure(.timeout),.success(.string(fixtureID))])
        let id = try await rpc.service().broadcast(rawTransaction: Data(hex:legacyHex)!)
        XCTAssertEqual(id,fixtureID)
        let calls = await rpc.calls
        XCTAssertEqual(calls.map(\.host),["first.invalid","second.invalid"])
        XCTAssertTrue(calls.allSatisfy { $0.timeout == 8 && $0.method == "blockchain.transaction.broadcast" && $0.params == [.string(legacyHex)] })
    }
    func testTransportFailuresStopAfterThreeAndKeepAttempts() async throws {
        let rpc = TestElectrum(); await rpc.broadcasts([.failure(.timeout),.failure(.unavailable),.failure(.network)])
        do { _ = try await rpc.service().broadcastDetailed(rawTransaction:Data(hex:legacyHex)!); XCTFail() }
        catch let failure as BroadcastFailure {
            XCTAssertFalse(failure.definitive); XCTAssertEqual(failure.attempts.count,4)
            XCTAssertEqual(failure.source,"third.invalid")
        }
        let calls = await rpc.calls; XCTAssertEqual(calls.count,3)
    }
    func testClearRejectionNeverRetriesAndPreservesActualHostAndMessage() async throws {
        let rpc = TestElectrum(); await rpc.reject("insufficient fee: replacement fee too low")
        do { _ = try await rpc.service().broadcastDetailed(rawTransaction:Data(hex:legacyHex)!); XCTFail() }
        catch let failure as BroadcastFailure { XCTAssertTrue(failure.definitive); XCTAssertEqual(failure.source,"first.invalid"); XCTAssertEqual(failure.message,"insufficient fee: replacement fee too low") }
        let calls = await rpc.calls; XCTAssertEqual(calls.count,1)
    }
    func testWrongTxidStopsAndAlreadyKnownSucceeds() async throws {
        let rpc = TestElectrum(); await rpc.broadcasts([.success(.string(String(repeating:"b",count:64)))])
        do { _ = try await rpc.service().broadcast(rawTransaction:Data(hex:legacyHex)!); XCTFail() }
        catch { XCTAssertEqual(error as? ChainError,.txidMismatch) }
        let calls = await rpc.calls; XCTAssertEqual(calls.count,1)
        await rpc.reject("txn-already-known")
        let id = try await rpc.service().broadcast(rawTransaction:Data(hex:legacyHex)!); XCTAssertEqual(id,fixtureID)
    }
    func testHistoryUTXOAndRawTransactionAreBatchedAndNeverVerbose() async throws {
        let rpc = TestElectrum(), address = ChainAddress(address:"fixture",scriptPubKey:Data([0x51]))
        await rpc.set("blockchain.scripthash.get_history", .array([.object(["tx_hash":.string(fixtureID),"height":.number(-1)])]))
        await rpc.set("blockchain.scripthash.listunspent", .array([.object(["tx_hash":.string(fixtureID),"tx_pos":.number(0),"height":.number(0),"value":.number(1234)])]))
        await rpc.set("blockchain.transaction.get", .string(legacyHex))
        let service = try rpc.service()
        let history = try await service.history(for:address), utxos = try await service.client.unspent([address.electrumScriptHash]), raw = try await service.client.transactions([fixtureID])
        XCTAssertFalse(history[0].isConfirmed); XCTAssertEqual(utxos[0][0].value,1234); XCTAssertEqual(raw.count,1)
        let calls = await rpc.calls
        XCTAssertEqual(calls.last?.params,[.string(fixtureID),.bool(false)])
    }
    func testInvalidUTXOAndInvalidRawAreRejected() async throws {
        let rpc = TestElectrum()
        await rpc.set("blockchain.scripthash.listunspent", .array([.object(["tx_hash":.string(fixtureID),"tx_pos":.number(0),"height":.number(0),"value":.number(-1)])]))
        do { _ = try await rpc.service().client.unspent([String(repeating:"0",count:64)]); XCTFail() } catch { XCTAssertEqual(error as? ChainError,.invalidResponse) }
        await rpc.set("blockchain.transaction.get", .string("00"))
        do { _ = try await rpc.service().client.transactions([fixtureID]); XCTFail() } catch { XCTAssertNotNil(error as? ChainError) }
    }
    func testStatusComesFromHistoryAndTip() async throws {
        let rpc = TestElectrum()
        await rpc.set("blockchain.scripthash.get_history", .array([.object(["tx_hash":.string(fixtureID),"height":.number(899999)])]))
        let confirmations = try await rpc.service().transactionStatus(txid:fixtureID,scripts:[Data([0x51])])
        XCTAssertEqual(confirmations,2)
        let calls = await rpc.calls; XCTAssertFalse(calls.contains { $0.method == "blockchain.transaction.get" })
    }
    func testInvalidTransactionFailsBeforeNetwork() async throws {
        let rpc = TestElectrum()
        do { _ = try await rpc.service().broadcast(rawTransaction:Data([0])); XCTFail() } catch { XCTAssertEqual(error as? ChainError,.invalidTransaction) }
        let calls = await rpc.calls; XCTAssertTrue(calls.isEmpty)
    }
    func testJSONDecimalPrecision() throws {
        let value = try JSONDecoder().decode(JSONValue.self,from:Data("0.00000001".utf8))
        XCTAssertEqual(value.decimal,Decimal(string:"0.00000001")); XCTAssertNil(value.integer)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self,from:JSONEncoder().encode(value)),value)
    }
}

final class TransactionIDTests: XCTestCase {
    func testLegacyAndSegWitProduceSameTxidForSameBaseTransaction() throws {
        let legacy = Data(hex:legacyHex)!
        let segwit = legacy.prefix(4) + Data([0,1]) + legacy.dropFirst(4).dropLast(4) + Data([1,1,0]) + legacy.suffix(4)
        XCTAssertEqual(try TransactionID.compute(raw:legacy),fixtureID)
        XCTAssertEqual(try TransactionID.compute(raw:segwit),fixtureID)
    }
    func testRejectsTruncatedTrailingAndNonCanonicalTransactions() {
        let legacy = Data(hex:legacyHex)!
        for bytes in [Data(legacy.dropLast()),legacy + Data([0]), Data([1,0,0,0,0,2]),
                      legacy.prefix(4) + Data([253,1,0]) + legacy.dropFirst(5)] {
            XCTAssertThrowsError(try TransactionID.compute(raw:bytes))
        }
    }
}
