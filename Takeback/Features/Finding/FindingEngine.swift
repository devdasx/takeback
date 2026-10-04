import Foundation

struct SearchRow: Equatable, Sendable {
    let type: AddressStandard
    var completed = 0
    var total: Int
    var started = false
    var pending = 0
    var searchPath: SearchPath? = nil
    var id: String { searchPath?.id ?? "type-\(type.rawValue)" }
    var title: String { searchPath?.title ?? type.title }
    var subtitle: String { searchPath.map { $0.source == .custom ? $0.subtitle : "BIP\(type.rawValue) · \($0.path)" } ?? type.subtitle }
    var done: Bool { completed == total }
    var status: String { done ? (pending > 0 ? "\(pending) pending" : "Nothing pending") : started ? "Checking \(completed) of \(total)" : "Waiting" }
}
struct SearchProgress: Sendable {
    var rows: [SearchRow]
    var server: String
    var isFallback: Bool
    var failedHost: String? = nil
    var fraction: Double {
        let total = rows.reduce(0) { $0 + $1.total }
        return total == 0 ? 0 : Double(rows.reduce(0) { $0 + $1.completed }) / Double(total)
    }
}
struct SearchResult: Sendable {
    let payments: [PendingPayment]
    let lastConfirmed: Date?
    let server: String
    let checkedAt: Date
}
enum FindingOutcome: Sendable {
    case searching, found(SearchResult), none, confirmed(Date), offline, serversDown([SearchAttempt])
}

typealias SearchProgressHandler = @Sendable (SearchProgress) async -> Void
private actor SearchProgressTracker {
    var progress: SearchProgress
    let handler: SearchProgressHandler
    init(rows: [SearchRow], server: String, fallback: Bool, handler: @escaping SearchProgressHandler) {
        progress = .init(rows: rows, server: server, isFallback: fallback); self.handler = handler
    }
    func update(type: AddressStandard, completed: Int, pending: Int) async {
        guard let index = progress.rows.firstIndex(where: { $0.type == type }) else { return }
        progress.rows[index].started = true; progress.rows[index].completed = completed; progress.rows[index].pending = pending
        await handler(progress)
    }
}

struct FindingEngine: Sendable {
    let configuration: ChainConfiguration
    var http: any HTTPTransport = URLSessionTransport()
    var electrum: any ElectrumTransport = TLSElectrumTransport()
    var connectivity: any SearchConnectivity = PathConnectivity()

