#if DEBUG
import SwiftUI

enum SettingsFixtures {
    static let names = ["settings", "default-fee", "server", "own-checking", "own-connected", "own-unavailable", "own-invalid", "about"]
    static let rates = try! FeeRecommendations(nextBlock: 30, fast: 20, medium: 10, minimum: 1)
    static var isUITest: Bool { ProcessInfo.processInfo.arguments.contains("-settings-ui") }
    @MainActor static func prepareUITest() {
        if isUITest && ProcessInfo.processInfo.arguments.contains("-settings-reset") {
            NetworkPreferences.shared.resetForUITest(); UserDefaults.standard.removeObject(forKey: "defaultFee")
        }
    }
    @MainActor static func uiModel(preferences: NetworkPreferences) -> ServerSettingsModel? {
        guard isUITest else { return nil }
        return .init(preferences: preferences, http: SettingsFixtureHTTP(), electrum: SettingsFixtureRPC())
    }
}
private struct SettingsFixtureHTTP: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        if request.url?.host == "offline.example" { throw ChainError.network }
        return .init(status: 200, data: Data((request.url?.host == "invalid.example" ? "<html>not an API</html>" : "900001").utf8))
    }
}
private struct SettingsFixtureRPC: ElectrumTransport {
    func call(server: ElectrumServer, method: String, params: [JSONValue], timeout: TimeInterval) async throws -> JSONValue {
        if server.host == "offline.example" { throw ChainError.network }
        return .array([.string("Fixture"), .string("1.4")])
    }
}
@MainActor final class SettingsPreviewStore: ObservableObject {
    let session = SecretSession()
    let router: WelcomeRouter
    let preferences: NetworkPreferences
    let model: ServerSettingsModel
    init(state: Int) {
        router = WelcomeRouter(session: session)
        preferences = NetworkPreferences(defaults: UserDefaults(suiteName: "app.takeback.settings.preview")!)
        model = ServerSettingsModel(preferences: preferences)
        model.fixture = true
        switch state {
        case 3: model.showFixture(.checking)
        case 4: model.showFixture(.connected(900001))
        case 5: model.showFixture(.unavailable)
        case 6: model.showFixture(.invalidAPI)
        default: break
        }
    }
}
struct SettingsFixturePreview: View {
    let device: WelcomeDeviceFixture
    let state: Int
    let scheme: ColorScheme
    @StateObject private var store: SettingsPreviewStore
    init(device: WelcomeDeviceFixture, state: Int, scheme: ColorScheme) {
        self.device = device; self.state = state; self.scheme = scheme
        _store = StateObject(wrappedValue: SettingsPreviewStore(state: state))
    }
    var body: some View {
        Group {
            switch state {
            case 0: SettingsView(router: store.router, preferences: store.preferences)
            case 1: DefaultFeeView(router: store.router, preferences: store.preferences, previewRates: SettingsFixtures.rates)
            case 2...6: ServerSettingsView(router: store.router, preferences: store.preferences, model: store.model)
            default: AboutView(router: store.router)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: device.top) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: device.bottom) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: device.trailing) }
        .preferredColorScheme(scheme)
    }
}
#Preview("iPhone SE · light · settings", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 0, scheme: .light)
}
#Preview("iPhone SE · light · default-fee", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 1, scheme: .light)
}
#Preview("iPhone SE · light · server", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 2, scheme: .light)
}
#Preview("iPhone SE · light · own-checking", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 3, scheme: .light)
}
#Preview("iPhone SE · light · own-connected", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 4, scheme: .light)
}
#Preview("iPhone SE · light · own-unavailable", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 5, scheme: .light)
}
#Preview("iPhone SE · light · own-invalid", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 6, scheme: .light)
}
#Preview("iPhone SE · light · about", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 7, scheme: .light)
}
#Preview("iPhone SE · dark · settings", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 0, scheme: .dark)
}
#Preview("iPhone SE · dark · default-fee", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 1, scheme: .dark)
}
#Preview("iPhone SE · dark · server", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 2, scheme: .dark)
}
#Preview("iPhone SE · dark · own-checking", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 3, scheme: .dark)
}
#Preview("iPhone SE · dark · own-connected", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 4, scheme: .dark)
}
#Preview("iPhone SE · dark · own-unavailable", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 5, scheme: .dark)
}
#Preview("iPhone SE · dark · own-invalid", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 6, scheme: .dark)
}
#Preview("iPhone SE · dark · about", traits: .fixedLayout(width: 375, height: 667)) {
    SettingsFixturePreview(device: .requested[0], state: 7, scheme: .dark)
}
#Preview("iPhone 17 Pro · light · settings", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 0, scheme: .light)
}
#Preview("iPhone 17 Pro · light · default-fee", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 1, scheme: .light)
}
#Preview("iPhone 17 Pro · light · server", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 2, scheme: .light)
}
#Preview("iPhone 17 Pro · light · own-checking", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 3, scheme: .light)
}
#Preview("iPhone 17 Pro · light · own-connected", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 4, scheme: .light)
}
#Preview("iPhone 17 Pro · light · own-unavailable", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 5, scheme: .light)
}
#Preview("iPhone 17 Pro · light · own-invalid", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 6, scheme: .light)
}
#Preview("iPhone 17 Pro · light · about", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 7, scheme: .light)
}
#Preview("iPhone 17 Pro · dark · settings", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 0, scheme: .dark)
}
#Preview("iPhone 17 Pro · dark · default-fee", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 1, scheme: .dark)
}
#Preview("iPhone 17 Pro · dark · server", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 2, scheme: .dark)
}
#Preview("iPhone 17 Pro · dark · own-checking", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 3, scheme: .dark)
}
#Preview("iPhone 17 Pro · dark · own-connected", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 4, scheme: .dark)
}
#Preview("iPhone 17 Pro · dark · own-unavailable", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 5, scheme: .dark)
}
#Preview("iPhone 17 Pro · dark · own-invalid", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 6, scheme: .dark)
}
#Preview("iPhone 17 Pro · dark · about", traits: .fixedLayout(width: 402, height: 874)) {
    SettingsFixturePreview(device: .requested[1], state: 7, scheme: .dark)
}
#Preview("iPhone 17 Pro Max · light · settings", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 0, scheme: .light)
}
#Preview("iPhone 17 Pro Max · light · default-fee", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 1, scheme: .light)
}
#Preview("iPhone 17 Pro Max · light · server", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 2, scheme: .light)
}
#Preview("iPhone 17 Pro Max · light · own-checking", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 3, scheme: .light)
}
#Preview("iPhone 17 Pro Max · light · own-connected", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 4, scheme: .light)
}
#Preview("iPhone 17 Pro Max · light · own-unavailable", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 5, scheme: .light)
}
#Preview("iPhone 17 Pro Max · light · own-invalid", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 6, scheme: .light)
}
#Preview("iPhone 17 Pro Max · light · about", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 7, scheme: .light)
}
#Preview("iPhone 17 Pro Max · dark · settings", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 0, scheme: .dark)
}
#Preview("iPhone 17 Pro Max · dark · default-fee", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 1, scheme: .dark)
}
#Preview("iPhone 17 Pro Max · dark · server", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 2, scheme: .dark)
}
#Preview("iPhone 17 Pro Max · dark · own-checking", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 3, scheme: .dark)
}
#Preview("iPhone 17 Pro Max · dark · own-connected", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 4, scheme: .dark)
}
#Preview("iPhone 17 Pro Max · dark · own-unavailable", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 5, scheme: .dark)
}
#Preview("iPhone 17 Pro Max · dark · own-invalid", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 6, scheme: .dark)
}
#Preview("iPhone 17 Pro Max · dark · about", traits: .fixedLayout(width: 440, height: 956)) {
    SettingsFixturePreview(device: .requested[2], state: 7, scheme: .dark)
}
#Preview("Duo outer · light · settings", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 0, scheme: .light)
}
#Preview("Duo outer · light · default-fee", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 1, scheme: .light)
}
#Preview("Duo outer · light · server", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 2, scheme: .light)
}
#Preview("Duo outer · light · own-checking", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 3, scheme: .light)
}
#Preview("Duo outer · light · own-connected", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 4, scheme: .light)
}
#Preview("Duo outer · light · own-unavailable", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 5, scheme: .light)
}
#Preview("Duo outer · light · own-invalid", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 6, scheme: .light)
}
#Preview("Duo outer · light · about", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 7, scheme: .light)
}
#Preview("Duo outer · dark · settings", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 0, scheme: .dark)
}
#Preview("Duo outer · dark · default-fee", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 1, scheme: .dark)
}
#Preview("Duo outer · dark · server", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 2, scheme: .dark)
}
#Preview("Duo outer · dark · own-checking", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 3, scheme: .dark)
}
#Preview("Duo outer · dark · own-connected", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 4, scheme: .dark)
}
#Preview("Duo outer · dark · own-unavailable", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 5, scheme: .dark)
}
#Preview("Duo outer · dark · own-invalid", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 6, scheme: .dark)
}
#Preview("Duo outer · dark · about", traits: .fixedLayout(width: 466, height: 678)) {
    SettingsFixturePreview(device: .requested[3], state: 7, scheme: .dark)
}
#Preview("Duo inner · light · settings", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 0, scheme: .light)
}
#Preview("Duo inner · light · default-fee", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 1, scheme: .light)
}
#Preview("Duo inner · light · server", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 2, scheme: .light)
}
#Preview("Duo inner · light · own-checking", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 3, scheme: .light)
}
#Preview("Duo inner · light · own-connected", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 4, scheme: .light)
}
#Preview("Duo inner · light · own-unavailable", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 5, scheme: .light)
}
#Preview("Duo inner · light · own-invalid", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 6, scheme: .light)
}
#Preview("Duo inner · light · about", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 7, scheme: .light)
}
#Preview("Duo inner · dark · settings", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 0, scheme: .dark)
}
#Preview("Duo inner · dark · default-fee", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 1, scheme: .dark)
}
#Preview("Duo inner · dark · server", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 2, scheme: .dark)
}
#Preview("Duo inner · dark · own-checking", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 3, scheme: .dark)
}
#Preview("Duo inner · dark · own-connected", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 4, scheme: .dark)
}
#Preview("Duo inner · dark · own-unavailable", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 5, scheme: .dark)
}
#Preview("Duo inner · dark · own-invalid", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 6, scheme: .dark)
}
#Preview("Duo inner · dark · about", traits: .fixedLayout(width: 890, height: 626)) {
    SettingsFixturePreview(device: .requested[4], state: 7, scheme: .dark)
}
#Preview("Duo rotated · light · settings", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 0, scheme: .light)
}
#Preview("Duo rotated · light · default-fee", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 1, scheme: .light)
}
#Preview("Duo rotated · light · server", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 2, scheme: .light)
}
#Preview("Duo rotated · light · own-checking", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 3, scheme: .light)
}
#Preview("Duo rotated · light · own-connected", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 4, scheme: .light)
}
#Preview("Duo rotated · light · own-unavailable", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 5, scheme: .light)
}
#Preview("Duo rotated · light · own-invalid", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 6, scheme: .light)
}
#Preview("Duo rotated · light · about", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 7, scheme: .light)
}
#Preview("Duo rotated · dark · settings", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 0, scheme: .dark)
}
#Preview("Duo rotated · dark · default-fee", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 1, scheme: .dark)
}
#Preview("Duo rotated · dark · server", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 2, scheme: .dark)
}
#Preview("Duo rotated · dark · own-checking", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 3, scheme: .dark)
}
#Preview("Duo rotated · dark · own-connected", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 4, scheme: .dark)
}
#Preview("Duo rotated · dark · own-unavailable", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 5, scheme: .dark)
}
#Preview("Duo rotated · dark · own-invalid", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 6, scheme: .dark)
}
#Preview("Duo rotated · dark · about", traits: .fixedLayout(width: 626, height: 890)) {
    SettingsFixturePreview(device: .requested[5], state: 7, scheme: .dark)
}
#Preview("iPad mini portrait · light · settings", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 0, scheme: .light)
}
#Preview("iPad mini portrait · light · default-fee", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 1, scheme: .light)
}
#Preview("iPad mini portrait · light · server", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 2, scheme: .light)
}
#Preview("iPad mini portrait · light · own-checking", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 3, scheme: .light)
}
#Preview("iPad mini portrait · light · own-connected", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 4, scheme: .light)
}
#Preview("iPad mini portrait · light · own-unavailable", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 5, scheme: .light)
}
#Preview("iPad mini portrait · light · own-invalid", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 6, scheme: .light)
}
#Preview("iPad mini portrait · light · about", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 7, scheme: .light)
}
#Preview("iPad mini portrait · dark · settings", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 0, scheme: .dark)
}
#Preview("iPad mini portrait · dark · default-fee", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 1, scheme: .dark)
}
#Preview("iPad mini portrait · dark · server", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 2, scheme: .dark)
}
#Preview("iPad mini portrait · dark · own-checking", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 3, scheme: .dark)
}
#Preview("iPad mini portrait · dark · own-connected", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 4, scheme: .dark)
}
#Preview("iPad mini portrait · dark · own-unavailable", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 5, scheme: .dark)
}
#Preview("iPad mini portrait · dark · own-invalid", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 6, scheme: .dark)
}
#Preview("iPad mini portrait · dark · about", traits: .fixedLayout(width: 744, height: 1133)) {
    SettingsFixturePreview(device: .requested[6], state: 7, scheme: .dark)
}
#Preview("iPad mini landscape · light · settings", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 0, scheme: .light)
}
#Preview("iPad mini landscape · light · default-fee", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 1, scheme: .light)
}
#Preview("iPad mini landscape · light · server", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 2, scheme: .light)
}
#Preview("iPad mini landscape · light · own-checking", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 3, scheme: .light)
}
#Preview("iPad mini landscape · light · own-connected", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 4, scheme: .light)
}
#Preview("iPad mini landscape · light · own-unavailable", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 5, scheme: .light)
}
#Preview("iPad mini landscape · light · own-invalid", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 6, scheme: .light)
}
#Preview("iPad mini landscape · light · about", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 7, scheme: .light)
}
#Preview("iPad mini landscape · dark · settings", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 0, scheme: .dark)
}
#Preview("iPad mini landscape · dark · default-fee", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 1, scheme: .dark)
}
#Preview("iPad mini landscape · dark · server", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 2, scheme: .dark)
}
#Preview("iPad mini landscape · dark · own-checking", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 3, scheme: .dark)
}
#Preview("iPad mini landscape · dark · own-connected", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 4, scheme: .dark)
}
#Preview("iPad mini landscape · dark · own-unavailable", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 5, scheme: .dark)
}
#Preview("iPad mini landscape · dark · own-invalid", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 6, scheme: .dark)
}
#Preview("iPad mini landscape · dark · about", traits: .fixedLayout(width: 1133, height: 744)) {
    SettingsFixturePreview(device: .requested[7], state: 7, scheme: .dark)
}
#Preview("iPad Pro 13 landscape · light · settings", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 0, scheme: .light)
}
#Preview("iPad Pro 13 landscape · light · default-fee", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 1, scheme: .light)
}
#Preview("iPad Pro 13 landscape · light · server", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 2, scheme: .light)
}
#Preview("iPad Pro 13 landscape · light · own-checking", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 3, scheme: .light)
}
#Preview("iPad Pro 13 landscape · light · own-connected", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 4, scheme: .light)
}
#Preview("iPad Pro 13 landscape · light · own-unavailable", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 5, scheme: .light)
}
#Preview("iPad Pro 13 landscape · light · own-invalid", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 6, scheme: .light)
}
#Preview("iPad Pro 13 landscape · light · about", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 7, scheme: .light)
}
#Preview("iPad Pro 13 landscape · dark · settings", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 0, scheme: .dark)
}
#Preview("iPad Pro 13 landscape · dark · default-fee", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 1, scheme: .dark)
}
#Preview("iPad Pro 13 landscape · dark · server", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 2, scheme: .dark)
}
#Preview("iPad Pro 13 landscape · dark · own-checking", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 3, scheme: .dark)
}
#Preview("iPad Pro 13 landscape · dark · own-connected", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 4, scheme: .dark)
}
#Preview("iPad Pro 13 landscape · dark · own-unavailable", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 5, scheme: .dark)
}
#Preview("iPad Pro 13 landscape · dark · own-invalid", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 6, scheme: .dark)
}
#Preview("iPad Pro 13 landscape · dark · about", traits: .fixedLayout(width: 1376, height: 1032)) {
    SettingsFixturePreview(device: .requested[8], state: 7, scheme: .dark)
}
#endif
