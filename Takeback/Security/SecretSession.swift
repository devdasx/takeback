import UIKit
import Combine

/// All secret buffers, including passphrases, belong to one ephemeral session.
@MainActor final class SecretSession: ObservableObject {
    static let shared = SecretSession()
    static let backgroundLifetime: TimeInterval = 60
    var publicScanPlan: PublicScanPlan?
    @Published var searchSelection: SearchSelection? { didSet { publicScanPlan = nil } }
    func ensureSearchSelection() { if searchSelection == nil { searchSelection = SearchDefaults.shared.selection } }
    func resetSearchSelection() { searchSelection = nil }
    let key = SecureBytes()
    let passphrase = SecureBytes()
    @Published private(set) var wipeGeneration = 0
    @Published private(set) var passphraseFingerprint: String?

    func discardPassphrase() {
        publicScanPlan = nil
        fingerprintGeneration &+= 1
        fingerprintTask?.cancel(); fingerprintTask = nil
        fingerprintWork?.cancel(); fingerprintWork = nil
        passphrase.wipe()
        passphraseFingerprint = nil
    }

    /// Store only the public, eight-digit master fingerprint alongside ephemeral secrets.
    func setPassphraseFingerprint(_ fingerprint: String) {
        guard fingerprint.utf8.count == 8, fingerprint.utf8.allSatisfy({ KeyValidation.hexNibble($0) != nil }) else { return }
        passphraseFingerprint = fingerprint.lowercased()
    }
    private var fingerprintGeneration = 0
    private var fingerprintTask: Task<Void, Never>?
    private var fingerprintWork: FingerprintWork?
    deinit { fingerprintTask?.cancel(); fingerprintWork?.cancel(); expiryTask?.cancel() }

    func refreshPassphraseFingerprint() {
        fingerprintGeneration &+= 1
        fingerprintTask?.cancel(); fingerprintWork?.cancel()
        passphraseFingerprint = nil
        guard passphrase.count > 0 else { return }
        let expected = fingerprintGeneration
        let work = FingerprintWork(mnemonic: key, passphrase: passphrase)
        fingerprintWork = work
        fingerprintTask = Task { [weak self] in
            let result = await FingerprintEngine.compute(work)
            guard !Task.isCancelled, let self, expected == self.fingerprintGeneration else { return }
            if let result { self.setPassphraseFingerprint(result.withPassphrase) }
        }
    }
    private var backgroundStart: TimeInterval?
    private var expiryTask: Task<Void, Never>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var clearHandlers: [UUID: () -> Void] = [:]

    func registerEditorClear(_ clear: @escaping () -> Void) -> UUID {
        let id = UUID()
        clearHandlers[id] = clear
        return id
    }

    func unregisterEditorClear(_ id: UUID) { clearHandlers[id] = nil }

    func wipe() {
        resetSearchSelection()
        publicScanPlan = nil
        key.wipe()
        discardPassphrase()
        // A draft's clear handler may unregister itself during the wipe.
        Array(clearHandlers.values).forEach { $0() }
        wipeGeneration &+= 1
        backgroundStart = nil
        expiryTask?.cancel()
        expiryTask = nil
        endBackgroundTask()
    }

    func returnedToWelcome() { wipe() }
    func completedCancellation() { wipe() }
    func applicationWillTerminate() { wipe() }

    func enteredBackground(now: TimeInterval = ProcessInfo.processInfo.systemUptime,
                           requestExecutionTime: Bool = true) {
        guard backgroundStart == nil else { return }
        backgroundStart = now
        if requestExecutionTime {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Clear ephemeral session") { [weak self] in
                // UIKit calls expiration handlers on the main thread. Wipe before suspension.
                MainActor.assumeIsolated { self?.wipe() }
            }
        }
        expiryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(Self.backgroundLifetime)) }
            catch { return }
            self?.wipe()
        }
    }

    func becameActive(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        if let start = backgroundStart, now - start >= Self.backgroundLifetime { wipe() }
        backgroundStart = nil
        expiryTask?.cancel()
        expiryTask = nil
        endBackgroundTask()
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