    func search(addresses initial: [SearchAddress], publicPlan: PublicScanPlan? = nil, gap: Int = 20, now: Date = Date(), progress: @escaping SearchProgressHandler) async throws -> FindingOutcome {
        guard try await connectivity.isOnline() else { return .offline }
        try Task.checkCancellation()
        guard !initial.isEmpty else { throw ChainError.invalidConfiguration }
        let client = ElectrumClient(configuration: configuration, transport: electrum)
        let network = SearchNetwork(configuration: configuration, http: http, electrum: electrum, client: client)
        do {
            let result = try await scan(initial: initial, publicPlan: publicPlan, gap: gap, network: network, client: client, now: now, progress: progress)
            if !result.payments.isEmpty { return .found(result) }
            if let date = result.lastConfirmed { return .confirmed(date) }
            return .none
        } catch {
            try Task.checkCancellation()
            if case SearchFailure.servers(let attempts) = error { return .serversDown(attempts.map { .init(server: $0.host, detail: $0.reason) }) }
            let server = await client.current?.host ?? configuration.electrumServers.first?.host ?? "Electrum"
            return .serversDown([.init(server: server, error: error, timeout: 8)])
        }
    }
    private func scan(initial: [SearchAddress], publicPlan: PublicScanPlan?, gap: Int, network: SearchNetwork, client: ElectrumClient,
                      now: Date, progress: @escaping SearchProgressHandler) async throws -> SearchResult {
        let addresses: [SearchAddress], histories: [[TransactionSummary]]
        if let publicPlan {
            let scanned = try await GapScanner.scan(plan: publicPlan, gap: gap, client: client, progress: progress)
            addresses = scanned.addresses; histories = scanned.histories
        } else {
            addresses = initial; histories = try await network.histories(initial)
        }
        let owned = Dictionary(addresses.map { ($0.chain.scriptPubKey.hex, $0.type) }, uniquingKeysWith: { a, _ in a })
        let transactions = try await network.collected(addresses, histories: histories, since: now.addingTimeInterval(-86_400))
        let server = await client.current?.host ?? "Electrum"
        let previousTransactions = await SessionTransactions.shared.observe(transactions)
        try Task.checkCancellation()
        var unique: [String: SearchTransaction] = [:]
        for tx in transactions {
            // Prefer confirmed if a transaction confirmed while its other addresses were being checked.
            if unique[tx.txid]?.status.confirmed != true { unique[tx.txid] = tx }
        }
        var payments: [PendingPayment] = [], lastConfirmed: Date?
        let needsMetadata = unique.values.contains { !$0.status.confirmed && $0.vin.contains { owned[$0.prevout?.scriptpubkey.lowercased() ?? ""] != nil } }
        let metadata = needsMetadata ? await network.paymentMetadata() : (usdRate: nil as Decimal?, fullRBF: false)
        try Task.checkCancellation()
        let ownedScripts = Set(owned.keys)
        for tx in unique.values.sorted(by: { $0.txid < $1.txid }) {
            let ourInputs = tx.vin.compactMap { owned[$0.prevout?.scriptpubkey.lowercased() ?? ""] }
            guard !ourInputs.isEmpty else { continue }
            if tx.status.confirmed {
                if let timestamp = tx.status.block_time {
                    let date = Date(timeIntervalSince1970: Double(timestamp))
                    if date >= now.addingTimeInterval(-86_400), date <= now { lastConfirmed = max(lastConfirmed ?? date, date) }
                }
                continue
            }
            var payment = PendingPayment(txid: tx.txid, types: AddressStandard.allCases.filter { ourInputs.contains($0) },
                ownedInputCount: ourInputs.count, totalInputCount: tx.vin.count,
                signalsRBF: tx.vin.contains { $0.sequence < 0xfffffffe }, feeSats: tx.fee,
                virtualSize: (tx.weight+3)/4, firstSeen: nil,
                recipient: tx.vout.first(where: { owned[$0.scriptpubkey.lowercased()] == nil }).map { $0.scriptpubkey_address ?? $0.scriptpubkey }, descendants: nil)
            // These APIs do not all supply first-seen time. Preserve unknown instead of inventing an age.
            payment.firstSeen = try? await network.firstSeen(tx.txid)
            try Task.checkCancellation()
            payment.descendants = try await network.descendants(of: tx)
            try Task.checkCancellation()
            let totals = try PaymentEvidence.totals(tx, owned: ownedScripts)
            payment.amountSats = totals.amount
            payment.ownedInputSats = totals.ours
            payment.otherInputSats = totals.others
            payment.usdRate = metadata.usdRate
            payment.fullRBF = metadata.fullRBF
            payment.inheritedRBF = PaymentEvidence.inheritedRBF(tx, transactions: unique)
            for original in previousTransactions + Array(unique.values) {
                if PaymentEvidence.isOwnCancellation(original: original, replacement: tx, owned: ownedScripts) {
                    let originalTotals = try PaymentEvidence.totals(original, owned: ownedScripts)
                    payment.cancellation = .init(originalTxid: original.txid,
                        originalRecipient: original.vout.first { !ownedScripts.contains($0.scriptpubkey) }?.scriptpubkey_address,
                        originalAmountSats: originalTotals.amount, originalFeeRate: Decimal(original.fee) / Decimal((original.weight+3)/4),
                        originalFirstSeen: nil, replacementTxid: tx.txid, replacementFeeRate: payment.feeRate, replacementFirstSeen: nil)
                    break
                }
            }
            payment.signingAddresses = addresses.map { address in
                if address.derivation != nil { return address.signing }
                return SigningAddress(type: address.type, path: [], script: address.chain.scriptPubKey, compressed: address.compressed)
            }
            payment.mempoolAPIURL = configuration.mempoolURL
            payment.electrumServers = configuration.electrumServers
            payment.explorerBaseURL = configuration.mempoolURL.lastPathComponent == "api"
                ? configuration.mempoolURL.deletingLastPathComponent() : configuration.mempoolURL
            try Task.checkCancellation()
            payments.append(payment)
        }
        var finalRows = publicPlan?.rows(gap: gap) ?? initial.map { SearchRow(type: $0.type, total: 1) }
        for i in finalRows.indices {
            let matching = addresses.filter { $0.rowID == finalRows[i].id }
            let scripts = Set(matching.map { $0.chain.scriptPubKey })
            finalRows[i].total = matching.count; finalRows[i].completed = matching.count; finalRows[i].started = true
            finalRows[i].pending = payments.filter { payment in
                guard let tx = unique[payment.txid] else { return false }
                return tx.vin.contains { input in input.prevout.flatMap { Data(hex: $0.scriptpubkey) }.map { scripts.contains($0) } ?? false }
            }.count
        }
        await progress(.init(rows: finalRows, server: server, isFallback: await client.failedOver != nil, failedHost: await client.failedOver?.from))
        payments.sort { ($0.firstSeen ?? .distantFuture, $0.txid) < ($1.firstSeen ?? .distantFuture, $1.txid) }
        return SearchResult(payments: payments, lastConfirmed: lastConfirmed, server: server, checkedAt: now)
    }
}
