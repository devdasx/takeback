import SwiftUI
import SafariServices

/// Source link configured in project.yml.
enum AppConfig {
    static var sourceCodeURL: URL {
        resolvedSourceURL(Bundle.main.object(forInfoDictionaryKey: "TakebackSourceRepositoryURL") as? String)
    }
    static func resolvedSourceURL(_ configured: String?) -> URL {
        AppConfiguration.sourceURL(configured) ?? URL(string: "https://github.com/")!
    }
}

struct SourceBrowser: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

struct OpenSourceSheet: View {
    var sourceURL: URL = AppConfig.sourceCodeURL
    @State private var showsBrowser = false
    var body: some View {
        NativeSheet(title: "Open source", titleImage: "Logo") {
            ScrollView {
                OpenSourceContent().padding(.horizontal, 20).padding(.vertical, 20)
                    .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }.scrollBounceBehavior(.basedOnSize).accessibilityIdentifier("source.content")
                .bottomActions(adaptsToSplit: false) {
                    PrimaryButton(title: "View source code on GitHub", symbol: "chevron.left.forwardslash.chevron.right") {
                        showsBrowser = true
                    }.accessibilityIdentifier("source.github")
                }.background(Theme.bg)
        }.sheet(isPresented: $showsBrowser) { SourceBrowser(url: sourceURL).ignoresSafeArea() }
    }
}

struct OpenSourceContent: View {
    static let rows: [(symbol: String, title: String, body: String)] = [
        ("info.circle", "What Takeback does", "It finds pending payments sent from your key, then replaces one with a new transaction that pays the same coins back to you with a higher fee."),
        ("eye", "Why open source", "You’re trusting it with your key, so you shouldn’t have to take our word for it. Anyone can read every line and check it does only that."),
        ("lock", "Nothing leaves this iPhone", "Your key is used in memory and wiped after. Only addresses and the signed cancel go to the network."),
        ("terminal", "Run it yourself", "Build it from the source with Xcode and run it on your own device, or point it at your own Electrum server in Settings.")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                ForEach(Self.rows.indices, id: \.self) { i in
                    let row = Self.rows[i]
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: row.symbol).font(.system(size: 20)).foregroundStyle(Theme.mute).frame(width: 24).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.title).font(Geist.font(15, .semibold))
                            Text(row.body).font(Geist.font(14)).foregroundStyle(Theme.mute).lineSpacing(4)
                        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                    }.padding(.vertical, 14).padding(.horizontal, 18)
                    if i < Self.rows.count - 1 { Rectangle().fill(Theme.line).frame(height: 0.5) }
                }
            }.background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text("Free and open-source software. Each release is built from the public code.")
                .font(Geist.font(13)).foregroundStyle(Theme.mute).padding(.horizontal, 6).fixedSize(horizontal: false, vertical: true)
        }.fixedSize(horizontal: false, vertical: true)
    }
}
