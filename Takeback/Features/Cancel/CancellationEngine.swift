import Foundation

struct CancellationEngine: Sendable {
    let configuration: ChainConfiguration
    var http: any HTTPTransport = URLSessionTransport()
    var electrum: any ElectrumTransport = TLSElectrumTransport()
    var service: ChainService { ChainService(configuration: configuration, http: http, electrum: electrum) }
    func prepare(payment: PendingPayment, work: CancellationKeyWork) async throws -> CancellationPlan {
        guard payment.kind.canCancel else { throw CancelFailure.invalidReplacement }
        let addresses = payment.signingAddresses.isEmpty ? try await Task.detached(priority: .userInitiated) { try work.addresses() }.value : payment.signingAddresses
        try Task.checkCancellation()
        let network = SearchNetwork(configuration: configuration, http: http, electrum: electrum)
        return try await prepare(payment: payment, work: work, addresses: addresses, network: network)
    }
    func prepareSpeedUp(payment: PendingPayment, work: CancellationKeyWork) async throws -> CancellationPlan {
        let cancellation = try await prepare(payment: payment, work: work)
        let tx = try await service.client.transactions([payment.txid])[0]
        let known = payment.signingAddresses.isEmpty ? try work.addresses() : payment.signingAddresses
        let owned = Dictionary(known.map { ($0.script.hex, $0) }, uniquingKeysWith: { a, _ in a })
        let candidates = tx.outputs.indices.filter { owned[tx.outputs[$0].scriptpubkey] != nil }
        let change = candidates.max(by: { tx.outputs[$0].value < tx.outputs[$1].value })
        let index = change ?? (tx.outputs.count == 1 ? 0 : -1)
        let destination = change.flatMap { owned[tx.outputs[$0].scriptpubkey] } ?? cancellation.destination
        return CancellationPlan(originalID: cancellation.originalID, originalFee: cancellation.originalFee,
            originalVSize: cancellation.originalVSize, inputs: cancellation.inputs, destination: destination,
            descendants: cancellation.descendants, height: tx.locktime, incrementalRelayRate: cancellation.incrementalRelayRate,
            speedUpOutputs: try tx.outputs.map { output in
                guard let script = Data(hex: output.scriptpubkey) else { throw CancelFailure.invalidReplacement }
                return ReplacementOutput(value: output.value, script: script)
            }, changeIndex: index, fromAmount: change == nil, recipientIndexes: tx.outputs.indices.filter { owned[tx.outputs[$0].scriptpubkey] == nil })
    }
    private func prepare(payment: PendingPayment, work: CancellationKeyWork, addresses: [SigningAddress], network: SearchNetwork) async throws -> CancellationPlan {
        let original = try await network.verifiedPending(payment.txid)
        let owned = Dictionary(addresses.map { ($0.script.hex,$0) }, uniquingKeysWith: { a,_ in a })
        let inputs = try original.vin.map { input -> ReplacementInput in
            guard let prevout = input.prevout, let key = owned[prevout.scriptpubkey], input.vout <= UInt32.max else { throw CancelFailure.invalidReplacement }
            return .init(txid: input.txid, index: UInt32(input.vout), value: prevout.value, key: key)
        }
        guard !inputs.isEmpty, inputs.count <= 1000,
              Set(inputs.map { $0.outpoint }).count == inputs.count else { throw CancelFailure.invalidReplacement }
        _ = try PaymentEvidence.totals(original, owned: Set(owned.keys))
        guard let largest = inputs.max(by: { $0.value < $1.value }) else { throw CancelFailure.invalidReplacement }
        let destination: SigningAddress
        if work.plan.origin == .single { destination = largest.key }
        else {
            // Preserve the actual search path, including fixed chains and nonzero accounts.
            let source = largest.key.searchPath ?? SearchPath.standard(largest.key.type, account: 0)
            let selection = SearchSelection(enabled: [], custom: [source])
            let publicPlan = try work.publicPlan(selection: work.plan.isAccount ? SearchSelection(enabled: [largest.key.type]) : selection)
            guard let path = publicPlan.effectivePaths.first else { throw CancelFailure.invalidReplacement }
            var next: UInt32 = 0
            var candidate = work.signingAddress(try publicPlan.address(path: path, branch: 0, index: next))
            while try await network.used(candidate) {
                try Task.checkCancellation()
                guard next < 0x7ffffffe else { throw ChainError.unavailable }; next += 1
                candidate = work.signingAddress(try publicPlan.address(path: path, branch: 0, index: next))
            }
            destination = candidate
        }
        let ids = try await network.descendants(of: original)
        guard ids.count < 100 else { throw CancelFailure.invalidReplacement }
        var linked: [LinkedPayment] = []
        for id in ids {
            let tx = try await network.verifiedPending(id)
            let totals = try PaymentEvidence.totals(tx, owned: Set(owned.keys))
            let recipient = tx.vout.first { owned[$0.scriptpubkey] == nil }?.scriptpubkey_address
            linked.append(.init(txid: id, fee: tx.fee, amount: totals.amount, recipient: recipient, firstSeen: try? await network.firstSeen(id)))
        }
        let plan = CancellationPlan(originalID: original.txid, originalFee: original.fee, originalVSize: (original.weight+3)/4,
            inputs: inputs, destination: destination, descendants: linked, height: try await network.currentHeight(), incrementalRelayRate: (try await service.electrumFees()).minimum)
        guard plan.replacedFee <= 2_100_000_000_000_000 else { throw CancelFailure.invalidReplacement }
        return plan
    }
}
