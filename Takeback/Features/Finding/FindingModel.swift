import Foundation

@MainActor final class FindingModel: ObservableObject {
    @Published var outcome: FindingOutcome = .searching
    @Published var progress: SearchProgress
    @Published private(set) var gap = 20
    let plan: KeySearchPlan
    let label: String
    let isPhrase: Bool
    let hasPassphrase: Bool
    @Published private(set) var primaryServer: String
    private let session: SecretSession
    private var engine: FindingEngine
    private let refreshConfiguration: Bool
    private let preferences: NetworkPreferences
    private var task: Task<Void, Never>?
    private var work: SearchDerivationWork?
    private var generation = UUID()
    private var wipeHandler: UUID?
    private var addresses: [SearchAddress] = []
    private let selection: SearchSelection
    private var publicPlan: PublicScanPlan?
    init(plan: KeySearchPlan, session: SecretSession, engine: FindingEngine? = nil, preferences: NetworkPreferences = .shared) {
        self.preferences = preferences
        self.plan = plan; self.session = session
        selection = session.searchSelection ?? SearchDefaults.shared.selection
        gap = selection.addressesPerPath
        publicPlan = session.publicScanPlan
        let detection = detectKey(session.key)
        isPhrase = detection.isPhrase
        hasPassphrase = detection.isPhrase && session.passphrase.count > 0
        label = detection.label(settled: true) + (hasPassphrase ? " + passphrase" : "")
        #if DEBUG
        refreshConfiguration = engine == nil && FindingUITestSupport.engine == nil
        let engine = engine ?? FindingUITestSupport.engine ?? FindingEngine(configuration: preferences.configuration)
        #else
        refreshConfiguration = engine == nil
        let engine = engine ?? FindingEngine(configuration: preferences.configuration)
        #endif
        self.engine = engine
        let server = engine.configuration.electrumServers.first?.host ?? "Electrum"
        primaryServer = server
        progress = .init(rows: [], server: server, isFallback: false)
        progress.rows = initialRows
        wipeHandler = session.registerEditorClear { [weak self] in self?.stop() }
    }
    func start(gap requestedGap: Int? = nil) {
        stop()
        if refreshConfiguration { engine = FindingEngine(configuration: preferences.configuration); primaryServer = engine.configuration.electrumServers.first?.host ?? "Electrum" }
        guard session.key.count > 0 else { return }
        if wipeHandler == nil { wipeHandler = session.registerEditorClear { [weak self] in self?.stop() } }
        let nextGap = requestedGap ?? gap
        if nextGap != gap { addresses = [] }
        gap = nextGap
        outcome = .searching
        progress = .init(rows: initialRows, server: primaryServer, isFallback: false)
        let id = generation
        task = Task { [weak self] in
            guard let self else { return }
            do {
                #if DEBUG
                if let result = PaymentsUITestSupport.result { self.outcome = .found(result); return }
                #endif
                if let publicPlan = self.publicPlan { self.addresses = try publicPlan.initial(gap: gap) }
                if self.addresses.isEmpty {
                    let work = try SearchDerivationWork(key: session.key, passphrase: session.passphrase)
                    self.work = work
                    let prepared = try await Task.detached(priority: .userInitiated) { try work.prepare(plan: self.plan, selection: self.selection) }.value
                    guard !Task.isCancelled, self.generation == id, session.key.count > 0 else { return }
                    self.publicPlan = prepared
                    self.addresses = try prepared.initial(gap: gap)
                    self.work = nil
                }
                try Task.checkCancellation()
                let result = try await engine.search(addresses: addresses, publicPlan: publicPlan, gap: gap) { [weak self] progress in
                    await self?.accept(progress, generation: id)
                }
                guard !Task.isCancelled, self.generation == id else { return }
                self.outcome = result
            } catch {
                guard !Task.isCancelled, self.generation == id else { return }
                // A vanished session returns to entry through the view's wipe-generation observer.
                self.outcome = .serversDown([.init(server: primaryServer, detail: "Search couldn’t be completed")])
            }
        }
    }
    #if DEBUG
    func setPreviewGap(_ value: Int) { gap = value }
    #endif
    private func accept(_ progress: SearchProgress, generation: UUID) {
        guard self.generation == generation else { return }; self.progress = progress
    }
    func stop() { generation = UUID(); task?.cancel(); task = nil; work?.cancel(); work = nil }
    func release() { stop(); addresses = []; publicPlan = nil; if let wipeHandler { session.unregisterEditorClear(wipeHandler); self.wipeHandler = nil } }
    deinit { task?.cancel(); work?.cancel() }
    var initialRows: [SearchRow] {
        if plan.origin == .single { return selection.enabledTypes(for: plan).map { .init(type: $0, total: 1) } }
        return selection.paths(for: plan).map { .init(type: $0.scriptType, total: gap * $0.branches.count, searchPath: $0) }
    }
    var searchingDescription: String {
        if plan.origin == .single { return "Checking \(selection.enabledTypes(for: plan).count) addresses." }
        return "Checking \(gap) addresses per path on \(selection.paths(for: plan).count) paths."
    }
    var checkedDescription: String {
        if plan.origin == .single { let count = selection.enabledTypes(for: plan).count; return count == 1 ? "the address of this key" : "the \(count) addresses of this key" }
        return "\(gap) addresses per path on \(selection.paths(for: plan).count) paths"
    }
    var reasons: [(String, String)] {
        var list: [(String, String)] = []
        if hasPassphrase { list.append(("Check the passphrase", "A different passphrase opens a different wallet. Even one wrong character changes it.")) }
        list += [("It may have already confirmed", "Confirmed payments are final and can’t be canceled."),
                 ("It may be from a different key", "Use the recovery phrase or key of the wallet that sent it.")]
        if isPhrase { list.append(("It may use later addresses", "Search up to 100 addresses of each type.")) }
        return list
    }
    nonisolated static func age(_ date: Date, now: Date = Date()) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        if minutes < 1 { return "less than a minute" }
        if minutes < 60 { return "\(minutes) \(minutes == 1 ? "minute" : "minutes")" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) \(hours == 1 ? "hour" : "hours")" }
        let days = hours / 24
        return "\(days) \(days == 1 ? "day" : "days")"
    }
    static func foundBody(_ result: SearchResult) -> String {
        let types = AddressStandard.allCases.filter { type in result.payments.contains { $0.types.contains(type) } }.map(\.title)
        let names = ListFormatter.localizedString(byJoining: types)
        let count = result.payments.count
        let intro = count == 1 ? "From your \(names) address." : "\(count == 2 ? "Both" : "All") from \(names) addresses."
        let dates = result.payments.compactMap(\.firstSeen)
        guard dates.count == count, let oldest = dates.min() else { return intro }
        return intro + (count == 1 ? " It’s been waiting " : " The oldest has been waiting ") + age(oldest, now: result.checkedAt) + "."
    }
}
