import SwiftUI

struct SearchPathSheet: View {
    @ObservedObject var session: SecretSession
    let initial: SearchPath
    let editing: Bool
    @State private var text: String
    @State private var type: AddressStandard
    @State private var change: Bool
    @State private var name: String
    @State private var preview: String?
    @State private var previewPath: SearchPath?
    @Environment(\.dismiss) private var dismiss
    init(session: SecretSession, initial: SearchPath, editing: Bool) {
        self.session = session; self.initial = initial; self.editing = editing
        _text = State(initialValue: initial.components.isEmpty ? "" : initial.path)
        _type = State(initialValue: initial.scriptType); _change = State(initialValue: initial.includeChange)
        _name = State(initialValue: initial.name)
    }
    private var selection: SearchSelection { session.searchSelection ?? SearchDefaults.shared.selection }
    private var validation: Result<[UInt32], DerivationPath.Problem> {
        do { return .success(try DerivationPath.validate(text, type: type, customs: selection.custom, accounts: selection.accounts, editing: editing ? initial.id : nil)) }
        catch { return .failure(error as? DerivationPath.Problem ?? .syntax) }
    }
    private var candidate: SearchPath? {
        guard case .success(let components) = validation else { return nil }
        return .init(id: initial.id, name: String(name.prefix(24)), components: components, scriptType: type, includeChange: change)
    }
    private var error: String? { if case .failure(let problem) = validation, !text.isEmpty { problem.rawValue } else { nil } }
    var body: some View {
        NativeSheet(title: editing ? "Edit path" : "Add path", doneEnabled: candidate != nil && candidate == previewPath && preview != nil,
                    doneIdentifier: "path.done", doneSymbol: true, onDone: save) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Derivation path").font(Geist.font(14, .medium))
                        TextField("m/84'/0'/1'", text: $text)
                            .font(Geist.font(17, .medium)).monospacedDigit().keyboardType(.asciiCapable)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                            .padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                            .overlay { RoundedRectangle(cornerRadius: 14).stroke(error == nil ? Theme.line : Theme.red, lineWidth: 1) }
                            .accessibilityIdentifier("path.field")
                        Text(error ?? status).font(Geist.font(13, error == nil ? .regular : .medium)).foregroundStyle(error == nil ? Theme.mute : Theme.red)
                            .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("path.status")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Common wallets").font(Geist.font(14, .medium))
                        // An adaptive grid wraps chips at large text sizes instead of clipping them.
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), alignment: .leading)], alignment: .leading, spacing: 10) {
                            ForEach(Self.wallets, id: \.0) { label, path, standard in
                                Button(label) { text = path; type = standard; name = label }
                                    .font(Geist.font(13, .medium)).padding(.horizontal, 12).padding(.vertical, 10)
                                    .background(Theme.card, in: Capsule()).buttonStyle(.plain).accessibilityIdentifier("path.wallet.\(label)")
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Address type").font(Geist.font(14, .medium))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(AddressStandard.allCases, id: \.self) { standard in
                                Button { type = standard } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(standard.title).font(Geist.font(14, .medium))
                                        Text(standard.subtitle).font(Geist.font(12)).foregroundStyle(Theme.mute)
                                    }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).padding(12)
                                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                                        .overlay { RoundedRectangle(cornerRadius: 14).stroke(type == standard ? Theme.fg : Theme.line, lineWidth: 1) }
                                }.buttonStyle(.plain).accessibilityAddTraits(type == standard ? .isSelected : []).accessibilityIdentifier("path.type.\(standard.rawValue)")
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        if candidate?.fixedChain != true {
                            Toggle("Include change addresses", isOn: $change).tint(Theme.fg).font(Geist.font(16)).accessibilityIdentifier("path.change")
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name").font(Geist.font(14, .medium))
                            TextField("Optional", text: $name).font(Geist.font(16)).padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("path.name")
                                .onChange(of: name) { _, value in name = String(value.prefix(24)) }
                        }
                    }
                    if let path = candidate, path == previewPath, let preview {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("First address · \(DerivationPath.format(path.childPath(branch: 0, index: 0)))").font(Geist.font(13)).foregroundStyle(Theme.mute)
                            (Text(String(preview.prefix(8))).foregroundColor(Theme.fg) + Text(String(preview.dropFirst(8).dropLast(6))).foregroundColor(Theme.mute) + Text(String(preview.suffix(6))).foregroundColor(Theme.fg))
                                .font(Geist.font(15)).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("path.preview")
                        }
                    }

                }.padding(20).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively).background(Theme.bg).accessibilityIdentifier("path.content")
                .toolbar {
                    if editing {
                        NativeBottomBar {
                            Button("Remove path", role: .destructive) {
                                var next = selection
                                next.custom.removeAll { $0.id == initial.id }
                                session.searchSelection = next
                                dismiss()
                            }.accessibilityIdentifier("path.remove")
                        }
                    }
                }
        }
        .task(id: candidate) { await derivePreview() }
        .onChange(of: session.wipeGeneration) { _, _ in preview = nil; dismiss() }
    }
    private var status: String {
        guard let path = candidate else { return "Type a path, or pick a common wallet below" }
        if path.fixedChain { return "Searches addresses \(path.path)/0 to /\(selection.addressesPerPath - 1) (fixed chain)" }
        return "Searches \(path.path)/0/* receive" + (change ? " and /1/* change · \(selection.addressesPerPath) each" : " only · \(selection.addressesPerPath)")
    }
    private func save() {
        guard let candidate else { return }
        var next = selection
        if let i = next.custom.firstIndex(where: { $0.id == initial.id }) { next.custom[i] = candidate } else { next.custom.append(candidate) }
        session.searchSelection = next; dismiss()
    }
    private func derivePreview() async {
        preview = nil; previewPath = nil
        guard let candidate, let plan = detectKey(session.key).searchPlan, !plan.isAccount, plan.origin != .single else { return }
        do {
            try await Task.sleep(for: .milliseconds(120))
            let worker = try SearchDerivationWork(key: session.key, passphrase: session.passphrase)
            let token = session.registerEditorClear { worker.cancel() }
            defer { worker.cancel(); session.unregisterEditorClear(token) }
            let task = Task.detached(priority: .userInitiated) {
                let prepared = try worker.prepare(plan: plan, selection: .init(enabled: [], custom: [candidate]))
                return try prepared.address(path: candidate, branch: 0, index: 0).chain.address
            }
            let address = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel(); worker.cancel() }
            guard !Task.isCancelled, session.key.count > 0 else { return }
            previewPath = candidate; preview = address
        } catch { /* A canceled older task must not erase a newer preview. */ }
    }
    static let wallets: [(String, String, AddressStandard)] = [
        ("Account 1", "m/84'/0'/1'", .bip84), ("Electrum", "m/0'", .bip84),
        ("Bitcoin Core", "m/0'/0'", .bip84), ("Samourai postmix", "m/84'/0'/2147483646'", .bip84),
        ("Ledger Legacy", "m/44'/0'/0'/0", .bip44)
    ]
}
