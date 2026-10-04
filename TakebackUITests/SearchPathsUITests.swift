import XCTest

@MainActor final class SearchPathsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testNativeSheetScrollingPreviewEditingAndClose() {
        let app = XCUIApplication()
        app.launchArguments = ["--paths-ui"]
        if ProcessInfo.processInfo.environment["TAKEBACK_PATHS_AX3"] == "1" {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["paths.add"].waitForExistence(timeout: 8))
        reveal(app.buttons["paths.add"], app: app)
        app.buttons["paths.add"].tap()
        XCTAssertTrue(app.textFields["path.field"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["path.done"].isEnabled)
        if app.frame.width > 700 {
            XCTAssertLessThan(app.scrollViews["path.content"].frame.width, app.frame.width - 80, "iPad uses a centered form sheet")
        }
        reveal(app.buttons["path.wallet.Electrum"], app: app)
        app.buttons["path.wallet.Electrum"].tap()
        let done = app.buttons["path.done"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: done)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
        reveal(app.staticTexts["path.preview"], app: app)
        XCTAssertTrue(app.staticTexts["path.preview"].isHittable)
        XCTAssertTrue(done.isHittable)
        XCTAssertTrue(app.buttons["Close"].isHittable)
        capture("add-scrolled")
        done.tap()
        let custom = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "paths.custom.")).firstMatch
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        reveal(custom, app: app); custom.tap()
        XCTAssertTrue(app.buttons["path.remove"].waitForExistence(timeout: 5))
        reveal(app.buttons["path.remove"], app: app)
        XCTAssertTrue(app.buttons["path.done"].isHittable)
        XCTAssertTrue(app.toolbars.buttons["path.remove"].isHittable)
        capture("edit-scrolled")
        app.buttons["Close"].tap()
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        reveal(custom, app: app); custom.tap()
        reveal(app.buttons["path.remove"], app: app); app.buttons["path.remove"].tap()
        XCTAssertFalse(custom.exists)
        XCTAssertTrue(app.buttons["paths.done"].isHittable)
        app.buttons["paths.done"].tap()
        XCTAssertTrue(app.buttons["enterKey.paths"].waitForExistence(timeout: 5))
    }
    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<15 where !element.isHittable {
            let sheet = app.scrollViews["path.content"]
            if sheet.exists { sheet.swipeUp() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
