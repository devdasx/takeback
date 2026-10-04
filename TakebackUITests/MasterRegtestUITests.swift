import XCTest
import Darwin

@MainActor final class MasterRegtestUITests: XCTestCase {
  private func control(_ action: String) async throws {
    var request = URLRequest(url: URL(string: "http://127.0.0.1:52110/" + action)!)
    request.httpMethod = "POST"
    let (_, response) = try await URLSession.shared.data(for: request)
    XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
  }
  func testRealWelcomeToConfirmedCancelWithSimulatedFaceID() async throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["TAKEBACK_MASTER_UI"] == "1")
    continueAfterFailure = false
    try await control("prepare")
    // Simulated biometrics: enroll, then answer the prompt with a match (Face ID is "pearl", Touch ID "fingerTouch").
    var token: Int32 = 0
    notify_register_check("com.apple.BiometricKit.enrollmentChanged", &token)
    notify_set_state(token, 1)
    notify_post("com.apple.BiometricKit.enrollmentChanged")
    try await Task.sleep(for: .seconds(1))
    let app = XCUIApplication()
    app.launchEnvironment["TAKEBACK_REGTEST"] = "1"
    app.launchEnvironment["TAKEBACK_TEST_HERO_TIME"] = "0"
    app.launchEnvironment["showUSD"] = "0"
    addUIInterruptionMonitor(withDescription: "Face ID permission") { alert in
      if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
      return false
    }
    app.launch()
    XCTAssertTrue(app.buttons["welcome.cancel"].waitForExistence(timeout: 10))
    app.buttons["welcome.cancel"].tap()
    let field = app.textViews["enterKey.field"]
    XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
    field.typeText(String(repeating: "0", count: 63) + "9")
    try await Task.sleep(for: .milliseconds(500))
    let find = app.buttons["enterKey.find"]
    XCTAssertTrue(find.waitForExistence(timeout: 5)); find.tap()
    let found = app.buttons["finding.show"]
    XCTAssertTrue(found.waitForExistence(timeout: 90))
    XCTAssertEqual(app.staticTexts["finding.title"].label, "Found 1 pending payment")
    found.tap()
    let submit = app.buttons["cancel.submit"]
    XCTAssertTrue(submit.waitForExistence(timeout: 30))
    let ready = NSPredicate(format: "isEnabled == true")
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: submit)], timeout: 30), .completed)
    let matches = Task.detached {
      for _ in 0..<160 {
        try? await Task.sleep(for: .milliseconds(500))
        if Task.isCancelled { return }
        notify_post("com.apple.BiometricKit_Sim.pearl.match")
      }
    }
    defer { matches.cancel() }
    submit.tap()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    if springboard.buttons["Allow"].exists { springboard.buttons["Allow"].tap() }
    app.tap()
    let canceled = app.staticTexts["result.title"]
    for _ in 0..<40 where !canceled.exists {
      try await Task.sleep(for: .milliseconds(750))
      notify_post("com.apple.BiometricKit_Sim.pearl.match")
      notify_post("com.apple.BiometricKit_Sim.fingerTouch.match")
    }
    XCTAssertTrue(canceled.waitForExistence(timeout: 30))
    capture("Regtest-Canceled-pending")
    try await control("mine")
    let confirmed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'Confirmed'"), object: app.descendants(matching: .any)["result.status"].firstMatch)
    XCTAssertEqual(XCTWaiter.wait(for: [confirmed], timeout: 35), .completed)
    capture("Regtest-Canceled-confirmed")
    app.buttons["result.done"].tap()
    XCTAssertTrue(app.buttons["welcome.cancel"].waitForExistence(timeout: 5))
    notify_cancel(token)
  }
  private func capture(_ name: String) {
    let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
  }
}
