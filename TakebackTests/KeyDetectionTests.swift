import XCTest
@testable import Takeback

final class KeyDetectionTests: XCTestCase {
    struct Vector: Decodable { let id: String; let input: String; let kind: String; let valid: Bool }
    func testDetectionMatrixAndAdversarialVectors() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "KeyVectors", withExtension: "json"))
        let vectors = try JSONDecoder().decode([Vector].self, from: Data(contentsOf: url))
        XCTAssertEqual(vectors.count, 68)
        for vector in vectors {
            let input = SecureBytes()
            try input.replace(with: vector.input.utf8)
            let result = detectKey(input)
            XCTAssertEqual(result.isValid, vector.valid, vector.id)
            XCTAssertEqual(kind(result), vector.kind, vector.id)
            XCTAssertEqual(input.withUnsafeBytes { $0.elementsEqual(vector.input.utf8) }, true, "Detector must not mutate caller: \(vector.id)")
            input.wipe()
        }
    }
    func testSearchPlansPreserveOriginStandardsAndBothBranches() throws {
        let phrase = KeyDetection.phrase(words: 12, checksumValid: true).searchPlan
        XCTAssertEqual(phrase?.origin, .mnemonic)
        XCTAssertEqual(phrase?.standards, [.bip86,.bip84,.bip49,.bip44])
        XCTAssertEqual(phrase?.branches, [0,1])
        for prefix in [ExtendedPrivatePrefix.xprv, .yprv, .zprv] {
            for depth: UInt8 in [0,3] {
                let plan = try XCTUnwrap(KeyDetection.extended(prefix: prefix, depth: depth, childNumber: 0x80000002).searchPlan)
                XCTAssertEqual(plan.origin, depth == 0 ? .master : .account(childNumber: 0x80000002))
                XCTAssertEqual(plan.standards, depth == 0 ? [.bip86,.bip84,.bip49,.bip44] : prefix == .xprv ? [.bip44] : prefix == .yprv ? [.bip49] : [.bip84])
                XCTAssertEqual(plan.branches, [0,1])
            }
        }
        for key in [KeyDetection.wif(compressed: true), .hex] {
            XCTAssertEqual(key.searchPlan?.singleAddresses, [.p2tr,.p2wpkh,.p2shP2wpkh,.p2pkh])
            XCTAssertEqual(key.searchPlan?.branches, [])
        }
        XCTAssertEqual(KeyDetection.mini(length: 30).searchPlan?.singleAddresses, [.p2pkh])
        XCTAssertEqual(KeyDetection.wif(compressed: false).searchPlan?.singleAddresses, [.p2pkh])
        for key in [KeyDetection.empty,.phrase(words: 3, checksumValid: false),.publicOnly,.testnet,.unrecognized] { XCTAssertNil(key.searchPlan) }
    }
    func testStatusCopyAndIdleErrors() {
        let incomplete = KeyDetection.phrase(words: 3, checksumValid: false)
        XCTAssertEqual(incomplete.label(settled: false), "Recovery phrase · 3 words so far")
        XCTAssertFalse(incomplete.isError(settled: false))
        XCTAssertEqual(incomplete.label(settled: true), "Recovery phrases have 12, 15, 18, 21 or 24 words")
        XCTAssertTrue(incomplete.isError(settled: true))
        XCTAssertFalse(KeyDetection.unrecognized.isError(settled: false))
        XCTAssertTrue(KeyDetection.unrecognized.isError(settled: true))
        XCTAssertEqual(KeyDetection.publicOnly.label(settled: true), "That’s public. Canceling needs the private key or recovery phrase.")
        XCTAssertEqual(KeyDetection.testnet.label(settled: true), "This is a testnet key")
    }
    private func kind(_ result: KeyDetection) -> String {
        switch result {
        case .empty: "empty"
        case .phrase(_, true): "phrase"
        case .phrase(let count, false): KeyDetection.phraseCounts.contains(count) ? "invalid" : "incomplete"
        case .wif(let compressed): compressed ? "compressed" : "uncompressed"
        case .mini: "mini"
        case .hex: "hex"
        case .extended(let prefix, _, _): prefix.rawValue
        case .publicOnly: "public"
        case .testnet: "testnet"
        case .unrecognized: "invalid"
        }
    }
}
