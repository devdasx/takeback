import XCTest

@MainActor final class SpeedUpUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func open(ax: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchArguments = ["--speed-ui"]
        if ax { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch(); XCTAssertTrue(app.buttons["cancel.submit"].waitForExistence(timeout: 10)); return app
    }
    func testDefaultCancelSwitchAndSharedCustomFeeOnSE() {
        let app = open(), button = app.buttons["cancel.submit"]
        XCTAssertEqual(button.label, "Cancel payment"); XCTAssertTrue(button.isHittable); XCTAssertEqual(app.buttons.matching(identifier: button.identifier).firstMatch.frame.height, 60, accuracy: 1)
        let segment = app.segmentedControls["action.mode"]
        XCTAssertTrue(segment.exists); segment.buttons["Speed up"].tap()
        XCTAssertEqual(button.label, "Speed up payment"); XCTAssertTrue(button.isHittable)
        capture("speed-SE", app)
        let fee = app.buttons["cancel.fee"]
        for _ in 0..<6 where !fee.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(fee.label.contains("+$")); fee.tap()
        XCTAssertTrue(app.staticTexts["Extra cost to confirm it sooner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["fee.fast"].label.contains("+$"))
        app.buttons["fee.custom"].tap()
        let field = app.textFields["fee.field"]; XCTAssertTrue(field.waitForExistence(timeout: 5)); field.typeText("1")
        XCTAssertFalse(app.buttons["fee.done"].isEnabled)
        field.typeText(XCUIKeyboardKey.delete.rawValue + "30"); XCTAssertTrue(app.buttons["fee.done"].isEnabled); app.buttons["fee.done"].tap()
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        for _ in 0..<6 where !segment.isHittable { app.scrollViews.firstMatch.swipeDown() }
        segment.buttons["Cancel"].tap()
        XCTAssertEqual(button.label, "Cancel payment")
        for _ in 0..<6 where !fee.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(fee.label.contains("30 sat/vB")); XCTAssertFalse(fee.label.contains("+$"))
    }
    func testAX5MenuAndPinnedPrimaryOnSE() {
        let app = open(ax: true), button = app.buttons["cancel.submit"]
        XCTAssertTrue(button.isHittable); XCTAssertEqual(app.buttons.matching(identifier: button.identifier).firstMatch.frame.height, 60, accuracy: 1)
        let menu = app.buttons["action.modeMenu"]; XCTAssertTrue(menu.isHittable); menu.tap()
        app.buttons["Speed up"].firstMatch.tap()
        XCTAssertEqual(button.label, "Speed up payment")
        let ready = NSPredicate { _, _ in button.isHittable }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 3), .completed)
        capture("speed-SE-AX5", app)
        let fee = app.buttons["cancel.fee"]
        for _ in 0..<10 where !fee.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(fee.isHittable); XCTAssertTrue(button.isHittable)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
