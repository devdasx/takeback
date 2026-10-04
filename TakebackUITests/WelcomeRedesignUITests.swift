import XCTest

@MainActor final class WelcomeRedesignUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testWelcomeAndOpenSourceSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["--welcome-redesign-ui"]
        if ProcessInfo.processInfo.environment["TAKEBACK_WELCOME_AX3"] == "1" {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        }
        app.launch()
        let primary = app.buttons["welcome.cancel"], source = app.buttons["welcome.source"]
        XCTAssertTrue(primary.waitForExistence(timeout: 8)); XCTAssertTrue(primary.isHittable)
        XCTAssertEqual(primary.label, "Cancel a payment")
        XCTAssertTrue(app.toolbars.buttons.matching(identifier: primary.identifier).firstMatch.exists)
        XCTAssertTrue(app.toolbars.buttons.matching(identifier: app.buttons["welcome.howItWorks"].identifier).firstMatch.exists)
        capture("welcome-initial")
        if ProcessInfo.processInfo.environment["TAKEBACK_WELCOME_AX3"] != "1" {
            XCTAssertTrue(source.isHittable, "Trust points must be visible at default text size")
        }
        for _ in 0..<8 where !source.isHittable { app.scrollViews["welcome.content"].swipeUp() }
        XCTAssertTrue(source.isHittable)
        let first = app.staticTexts["welcome.trust.biometry.label"], second = app.staticTexts["welcome.trust.keys.label"]
        XCTAssertTrue(first.exists); XCTAssertTrue(second.exists)
        XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 1)
        if ProcessInfo.processInfo.environment["TAKEBACK_WELCOME_AX3"] != "1" {
            XCTAssertLessThanOrEqual(first.frame.maxY, primary.frame.minY)
            XCTAssertLessThanOrEqual(second.frame.maxY, primary.frame.minY)
        }
        source.tap()
        let github = app.buttons["source.github"]
        XCTAssertTrue(github.waitForExistence(timeout: 5)); XCTAssertTrue(github.isHittable)
        let last = app.staticTexts["Run it yourself"]
        for _ in 0..<10 where !last.isHittable { app.scrollViews["source.content"].swipeUp() }
        XCTAssertTrue(last.isHittable); XCTAssertTrue(github.isHittable)
        capture("source-scrolled")
        github.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 10), "Native Safari view is presented")
        capture("source-browser")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5)); app.buttons["Close"].tap()
        XCTAssertTrue(primary.waitForExistence(timeout: 5)); primary.tap()
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5)); app.navigationBars.buttons.firstMatch.tap()
        app.buttons["welcome.settings"].tap()
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5)); app.navigationBars.buttons.firstMatch.tap()
        app.buttons["welcome.howItWorks"].tap()
        XCTAssertTrue(app.staticTexts["Find the payment"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
