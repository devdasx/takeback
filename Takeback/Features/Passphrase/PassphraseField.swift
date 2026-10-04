import SwiftUI
import UIKit

struct PassphraseField: View {
    @ObservedObject var model: PassphraseModel
    var autofocus = true
    @State private var revealed = false

    var body: some View {
        HStack(spacing: 0) {
            PassphraseEditor(model: model, revealed: revealed, autofocus: autofocus)
                .frame(maxWidth: .infinity)
            Button { revealed.toggle() } label: {
                Image(systemName: revealed ? "eye.slash" : "eye")
                    .font(.system(size: 20)).foregroundStyle(Theme.mute)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(revealed ? "Hide passphrase" : "Show passphrase")
            .accessibilityIdentifier("passphrase.visibility")
        }
        .padding(.leading, 16).padding(.trailing, 6)
        .frame(height: 56)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .secretPrivacy()
    }
}

private struct PassphraseEditor: UIViewControllerRepresentable {
    @ObservedObject var model: PassphraseModel
    let revealed: Bool
    let autofocus: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> PassphraseEditorController {
        let field = ProtectedTextField()
        field.isSecureTextEntry = !revealed
        field.text = model.draft.withUnsafeBytes { String(decoding: $0, as: UTF8.self) }
        field.textDragInteraction?.isEnabled = false
        if #available(iOS 18.0, *) { field.writingToolsBehavior = .none }
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.autocapitalizationType = .none
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.textContentType = nil
        field.keyboardType = .default
        field.returnKeyType = .done
        field.delegate = context.coordinator

        field.accessibilityLabel = "Passphrase"
        field.accessibilityIdentifier = "passphrase.field"
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        context.coordinator.clearID = model.session.registerEditorClear { [weak field] in
            field?.text = nil
            field?.undoManager?.removeAllActions()
            field?.resignFirstResponder()
        }
        return PassphraseEditorController(field: field, autofocus: autofocus)
    }
    func updateUIViewController(_ controller: PassphraseEditorController, context: Context) {
        let field = controller.field
        context.coordinator.parent = self
        field.font = Geist.uiFont(17, traits: field.traitCollection)
        field.textColor = UIColor(Theme.fg); field.tintColor = UIColor(Theme.fg)
        if field.isSecureTextEntry == revealed {
            let selection = field.selectedTextRange
            let text = field.text
            field.isSecureTextEntry = !revealed
            field.text = text
            field.selectedTextRange = selection
        }
        if model.isClosed {
            field.text = nil; field.undoManager?.removeAllActions(); field.resignFirstResponder()
        }
    }
    static func dismantleUIViewController(_ controller: PassphraseEditorController, coordinator: Coordinator) {
        let field = controller.field
        field.text = nil; field.undoManager?.removeAllActions(); field.resignFirstResponder()
        if let id = coordinator.clearID { coordinator.parent.model.session.unregisterEditorClear(id) }
    }
    @MainActor final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PassphraseEditor
        var clearID: UUID?
        init(_ parent: PassphraseEditor) { self.parent = parent }
        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard !parent.model.isClosed else { return false }
            let current = field.text ?? ""
            guard let part = Range(range, in: current) else { return false }
            return current.utf8.count - current[part].utf8.count + string.utf8.count <= parent.model.draft.capacity
        }
        @objc func changed(_ field: UITextField) {
            do { try parent.model.draft.replace(with: (field.text ?? "").utf8) }
            catch { field.text = nil; parent.model.draft.wipe() }
            field.undoManager?.removeAllActions()
            parent.model.edited()
        }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return false
        }
    }
}

private final class PassphraseEditorController: UIViewController {
    let field: ProtectedTextField
    let autofocus: Bool
    private var requestedFocus = false
    private var focusTask: Task<Void, Never>?
    init(field: ProtectedTextField, autofocus: Bool) {
        self.field = field; self.autofocus = autofocus
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("Not used for restoration") }
    override func loadView() { view = field }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Wait for native presentation to finish. didMoveToWindow fires too early
        // during sheet transitions and can silently fail to display the keyboard.
        guard autofocus, !requestedFocus else { return }
        focusTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            guard let self, self.view.window != nil, !Task.isCancelled else { return }
            self.requestedFocus = self.field.becomeFirstResponder()
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        focusTask?.cancel(); focusTask = nil
        super.viewWillDisappear(animated)
    }
    deinit { focusTask?.cancel() }
}
