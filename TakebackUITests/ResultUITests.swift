import XCTest

@MainActor final class ResultUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ state: Int, ax: Bool = false, dark: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-result-ui", String(state), "-cancel-ui"]
        if ax { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        if dark { app.launchArguments += ["-AppleInterfaceStyle", "Dark"] }
        app.launch()
        let portrait = NSPredicate { _,_ in app.frame.height > app.frame.width }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: portrait, object: nil)], timeout: 5), .completed)
        return app
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testCancelingHasNoExitAndBlocksSwipe() {
        let app = launch(0)
        XCTAssertTrue(app.staticTexts["result.canceling"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["result.done"].exists); XCTAssertFalse(app.buttons["Back"].exists)
        app.swipeRight(); XCTAssertTrue(app.staticTexts["result.canceling"].exists); capture("canceling-native")
    }
    func testPendingReceiptDoneReturnsToWelcomeWithEmptyEntry() {
        let app = launch(1)
        XCTAssertTrue(app.buttons["result.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["result.status"].firstMatch.label.contains("Pending · 0 confirmations"))
        XCTAssertTrue(app.buttons["result.explorer"].isHittable)
        let copy = app.buttons["result.copy"]
        for _ in 0..<5 where !copy.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(copy.isHittable); copy.tap(); capture("pending-native")
        app.buttons["result.done"].tap(); XCTAssertTrue(app.buttons["welcome.cancel"].waitForExistence(timeout: 5))
        app.buttons["welcome.cancel"].tap(); XCTAssertTrue(app.textViews["enterKey.field"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["enterKey.find"].isEnabled)
    }
    func testLiveConfirmationUpdatesAndReceiptSurvivesWipe() {
        let app = launch(7)
        XCTAssertTrue(app.staticTexts["result.title"].waitForExistence(timeout: 5))
        let confirmed = NSPredicate { _,_ in app.descendants(matching: .any)["result.status"].firstMatch.label.contains("Confirmed · 1 confirmation") }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: confirmed, object: nil)], timeout: 8), .completed)
        XCTAssertEqual(app.staticTexts["result.subtitle"].label, "Back in your wallet.")
        capture("confirmed-live-native")
    }
    func testAlreadyConfirmedAndDone() {
        let app = launch(3, dark: true)
        XCTAssertTrue(app.staticTexts["result.title"].waitForExistence(timeout: 5)); XCTAssertEqual(app.staticTexts["result.title"].label, "It already confirmed")
        XCTAssertTrue(app.buttons["result.explorer"].isHittable); capture("already-confirmed-native")
        app.buttons["result.done"].tap(); XCTAssertTrue(app.buttons["welcome.cancel"].waitForExistence(timeout: 5))
    }
    func testNotEnoughHasNoImpossibleLowerFeeAndAX5PinnedDone() {
        let app = launch(4, ax: true, dark: true)
        XCTAssertTrue(app.buttons["result.done"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["result.done"].isHittable)
        XCTAssertFalse(app.buttons["result.lowerFee"].exists); capture("not-enough-AX5-native")
        XCUIDevice.shared.orientation = .landscapeLeft; defer { XCUIDevice.shared.orientation = .portrait }
        let rotated = NSPredicate { _,_ in app.frame.width > app.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rotated, object: nil)], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["result.done"].isHittable); capture("not-enough-landscape-AX5-native")
    }
    func testRejectedDetailsAndHigherFeeSheet() {
        let app = launch(5)
        XCTAssertTrue(app.buttons["result.higherFee"].waitForExistence(timeout: 5))
        let details = app.descendants(matching: .any)["result.details"].firstMatch
        for _ in 0..<5 where !details.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(details.isHittable); details.tap(); capture("rejected-details-native")
        app.buttons["result.higherFee"].tap(); XCTAssertTrue(app.buttons["fee.custom"].waitForExistence(timeout: 5)); capture("retry-fee-native")
    }
    func testRecoverableDustOpensLowerFeeSheet() {
        let app = launch(6)
        XCTAssertTrue(app.buttons["result.lowerFee"].waitForExistence(timeout: 5)); app.buttons["result.lowerFee"].tap()
        XCTAssertTrue(app.buttons["fee.custom"].waitForExistence(timeout: 5))
    }
    func testRejectedBackReturnsToCancelWithoutSheet() {
        let app = launch(5)
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5)); app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["cancel.submit"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["fee.custom"].exists)
    }
}
