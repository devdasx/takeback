import Foundation

/// Worker-owned key copies are cleared on completion, task cancellation and session expiry.
final class CancellationKeyWork: @unchecked Sendable {
    private let lock = NSLock()
    private let key = SecureBytes(), passphrase = SecureBytes()
    private var canceled = false
    let plan: KeySearchPlan
    let compressed: Bool
    init(sessionKey: SecureBytes, passphrase: SecureBytes) throws {
        let detection = detectKey(sessionKey)
        guard let plan = detection.searchPlan else { throw CancelFailure.unavailable }
        self.plan = plan; compressed = detection.compressed
        try sessionKey.withUnsafeBytes { try key.replace(with: $0) }
        try passphrase.withUnsafeBytes { try self.passphrase.replace(with: $0) }
    }
    func cancel() { lock.withLock { canceled = true; key.wipe(); passphrase.wipe() } }
    var isCleared: Bool { lock.withLock { key.count == 0 && passphrase.count == 0 } }
    func withRoot<T>(_ body: (SecureBytes) throws -> T) throws -> T {
        try lock.withLock {
            guard !canceled else { throw CancellationError() }
            let root = try KeyMaterial.root(key: key, passphrase: passphrase)
            defer { root.wipe() }
            return try body(root)
        }
    }
    func publicPlan(selection: SearchSelection = .init()) throws -> PublicScanPlan {
        try lock.withLock {
            guard !canceled else { throw CancellationError() }
            return try SearchDerivationWork(key: key, passphrase: passphrase).prepare(plan: plan, selection: selection)
        }
    }
    func signingAddress(_ address: SearchAddress) -> SigningAddress {
        if address.derivation != nil { return address.signing }
        var path: [UInt32] = []
        if plan.origin != .single {
            if plan.origin == .mnemonic || plan.origin == .master { path = [UInt32(address.type.rawValue) | 0x80000000, 0x80000000, 0x80000000] }
            path += [address.branch, address.index]
        }
        return .init(type: address.type, path: path, script: address.chain.scriptPubKey, compressed: compressed)
    }
    func addresses(gap: Int = 100) throws -> [SigningAddress] {
        try publicPlan().initial(gap: gap).map(signingAddress)
    }
    func address(type: AddressStandard, index: UInt32) throws -> SigningAddress {
        let publicPlan = try publicPlan()
        if let single = publicPlan.single.first(where: { $0.type == type }) { return signingAddress(single) }
        return signingAddress(try publicPlan.address(type: type, branch: 0, index: index))
    }
    static func address(root: SecureBytes, plan: KeySearchPlan, type: AddressStandard, branch: UInt32, index: UInt32, compressed: Bool) throws -> SigningAddress {
        var path: [UInt32] = []
        if plan.origin != .single {
            if plan.origin == .mnemonic || plan.origin == .master { path = [UInt32(type.rawValue) | 0x80000000, 0x80000000, 0x80000000] }
            path += [branch,index]
        }
        let template = SigningAddress(type: type, path: path, script: Data(), compressed: compressed)
        return SigningAddress(type: type, path: path, script: try script(root: root, address: template), compressed: compressed)
    }
    static func script(root: SecureBytes, address: SigningAddress) throws -> Data {
        var script = [UInt8](repeating: 0, count: 34), count = 0
        let ok = root.withUnsafeBytes { takeback_search_script($0.bindMemory(to: UInt8.self).baseAddress, address.path, address.path.count, Int32(address.type.rawValue), address.compressed ? 1 : 0, &script, &count) }
        guard ok == 1 else { throw CancelFailure.invalidReplacement }
        return Data(script.prefix(count))
    }
    static func publicKey(root: SecureBytes, address: SigningAddress) throws -> Data {
        var pub = [UInt8](repeating: 0, count: 65), count = 0
        let ok = root.withUnsafeBytes { takeback_public($0.bindMemory(to: UInt8.self).baseAddress, address.path, address.path.count, address.compressed ? 1 : 0, &pub, &count) }
        guard ok == 1 else { throw CancelFailure.invalidReplacement }
        return Data(pub.prefix(count))
    }
    func sign(_ plan: CancellationPlan, rate: Decimal) throws -> SignedCancellation {
        defer { cancel() }
        return try withRoot { root in
            let fee = try plan.validate(rate: rate)
            guard try Self.script(root: root, address: plan.destination) == plan.destination.script else { throw CancelFailure.invalidReplacement }
            for input in plan.inputs {
                guard try Self.script(root: root, address: input.key) == input.key.script else { throw CancelFailure.invalidReplacement }
            }
            let pubs = try plan.inputs.map { try Self.publicKey(root: root, address: $0.key) }
            let unsigned = plan.transaction(amount: plan.total - plan.fixedOutputValue - fee, signatures: plan.inputs.map { _ in Data() }, publicKeys: pubs)
            var signatures: [Data] = []
            for i in plan.inputs.indices {
                try Task.checkCancellation()
                let address = plan.inputs[i].key
                let digest = try unsigned.signatureHash(index: i, publicKey: pubs[i])
                var signature = [UInt8](repeating: 0, count: 72), count = 0
                let ok = root.withUnsafeBytes { takeback_sign($0.bindMemory(to: UInt8.self).baseAddress, address.path, address.path.count, address.type == .bip86 ? 1 : 0, [UInt8](digest), &signature, &count) }
                guard ok == 1 else { throw CancelFailure.invalidReplacement }
                signatures.append(Data(signature.prefix(count)) + (address.type == .bip86 ? Data() : Data([1])))
            }
            let wire = plan.transaction(amount: plan.total - plan.fixedOutputValue - fee, signatures: signatures, publicKeys: pubs)
            let raw = wire.serialize(witness: true)
            try ReplacementCheck.validate(raw: raw, plan: plan, rate: rate, root: root)
            return SignedCancellation(originalID: plan.originalID, raw: raw, txid: try TransactionID.compute(raw: raw), destination: plan.mode == .speedUp ? (plan.speedUpOutputs.flatMap { outputs in (plan.recipientIndexes?.first ?? outputs.indices.first).flatMap { BitcoinAddress.encode(script: outputs[$0].script) } } ?? "") : plan.destination.address, fee: fee, amount: try plan.recipientAmount(rate: rate))
        }
    }
}

