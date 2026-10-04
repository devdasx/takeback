import Foundation
import Combine

@MainActor final class PassphraseModel: ObservableObject {
    let session: SecretSession
    let draft = SecureBytes()
    let isEditing: Bool
    @Published private(set) var isEmpty = true
    @Published private(set) var startsWithSpace = false
    @Published private(set) var endsWithSpace = false
    @Published private(set) var fingerprints: WalletFingerprints?
    @Published private(set) var baseFingerprint: String?
    @Published private(set) var isClosed = false
    private let originalKey = SecureBytes()
    private let compute: @Sendable (FingerprintWork) async -> WalletFingerprints?
    private var generation = 0
    private var task: Task<Void, Never>?
    private var work: FingerprintWork?
    private var clearID: UUID?

    init(session: SecretSession,
         compute: @escaping @Sendable (FingerprintWork) async -> WalletFingerprints? = FingerprintEngine.compute) {
        self.session = session
        self.compute = compute
        isEditing = session.passphrase.count > 0
        try? session.passphrase.withUnsafeBytes { try draft.replace(with: $0) }
        try? session.key.withUnsafeBytes { try originalKey.replace(with: $0) }
        updateFlags()
        clearID = session.registerEditorClear { [weak self] in self?.discard() }
    }
    deinit { task?.cancel(); work?.cancel() }
    var canSave: Bool { !isClosed && (isEditing || !isEmpty) }
    func start() { schedule() }
    func edited() {
        guard !isClosed else { draft.wipe(); return }
        updateFlags()
        schedule()
    }
    private func updateFlags() {
        isEmpty = draft.count == 0
        draft.withUnsafeBytes { startsWithSpace = $0.first == 32; endsWithSpace = $0.last == 32 }
    }
    func save(onSaved: @escaping @MainActor () -> Void) {
        guard canSave else { return }
        // Done may be tapped during the debounce. Derive the exact current draft immediately
        // and commit only if neither the key, draft nor session has changed in the meantime.
        schedule(delay: .zero, onSaved: onSaved)
    }
    func remove() {
        guard !isClosed, keyMatches else { discard(); return }
        session.discardPassphrase()
        discard()
    }
    func discard() {
        stopWork()
        draft.wipe(); originalKey.wipe()
        fingerprints = nil; baseFingerprint = nil; isEmpty = true; startsWithSpace = false; endsWithSpace = false
        isClosed = true
        if let clearID { session.unregisterEditorClear(clearID); self.clearID = nil }
    }
    private var keyMatches: Bool {
        originalKey.withUnsafeBytes { original in session.key.withUnsafeBytes { original.elementsEqual($0) } }
    }
    private func stopWork() {
        generation &+= 1
        task?.cancel(); task = nil
        work?.cancel(); work = nil
    }
    private func schedule(delay: Duration = .milliseconds(250), onSaved: (@MainActor () -> Void)? = nil) {
        stopWork()
        fingerprints = nil
        guard !isClosed, keyMatches else { return }
        let expected = generation
        let work = FingerprintWork(mnemonic: originalKey, passphrase: draft, knownBase: baseFingerprint)
        self.work = work
        let compute = compute
        task = Task { [weak self] in
            do { try await Task.sleep(for: delay) } catch { work.cancel(); return }
            guard !Task.isCancelled else { work.cancel(); return }
            let result = await compute(work)
            work.cancel()
            guard !Task.isCancelled, let self, !self.isClosed,
                  self.generation == expected, self.keyMatches else { return }
            self.fingerprints = result
            if let result { self.baseFingerprint = result.withoutPassphrase }
            if let onSaved {
                // An incomplete mnemonic has no fingerprint yet; the optional passphrase can
                // still be saved. Entry recomputes it once a valid mnemonic is supplied.
                let key = detectKey(self.originalKey)
                guard result != nil || !key.isValid else { return }
                self.session.discardPassphrase()
                try? self.draft.withUnsafeBytes { try self.session.passphrase.replace(with: $0) }
                if self.draft.count > 0, let fingerprint = result?.withPassphrase {
                    self.session.setPassphraseFingerprint(fingerprint)
                }
                self.discard()
                onSaved()
            }
        }
    }
}
