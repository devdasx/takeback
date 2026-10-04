import Foundation

struct GapScanResult: Sendable {
    let addresses: [SearchAddress]
    let histories: [[TransactionSummary]]
    let unspent: [[ElectrumUTXO]]
    let batches: Int
    let elapsed: TimeInterval
    let host: String
}
enum GapScanner {
    static func scan(plan: PublicScanPlan, gap: Int, client: ElectrumClient,
                     progress: @escaping SearchProgressHandler = { _ in }) async throws -> GapScanResult {
        guard [20,50,100,200].contains(gap) else { throw ChainError.invalidConfiguration }
        let start = Date()
        var addresses: [SearchAddress] = [], histories: [[TransactionSummary]] = []
        var round = try plan.initial(gap: gap)
        var known: [String: [TransactionSummary]] = [:]
        while !round.isEmpty {
            try Task.checkCancellation()
            let planned = addresses + round
            let rows = plan.rows(gap: gap).map { template in
                var row = template
                row.completed = addresses.filter { $0.rowID == row.id }.count
                row.total = planned.filter { $0.rowID == row.id }.count
                row.started = true
                return row
            }
            await progress(.init(rows: rows, server: await client.current?.host ?? "Electrum", isFallback: await client.failedOver != nil, failedHost: await client.failedOver?.from))
            // Paths can overlap (e.g. a custom fixed receive chain). Query their union once.
            var seen = Set<String>()
            let hashes = round.map { $0.chain.electrumScriptHash }.filter { known[$0] == nil && seen.insert($0).inserted }
            let replies = try await client.histories(hashes)
            for (hash, reply) in zip(hashes, replies) { known[hash] = reply }
            addresses += round; histories += round.map { known[$0.chain.electrumScriptHash] ?? [] }
            await progress(.init(rows: rows.map { var r = $0; r.completed = r.total; return r }, server: await client.current?.host ?? "Electrum", isFallback: await client.failedOver != nil, failedHost: await client.failedOver?.from))
            round = []
            if plan.single.isEmpty {
                for path in plan.effectivePaths { for branch in path.branches {
                    let checked = zip(addresses, histories).filter { $0.0.rowID == path.id && $0.0.branch == branch }
                    let next = (checked.map { Int($0.0.index) }.max() ?? -1) + 1
                    let tailUsed = checked.contains { Int($0.0.index) >= next - 20 && !$0.1.isEmpty }
                    if tailUsed && next < 1000 {
                        for index in next..<min(1000, next + 20) {
                            try Task.checkCancellation()
                            round.append(try plan.address(path: path, branch: branch, index: UInt32(index)))
                        }
                    }
                } }
            }
        }
        var seen = Set<String>()
        let hashes = addresses.map { $0.chain.electrumScriptHash }.filter { seen.insert($0).inserted }
        let unspent = try await client.unspent(hashes)
        return .init(addresses: addresses, histories: histories, unspent: unspent, batches: await client.batchCount,
                     elapsed: Date().timeIntervalSince(start), host: await client.current?.host ?? "Electrum")
    }
}
