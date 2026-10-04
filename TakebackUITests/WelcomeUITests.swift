import XCTest

@MainActor final class WelcomeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testColdLaunchAndReservedRoutes() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["welcome.cancel"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["How it works"].exists)
        app.buttons["welcome.cancel"].tap()
        XCTAssertFalse(app.buttons["welcome.cancel"].isHittable)
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 3))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["welcome.cancel"].waitForExistence(timeout: 3))
        app.buttons["welcome.settings"].tap()
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 3))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["welcome.howItWorks"].waitForExistence(timeout: 3))
    }

    func testNativeSheetFitsContentAndCloses() { checkNativeSheet() }

    func testNativeSheetInLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        checkNativeSheet()
    }

    private func checkNativeSheet() {
        let app = XCUIApplication()
        app.launch()
        let welcome = app.buttons["welcome.howItWorks"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 10))
        welcome.tap()
        XCTAssertTrue(app.staticTexts["Find the payment"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Prove it’s yours"].exists)
        XCTAssertTrue(app.staticTexts["Send it back with a higher fee"].exists)
        if !app.staticTexts["When it can’t work"].isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(app.staticTexts["When it can’t work"].isHittable)
        let sheetTop = app.navigationBars.firstMatch.frame.minY
        if app.frame.height > 700 {
            XCTAssertGreaterThan(sheetTop, app.frame.height * 0.15, "Normal text should use a fitted sheet, not full height.")
        }
        capture("native-how-it-works", app: app)
        app.buttons["Close"].tap()
        XCTAssertTrue(welcome.waitForExistence(timeout: 3))
        XCTAssertTrue(welcome.isHittable)
    }

    func testWelcomeHasVisibleFixedButtonsAtAX3() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        let primary = app.buttons["welcome.cancel"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10))
        XCTAssertTrue(primary.isHittable)
        XCTAssertTrue(app.buttons["welcome.howItWorks"].isHittable)
        XCTAssertEqual(app.buttons.matching(identifier: primary.identifier).firstMatch.frame.height, 56, accuracy: 1)
        XCTAssertEqual(app.buttons.matching(identifier: app.buttons["welcome.howItWorks"].identifier).firstMatch.frame.height, 48, accuracy: 1)
        capture("native-welcome-AX3", app: app)
        app.buttons["welcome.howItWorks"].tap()
        XCTAssertTrue(app.staticTexts["Find the payment"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close"].isHittable)
        capture("native-how-it-works-AX3", app: app)
        app.buttons["Close"].tap()
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
