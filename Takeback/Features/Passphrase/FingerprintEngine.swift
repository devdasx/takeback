import Foundation

struct WalletFingerprints: Equatable, Sendable {
    let withPassphrase: String
    let withoutPassphrase: String

    static func formatted(_ value: String) -> String {
        guard value.count == 8 else { return value }
        return value.prefix(4).uppercased() + " " + value.suffix(4).uppercased()
    }
}

/// The only cross-thread secret owner. The lock protects all access, including cancellation
/// and zeroing; buffers never escape. SecureBytes itself remains deliberately non-Sendable.
final class FingerprintWork: @unchecked Sendable {
    private let lock = NSLock()
    private let mnemonic = SecureBytes()
    private let passphrase = SecureBytes()
    private var cancelled = false
    private let knownBase: String?

    init(mnemonic: SecureBytes, passphrase: SecureBytes, knownBase: String? = nil) {
        self.knownBase = knownBase
        try? mnemonic.withUnsafeBytes { try self.mnemonic.replace(with: $0) }
        try? passphrase.withUnsafeBytes { try self.passphrase.replace(with: $0) }
    }
    func cancel() {
        lock.withLock { cancelled = true; mnemonic.wipe(); passphrase.wipe() }
    }
    var isCleared: Bool { lock.withLock { mnemonic.count == 0 && passphrase.count == 0 } }

    func calculate() -> WalletFingerprints? {
        lock.withLock {
            defer { mnemonic.wipe(); passphrase.wipe() }
            guard !cancelled, !Task.isCancelled else { return nil }
            let detection = detectKey(mnemonic)
            guard detection.isPhrase, detection.isValid,
                  let normalizedWords = try? KeyValidation.normalized(mnemonic, lowercaseWords: true) else { return nil }
            defer { normalizedWords.wipe() }
            let words = Self.nfkd(normalizedWords), phrase = Self.nfkd(passphrase)
            defer { words.wipe(); phrase.wipe() }
            guard let with = Self.derive(words, phrase), !Task.isCancelled,
                  let without = knownBase ?? (phrase.count == 0 ? with : Self.derive(words, SecureBytes(capacity: 1))) else { return nil }
            return WalletFingerprints(withPassphrase: with, withoutPassphrase: without)
        }
    }
    private static func nfkd(_ bytes: SecureBytes) -> SecureBytes {
        // Foundation's Unicode normalization necessarily uses transient String storage.
        // Never retain it in model/view state; preserve original user bytes in the draft.
        let text = bytes.withUnsafeBytes { String(decoding: $0, as: UTF8.self) }.decomposedStringWithCompatibilityMapping
        let result = SecureBytes(capacity: max(1, text.utf8.count))
        try? result.replace(with: text.utf8)
        return result
    }
    private static func derive(_ mnemonic: SecureBytes, _ passphrase: SecureBytes) -> String? {
        var output = [UInt8](repeating: 0, count: 4) // Only the public fingerprint leaves C.
        let success = mnemonic.withUnsafeBytes { words in
            passphrase.withUnsafeBytes { phrase in
                takeback_master_fingerprint(words.bindMemory(to: UInt8.self).baseAddress, words.count,
                                            phrase.bindMemory(to: UInt8.self).baseAddress, phrase.count, &output)
            }
        }
        guard success == 1 else { return nil }
        return output.map { String(format: "%02X", $0) }.joined()
    }
    deinit { mnemonic.wipe(); passphrase.wipe() }
}

enum FingerprintEngine {
    static func compute(_ work: FingerprintWork) async -> WalletFingerprints? {
        let worker = Task.detached(priority: .userInitiated) { work.calculate() }
        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
            work.cancel()
        }
    }
}
