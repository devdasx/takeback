import XCTest

@MainActor final class PassphraseUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func openSheet(_ app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.buttons["welcome.cancel"].waitForExistence(timeout: 10))
        app.buttons["welcome.cancel"].tap()
        let key = app.textViews["enterKey.field"]
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        for _ in 0..<3 where key.frame.maxY > app.buttons["enterKey.find"].frame.minY {
            scrollEntryUp(app)
        }
        key.tap()
        key.typeText("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
        let row = app.buttons["enterKey.passphrase"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        showPassphrase(app)
        XCTAssertTrue(app.secureTextFields["passphrase.field"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["passphrase.done"].isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["Close"].frame.minY, 20)
        XCTAssertTrue(app.secureTextFields["passphrase.field"].isHittable)
    }
    func testLiveFingerprintSpacesSaveHiddenEditCloseAndRemove() {
        let app = XCUIApplication()
        openSheet(app)
        XCTAssertFalse(app.buttons["passphrase.done"].isEnabled)
        XCTAssertTrue(app.staticTexts["Without a passphrase · 73C5 DA0A"].waitForExistence(timeout: 5))
        capture("empty")
        app.secureTextFields["passphrase.field"].typeText("TREZOR")
        XCTAssertTrue(app.staticTexts["With this passphrase · B4E3 F5ED"].waitForExistence(timeout: 5))
        capture("typed")
        app.buttons["passphrase.visibility"].tap()
        XCTAssertEqual(app.textFields["passphrase.field"].value as? String, "TREZOR")
        XCTAssertEqual(app.buttons["passphrase.visibility"].label, "Hide passphrase")
        app.textFields["passphrase.field"].typeText(" ")
        XCTAssertTrue(app.staticTexts["Ends with a space"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["With this passphrase · 1727 E924"].waitForExistence(timeout: 5))
        capture("trailing-space")
        app.buttons["passphrase.done"].tap()
        XCTAssertTrue(app.staticTexts["•••••• · 1727 E924"].waitForExistence(timeout: 5))
        capture("set-row")
        showPassphrase(app)
        XCTAssertTrue(app.secureTextFields["passphrase.field"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["passphrase.done"].isEnabled)
        capture("edit")
        app.buttons["passphrase.visibility"].tap()
        XCTAssertEqual(app.textFields["passphrase.field"].value as? String, "TREZOR ")
        app.buttons["passphrase.visibility"].tap()
        app.secureTextFields["passphrase.field"].typeText("changed")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["•••••• · 1727 E924"].waitForExistence(timeout: 5))
        showPassphrase(app)
        XCTAssertTrue(app.buttons["passphrase.remove"].waitForExistence(timeout: 5))
        for _ in 0..<4 where !app.buttons["passphrase.remove"].isHittable { scrollSheetUp(app) }
        XCTAssertTrue(app.buttons["passphrase.remove"].isHittable, "scroll=\(app.scrollViews["passphrase.content"].frame), remove=\(app.buttons["passphrase.remove"].frame), visibleBottom=\(visibleSheetBottom(app))")
        capture("remove-visible")
        app.buttons["passphrase.remove"].tap()
        XCTAssertTrue(app.staticTexts["None"].waitForExistence(timeout: 5))
    }
    func testZDarkSheetAndAccessibilityTextRemainScrollable() {
        let app = XCUIApplication()
        // The host run sets this dedicated simulator's appearance to dark.
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        openSheet(app)
        let field = app.secureTextFields["passphrase.field"]
        field.typeText(" TREZOR")
        XCTAssertTrue(app.staticTexts["Starts with a space"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["passphrase.done"].isHittable)
        capture("dark-AX5")
        let explanation = app.staticTexts["Every passphrase opens a different wallet. Case, spaces and symbols count."]
        for _ in 0..<24 where explanation.frame.maxY > visibleSheetBottom(app) {
            scrollSheetUp(app)
        }
        XCTAssertLessThanOrEqual(explanation.frame.maxY, visibleSheetBottom(app) + 1)
        capture("dark-AX5-scrolled")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["None"].waitForExistence(timeout: 5))
    }
    func testNativeSoftwareKeyboardPresentation() {
        let app = XCUIApplication()
        openSheet(app)
        let visibleKeyboard = NSPredicate { _, _ in
            app.keyboards.firstMatch.exists && app.keyboards.firstMatch.frame.minY < app.frame.maxY - 100
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: visibleKeyboard, object: nil)], timeout: 5), .completed,
                       "keyboardFrames=" + app.keyboards.allElementsBoundByIndex.map { "\($0.frame)" }.joined(separator: ","))
        XCTAssertLessThanOrEqual(app.secureTextFields["passphrase.field"].frame.maxY, app.keyboards.firstMatch.frame.minY)
        capture("visible-keyboard")
        app.buttons["passphrase.visibility"].tap()
        let letter = app.keyboards.keys["a"]
        XCTAssertTrue(letter.waitForExistence(timeout: 3))
        XCTAssertTrue(letter.isHittable)
        letter.tap()
        XCTAssertEqual(app.textFields["passphrase.field"].value as? String, "a")
        capture("visible-keyboard-revealed")
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "passphrase-" + name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func showPassphrase(_ app: XCUIApplication) {
        let row = app.buttons["enterKey.passphrase"]
        for _ in 0..<4 where row.frame.maxY > app.buttons["enterKey.find"].frame.minY || !row.isHittable {
            scrollEntryUp(app)
        }
        XCTAssertLessThanOrEqual(row.frame.maxY, app.buttons["enterKey.find"].frame.minY)
        row.tap()
    }
    private func visibleSheetBottom(_ app: XCUIApplication) -> CGFloat {
        let screenBottom = app.frame.maxY
        guard app.keyboards.firstMatch.exists else { return screenBottom }
        let keyboardTop = app.keyboards.firstMatch.frame.minY
        // UIKit exposes the Passwords/input-assistant strip as a separate scroll view,
        // outside the Keyboard element's frame. Include its actual bounds.
        let accessory = app.scrollViews.firstMatch
        if accessory.exists, accessory.identifier != "passphrase.content",
           accessory.frame.height < 100, accessory.frame.maxY <= keyboardTop + 1,
           accessory.frame.minY >= keyboardTop - 100 {
            return min(screenBottom, accessory.frame.minY)
        }
        return min(screenBottom, keyboardTop)
    }
    private func scrollSheetUp(_ app: XCUIApplication) {
        let scroll = app.scrollViews["passphrase.content"]
        // Native scroll views may extend behind the keyboard with adjusted insets.
        // Keep the entire gesture in the visible content, away from that keyboard.
        let top = max(scroll.frame.minY, app.buttons["passphrase.done"].frame.maxY) + 20
        let limit = min(scroll.frame.maxY, visibleSheetBottom(app))
        let bottom = top + (limit - top) * 0.75
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let x = scroll.frame.midX
        origin.withOffset(CGVector(dx: x, dy: bottom)).press(forDuration: 0.1,
            thenDragTo: origin.withOffset(CGVector(dx: x, dy: top)))
    }
    private func scrollEntryUp(_ app: XCUIApplication) {
        // The key editor is itself scrollable. Drag the outer form's margin so the
        // gesture cannot be swallowed by that editor or the keyboard/pinned action.
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0))
        let start = origin.withOffset(CGVector(dx: 0, dy: app.buttons["enterKey.find"].frame.minY - 20))
        start.press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: 0, dy: 90)))
    }
}
