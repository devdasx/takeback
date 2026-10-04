import XCTest
import SwiftUI
@testable import Takeback

@MainActor final class WelcomeTests: XCTestCase {
    func testColdLaunchAndButtonRoutes() {
        let router = WelcomeRouter(session: SecretSession())
        XCTAssertTrue(router.path.isEmpty)
        XCTAssertFalse(router.showsHowItWorks)
        router.cancelTransaction()
        XCTAssertEqual(router.path, [.enterKey])
        router.returnToWelcome()
        router.openSettings()
        XCTAssertEqual(router.path, [.settings])
        router.returnToWelcome()
        router.showHowItWorks()
        XCTAssertTrue(router.showsHowItWorks)
        XCTAssertTrue(router.path.isEmpty)
    }

    func testPoppingToWelcomeWipesKeyAndPassphrase() throws {
        let session = SecretSession()
        let router = WelcomeRouter(session: session)
        router.cancelTransaction()
        try session.key.replace(with: [1, 2, 3])
        try session.passphrase.replace(with: [4, 5])
        router.path.removeLast() // Also covers native interactive-back binding updates.
        XCTAssertEqual(session.key.count, 0)
        XCTAssertEqual(session.passphrase.count, 0)
    }

    func testNativeBackFromSettingsKeepsSecretUntilEntryIsPopped() throws {
        let session = SecretSession()
        let router = WelcomeRouter(session: session)
        router.path = [.enterKey, .settings, .about, .privacy]
        try session.key.replace(with: [1, 2, 3])
        try session.passphrase.replace(with: [4, 5])
        router.navigate(to: [.enterKey, .settings, .about])
        router.navigate(to: [.enterKey])
        XCTAssertEqual(session.key.count, 3)
        XCTAssertEqual(session.passphrase.count, 2)
        router.navigate(to: [])
        XCTAssertEqual(session.key.count, 0)
        XCTAssertEqual(session.passphrase.count, 0)
    }

    func testNativeBackFromWipedResultSkipsStalePaymentReview() throws {
        let session = SecretSession()
        let router = WelcomeRouter(session: session)
        let request = ResultFixtures.request(session: session)
        router.path = [.enterKey, .review(request.context.payment), .canceling(request)]
        session.wipe()
        router.navigate(to: [.enterKey, .review(request.context.payment)])
        XCTAssertEqual(router.path, [.enterKey])
    }

    func testNativeBackFromRecoverableResultKeepsReviewAndKey() throws {
        let session = SecretSession()
        let router = WelcomeRouter(session: session)
        let request = ResultFixtures.request(session: session)
        try session.key.replace(with: [1, 2, 3])
        router.path = [.enterKey, .review(request.context.payment), .canceling(request)]
        router.navigate(to: [.enterKey, .review(request.context.payment)])
        XCTAssertEqual(router.path, [.enterKey, .review(request.context.payment)])
        XCTAssertEqual(session.key.count, 3)
    }

    func testScannerRouteReleasesCallbackAndIgnoresLateDelivery() throws {
        let session = SecretSession()
        let router = WelcomeRouter(session: session)
        router.cancelTransaction()
        var deliveries = 0
        router.openScanner { _ in deliveries += 1 }
        XCTAssertEqual(router.path, [.enterKey, .scanner])
        let bytes = SecureBytes()
        router.receiveScan(bytes)
        XCTAssertEqual(deliveries, 1)
        router.goBack()
        router.receiveScan(bytes)
        XCTAssertEqual(deliveries, 1)
        XCTAssertEqual(router.path, [.enterKey])
    }

    func testOpeningAndClosingExplanationDoesNotStartKeyFlow() {
        let router = WelcomeRouter(session: SecretSession())
        router.showHowItWorks()
        router.showsHowItWorks = false
        XCTAssertTrue(router.path.isEmpty)
    }

    func testBiometryLabelsAndSourceURL() {
        XCTAssertEqual(WelcomeBiometry.value(.touchID), .init(symbol: "touchid", name: "Touch ID"))
        XCTAssertEqual(WelcomeBiometry.value(.faceID), .init(symbol: "faceid", name: "Face ID"))
        XCTAssertEqual(WelcomeBiometry.value(.opticID), .init(symbol: "opticid", name: "Optic ID"))
        XCTAssertEqual(AppConfig.sourceCodeURL, AppConfiguration.sourceRepositoryURL ?? URL(string: "https://github.com/")!)
        XCTAssertEqual(AppConfig.resolvedSourceURL("https://github.com/example/takeback").absoluteString, "https://github.com/example/takeback")
        XCTAssertEqual(AppConfig.resolvedSourceURL("javascript:alert(1)").absoluteString, "https://github.com/")
        XCTAssertEqual(OpenSourceContent.rows.count, 4)
        XCTAssertNotNil(UIImage(named: "LogoTile"))
        XCTAssertEqual(OpenSourceContent.rows.last?.title, "Run it yourself")
    }

    func testSheetUsesMeasuredHeightAndFallsBackToLarge() {
        let fitted = HowItWorksSizing(measuredHeight: 453.3, availableHeight: 778)
        XCTAssertFalse(fitted.usesLargeDetent)
        XCTAssertEqual(fitted.detents, [.height(454)])
        let overflow = HowItWorksSizing(measuredHeight: 950, availableHeight: 778)
        XCTAssertTrue(overflow.usesLargeDetent)
        XCTAssertEqual(overflow.detents, [.large])
        XCTAssertEqual(HowItWorksSizing(measuredHeight: 0, availableHeight: 778).detents, [.large])
    }

    func testBalancedHeadlinePreservesExactCopyAndFitsEachLine() throws {
        let font = try XCTUnwrap(UIFont(name: Geist.Weight.medium.rawValue, size: 32))
        let text = BalancedWelcomeHeadline.text(width: 335, font: font, tracking: -1.28)
        XCTAssertEqual(text.replacingOccurrences(of: "\n", with: " "), "Cancel a stuck Bitcoin payment")
        XCTAssertEqual(text.components(separatedBy: "\n").count, 2)
        for line in text.components(separatedBy: "\n") {
            XCTAssertLessThanOrEqual((line as NSString).size(withAttributes: [.font: font, .kern: -1.28]).width, 335)
        }
    }
}
