import XCTest

@MainActor final class EnterKeyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func openEntry(_ app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.buttons["welcome.cancel"].waitForExistence(timeout: 10))
        app.buttons["welcome.cancel"].tap()
        XCTAssertTrue(app.textViews["enterKey.field"].waitForExistence(timeout: 5))
    }
    func testTypingValidationKeyboardFindAndBackWipe() {
        let app = XCUIApplication()
        openEntry(app)
        let find = app.buttons["enterKey.find"]
        XCTAssertFalse(find.isEnabled)
        let field = app.textViews["enterKey.field"]
        field.tap()
        field.typeText(String(repeating: "0", count: 63) + "1") // Public synthetic scalar-one vector.
        XCTAssertTrue(app.staticTexts["Private key · hex · 64 characters"].waitForExistence(timeout: 3))
        XCTAssertTrue(find.isEnabled); XCTAssertTrue(find.isHittable)
        XCTAssertLessThanOrEqual(find.frame.maxY, app.keyboards.firstMatch.frame.minY)
        capture("hex-with-keyboard", app)
        find.tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 3))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 3))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["welcome.cancel"].tap()
        XCTAssertTrue(app.buttons["enterKey.paste"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["enterKey.find"].isEnabled)
    }
    func testRecoveryPhrasePassphraseRouteAndClear() {
        let app = XCUIApplication()
        openEntry(app)
        let field = app.textViews["enterKey.field"]
        field.tap()
        field.typeText("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
        XCTAssertTrue(app.staticTexts["Recovery phrase · 12 words"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["enterKey.passphrase"].exists)
        if !app.buttons["enterKey.passphrase"].isHittable { app.scrollViews.firstMatch.swipeUp() }
        app.buttons["enterKey.passphrase"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 3))
        app.buttons["Close"].tap()
        app.buttons["enterKey.clear"].tap()
        XCTAssertFalse(app.buttons["enterKey.find"].isEnabled)
        XCTAssertFalse(app.buttons["enterKey.passphrase"].exists)
        capture("empty-after-clear", app)
    }
    func testIncompletePhraseErrorAndScannerRoute() {
        let app = XCUIApplication()
        openEntry(app)
        app.textViews["enterKey.field"].tap()
        app.textViews["enterKey.field"].typeText("abandon abandon")
        XCTAssertTrue(app.staticTexts["Recovery phrases have 12, 15, 18, 21 or 24 words"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["enterKey.find"].isEnabled)
        app.buttons["enterKey.scan"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 3))
        app.buttons["Close"].tap()
        XCTAssertTrue(app.textViews["enterKey.field"].waitForExistence(timeout: 3))
    }
    func testAX5EmptyAndLandscapeKeepActionsVisible() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        openEntry(app)
        XCTAssertTrue(app.buttons["enterKey.find"].isHittable)
        XCTAssertTrue(app.toolbars.buttons.matching(identifier: app.buttons["enterKey.find"].identifier).firstMatch.exists)
        capture("entry-AX5", app)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let rotated = NSPredicate { _, _ in app.frame.width > app.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rotated, object: nil)], timeout: 5), .completed)
        Thread.sleep(forTimeInterval: 1) // Let the native rotation finish before pixel capture.
        XCTAssertTrue(app.buttons["enterKey.find"].isHittable)
        capture("entry-landscape-AX5", app)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        // Capture the full display: app-element cropping is unreliable after rotation.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
