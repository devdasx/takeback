import SwiftUI

struct TakebackRoot: View {
    @StateObject private var router = WelcomeRouter(session: .shared)

    var body: some View {
        NavigationStack(path: Binding(get: { router.path }, set: { router.navigate(to: $0) })) {
            WelcomeView(router: router)
                .navigationDestination(for: WelcomeRouter.Destination.self) { destination in
                    switch destination {
                    case .enterKey:
                        EnterKeyView(router: router, session: .shared)
                    case .scanner:
                        ScannerView(session: .shared, usesNativeNavigation: true, onResult: router.receiveScan)
                            .nativeNavigation(title: "Scan")
                            .tint(.white)
                    case .finding(let plan):
                        FindingView(router: router, session: .shared, plan: plan)
                    case .payments(let payments):
                        PaymentsView(router: router, session: .shared, payments: payments)
                    case .paymentExplanation(let payment):
                        PaymentExplanation(router: router, session: .shared, payment: payment)
                    case .review(let payment):
                        CancelView(router: router, session: .shared, payment: payment)
                    case .canceling(let request):
                        #if DEBUG
                        CancellationResultView(router: router, model: ResultFixtures.uiModel(request: request, session: .shared) ?? .init(request: request, session: .shared))
                        #else
                        CancellationResultView(router: router, model: .init(request: request, session: .shared))
                        #endif
                    case .cancelError(let problem):
                        CancellationResultView(router: router, model: .init(problem: problem, session: .shared))
                    case .searchPaths: SearchPathsView(router: router, session: .shared)
                    case .settings: SettingsView(router: router)
                    case .serverSettings: ServerSettingsView(router: router)
                    case .defaultFee: DefaultFeeView(router: router)
                    case .about: AboutView(router: router)
                    case .privacy: SettingsTextPage(router: router, title: "Privacy", text: SettingsTextPage.privacy)
                    case .terms: SettingsTextPage(router: router, title: "Terms", text: AppConfiguration.termsText ?? "")
                    case .licenses: LicensesView(router: router)
                    case .license(let license): SettingsTextPage(router: router, title: license.title, text: license.text)
                    }
                }
        }
        .takebackStyle()
        .task {
            guard NSClassFromString("XCTestCase") == nil else { return }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--") }) { return }
            #endif
            await ElectrumServerPool.shared.warmUp(servers: NetworkPreferences.shared.configuration.electrumServers)
        }
        #if DEBUG
        .task {
            SettingsFixtures.prepareUITest(); ResultFixtures.route(router)
            if ProcessInfo.processInfo.arguments.contains("--speed-ui") {
                router.path = [.enterKey, .review(PaymentsFixtures.payment(.normal, id: "a"))]
            }
            if ProcessInfo.processInfo.arguments.contains("--paths-ui") {
                // Public BIP39 fixture, confined to DEBUG UI verification.
                let session = SecretSession.shared
                session.wipe()
                try? session.key.replace(with: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about".utf8)
                session.searchSelection = .init()
                router.path = [.enterKey, .searchPaths]
            }
        }
        #endif
    }
}
