import XCTest

@MainActor final class SettingsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(reset: Bool = true, ax: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchArguments = ["-settings-ui"]
        if reset { app.launchArguments += ["-settings-reset"] }
        if ax { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch(); XCTAssertTrue(app.buttons["welcome.settings"].waitForExistence(timeout: 10)); app.buttons["welcome.settings"].tap()
        XCTAssertTrue(app.buttons["settings.fee"].waitForExistence(timeout: 5)); return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable && element.frame.midY < app.frame.maxY - 80 && element.frame.minY > app.frame.minY + 64 { break }
            if element.exists && element.frame.minY < app.frame.minY + 64 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ name: String) { let a = XCTAttachment(screenshot:XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a) }
    func testDefaultFeePersistsAcrossLaunches() {
        var app = launch(); capture("settings-native")
        app.buttons["settings.fee"].tap(); XCTAssertTrue(app.buttons["defaultFee.medium"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["defaultFee.custom"].exists)
        XCTAssertTrue(app.buttons["defaultFee.fast"].label.contains("20 sat/vB"))
        app.buttons["defaultFee.medium"].tap(); capture("default-fee-native")
        app.navigationBars.buttons.firstMatch.tap(); XCTAssertTrue(app.buttons["settings.fee"].label.contains("Medium"))
        app.terminate(); app = launch(reset:false)
        XCTAssertTrue(app.buttons["settings.fee"].label.contains("Medium"))
    }
    func testOwnServerValidationSavePersistenceAndDefault() {
        var app = launch(); app.buttons["settings.server"].tap()
        XCTAssertTrue(app.buttons["server.own"].waitForExistence(timeout:5)); capture("server-native")
        app.buttons["server.own"].tap()
        let field = app.textFields["server.url"]; XCTAssertTrue(field.waitForExistence(timeout:5)); field.tap(); field.typeText("https://bitcoin.example/api")
        XCTAssertTrue(app.buttons["server.save"].waitForExistence(timeout:5))
        let enabled = NSPredicate(format:"enabled == true")
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:enabled,object:app.buttons["server.save"])],timeout:5),.completed)
        capture("own-connected-keyboard-native"); app.buttons["server.save"].tap()
        XCTAssertTrue(app.buttons["settings.server"].label.contains("Your server"))
        app.terminate(); app = launch(reset:false); XCTAssertTrue(app.buttons["settings.server"].label.contains("Your server"))
        app.buttons["settings.server"].tap(); app.buttons["server.default"].tap(); app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["settings.server"].label.contains("mempool.space"))
    }
    func testBadAPIAndOfflineCannotSave() {
        let app = launch(); app.buttons["settings.server"].tap(); app.buttons["server.own"].tap()
        let field = app.textFields["server.url"]; field.tap(); field.typeText("https://invalid.example/api")
        XCTAssertTrue(app.staticTexts["Not a mempool API"].waitForExistence(timeout:5)); XCTAssertFalse(app.buttons["server.save"].isEnabled); capture("own-invalid-native")
        field.tap(); field.press(forDuration:1.1)
        if app.menuItems["Select All"].waitForExistence(timeout:2) { app.menuItems["Select All"].tap(); field.typeText("https://offline.example/api") }
        else { field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:27)+"https://offline.example/api") }
        XCTAssertTrue(app.staticTexts["Couldn’t connect"].waitForExistence(timeout:5)); XCTAssertFalse(app.buttons["server.save"].isEnabled)
        app.navigationBars.buttons.firstMatch.tap(); XCTAssertTrue(app.buttons["settings.server"].label.contains("mempool.space"))
    }
    func testBackupToggleAddDeleteAndPersistence() {
        var app = launch(); app.buttons["settings.server"].tap()
        let first = app.switches["server.backup.electrum.blockstream.info"]; reveal(first,in:app); first.tap(); XCTAssertEqual(first.value as? String,"0")
        let add = app.buttons["server.add"]; reveal(add,in:app); add.tap()
        let field = app.alerts.textFields.firstMatch; XCTAssertTrue(field.waitForExistence(timeout:5)); field.typeText("custom.example:50002"); app.alerts.buttons["Add"].tap()
        let custom = app.descendants(matching:.any)["server.backup.custom.example"].firstMatch
        XCTAssertTrue(custom.waitForExistence(timeout:5)); reveal(custom,in:app); capture("electrum-added-native")
        app.terminate(); app = launch(reset:false); app.buttons["settings.server"].tap()
        let restored = app.switches["server.backup.electrum.blockstream.info"]; reveal(restored,in:app); XCTAssertEqual(restored.value as? String,"0")
        let row = app.descendants(matching:.any)["server.backup.custom.example"].firstMatch; reveal(row,in:app); row.swipeLeft()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout:5)); app.buttons["Delete"].tap(); XCTAssertFalse(row.exists)
    }
    func testAboutPrivacyLicensesAndEntryGearKeepsKeyInMemory() {
        let app = launch(); app.buttons["settings.about"].tap(); capture("about-native")
        app.buttons["about.privacy"].tap(); XCTAssertTrue(app.staticTexts["No analytics. No accounts. Keys stay in memory and are wiped after use. Network requests go only to the servers you choose."].waitForExistence(timeout:5)); capture("privacy-native")
        app.navigationBars.buttons.firstMatch.tap(); app.buttons["about.licenses"].tap()
        XCTAssertTrue(app.buttons["license.GeistLicense"].waitForExistence(timeout:5)); app.buttons["license.GeistLicense"].tap(); capture("license-native")
        app.navigationBars.buttons.firstMatch.tap(); app.navigationBars.buttons.firstMatch.tap(); app.navigationBars.buttons.firstMatch.tap(); app.navigationBars.buttons.firstMatch.tap()
        app.buttons["welcome.cancel"].tap(); let field = app.textViews["enterKey.field"]; XCTAssertTrue(field.waitForExistence(timeout:5)); field.tap()
        field.typeText("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
        app.buttons["enterKey.settings"].tap(); XCTAssertTrue(app.buttons["settings.fee"].waitForExistence(timeout:5)); app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["enterKey.find"].isEnabled)
    }
    func testSettingsAndServerAX5BothOrientations() {
        let app = launch(ax:true); reveal(app.buttons["settings.server"],in:app); app.buttons["settings.server"].tap()
        reveal(app.buttons["server.own"],in:app); capture("server-AX5-native")
        XCUIDevice.shared.orientation = .landscapeLeft; defer { XCUIDevice.shared.orientation = .portrait }
        let rotated = NSPredicate { _,_ in app.frame.width > app.frame.height }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:rotated,object:nil)],timeout:5),.completed)
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.isHittable); capture("server-landscape-AX5-native")
    }
}
