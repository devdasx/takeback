import XCTest

@MainActor final class FindingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func enter(_ mode: String, phrase: Bool = false, ax: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments += [mode]
        if ax { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["welcome.cancel"].waitForExistence(timeout: 10)); app.buttons["welcome.cancel"].tap()
        let field = app.textViews["enterKey.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        field.typeText(phrase ? "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about" : String(repeating: "0", count: 63) + "1")
        let find = app.buttons["enterKey.find"]
        XCTAssertTrue(find.isEnabled); find.tap()
        XCTAssertTrue(app.staticTexts["finding.title"].waitForExistence(timeout: 5))
        return app
    }
    func testStopKeepsKeyAndDifferentKeyClears() {
        let app = enter("-finding-ui-slow")
        XCTAssertTrue(app.buttons["finding.stop"].isHittable)
        capture("finding-searching", app)
        app.buttons["finding.stop"].tap()
        XCTAssertTrue(app.buttons["enterKey.find"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["enterKey.find"].isEnabled)
        app.terminate()
        let none = enter("-finding-ui-none")
        XCTAssertTrue(none.buttons["finding.different"].waitForExistence(timeout: 5))
        XCTAssertFalse(none.buttons["finding.deep"].exists)
        capture("finding-none", none)
        none.buttons["finding.different"].tap()
        XCTAssertTrue(none.buttons["enterKey.paste"].waitForExistence(timeout: 5))
        XCTAssertFalse(none.buttons["enterKey.find"].isEnabled)
    }
    func testPhraseDeepSearchAndBackKeepKey() {
        let app = enter("-finding-ui-none", phrase: true)
        let deep = app.buttons["finding.deep"]
        let action = deep
        XCTAssertTrue(action.waitForExistence(timeout: 5)); action.tap()
        XCTAssertTrue(app.staticTexts["Checked 100 addresses per path on 4 paths and found nothing waiting."].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["enterKey.find"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["enterKey.find"].isEnabled)
    }
    func testOfflineRetryAndServerSettingsRoute() {
        let app = enter("-finding-ui-offline")
        XCTAssertTrue(app.staticTexts["You’re offline"].waitForExistence(timeout: 5))
        app.buttons["finding.retry"].tap()
        XCTAssertTrue(app.staticTexts["You’re offline"].waitForExistence(timeout: 5))
        capture("finding-offline", app)
        app.terminate()
        let servers = enter("-finding-ui-servers")
        XCTAssertTrue(servers.buttons["Choose a server"].waitForExistence(timeout: 5))
        capture("finding-servers", servers)
        servers.buttons["Choose a server"].tap()
        XCTAssertTrue(servers.otherElements["route.settings.server"].waitForExistence(timeout: 5))
    }
    func testAX5AndLandscapePinActions() {
        let app = enter("-finding-ui-none", ax: true)
        let action = app.buttons["finding.different"]
        XCTAssertTrue(action.waitForExistence(timeout: 5)); XCTAssertTrue(action.isHittable)
        XCTAssertEqual(app.buttons.matching(identifier: action.identifier).firstMatch.frame.height, 60, accuracy: 1)
        capture("finding-AX5", app)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let rotated = NSPredicate { _, _ in app.frame.width > app.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rotated, object: nil)], timeout: 5), .completed)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(action.isHittable); capture("finding-landscape-AX5", app)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
