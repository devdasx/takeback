import XCTest
@testable import Takeback

final class MasterVectorTests: XCTestCase {
    func testOfficialBIP39EntropyMnemonicSeedAndMaster() throws {
        let vectors = try JSONDecoder().decode([[String]].self, from: Data(OfficialHDVectors.bip39.utf8))
        XCTAssertEqual(vectors.count, 24)
        for vector in vectors {
            let entropy = SecureBytes(), key = SecureBytes(), pass = SecureBytes()
            defer { entropy.wipe(); key.wipe(); pass.wipe() }
            try entropy.replace(with: XCTUnwrap(Data(hex: vector[0])))
            let mnemonic = try KeyScanRouter.mnemonic(entropy: entropy, range: 0..<entropy.count)
            defer { mnemonic.wipe() }
            XCTAssertTrue(mnemonic.withUnsafeBytes { $0.elementsEqual(vector[1].utf8) })
            XCTAssertTrue(detectKey(mnemonic).isValid)
            var seed = [UInt8](repeating: 0, count: 64)
            let words = Array(vector[1].utf8), phrase = Array("TREZOR".utf8)
            XCTAssertEqual(takeback_bip39_seed(words, words.count, phrase, phrase.count, &seed), 1)
            XCTAssertEqual(seed.hex, vector[2])
            var root = seed
            XCTAssertEqual(takeback_bip32_master(seed, seed.count, &root), 1)
            let decoded = try decode58(vector[3])
            XCTAssertEqual(Data(root.prefix(32)), decoded.suffix(32))
            XCTAssertEqual(Data(root.suffix(32)), decoded.subdata(in: 13..<45))
        }
    }
    func testOfficialBIP32VectorsOneThroughThree() throws {
        let vectors = try JSONDecoder().decode([[String:String]].self, from: Data(OfficialHDVectors.bip32.utf8))
        XCTAssertEqual(vectors.count, 14)
        for v in vectors {
            let seed = [UInt8](try XCTUnwrap(Data(hex: v["seed"]!)))
            let path: [UInt32] = v["path"]!.split(separator: "/").dropFirst().map { UInt32($0.replacingOccurrences(of: "'", with: ""))! | ($0.hasSuffix("'") ? 0x80000000 : 0) }
            var root = [UInt8](repeating: 0, count: 64), node = root
            XCTAssertEqual(takeback_bip32_master(seed, seed.count, &root), 1)
            XCTAssertEqual(takeback_bip32_node(root, path, path.count, &node), 1)
            let expectedPrivate = try decode58(v["priv"]!), expectedPublic = try decode58(v["pub"]!)
            XCTAssertEqual(Data(node.prefix(32)), expectedPrivate.suffix(32))
            XCTAssertEqual(Data(node.suffix(32)), expectedPrivate.subdata(in: 13..<45))
            var pub = [UInt8](repeating: 0, count: 65), count = 0
            XCTAssertEqual(takeback_public(node, [], 0, 1, &pub, &count), 1)
            XCTAssertEqual(Data(pub.prefix(count)), expectedPublic.suffix(33))
            var parentFingerprint = Data(repeating: 0, count: 4)
            if !path.isEmpty {
                XCTAssertEqual(takeback_public(root, Array(path.dropLast()), path.count - 1, 1, &pub, &count), 1)
                parentFingerprint = BitcoinWire.hash160(Data(pub.prefix(count))).prefix(4)
            }
            XCTAssertEqual(parentFingerprint, expectedPrivate.subdata(in: 5..<9))
            XCTAssertEqual(parentFingerprint, expectedPublic.subdata(in: 5..<9))
            XCTAssertEqual(expectedPrivate[4], UInt8(path.count))
            XCTAssertEqual(expectedPublic.subdata(in: 13..<45), Data(node.suffix(32)))
        }
    }
    func testPublishedReceiveAndChangeAddressesAndElectrumHash() throws {
        let key = SecureBytes(), pass = SecureBytes()
        try key.replace(with: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about".utf8)
        defer { key.wipe(); pass.wipe() }
        let plan = try SearchDerivationWork(key: key, passphrase: pass).prepare(plan: XCTUnwrap(detectKey(key).searchPlan))
        let expected: [(AddressStandard, UInt32, String)] = [
            (.bip84,0,"bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"),(.bip84,1,"bc1q8c6fshw2dlwun7ekn9qwf37cu2rn755upcp6el"),
            (.bip86,0,"bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr"),(.bip86,1,"bc1p3qkhfews2uk44qtvauqyr2ttdsw7svhkl9nkm9s9c3x4ax5h60wqwruhk7"),
            (.bip49,0,"37VucYSaXLCAsxYyAPfbSi9eh4iEcbShgf"),(.bip49,1,"34K56kSjgUCUSD8GTtuF7c9Zzwokbs6uZ7"),
            (.bip44,0,"1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA"),(.bip44,1,"1J3J6EvPrv8q6AC3VCjWV45Uf3nssNMRtH")]
        for (type,branch,address) in expected { XCTAssertEqual(try plan.address(type: type, branch: branch, index: 0).chain.address, address) }
        let script = Data(hex: "76a91462e907b15cbf27d5425399ebf6f0fb50ebb88f1888ac")!
        XCTAssertEqual(ChainAddress(address: "", scriptPubKey: script).electrumScriptHash, "8b01df4e368ea28f8dc0423bcf7a4923e3a12d307c875e47a0cfbf90b5c39161")
    }
    func testOfficialBIP143AndBIP341() throws {
        struct Prevout: Decodable { let scriptPubKey: String; let amountSats: Int64 }
        struct Tap: Decodable { let raw: String; let prevouts: [Prevout]; let index: Int; let type: UInt8; let hash: String }
        struct Seg: Decodable { let raw: String; let amount: Int64; let index: Int; let code: String; let hash: String }
        let taps = try JSONDecoder().decode([Tap].self, from: Data(OfficialSighashVectors.taproot.utf8))
        XCTAssertEqual(taps.count, 7)
        for v in taps {
            let outputs = v.prevouts.map { SearchTransaction.Output(scriptpubkey: $0.scriptPubKey, scriptpubkey_address: nil, value: $0.amountSats) }
            XCTAssertEqual(try BitcoinSighash.taproot(WireTransaction(Data(hex: v.raw)!), prevouts: outputs, index: v.index, hashType: v.type).hex, v.hash)
        }
        for v in try JSONDecoder().decode([Seg].self, from: Data(OfficialSighashVectors.segwit.utf8)) {
            XCTAssertEqual(try BitcoinSighash.segwit(WireTransaction(Data(hex: v.raw)!), index: v.index, amount: v.amount, scriptCode: Data(hex: v.code)!).hex, v.hash)
        }
    }
    func testOfficialBIP340SchnorrVectors() throws {
        struct Vector: Decodable { let pub: String; let message: String; let signature: String; let valid: Bool }
        let data = Data(#"[{"pub":"F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9","message":"0000000000000000000000000000000000000000000000000000000000000000","signature":"E907831F80848D1069A5371B402410364BDF1C5F8307B0084C55F1CE2DCA821525F66A4A85EA8B71E482A74F382D2CE5EBEEE8FDB2172F477DF4900D310536C0","valid":true},{"pub":"DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659","message":"243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89","signature":"6896BD60EEAE296DB48A229FF71DFE071BDE413E6D43F917DC8DCF8C78DE33418906D11AC976ABCCB20B091292BFF4EA897EFCB639EA871CFA95F6DE339E4B0A","valid":true},{"pub":"DD308AFEC5777E13121FA72B9CC1B7CC0139715309B086C960E18FD969774EB8","message":"7E2D58D8B3BCDF1ABADEC7829054F90DDA9805AAB56C77333024B9D0A508B75C","signature":"5831AAEED7B44BB74E5EAB94BA9D4294C49BCF2A60728D8B4C200F50DD313C1BAB745879A5AD954A72C45A91C3A51D3C7ADEA98D82F8481E0E1E03674A6F3FB7","valid":true},{"pub":"25D1DFF95105F5253C4022F628A996AD3A0D95FBF21D468A1B33F8C160D8F517","message":"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF","signature":"7EB0509757E246F19449885651611CB965ECC1A187DD51B64FDA1EDC9637D5EC97582B9CB13DB3933705B32BA982AF5AF25FD78881EBB32771FC5922EFC66EA3","valid":true},{"pub":"D69C3509BB99E412E68B0FE8544E72837DFA30746D8BE2AA65975F29D22DC7B9","message":"4DF3C3F68FCC83B27E9D42C90431A72499F17875C81A599B566C9889B9696703","signature":"00000000000000000000003B78CE563F89A0ED9414F5AA28AD0D96D6795F9C6376AFB1548AF603B3EB45C9F8207DEE1060CB71C04E80F593060B07D28308D7F4","valid":true},{"pub":"EEFDEA4CDB677750A420FEE807EACF21EB9898AE79B9768766E4FAA04A2D4A34","message":"243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89","signature":"6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E17776969E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B","valid":false},{"pub":"DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659","message":"243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89","signature":"FFF97BD5755EEEA420453A14355235D382F6472F8568A18B2F057A14602975563CC27944640AC607CD107AE10923D9EF7A73C643E166BE5EBEAFA34B1AC553E2","valid":false},{"pub":"DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659","message":"243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89","signature":"1FA62E331EDBC21C394792D2AB1100A7B432B013DF3F6FF4F99FCB33E0E1515F28890B3EDB6E7189B630448B515CE4F8622A954CFE545735AAEA5134FCCDB2BD","valid":false},{"pub":"DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659","message":"243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89","signature":"6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E177769961764B3AA9B2FFCB6EF947B6887A226E8D7C93E00C5ED0C1834FF0D0C2E6DA6","valid":false},{"pub":"DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659","message":"243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89","signature":"0000000000000000000000000000000000000000000000000000000000000000123DDA8328AF9C23A94C1FEECFD123BA4FB73476F0D594DCB65C6425BD186051","valid":false},{"pub":"DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659","message":"243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89","signature":"00000000000000000000000000000000000000000000000000000000000000017615FBAF5AE28864013C099742DEADB4DBA87F11AC6754F93780D5A1837CF197","valid":false},{"pub":"DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659","message":"243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89","signature":"4A298DACAE57395A15D0795DDBFD1DCB564DA82B0F269BC70A74F8220429BA1D69E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B","valid":false},{"pub":"DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659","message":"243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89","signature":"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F69E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B","valid":false},{"pub":"DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659","message":"243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89","signature":"6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E177769FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141","valid":false},{"pub":"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC30","message":"243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89","signature":"6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E17776969E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B","valid":false},{"pub":"778CAA53B4393AC467774D09497A87224BF9FAB6F6E68B23086497324D6FD117","message":"","signature":"71535DB165ECD9FBBC046E5FFAEA61186BB6AD436732FCCC25291A55895464CF6069CE26BF03466228F19A3A62DB8A649F2D560FAC652827D1AF0574E427AB63","valid":true},{"pub":"778CAA53B4393AC467774D09497A87224BF9FAB6F6E68B23086497324D6FD117","message":"11","signature":"08A20A0AFEF64124649232E0693C583AB1B9934AE63B4C3511F3AE1134C6A303EA3173BFEA6683BD101FA5AA5DBC1996FE7CACFC5A577D33EC14564CEC2BACBF","valid":true},{"pub":"778CAA53B4393AC467774D09497A87224BF9FAB6F6E68B23086497324D6FD117","message":"0102030405060708090A0B0C0D0E0F1011","signature":"5130F39A4059B43BC7CAC09A19ECE52B5D8699D1A71E3C52DA9AFDB6B50AC370C4A482B77BF960F8681540E25B6771ECE1E5A37FD80E5A51897C5566A97EA5A5","valid":true},{"pub":"778CAA53B4393AC467774D09497A87224BF9FAB6F6E68B23086497324D6FD117","message":"99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999","signature":"403B12B0D8555A344175EA7EC746566303321E5DBFA8BE6F091635163ECA79A8585ED3E3170807E7C03B720FC54C7B23897FCBA0E9D0B4A06894CFD249F22367","valid":true}]"#.utf8)
        let vectors = try JSONDecoder().decode([Vector].self, from: data)
        XCTAssertEqual(vectors.count, 19)
        for v in vectors {
            let pub = [UInt8](Data(hex: v.pub)!), message = [UInt8](Data(hex: v.message)!), signature = [UInt8](Data(hex: v.signature)!)
            XCTAssertEqual(takeback_schnorr_verify_message(pub, message, message.count, signature) == 1, v.valid)
        }
    }
    private func decode58(_ value: String) throws -> Data {
        let bytes = SecureBytes(); try bytes.replace(with: value.utf8); defer { bytes.wipe() }
        let decoded = try XCTUnwrap(bytes.withUnsafeBytes { KeyValidation.base58Check($0) }); defer { decoded.wipe() }
        return decoded.withUnsafeBytes { Data($0) }
    }
}
