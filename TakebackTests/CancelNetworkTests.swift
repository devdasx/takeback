import XCTest
@testable import Takeback

@MainActor final class CancelNetworkTests: XCTestCase {
    private func session() throws -> SecretSession { let s = SecretSession();try s.key.replace(with:(String(repeating:"0",count:63)+"1").utf8);return s }
    private func fixtures() throws -> (PendingPayment,[String:String]) {
        let directory = URL(fileURLWithPath:"/tmp/Takeback-Cancel-Regtest")
        guard FileManager.default.fileExists(atPath:directory.appendingPathComponent("Responses.json").path) else { throw XCTSkip("Run isolated regtest fixture preparation") }
        let data = try Data(contentsOf:directory.appendingPathComponent("Input.json"))
        let list = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [[String:Any]])
        let item = try XCTUnwrap(list.first { $0["name"] as? String == "linked" })
        let id = try XCTUnwrap(item["originalID"] as? String)
        let payment = PendingPayment(txid:id,types:[.bip84],ownedInputCount:1,totalInputCount:1,signalsRBF:true,feeSats:1000,virtualSize:item["originalVSize"] as! Int,firstSeen:nil,recipient:nil,descendants:[],amountSats:9_999_000)
        let responses = try JSONDecoder().decode([String:String].self,from:Data(contentsOf:directory.appendingPathComponent("Responses.json")))
        return (payment,responses)
    }
    private func engine(_ http: CancelHTTP) throws -> CancellationEngine { .init(configuration:try ChainConfiguration(mempoolURL:URL(string:"https://fixture.invalid/api")!,electrumServers:[.init(host:"fixture.invalid",port:50002)]),http:http,electrum:http) }
    func testRetryPreservesSelectedRateAndReRegistersWipeHandler() async throws {
        let (payment, responses) = try fixtures()
        let session = try session()
        let model = CancelModel(payment: payment, session: session, engine: try engine(CancelHTTP(responses)))
        await model.load()
        model.release()
        await model.load(forFeeRetry: true, retryRate: 25)
        XCTAssertEqual(model.choice?.rate, 26)
        XCTAssertEqual(model.choice?.speed, .custom)
        XCTAssertNotNil(model.plan)
        session.wipe()
        XCTAssertNil(model.plan); XCTAssertNil(model.choice); XCTAssertNil(model.recommendations)
    }
    func testLargestInputChoosesNextUnusedReceiveAddressAndSameHDKey() async throws {
        let session = SecretSession();try session.key.replace(with:"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about".utf8)
        let worker = try CancellationKeyWork(sessionKey:session.key,passphrase:session.passphrase)
        defer {worker.cancel();session.wipe()}
        let addresses = try worker.addresses()
        let small = try worker.address(type:.bip84,index:0), large = try worker.address(type:.bip86,index:0)
        let external = SigningAddress(type:.bip84,path:[],script:Data(hex:"0014751e76e8199196d454941c45d1b3a323f1433bd6")!,compressed:true)
        var replies:[String:String] = ["blocks/tip/height":"900000"]
        var inputs:[ReplacementInput] = []
        for (key,value) in [(small,Int64(200000)),(large,Int64(300000))] {
            let coinbase = ReplacementInput(txid:String(repeating:"0",count:64),index:UInt32.max,value:0,key:key)
            let funding = ReplacementWire(inputs:[coinbase],scripts:[Data([1,1])],witness:[[]],amount:value,output:key.script,height:0).serialize(witness:false)
            let id = try TransactionID.compute(raw:funding);replies["tx/\(id)/hex"] = funding.hex
            inputs.append(.init(txid:id,index:0,value:value,key:key))
        }
        let original = ReplacementWire(inputs:inputs,scripts:[Data(),Data()],witness:[[],[]],amount:499000,output:external.script,height:0).serialize(witness:false)
        let id = try TransactionID.compute(raw:original)
        replies["tx/\(id)/hex"] = original.hex;replies["tx/\(id)/status"] = "{\"confirmed\":false}"
        replies["tx/\(id)/outspends"] = "[{\"spent\":false}]"
        for address in addresses where address.type == .bip86 && address.path.dropLast().last == 0 {
            let used = [UInt32(0),5].contains(address.path.last!)
            replies["address/\(address.address)"] = "{\"chain_stats\":{\"tx_count\":\(used ? 1 : 0)},\"mempool_stats\":{\"tx_count\":0}}"
        }
        let payment = PendingPayment(txid:id,types:[.bip84,.bip86],ownedInputCount:2,totalInputCount:2,signalsRBF:true,feeSats:1000,virtualSize:150,firstSeen:nil,recipient:external.address,descendants:[])
        let http = CancelHTTP(replies)
        let result = try await engine(http).prepare(payment:payment,work:worker)
        XCTAssertEqual(result.destination.type,.bip86)
        XCTAssertEqual(result.destination.path,[86|0x80000000,0x80000000,0x80000000,0,1])
        XCTAssertEqual(result.destination,try worker.address(type:.bip86,index:1))
        XCTAssertEqual(result.inputs.map(\.value),[200000,300000])
    }
    func testVerifiedInputsAndDescendantFeesFromRawTransactions() async throws {
        let (payment,responses) = try fixtures();let http=CancelHTTP(responses);let engine=try engine(http);let session=try session()
        let worker=try CancellationKeyWork(sessionKey:session.key,passphrase:session.passphrase);defer {worker.cancel();session.wipe()}
        let plan=try await engine.prepare(payment:payment,work:worker)
        XCTAssertEqual(plan.inputs.count,1);XCTAssertEqual(plan.total,10_000_000)
        XCTAssertEqual(plan.originalFee,1000);XCTAssertEqual(plan.descendants.count,1);XCTAssertEqual(plan.replacedFee,2000)
        XCTAssertEqual(plan.destination,plan.inputs[0].key);XCTAssertEqual(plan.destination.type,.bip84)
        let requests=await http.paths;XCTAssertTrue(requests.contains("tx/\(plan.inputs[0].txid)/hex"))
        XCTAssertFalse(requests.contains { $0.contains(String(repeating:"0",count:63)+"1") })
    }
    func testConfirmedPaymentDoesNotReachSigning() async throws {
        let (payment,responses)=try fixtures();var changed=responses
        changed["tx/\(payment.txid)/status"]="{\"confirmed\":true,\"block_time\":1700000000}"
        let session=try session(),worker=try CancellationKeyWork(sessionKey:session.key,passphrase:session.passphrase);defer {worker.cancel();session.wipe()}
        do { _ = try await engine(CancelHTTP(changed)).prepare(payment:payment,work:worker);XCTFail("Expected confirmed guard") }
        catch { XCTAssertEqual(error as? CancelFailure,.alreadyConfirmed) }
    }
    func testTamperedFundingRawRejectedBeforeFeePreview() async throws {
        let (payment,responses)=try fixtures();var changed=responses
        changed["tx/\(payment.txid)/hex"] = responses.first { $0.key.hasSuffix("/hex") && $0.key != "tx/\(payment.txid)/hex" }!.value
        let session=try session(),worker=try CancellationKeyWork(sessionKey:session.key,passphrase:session.passphrase);defer {worker.cancel();session.wipe()}
        do { _ = try await engine(CancelHTTP(changed)).prepare(payment:payment,work:worker);XCTFail("Expected txid check") }
        catch { XCTAssertEqual(error as? ChainError,.txidMismatch) }
    }
    func testSuccessfulAuthenticationBuildsChecksAndHandsOffWithoutBroadcast() async throws {
        let (payment,responses)=try fixtures();let http=CancelHTTP(responses),auth=SuccessfulAuthorization();let session=try session()
        let model=CancelModel(payment:payment,session:session,engine:try engine(http),authorizer:auth,defaultSpeed:.fast)
        await model.load();XCTAssertTrue(model.canCancel);XCTAssertNil(model.signed);XCTAssertEqual(auth.calls,0)
        model.cancelPayment();model.cancelPayment()
        for _ in 0..<100 where model.busy { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertEqual(auth.calls,1);XCTAssertNotNil(model.signed);XCTAssertNil(model.failure)
        XCTAssertEqual(model.signed?.destination,model.plan?.destination.address)
        let methods=await http.methods;XCTAssertTrue(methods.allSatisfy {$0=="GET"})
        model.release();session.wipe()
    }
    func testRateRefreshUpdatesSelectedPresetAndNeverChangesCustom() async throws {
        let (payment,responses)=try fixtures();let http=CancelHTTP(responses);let session=try session()
        let model=CancelModel(payment:payment,session:session,engine:try engine(http),defaultSpeed:.fast)
        await model.load();XCTAssertEqual(model.choice?.rate,30)
        await http.set("v1/fees/recommended","{\"fastestFee\":50,\"halfHourFee\":40,\"hourFee\":30,\"minimumFee\":1}")
        await model.refreshRates();XCTAssertEqual(model.choice?.rate,50)
        model.apply(.init(speed:.custom,rate:45));await http.set("v1/fees/recommended","{\"fastestFee\":60,\"halfHourFee\":50,\"hourFee\":40,\"minimumFee\":1}")
        await model.refreshRates();XCTAssertEqual(model.choice?.rate,45)
        model.release();session.wipe()
    }
}
actor CancelHTTP: HTTPTransport, ElectrumTransport {
    var transactions: [String: WireTransaction] = [:]
    var hashScripts: [String:String] = [:]
    var responses:[String:String];var paths:[String]=[];var methods:[String]=[]
    init(_ responses:[String:String]) {
        self.responses=responses
        for (path, text) in responses where path.hasSuffix("/hex") {
            if let raw = Data(hex:text), let tx = try? WireTransaction(raw) { transactions[String(path.dropFirst(3).dropLast(4))] = tx
                for output in tx.outputs { if let script = Data(hex:output.scriptpubkey) { hashScripts[ChainAddress(address:"",scriptPubKey:script).electrumScriptHash] = output.scriptpubkey } }
            }
        }
    }
    func set(_ path:String,_ response:String) {responses[path]=response}
    func send(_ request:URLRequest) async throws -> HTTPResponse {
        let path=request.url!.path.replacingOccurrences(of:"/api/",with:"")
        paths.append(path);methods.append(request.httpMethod ?? "GET")
        guard let text=responses[path] else {return .init(status:404,data:Data())}
        return .init(status:200,data:Data(text.utf8))
    }
    func call(server: ElectrumServer, method: String, params: [JSONValue], timeout: TimeInterval) async throws -> JSONValue {
        func json(_ text: String) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self,from:Data(text.utf8)) }
        switch method {
        case "server.version": return .array([.string("fixture"),.string("1.4")])
        case "server.ping": return .null
        case "blockchain.headers.subscribe": return .object(["height":.number(900000)])
        case "blockchain.estimatefee", "blockchain.relayfee":
            let fees = try json(responses["v1/fees/recommended"] ?? "{\"fastestFee\":30,\"halfHourFee\":20,\"hourFee\":10,\"minimumFee\":1}")
            guard case .object(let values) = fees else { throw ChainError.invalidResponse }
            let key = method == "blockchain.relayfee" ? "minimumFee" : params.first?.integer == 1 ? "fastestFee" : params.first?.integer == 3 ? "halfHourFee" : "hourFee"
            return .number((values[key]?.decimal ?? 1) / 100000)
        case "blockchain.transaction.get":
            let path = "tx/\(params[0].string!)/hex"; paths.append(path); methods.append("GET")
            guard let raw = responses[path] else { throw ChainError.invalidResponse }; return .string(raw)
        case "blockchain.scripthash.listunspent": return .array([])
        case "blockchain.scripthash.get_history", "blockchain.scripthash.get_mempool":
            let hash = params[0].string!
            // Capacity probes concern unused hashes and must not traverse the fixture graph.
            guard let script = hashScripts[hash] else { return .array([]) }
            var entries: [JSONValue] = []
            for (id, tx) in transactions {
                let touches = tx.outputs.contains { $0.scriptpubkey == script } || tx.inputs.contains { input in
                    guard let parent = transactions[input.txid], parent.outputs.indices.contains(input.index) else { return false }
                    return parent.outputs[input.index].scriptpubkey == script
                }
                guard touches else { continue }
                let status = try responses["tx/\(id)/status"].map(json)
                let confirmed: Bool
                if case .object(let object) = status { confirmed = object["confirmed"] == .bool(true) }
                else { confirmed = !responses.keys.contains("tx/\(id)/outspends") }
                if method.hasSuffix("get_mempool") && confirmed { continue }
                entries.append(.object(["tx_hash":.string(id),"height":.number(confirmed ? 100 : 0)]))
            }
            return .array(entries)
        default: throw ChainError.invalidResponse
        }
    }
    func batch(server: ElectrumServer, calls: [RPCCall], timeout: TimeInterval) async throws -> [Result<JSONValue, RPCFailure>] {
        var result: [Result<JSONValue, RPCFailure>] = []
        for item in calls { result.append(.success(try await call(server:server,method:item.method,params:item.params,timeout:timeout))) }
        return result
    }

}
@MainActor private final class SuccessfulAuthorization: CancellationAuthorizing {
    var calls=0;var symbol:String {"faceid"}
    func authorize(reason:String) async throws {calls += 1}
}
