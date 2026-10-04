import SwiftUI

struct AppLicense: Hashable, Identifiable {
    let id: String
    let title: String
    var text: String { Bundle.main.url(forResource: id, withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "" }
    static let all: [Self] = [
        .init(id: "MuunRecoveryLicense", title: "Muun recovery tool · MIT"),
        .init(id: "GeistLicense", title: "Geist"),
        .init(id: "Secp256k1License", title: "libsecp256k1"),
        .init(id: "BitcoinCoreLicense", title: "Bitcoin Core · RIPEMD-160"),
        .init(id: "BIP39License", title: "BIP39 word list"),
        .init(id: "ScannerNotices", title: "Blockchain Commons · URKit")
    ]
}
struct AboutView: View {
    @ObservedObject var router: WelcomeRouter
    @Environment(\.openURL) private var openURL
    var body: some View {
        SettingsPage(router: router, title: "Takeback", subtitle: "Version \(AppConfiguration.version)", hero: AnyView(Image("LogoTile").resizable().scaledToFit().frame(width: 64, height: 64).accessibilityLabel("Takeback").accessibilityIdentifier("about.logo")), centeredHeader: true) {
            IndexRow(symbol: "chevron.left.forwardslash.chevron.right", title: "Source code", value: "View on GitHub ↗") {
                if let url = AppConfiguration.sourceRepositoryURL { openURL(url) }
            }.disabled(AppConfiguration.sourceRepositoryURL == nil).accessibilityIdentifier("about.source")
            IndexRow(symbol: "hand.raised", title: "Privacy", value: "Takeback collects no data") { router.path.append(.privacy) }.accessibilityIdentifier("about.privacy")
            IndexRow(symbol: "doc.text", title: "Terms") { router.path.append(.terms) }
                .disabled(AppConfiguration.termsText == nil).accessibilityIdentifier("about.terms")
            IndexRow(symbol: "doc.plaintext", title: "Open-source licenses") { router.path.append(.licenses) }.accessibilityIdentifier("about.licenses")
        }
    }
}
struct SettingsTextPage: View {
    @ObservedObject var router: WelcomeRouter
    let title: String
    let text: String
    var body: some View {
        SettingsPage(router: router, title: title) {
            Text(text).font(Geist.font(15)).foregroundStyle(Theme.mute).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true).padding(.vertical, 16)
        }
    }
    static let privacy = "Takeback has no accounts and collects no data. Your key stays in memory and is wiped after use. Electrum servers see the addresses being checked; use your own or a Tor server for more privacy."
}
struct LicensesView: View {
    @ObservedObject var router: WelcomeRouter
    var body: some View {
        SettingsPage(router: router, title: "Open-source licenses") {
            ForEach(AppLicense.all) { license in
                IndexRow(symbol: "doc.plaintext", title: license.title) { router.path.append(.license(license)) }.accessibilityIdentifier("license.\(license.id)")
            }
        }
    }
}
