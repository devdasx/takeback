import UIKit
import Combine

@MainActor protocol KeyClipboard {
    var changeCount: Int { get }
    func read() -> String?
    func clear()
}
@MainActor struct SystemKeyClipboard: KeyClipboard {
    var changeCount: Int { UIPasteboard.general.changeCount }
    func read() -> String? { UIPasteboard.general.string }
    func clear() { UIPasteboard.general.items = [] }
}

@MainActor final class EnterKeyModel: ObservableObject {
    let session: SecretSession
    @Published private(set) var detection: KeyDetection = .empty
    @Published private(set) var settled = false
    @Published private(set) var isDetecting = false
    @Published private(set) var editorRevision = 0
    private var generation = 0
    private var debounceTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
    private var wipeObserver: AnyCancellable?
    private let clipboard: any KeyClipboard

    init(session: SecretSession, clipboard: any KeyClipboard = SystemKeyClipboard()) {
        self.session = session
        self.clipboard = clipboard
        detection = detectKey(session.key)
        wipeObserver = session.$wipeGeneration.dropFirst().sink { [weak self] _ in self?.resetAfterWipe() }
    }
    deinit { debounceTask?.cancel(); idleTask?.cancel() }
    @Published private(set) var preparing = false
    var canFind: Bool { !isDetecting && !preparing && detection.isValid && (detection.searchPlan.map { (session.searchSelection ?? SearchDefaults.shared.selection).isValid(for: $0) } ?? false) }
    var showsPassphrase: Bool { detection.isPhrase }
    var hasInput: Bool { session.key.count > 0 }
    var hasError: Bool { detection.isError(settled: settled) && !isDetecting }
    var status: String { detection.label(settled: settled) }

    func edited() {
        session.resetSearchSelection()
        session.publicScanPlan = nil
        session.refreshPassphraseFingerprint()
        cancelPending()
        generation &+= 1
        let expected = generation
        settled = false
        isDetecting = true // Gate immediately, including the 120 ms debounce window.
        debounceTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            guard let self, expected == self.generation else { return }
            await self.classifyInBackground(settled: false, expected: expected)
        }
        idleTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(1200)) } catch { return }
            guard let self, expected == self.generation else { return }
            await self.classifyInBackground(settled: true, expected: expected)
        }
    }

    /// The pasteboard is read exactly once. Clear only a validated private import,
    /// and only if another application has not replaced the clipboard meanwhile.
    func paste() {
        session.resetSearchSelection()
        let change = clipboard.changeCount
        guard let text = clipboard.read() else { return }
        cancelPending(); generation &+= 1
        do { try session.key.replace(with: text.utf8) }
        catch {
            session.key.wipe(); session.discardPassphrase()
            detection = .unrecognized; settled = true; isDetecting = false
            editorRevision &+= 1
            return
        }
        classify(settled: true)
        if detection.isValid && change == clipboard.changeCount { clipboard.clear() }
        editorRevision &+= 1
    }
    /// Input-only paste from the editor's context menu follows exactly the same policy.
    func clear() {
        session.resetSearchSelection()
        cancelPending(); generation &+= 1
        session.key.wipe()
        session.discardPassphrase()
        detection = .empty; settled = false; isDetecting = false
        editorRevision &+= 1
    }
    func importScanned(_ bytes: SecureBytes) {
        guard detectKey(bytes).isValid else { return }
        session.resetSearchSelection()
        cancelPending(); generation &+= 1
        do { try bytes.withUnsafeBytes { try session.key.replace(with: $0) } }
        catch { clear(); return }
        classify(settled: true); editorRevision &+= 1
    }
    func suspend() { cancelPending(); isDetecting = false }
    func refresh() { classify(settled: hasInput); editorRevision &+= 1 }

    /// Revalidate synchronously at the navigation boundary. The plan contains no key material.
    func prepareSearch() -> KeySearchPlan? {
        guard canFind else { return nil }
        classify(settled: true)
        guard let plan = detection.searchPlan,
              let normalized = try? KeyValidation.normalized(session.key, lowercaseWords: detection.isPhrase) else { return nil }
        defer { normalized.wipe() }
        try? normalized.withUnsafeBytes { try session.key.replace(with: $0) }
        editorRevision &+= 1
        return plan
    }
    func prepareAccounts() async -> KeySearchPlan? {
        guard let plan = prepareSearch() else { return nil }
        let expectedGeneration = generation
        preparing = true
        defer { preparing = false }
        do {
            let worker = try SearchDerivationWork(key: session.key, passphrase: session.passphrase)
            let token = session.registerEditorClear { worker.cancel() }
            defer { worker.cancel(); session.unregisterEditorClear(token) }
            let selection = session.searchSelection ?? SearchDefaults.shared.selection
            let task = Task.detached(priority: .userInitiated) { try worker.prepare(plan: plan, selection: selection) }
            let prepared = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel(); worker.cancel() }
            guard !Task.isCancelled, session.key.count > 0, generation == expectedGeneration,
                  session.searchSelection == selection else { return nil }
            session.publicScanPlan = prepared
            return plan
        } catch { return nil }
    }
    private func classifyInBackground(settled: Bool, expected: Int) async {
        let worker = DetectionWork(session.key)
        let task = Task.detached(priority: .userInitiated) { worker.detect() }
        let next = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel(); worker.cancel() }
        guard !Task.isCancelled, generation == expected else { return }
        if !next.isPhrase { session.discardPassphrase() }
        if next.isValid { session.ensureSearchSelection() }
        detection = next; self.settled = settled; isDetecting = false
    }
    func classify(settled: Bool) {
        let next = detectKey(session.key)
        if !next.isPhrase { session.discardPassphrase() }
        else { session.refreshPassphraseFingerprint() }
        if next.isValid { session.ensureSearchSelection() }
        detection = next
        self.settled = settled
        isDetecting = false
    }
    private func cancelPending() { debounceTask?.cancel(); idleTask?.cancel(); debounceTask = nil; idleTask = nil }
    private func resetAfterWipe() {
        cancelPending(); generation &+= 1
        detection = .empty; settled = false; isDetecting = false
        editorRevision &+= 1
    }
}

private final class DetectionWork: @unchecked Sendable {
    private let lock = NSLock(), bytes = SecureBytes()
    init(_ input: SecureBytes) { try? input.withUnsafeBytes { try bytes.replace(with: $0) } }
    func cancel() { lock.withLock { bytes.wipe() } }
    func detect() -> KeyDetection { lock.withLock { defer { bytes.wipe() }; return detectKey(bytes) } }
}