enum ReplacementCheck {
    static func validate(raw: Data, plan: CancellationPlan, rate: Decimal, root: SecureBytes) throws {
        let expectedFee = try plan.validate(rate: rate)
        let parsed = try WireTransaction(raw)
        let expectedOutputs = plan.outputs(amount: plan.total - plan.fixedOutputValue - expectedFee)
        let actualSize = (parsed.weight + 3) / 4
        let actualFee = plan.total - parsed.outputs.reduce(0) { $0 + $1.value }
        let droppedChange = plan.mode == .speedUp && !plan.fromAmount && expectedOutputs.count < (plan.speedUpOutputs?.count ?? 0)
        // Dust absorption is the only permitted excess over the selected fee target.
        let absorbed = droppedChange ? max(0, expectedFee - (try FeeMath.ceil(rate * Decimal(plan.virtualSize)))) : 0
        guard parsed.inputs.count == plan.inputs.count, parsed.outputs.count == expectedOutputs.count,
              parsed.outputs.allSatisfy({ $0.value >= 546 }), actualFee == expectedFee,
              try CancellationKeyWork.script(root: root, address: plan.destination) == plan.destination.script,
              actualSize <= plan.virtualSize,
              (droppedChange || abs(Decimal(actualFee) / Decimal(actualSize) - rate) <= 1), absorbed < 546,
              expectedFee >= plan.replacedFee + (try FeeMath.ceil(plan.incrementalRelayRate * Decimal(actualSize))),
              Decimal(expectedFee) / Decimal(actualSize) > plan.originalRate else { throw CancelFailure.invalidReplacement }
        for (output, expected) in zip(parsed.outputs, plan.outputs(amount: plan.total - plan.fixedOutputValue - expectedFee)) {
            guard output.value == expected.value, output.scriptpubkey == expected.script.hex else { throw CancelFailure.invalidReplacement }
        }
        for (input, original) in zip(parsed.inputs, plan.inputs) {
            guard input.txid == original.txid, input.index == original.index, input.sequence == 0xfffffffd else { throw CancelFailure.invalidReplacement }
        }
        // Decode the signed scripts/witness independently, reject unexpected bytes or signature modes.
        var c = WireCursor(raw)
        guard try c.number(4) == 2 else { throw CancelFailure.invalidReplacement }
        let witness = raw[4] == 0
        if witness { guard try c.take(2) == Data([0,1]) else { throw CancelFailure.invalidReplacement } }
        guard try c.variable() == plan.inputs.count else { throw CancelFailure.invalidReplacement }
        var scripts: [Data] = []
        for _ in plan.inputs { _ = try c.take(36); scripts.append(try c.take(c.variable())); _ = try c.take(4) }
        guard try c.variable() == parsed.outputs.count else { throw CancelFailure.invalidReplacement }
        for _ in parsed.outputs { _ = try c.take(8); _ = try c.take(c.variable()) }
        var stacks = plan.inputs.map { _ in [Data]() }
        if witness { for i in plan.inputs.indices { let n = try c.variable(); guard n <= 2 else { throw CancelFailure.invalidReplacement }; for _ in 0..<n { stacks[i].append(try c.take(c.variable())) } } }
        guard try c.number(4) == plan.height, c.offset == raw.count else { throw CancelFailure.invalidReplacement }
        let pubs = try plan.inputs.map { try CancellationKeyWork.publicKey(root: root, address: $0.key) }
        var signatures: [Data] = []
        for i in plan.inputs.indices {
            let input = plan.inputs[i]
            guard try CancellationKeyWork.script(root: root, address: input.key) == input.key.script else { throw CancelFailure.invalidReplacement }
            let sig: Data
            if input.key.type == .bip44 {
                var script = WireCursor(scripts[i]); sig = try script.take(Int(script.number(1)))
                let pub = try script.take(Int(script.number(1)))
                guard pub == pubs[i], script.offset == scripts[i].count, stacks[i].isEmpty else { throw CancelFailure.invalidReplacement }
            } else {
                guard stacks[i].count == (input.key.type == .bip86 ? 1 : 2) else { throw CancelFailure.invalidReplacement }
                sig = stacks[i][0]
                if input.key.type != .bip86 { guard stacks[i][1] == pubs[i] else { throw CancelFailure.invalidReplacement } }
            }
            signatures.append(sig)
        }
        let rebuilt = plan.transaction(amount: plan.total - plan.fixedOutputValue - expectedFee, signatures: signatures, publicKeys: pubs)
        guard rebuilt.serialize(witness: true) == raw else { throw CancelFailure.invalidReplacement }
        for i in plan.inputs.indices {
            let tap = plan.inputs[i].key.type == .bip86
            let sig = signatures[i]
            guard tap ? sig.count == 64 : (sig.count == 71 && sig.last == 1) else { throw CancelFailure.invalidReplacement }
            let publicKey = tap ? Data(plan.inputs[i].key.script.dropFirst(2)) : pubs[i]
            let digest = try rebuilt.signatureHash(index: i, publicKey: pubs[i])
            let signature = tap ? sig : Data(sig.dropLast())
            guard takeback_verify([UInt8](publicKey), publicKey.count, [UInt8](digest), [UInt8](signature), signature.count, tap ? 1 : 0) == 1 else { throw CancelFailure.invalidReplacement }
        }
    }
}
