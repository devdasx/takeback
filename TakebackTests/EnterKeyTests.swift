import XCTest
import UIKit
@testable import Takeback

@MainActor final class EnterKeyTests: XCTestCase {
    private let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private let hex = String(repeating: "0", count: 63) + "1"

    func testPasteReadsOnceAndClearsOnlyValidPrivateClipboard() throws {
        for (input, shouldClear) in [(phrase,true),(hex,true),("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",false),("abandon abandon",false),("unrelated clipboard",false)] {
            let clipboard = FakeClipboard(input)
            let model = EnterKeyModel(session: SecretSession(), clipboard: clipboard)
            model.paste()
            XCTAssertEqual(clipboard.reads, 1)
            XCTAssertEqual(clipboard.clears, shouldClear ? 1 : 0)
            XCTAssertEqual(model.canFind, shouldClear)
        }
    }
    func testPasteDoesNotEraseAChangedClipboardOrAcceptOversizedInput() {
        let clipboard = FakeClipboard(hex)
        clipboard.changeOnRead = true
        let model = EnterKeyModel(session: SecretSession(), clipboard: clipboard)
        model.paste()
        XCTAssertTrue(model.canFind); XCTAssertEqual(clipboard.clears, 0)
        clipboard.value = String(repeating: "a", count: 5000)
        model.paste()
        XCTAssertFalse(model.canFind); XCTAssertTrue(model.hasError)
        XCTAssertEqual(model.session.key.count, 0)
    }
    func testSwitchingFromPhraseZeroesPassphraseAndFingerprint() throws {
        let session = SecretSession()
        try session.key.replace(with: phrase.utf8)
        let model = EnterKeyModel(session: session)
        try session.passphrase.replace(with: "synthetic fixture".utf8)
        session.setPassphraseFingerprint("1234abcd")
        try session.key.replace(with: hex.utf8)
        session.passphrase.withUnsafeBytes { storage in
            model.classify(settled: true)
            XCTAssertTrue(storage.allSatisfy { $0 == 0 })
        }
        XCTAssertEqual(session.passphrase.count, 0); XCTAssertNil(session.passphraseFingerprint)
        XCTAssertFalse(model.showsPassphrase)
    }
    func testBackWipesBothNativeEditorAndModelAndCancelsPendingDetection() async throws {
        let session = SecretSession()
        let router = WelcomeRouter(session: session)
        router.cancelTransaction()
        let model = EnterKeyModel(session: session)
        try session.key.replace(with: hex.utf8)
        try session.passphrase.replace(with: "fixture".utf8)
        var cleared = false
        let id = session.registerEditorClear { cleared = true }
        model.edited()
        router.returnToWelcome()
        try await Task.sleep(for: .milliseconds(1400))
        XCTAssertTrue(cleared); XCTAssertEqual(session.key.count, 0); XCTAssertEqual(session.passphrase.count, 0)
        XCTAssertEqual(model.detection, .empty); XCTAssertFalse(model.canFind); XCTAssertFalse(model.hasError)
        session.unregisterEditorClear(id)
    }
    func testDebounceIdleTimingAndImmediateButtonGating() async throws {
        let session = SecretSession()
        try session.key.replace(with: hex.utf8)
        let model = EnterKeyModel(session: session)
        XCTAssertTrue(model.canFind)
        try session.key.replace(with: "abandon abandon".utf8)
        model.edited()
        XCTAssertFalse(model.canFind); XCTAssertTrue(model.isDetecting)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(model.status, "Recovery phrase · 2 words so far"); XCTAssertFalse(model.hasError)
        try await Task.sleep(for: .milliseconds(1100))
        XCTAssertTrue(model.hasError)
        XCTAssertEqual(model.status, "Recovery phrases have 12, 15, 18, 21 or 24 words")
    }
    func testSearchBoundaryRevalidatesAndNormalizesWithoutPuttingKeyInRoute() throws {
        let session = SecretSession()
        try session.key.replace(with: (" \n" + phrase.uppercased().replacingOccurrences(of: " ", with: "\t  ") + " ").utf8)
        let model = EnterKeyModel(session: session)
        let plan = try XCTUnwrap(model.prepareSearch())
        XCTAssertEqual(plan.origin, .mnemonic)
        XCTAssertTrue(session.key.withUnsafeBytes { $0.elementsEqual(phrase.utf8) })
        let router = WelcomeRouter(session: session)
        router.cancelTransaction(); router.findPendingPayments(plan)
        XCTAssertEqual(router.path, [.enterKey,.finding(plan)])
        router.goBack()
        XCTAssertGreaterThan(session.key.count, 0)
        try session.key.replace(with: "invalid".utf8) // Catch a changed buffer even before the UI callback.
        XCTAssertNil(model.prepareSearch())
    }
    func testClearWipesAndResetsAndSettingsBackPreservesSession() throws {
        let session = SecretSession()
        try session.key.replace(with: hex.utf8)
        let model = EnterKeyModel(session: session)
        let router = WelcomeRouter(session: session)
        router.cancelTransaction(); router.openSettings(); router.goBack()
        XCTAssertEqual(router.path, [.enterKey]); XCTAssertTrue(model.canFind)
        model.clear()
        XCTAssertFalse(model.hasInput); XCTAssertFalse(model.canFind); XCTAssertEqual(model.detection, .empty)
    }
    func testNativeEditorBlocksSecretExport() {
        XCTAssertFalse(AppDelegate().application(.shared, shouldAllowExtensionPointIdentifier: .keyboard))
        let editor = ProtectedTextView()
        editor.text = "synthetic fixture"
        XCTAssertFalse(editor.canPerformAction(#selector(UIResponderStandardEditActions.copy(_:)), withSender: nil))
        XCTAssertFalse(editor.canPerformAction(#selector(UIResponderStandardEditActions.cut(_:)), withSender: nil))
        var pasted = false
        editor.pasteInput = { pasted = true }
        editor.paste(nil)
        XCTAssertTrue(pasted)
    }
}

@MainActor private final class FakeClipboard: KeyClipboard {
    var value: String?
    var reads = 0, clears = 0, changeCount = 1
    var changeOnRead = false
    init(_ value: String) { self.value = value }
    func read() -> String? { reads += 1; if changeOnRead { changeCount += 1 }; return value }
    func clear() { clears += 1; value = nil; changeCount += 1 }
}
