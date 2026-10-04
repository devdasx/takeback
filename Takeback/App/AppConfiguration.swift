import Foundation

enum AppConfiguration {
    // TODO(owner): domain — supply final privacy, terms and support URLs when decided.
    // No existing external policy URLs are configured; keep the bundled pages unchanged.
    /// Set TAKEBACK_SOURCE_URL in project.yml to the app's actual public repository.
    /// An absent configuration never sends the user to an unrelated or invented repository.
    static var sourceRepositoryURL: URL? {
        sourceURL(Bundle.main.object(forInfoDictionaryKey: "TakebackSourceRepositoryURL") as? String)
    }
    static func sourceURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme == "https", url.host == "github.com",
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.pathComponents.count >= 3 else { return nil }
        return url
    }
    static var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
    /// Supply the approved static Terms copy as a bundled resource; never invent legal terms.
    static var termsText: String? {
        guard let url = Bundle.main.url(forResource: "TakebackTerms", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty else { return nil }
        return text
    }
}
