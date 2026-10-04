import XCTest

@MainActor final class CancelUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func openCancel(linked: Bool = false, ax: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication();app.launchArguments += ["-payments-ui","-cancel-ui"]
        if ax { app.launchArguments += ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let portrait = NSPredicate { _,_ in app.frame.height > app.frame.width }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:portrait,object:nil)],timeout:5),.completed)
        XCTAssertTrue(app.buttons["welcome.cancel"].waitForExistence(timeout:10));app.buttons["welcome.cancel"].tap()
        let field = app.textViews["enterKey.field"];XCTAssertTrue(field.waitForExistence(timeout:5));field.tap()
        field.typeText("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
        app.buttons["enterKey.find"].tap();XCTAssertTrue(app.buttons["finding.show"].waitForExistence(timeout:5));app.buttons["finding.show"].tap()
        let row = app.buttons["payments.row." + String(repeating:linked ? "b" : "a",count:64)]
        for _ in 0..<6 where !row.isHittable { app.scrollViews.element(boundBy:max(0,app.scrollViews.count-1)).swipeUp() }
        XCTAssertTrue(row.isHittable);row.tap();XCTAssertTrue(app.buttons["cancel.submit"].waitForExistence(timeout:5))
        return app
    }
    private func openFee(_ app: XCUIApplication) {
        let fee = app.buttons["cancel.fee"]
        for _ in 0..<6 where !fee.isHittable { app.scrollViews.element(boundBy:max(0,app.scrollViews.count-1)).swipeUp() }
        XCTAssertTrue(fee.isHittable);fee.tap();XCTAssertTrue(app.buttons["fee.custom"].waitForExistence(timeout:5))
    }
    func testCustomFocusMinimumDoneAndPresetUpdates() {
        let app = openCancel();let original = app.descendants(matching:.any)["cancel.amount"].firstMatch.label;capture("cancel",app)
        openFee(app);capture("new-fee",app);app.buttons["fee.custom"].tap()
        let field = app.textFields["fee.field"];XCTAssertTrue(field.waitForExistence(timeout:5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:5));field.typeText("1")
        XCTAssertEqual(app.staticTexts["fee.status"].label,"Must be higher than the original 2 sat/vB")
        XCTAssertFalse(app.buttons["fee.done"].isEnabled);capture("custom-low",app)
        field.typeText(XCUIKeyboardKey.delete.rawValue + "91")
        XCTAssertEqual(app.staticTexts["fee.status"].label,"Much higher than needed")
        field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:2)+"25")
        XCTAssertTrue(app.buttons["fee.done"].isEnabled);capture("custom-valid",app);app.buttons["fee.done"].tap()
        XCTAssertTrue(app.buttons["cancel.fee"].waitForExistence(timeout:5));XCTAssertNotEqual(app.descendants(matching:.any)["cancel.amount"].firstMatch.label,original)
        openFee(app);app.buttons["fee.nextBlock"].tap()
        XCTAssertTrue(app.buttons["cancel.fee"].waitForExistence(timeout:5));XCTAssertTrue(app.buttons["cancel.fee"].label.contains("Next block"))
        app.navigationBars.buttons.firstMatch.tap();XCTAssertTrue(app.staticTexts["payments.title"].waitForExistence(timeout:5))
    }
    func testLandscapeCustomKeepsStatusAndDoneAboveKeyboard() {
        let app = openCancel()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let rotated = NSPredicate { _,_ in app.frame.width > app.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:rotated,object:nil)],timeout:5),.completed)
        openFee(app);app.buttons["fee.custom"].tap()
        let field = app.textFields["fee.field"];XCTAssertTrue(field.waitForExistence(timeout:5));field.typeText("25")
        let visible = NSPredicate { _,_ in app.staticTexts["fee.status"].isHittable && app.buttons["fee.done"].isHittable }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:visible,object:nil)],timeout:5),.completed)
        capture("custom-landscape-keyboard",app)
    }
    func testLinkedWarningAndPinnedButtonInAX5BothOrientations() {
        let app = openCancel(linked:true,ax:true)
        let button = app.buttons["cancel.submit"]
        XCTAssertTrue(button.isHittable);XCTAssertEqual(app.buttons.matching(identifier: button.identifier).firstMatch.frame.height, 60, accuracy: 1);capture("linked-AX5",app)
        let warning = app.staticTexts["This also cancels a later payment"]
        for _ in 0..<8 where !warning.isHittable { app.scrollViews.element(boundBy:max(0,app.scrollViews.count-1)).swipeUp() }
        XCTAssertTrue(app.staticTexts["This also cancels a later payment"].exists)
        XCUIDevice.shared.orientation = .landscapeLeft;defer { XCUIDevice.shared.orientation = .portrait }
        let rotated = NSPredicate { _,_ in app.frame.width > app.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:rotated,object:nil)],timeout:5),.completed)
        XCTAssertTrue(button.isHittable);XCTAssertEqual(app.buttons.matching(identifier: button.identifier).firstMatch.frame.height, 60, accuracy: 1);capture("linked-landscape-AX5",app)
    }
    private func capture(_ name:String,_ app:XCUIApplication) {
        let a=XCTAttachment(screenshot:XCUIScreen.main.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)
    }
}
