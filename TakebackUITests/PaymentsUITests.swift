import XCTest

@MainActor final class PaymentsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func openList(ax: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments += ["-payments-ui"]
        if ax { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["welcome.cancel"].waitForExistence(timeout: 10)); app.buttons["welcome.cancel"].tap()
        let field = app.textViews["enterKey.field"]; XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        field.typeText("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
        app.buttons["enterKey.find"].tap()
        XCTAssertTrue(app.buttons["finding.show"].waitForExistence(timeout: 5)); app.buttons["finding.show"].tap()
        XCTAssertTrue(app.staticTexts["payments.title"].waitForExistence(timeout: 5))
        return app
    }
    private func row(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["payments.row." + String(repeating: id, count: 64)]
        for _ in 0..<9 {
            if button.isHittable { return button }
            app.scrollViews.element(boundBy: max(0, app.scrollViews.count - 1)).swipeUp()
        }
        XCTAssertTrue(button.isHittable); return button
    }
    func testNormalLinkedAndRestrictedRouting() {
        let app = openList()
        XCTAssertEqual(app.staticTexts["payments.subtitle"].label, "5 payments from this key are waiting to confirm. 2 can be canceled.")
        capture("payments-mixed", app)
        for id in ["b", "a"] {
            row(id, in: app).tap()
            XCTAssertTrue(app.buttons["cancel.submit"].waitForExistence(timeout: 5))
            app.buttons["Back"].tap()
            XCTAssertTrue(app.staticTexts["payments.title"].waitForExistence(timeout: 5))
        }
        row("c", in: app).tap()
        XCTAssertTrue(app.staticTexts["Some coins aren’t yours"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["3 of 5 coins"].exists)
        XCTAssertTrue(app.buttons["paymentExplanation.done"].isHittable)
        capture("payments-not-owned", app)
        app.buttons["paymentExplanation.done"].tap()
        row("e", in: app).tap()
        XCTAssertTrue(app.staticTexts["Can’t be replaced"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Use the other wallet"].exists)
        app.buttons["paymentExplanation.done"].tap()
        XCTAssertTrue(app.staticTexts["payments.title"].waitForExistence(timeout: 5))
    }
    func testCancelingCopyDoneAndBackToFindingResults() {
        let app = openList()
        row("d", in: app).tap()
        XCTAssertTrue(app.staticTexts["Already being canceled"].waitForExistence(timeout: 5))
        let copy = app.buttons["paymentExplanation.copy"]
        if !copy.isHittable { app.scrollViews.element(boundBy: max(0, app.scrollViews.count - 1)).swipeUp() }
        XCTAssertTrue(copy.isHittable); copy.tap()
        XCTAssertTrue(app.buttons["paymentExplanation.explorer"].isHittable)
        capture("payments-canceling", app)
        app.buttons["paymentExplanation.done"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["finding.show"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["finding.title"].label, "Found 5 pending payments")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["enterKey.find"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["enterKey.find"].isEnabled)
    }
    func testAX5PortraitAndLandscapeExplanationButtons() {
        let app = openList(ax: true)
        row("c", in: app).tap()
        let done = app.buttons["paymentExplanation.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); XCTAssertTrue(done.isHittable)
        XCTAssertEqual(app.buttons.matching(identifier: done.identifier).firstMatch.frame.height, 60, accuracy: 1)
        capture("payments-explanation-AX5", app)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let rotated = NSPredicate { _, _ in app.frame.width > app.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rotated, object: nil)], timeout: 5), .completed)
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(done.isHittable); capture("payments-explanation-landscape-AX5", app)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
