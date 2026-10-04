import XCTest

@MainActor final class NativeNavigationUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--navigation-ui", "-settings-ui", "-settings-reset"] + arguments
        app.launch()
        return app
    }

    private func visible(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in element.exists && element.isHittable }, object: nil)
        let result = XCTWaiter.wait(for: [ready], timeout: 8)
        if result != .completed {
            capture("navigation-failure")
            let tree = XCTAttachment(string: XCUIApplication().debugDescription)
            tree.name = "navigation-failure-tree"; tree.lifetime = .keepAlways; add(tree)
        }
        XCTAssertEqual(result, .completed, file: file, line: line)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<7 where !element.isHittable { app.swipeUp() }
        visible(element)
    }

    private func back(_ app: XCUIApplication) {
        // Start at the screen edge: a center swipe does not test interactive pop.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.45))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.45)))
    }

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    private func enterKey(_ app: XCUIApplication, phrase: Bool = false) {
        visible(app.buttons["welcome.cancel"]); app.buttons["welcome.cancel"].tap()
        let field = app.textViews["enterKey.field"]; visible(field); field.tap()
        field.typeText(phrase ? "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about" : String(repeating: "0", count: 63) + "1")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.buttons["enterKey.find"].isEnabled }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
    }

    private func bottomAction(_ id: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[id]
        XCTAssertFalse(app.toolbars.buttons[id].exists, "Bottom actions must not use Liquid Glass toolbars", file: file, line: line)
        visible(button, file: file, line: line)
        XCTAssertTrue(app.frame.contains(button.frame), "The pinned action must stay within the screen", file: file, line: line)
    }

    func testNativeBarsWelcomeSourceAndKeyboard() {
        let app = launch()
        visible(app.navigationBars["Takeback"])
        XCTAssertTrue(app.navigationBars.buttons["welcome.settings"].exists)
        bottomAction("welcome.cancel", in: app)
        bottomAction("welcome.howItWorks", in: app)
        XCTAssertEqual(app.buttons["welcome.cancel"].frame.height, 56, accuracy: 1)
        XCTAssertEqual(app.buttons["welcome.howItWorks"].frame.height, 48, accuracy: 1)
        capture("restored-buttons-welcome")
        reveal(app.buttons["welcome.source"], in: app); app.buttons["welcome.source"].tap()
        visible(app.navigationBars["Open source"])
        let source = app.buttons["source.github"]
        XCTAssertTrue(source.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(source.frame.width, 200, "The named source action must not collapse to an icon")
        XCTAssertTrue(app.frame.contains(source.frame))
        capture("native-bars-source")
        // Native sheets may scale their entire surface during presentation.
        XCTAssertGreaterThan(source.frame.height, 52)
        XCTAssertLessThanOrEqual(source.frame.height, 61)
        // Verify the source action opens the native browser.
        source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let browserClose: XCUIElement
        if #available(iOS 26.0, *) {
            browserClose = app.buttons.matching(NSPredicate(format: "identifier == %@", "Close")).firstMatch
        } else { browserClose = app.buttons["Done"] }
        visible(browserClose); browserClose.tap()
        visible(app.buttons["Close"]); app.buttons["Close"].tap()
        enterKey(app)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        bottomAction("enterKey.find", in: app)
        XCTAssertLessThanOrEqual(app.buttons["enterKey.find"].frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        XCTAssertEqual(app.buttons["enterKey.find"].frame.height, 60, accuracy: 1)
        capture("restored-buttons-keyboard")
        app.buttons["enterKey.settings"].tap(); visible(app.buttons["settings.fee"])
        back(app); bottomAction("enterKey.find", in: app)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }

    func testWelcomeAndKeyKeepScrollGuttersInSplitLayout() {
        let app = launch()
        visible(app.buttons["welcome.cancel"])
        XCTAssertEqual(app.scrollViews["welcome.content"].frame.width, app.frame.width, accuracy: 1)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let rotated = NSPredicate { _, _ in app.frame.width > app.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rotated, object: nil)], timeout: 5), .completed)
        let source = app.buttons["welcome.source"]
        let welcomeColumn = app.scrollViews.containing(.button, identifier: "welcome.source").firstMatch
        // Scroll in the visible content area, above the pinned bottom actions.
        for _ in 0..<6 where source.frame.maxY > app.buttons["welcome.cancel"].frame.minY - 12 {
            welcomeColumn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.52))
                .press(forDuration: 0.05, thenDragTo: welcomeColumn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
        }
        visible(source)
        capture("welcome-scroll-gutters-split")
        XCTAssertTrue(app.frame.contains(app.buttons["welcome.source"].frame))
        app.buttons["welcome.cancel"].tap()
        let field = app.textViews["enterKey.field"]
        visible(field)
        let column = app.scrollViews.containing(.textView, identifier: "enterKey.field").firstMatch
        XCTAssertGreaterThanOrEqual(field.frame.minX - column.frame.minX, 47)
        XCTAssertGreaterThanOrEqual(column.frame.maxX - field.frame.maxX, 47)
        capture("key-scroll-gutters-split")
        back(app)
        visible(app.buttons["welcome.cancel"])
    }

    func testNativeBarsLongFindingAndResultActions() {
        let app = launch(["-finding-ui-none"]); enterKey(app, phrase: true)
        app.buttons["enterKey.find"].tap()
        bottomAction("finding.different", in: app)
        let deep = app.buttons["finding.deep"]
        let search = deep
        visible(search)
        capture("native-bars-finding")
        search.tap()
        visible(app.staticTexts["Checked 100 addresses per path on 4 paths and found nothing waiting."])
        app.buttons["finding.different"].tap(); bottomAction("enterKey.find", in: app)
        XCTAssertFalse(app.buttons["enterKey.find"].isEnabled)
        app.terminate()
        let result = launch(["-result-ui", "1", "-cancel-ui"])
        bottomAction("result.explorer", in: result)
        bottomAction("result.done", in: result)
        capture("native-bars-result")
        result.buttons["result.done"].tap(); bottomAction("welcome.cancel", in: result)
    }

    func testSettingsHierarchyUsesNativeEdgeBackAndButton() {
        let app = launch()
        visible(app.buttons["welcome.settings"]); app.buttons["welcome.settings"].tap()
        visible(app.buttons["settings.fee"])
        for _ in 0..<3 {
            app.buttons["settings.fee"].tap(); visible(app.navigationBars.buttons.firstMatch)
            back(app); visible(app.buttons["settings.fee"])
        }
        app.buttons["settings.server"].tap(); visible(app.buttons["server.own"])
        back(app); visible(app.buttons["settings.fee"])
        reveal(app.buttons["settings.about"], in: app); app.buttons["settings.about"].tap()
        visible(app.buttons["about.privacy"]); app.buttons["about.privacy"].tap()
        visible(app.staticTexts["settings.title"]); back(app); visible(app.buttons["about.privacy"])
        app.buttons["about.licenses"].tap(); visible(app.buttons["license.GeistLicense"])
        app.buttons["license.GeistLicense"].tap(); visible(app.staticTexts["settings.title"])
        back(app); visible(app.buttons["license.GeistLicense"])
        back(app); visible(app.buttons["about.privacy"])
        capture("native-about-back")
        app.navigationBars.buttons.firstMatch.tap(); visible(app.buttons["settings.about"])
        back(app); visible(app.buttons["welcome.cancel"])
        XCTAssertTrue(app.navigationBars["Takeback"].exists)
    }

    func testCanceledSwipeKeyboardAndSheetPreserveKeyThenCompletedBackWipesIt() {
        let app = launch(); enterKey(app, phrase: true)
        // A short, slow edge drag must cancel, leaving both the screen and key intact.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.4))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.4)), withVelocity: .slow, thenHoldForDuration: 0.7)
        visible(app.textViews["enterKey.field"]); XCTAssertTrue(app.buttons["enterKey.find"].isEnabled)
        app.buttons["enterKey.settings"].tap(); visible(app.buttons["settings.fee"])
        back(app); visible(app.textViews["enterKey.field"]); XCTAssertTrue(app.buttons["enterKey.find"].isEnabled)
        reveal(app.buttons["enterKey.paths"], in: app); app.buttons["enterKey.paths"].tap()
        visible(app.buttons["paths.done"]); back(app); visible(app.buttons["enterKey.find"])
        reveal(app.buttons["enterKey.passphrase"], in: app); app.buttons["enterKey.passphrase"].tap()
        visible(app.buttons["passphrase.done"])
        let sheetBar = app.navigationBars.containing(.button, identifier: "passphrase.done").firstMatch
        sheetBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.96)))
        visible(app.buttons["enterKey.find"]); XCTAssertTrue(app.buttons["enterKey.find"].isEnabled)
        capture("native-entry-after-sheet")
        back(app); visible(app.buttons["welcome.cancel"])
        app.buttons["welcome.cancel"].tap(); visible(app.textViews["enterKey.field"])
        XCTAssertFalse(app.buttons["enterKey.find"].isEnabled)
        XCTAssertEqual(app.textViews["enterKey.field"].value as? String, "")
    }

    func testScannerUsesNativeBackAndKeepsEntryUsable() {
        let app = launch(); enterKey(app)
        reveal(app.buttons["enterKey.scan"], in: app); app.buttons["enterKey.scan"].tap()
        visible(app.navigationBars["Scan"].buttons.firstMatch)
        XCTAssertFalse(app.buttons["scanner.close"].exists)
        back(app); visible(app.buttons["enterKey.find"])
        XCTAssertTrue(app.buttons["enterKey.find"].isEnabled)
        app.buttons["enterKey.settings"].tap(); visible(app.buttons["settings.fee"])
        back(app); visible(app.buttons["enterKey.find"])
        back(app); visible(app.buttons["welcome.cancel"])
        capture("native-scanner-back")
    }

    func testFindingSwipeStopsSearchAndAllowsRestart() {
        let app = launch(["-finding-ui-slow"]); enterKey(app)
        app.buttons["enterKey.find"].tap(); visible(app.buttons["finding.stop"])
        back(app); visible(app.buttons["enterKey.find"]); XCTAssertTrue(app.buttons["enterKey.find"].isEnabled)
        app.buttons["enterKey.find"].tap(); visible(app.buttons["finding.stop"])
        back(app); visible(app.buttons["enterKey.find"])
        capture("native-finding-back")
    }

    func testPaymentsReviewFeeAndRestrictedScreensPopOneLevel() {
        let app = launch(["-payments-ui", "-cancel-ui"]); enterKey(app)
        app.buttons["enterKey.find"].tap(); visible(app.buttons["finding.show"]); app.buttons["finding.show"].tap()
        visible(app.staticTexts["payments.title"])
        for id in ["a", "b", "c", "d", "e"] {
            let row = app.buttons["payments.row." + String(repeating: id, count: 64)]
            // Each return preserves scroll position. Search in either direction.
            for _ in 0..<5 where !row.isHittable { app.swipeDown() }
            reveal(row, in: app); row.tap()
            if id == "a" || id == "b" || id == "e" {
                visible(app.buttons["cancel.submit"])
                if id == "a" {
                    reveal(app.buttons["cancel.fee"], in: app); app.buttons["cancel.fee"].tap()
                    visible(app.buttons["fee.custom"]); app.buttons["Close"].tap()
                    visible(app.buttons["cancel.submit"])
                }
            } else { visible(app.buttons["paymentExplanation.done"]) }
            back(app); visible(row)
        }
        back(app); visible(app.buttons["finding.show"])
        back(app); visible(app.buttons["enterKey.find"]); XCTAssertTrue(app.buttons["enterKey.find"].isEnabled)
        capture("native-payments-back")
    }

    func testResultSwipeSkipsWipedReviewAndRetryResultReturnsToReview() {
        let app = launch(["-result-ui", "1", "-cancel-ui"])
        visible(app.buttons["result.done"]); back(app)
        visible(app.textViews["enterKey.field"]); XCTAssertFalse(app.buttons["enterKey.find"].isEnabled)
        XCTAssertFalse(app.buttons["cancel.submit"].exists)
        back(app); visible(app.buttons["welcome.cancel"])
        app.terminate()
        let retry = launch(["-result-ui", "5", "-cancel-ui"])
        visible(retry.buttons["result.higherFee"]); back(retry)
        visible(retry.buttons["cancel.submit"]); XCTAssertFalse(retry.buttons["fee.custom"].exists)
        back(retry); visible(retry.buttons["enterKey.find"]); XCTAssertTrue(retry.buttons["enterKey.find"].isEnabled)
        capture("native-result-back")
    }

    func testBroadcastStillBlocksEdgeGesture() {
        let app = launch(["-result-ui", "0", "-cancel-ui"])
        visible(app.staticTexts["result.canceling"])
        back(app); visible(app.staticTexts["result.canceling"])
        XCTAssertEqual(app.navigationBars.count, 0)
        XCTAssertFalse(app.buttons["result.done"].exists)
    }
}
