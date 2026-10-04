import XCTest
@testable import Takeback

@MainActor final class PassphraseTests: XCTestCase {
    private let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private func session(_ phrase: String = "") throws -> SecretSession {
        let value = SecretSession()
        try value.key.replace(with: mnemonic.utf8)
        try value.passphrase.replace(with: phrase.utf8)
        return value
    }
    func testIndependentFingerprintVectorsAndScratchClearing() async throws {
        struct Fixtures: Decodable {
            struct Vector: Decodable { let passphrase: String; let fingerprint: String }
            let mnemonic: String; let vectors: [Vector]
        }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "FingerprintVectors", withExtension: "json"))
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixtures.vectors.first?.fingerprint, "73C5DA0A")
        XCTAssertEqual(fixtures.vectors[1].fingerprint, "B4E3F5ED")
        for vector in fixtures.vectors {
            let session = try session(vector.passphrase)
            let work = FingerprintWork(mnemonic: session.key, passphrase: session.passphrase)
            let result = await FingerprintEngine.compute(work)
            XCTAssertEqual(result?.withPassphrase, vector.fingerprint)
            XCTAssertEqual(result?.withoutPassphrase, "73C5DA0A")
            XCTAssertTrue(work.isCleared)
            session.wipe()
        }
        XCTAssertEqual(WalletFingerprints.formatted("b4e3f5ed"), "B4E3 F5ED")
    }
    func testWhitespaceIsPreservedAndDoneCommitsExactDraft() async throws {
        let session = try session()
        let model = PassphraseModel(session: session)
        XCTAssertFalse(model.canSave)
        let text = " TREZOR "
        try model.draft.replace(with: text.utf8); model.edited()
        XCTAssertTrue(model.startsWithSpace); XCTAssertTrue(model.endsWithSpace); XCTAssertTrue(model.canSave)
        XCTAssertEqual(session.passphrase.count, 0)
        var saved = false
        model.save { saved = true }
        try await waitUntil { saved }
        XCTAssertTrue(session.passphrase.withUnsafeBytes { $0.elementsEqual(text.utf8) })
        XCTAssertEqual(session.passphraseFingerprint, "9a2a7b73")
        XCTAssertEqual(model.draft.count, 0); XCTAssertTrue(model.isClosed)
        session.wipe()
    }
    func testCloseDiscardsEditsAndRemoveZeroesCommittedBuffer() async throws {
        let session = try session("TREZOR")
        session.setPassphraseFingerprint("B4E3F5ED")
        let model = PassphraseModel(session: session)
        XCTAssertTrue(model.isEditing); XCTAssertTrue(model.canSave)
        XCTAssertTrue(model.draft.withUnsafeBytes { $0.elementsEqual("TREZOR".utf8) })
        try model.draft.replace(with: "different".utf8); model.edited(); model.discard()
        XCTAssertEqual(model.draft.count, 0)
        XCTAssertTrue(session.passphrase.withUnsafeBytes { $0.elementsEqual("TREZOR".utf8) })
        XCTAssertEqual(session.passphraseFingerprint, "b4e3f5ed")
        let edit = PassphraseModel(session: session)
        session.passphrase.withUnsafeBytes { bytes in
            edit.remove()
            XCTAssertTrue(bytes.allSatisfy { $0 == 0 })
        }
        XCTAssertEqual(session.passphrase.count, 0); XCTAssertNil(session.passphraseFingerprint)
        XCTAssertEqual(edit.draft.count, 0); XCTAssertTrue(edit.isClosed)
    }
    func testDoneAlwaysEnabledForEmptyEditAndClearsPassphrase() async throws {
        let session = try session("TREZOR")
        let model = PassphraseModel(session: session)
        model.draft.wipe(); model.edited()
        XCTAssertTrue(model.isEmpty); XCTAssertTrue(model.canSave)
        var saved = false
        model.save { saved = true }
        try await waitUntil { saved }
        XCTAssertEqual(session.passphrase.count, 0); XCTAssertNil(session.passphraseFingerprint)
    }
    func testSessionWipeClearsDraftAndCannotBeResurrectedByLateResult() async throws {
        let session = try session("TREZOR")
        let gate = FingerprintGate()
        let model = PassphraseModel(session: session, compute: { await gate.compute($0) })
        var saved = false
        model.save { saved = true }
        try await waitForCalls(1, gate)
        session.wipe()
        XCTAssertEqual(model.draft.count, 0); XCTAssertTrue(model.isClosed)
        let cleared = await gate.isCleared(1); XCTAssertTrue(cleared)
        await gate.finish(1, fingerprint: "B4E3F5ED")
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(saved); XCTAssertNil(model.fingerprints)
        XCTAssertEqual(session.passphrase.count, 0); XCTAssertNil(session.passphraseFingerprint)
    }
    func testDebounceAndOutOfOrderComputationsCannotPublishStaleFingerprint() async throws {
        let session = try session()
        let gate = FingerprintGate()
        let model = PassphraseModel(session: session, compute: { await gate.compute($0) })
        try model.draft.replace(with: "one".utf8); model.edited()
        try await Task.sleep(for: .milliseconds(100))
        let earlyCalls = await gate.calls; XCTAssertEqual(earlyCalls, 0)
        try await waitForCalls(1, gate)
        try model.draft.replace(with: "two".utf8); model.edited()
        let oldCleared = await gate.isCleared(1); XCTAssertTrue(oldCleared)
        try await waitForCalls(2, gate)
        await gate.finish(2, fingerprint: "22222222")
        try await waitUntil { model.fingerprints?.withPassphrase == "22222222" }
        await gate.finish(1, fingerprint: "11111111")
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(model.fingerprints?.withPassphrase, "22222222")
        model.discard()
    }
    func testChangedKeyCannotCommitOldDraftAndRowFingerprintIsInvalidated() async throws {
        let session = try session("TREZOR")
        session.setPassphraseFingerprint("B4E3F5ED")
        let model = PassphraseModel(session: session)
        try session.key.replace(with: "abandon abandon".utf8)
        let entry = EnterKeyModel(session: session)
        entry.edited()
        XCTAssertNil(session.passphraseFingerprint)
        var saved = false
        model.save { saved = true }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(saved)
        XCTAssertNil(session.passphraseFingerprint)
        model.discard(); session.wipe()
    }
    func testIncompleteMnemonicHasNoInventedFingerprintAndCancelledWorkIsCleared() async throws {
        let session = try session("TREZOR")
        try session.key.replace(with: "abandon abandon".utf8)
        let work = FingerprintWork(mnemonic: session.key, passphrase: session.passphrase)
        let result = await FingerprintEngine.compute(work)
        XCTAssertNil(result); XCTAssertTrue(work.isCleared)
        let cancelled = FingerprintWork(mnemonic: session.key, passphrase: session.passphrase)
        cancelled.cancel()
        let cancelledResult = await FingerprintEngine.compute(cancelled)
        XCTAssertNil(cancelledResult); XCTAssertTrue(cancelled.isCleared)
        session.wipe()
    }
    private func waitUntil(_ predicate: () -> Bool) async throws {
        for _ in 0..<150 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Timed out waiting for public state")
    }
    private func waitForCalls(_ count: Int, _ gate: FingerprintGate) async throws {
        for _ in 0..<150 {
            if await gate.calls >= count { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Computation did not start")
    }
}

private actor FingerprintGate {
    var calls = 0
    private var pending: [Int: CheckedContinuation<WalletFingerprints?, Never>] = [:]
    private var work: [Int: FingerprintWork] = [:]
    func compute(_ input: FingerprintWork) async -> WalletFingerprints? {
        calls += 1
        let id = calls; work[id] = input
        // Deliberately ignores task cancellation to exercise the model's generation check.
        return await withCheckedContinuation { pending[id] = $0 }
    }
    func isCleared(_ id: Int) -> Bool { work[id]?.isCleared == true }
    func finish(_ id: Int, fingerprint: String) {
        pending.removeValue(forKey: id)?.resume(returning: .init(withPassphrase: fingerprint, withoutPassphrase: "73C5DA0A"))
    }
}
