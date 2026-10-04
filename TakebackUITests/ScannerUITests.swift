import XCTest

@MainActor final class ScannerUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func openScanner(_ app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.buttons["welcome.cancel"].waitForExistence(timeout: 10))
        app.buttons["welcome.cancel"].tap()
        XCTAssertTrue(app.buttons["enterKey.scan"].waitForExistence(timeout: 5))
        app.buttons["enterKey.scan"].tap()
        answerCameraPromptIfShown()
        XCTAssertTrue(app.navigationBars["Scan"].buttons.firstMatch.waitForExistence(timeout: 5))
    }
    func testUnavailableCameraPhotoCancelAndClosePreserveEntry() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["welcome.cancel"].waitForExistence(timeout: 10))
        app.buttons["welcome.cancel"].tap()
        let field = app.textViews["enterKey.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("abandon abandon")
        app.buttons["enterKey.scan"].tap()
        answerCameraPromptIfShown()
        XCTAssertTrue(app.staticTexts["Camera access is off"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["scanner.torch"].exists)
        XCTAssertTrue(app.buttons["scanner.settings"].isHittable)
        XCTAssertTrue(app.toolbars.buttons["scanner.photo"].isHittable)
        XCTAssertGreaterThan(app.buttons["scanner.photo"].frame.width, 100, "Choose photo must keep its visible label")
        capture("scanner-no-camera", app)
        app.buttons["scanner.photo"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Scan"].buttons.firstMatch.waitForExistence(timeout: 5))
        app.navigationBars["Scan"].buttons.firstMatch.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5)); XCTAssertEqual(field.value as? String, "abandon abandon")
    }
    func testPhotoImportFillsFieldAndEnablesFind() {
        // Simulator photo library contains only the explicitly installed PUBLIC scalar-one QR fixture.
        let app = XCUIApplication(); openScanner(app)
        app.buttons["scanner.photo"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH 'Photo,'")).firstMatch
        if !photo.waitForExistence(timeout: 5) { print(app.debugDescription) }
        XCTAssertTrue(photo.exists); photo.tap()
        let dismissed = NSPredicate { _, _ in !app.navigationBars["Scan"].buttons.firstMatch.exists }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: dismissed, object: nil)], timeout: 10), .completed)
        XCTAssertTrue(app.staticTexts["Private key · hex · 64 characters"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["enterKey.find"].isEnabled)
        XCTAssertEqual(app.textViews["enterKey.field"].value as? String, String(repeating: "0", count: 63) + "1")
        capture("scanner-imported-public-test-key", app)
        app.buttons["enterKey.clear"].tap()
    }
    func testAccessibilityPermissionButtonsRemainVisibleAfterRotation() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        openScanner(app)
        XCTAssertTrue(app.buttons["scanner.settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["scanner.settings"].isHittable); XCTAssertTrue(app.buttons["scanner.photo"].isHittable)
        capture("scanner-AX5", app)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let rotated = NSPredicate { _, _ in app.frame.width > app.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rotated, object: nil)], timeout: 5), .completed)
        XCTAssertTrue(app.navigationBars["Scan"].buttons.firstMatch.isHittable)
        XCTAssertTrue(app.buttons["scanner.settings"].isHittable); XCTAssertTrue(app.buttons["scanner.photo"].isHittable)
        XCTAssertTrue(app.toolbars.buttons["scanner.photo"].isHittable)
        Thread.sleep(forTimeInterval: 1) // Capture after the native rotation animation has finished.
        XCTAssertGreaterThanOrEqual(app.navigationBars["Scan"].buttons.firstMatch.frame.minY, 0)
        XCTAssertLessThanOrEqual(app.navigationBars["Scan"].buttons.firstMatch.frame.maxY, app.frame.height)
        capture("scanner-AX5-landscape", app)
        app.navigationBars["Scan"].buttons.firstMatch.tap()
    }
    private func answerCameraPromptIfShown() {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        guard alert.waitForExistence(timeout: 1) else { return }
        for label in ["Don’t Allow", "Don't Allow"] where alert.buttons[label].exists {
            alert.buttons[label].tap(); return
        }
        XCTFail("Unexpected system alert in camera permission test")
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
