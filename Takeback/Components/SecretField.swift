import SwiftUI
import UIKit

/// No Binding<String>, restoration identifier, copy/cut/share action or persisted editing state.
/// UIKit necessarily owns a transient text buffer; clear it on session wipe and dismantle.
struct SecretField: View {
    let placeholder: String
    let bytes: SecureBytes
    let session: SecretSession
    var onChange: () -> Void = { }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var fieldHeight: CGFloat = 52

    var body: some View {
        SecureEditor(placeholder: placeholder, bytes: bytes, session: session, onChange: onChange)
            .frame(height: fieldHeight)
            .padding(.horizontal, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            .secretPrivacy()
    }
}

private struct SecureEditor: UIViewRepresentable {
    let placeholder: String
    let bytes: SecureBytes
    let session: SecretSession
    let onChange: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> ProtectedTextField {
        let field = ProtectedTextField()
        field.isSecureTextEntry = true
        field.textDragInteraction?.isEnabled = false
        if #available(iOS 18.0, *) { field.writingToolsBehavior = .none }
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.autocapitalizationType = .none
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.textContentType = nil
        field.keyboardType = .asciiCapable
        field.delegate = context.coordinator
        field.adjustsFontForContentSizeCategory = true
        field.accessibilityLabel = placeholder
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        context.coordinator.clearID = session.registerEditorClear { [weak field] in
            field?.text = nil
            field?.undoManager?.removeAllActions()
            field?.resignFirstResponder()
        }
        return field
    }
    func updateUIView(_ field: ProtectedTextField, context: Context) {
        context.coordinator.parent = self
        field.font = Geist.uiFont(16, traits: field.traitCollection)
        field.textColor = UIColor(Theme.fg)
        field.tintColor = UIColor(Theme.fg)
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .font: Geist.uiFont(16, traits: field.traitCollection), .foregroundColor: UIColor(Theme.mute)
        ])
    }
    static func dismantleUIView(_ field: ProtectedTextField, coordinator: Coordinator) {
        field.text = nil
        field.undoManager?.removeAllActions()
        field.resignFirstResponder()
        if let id = coordinator.clearID { coordinator.parent.session.unregisterEditorClear(id) }
    }

    @MainActor final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SecureEditor
        var clearID: UUID?
        init(_ parent: SecureEditor) { self.parent = parent }
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Reject oversized edits before they replace the secure allocation.
            let current = textField.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return false }
            return current.utf8.count - current[swiftRange].utf8.count + string.utf8.count <= parent.bytes.capacity
        }
        @objc func changed(_ field: UITextField) {
            do { try parent.bytes.replace(with: (field.text ?? "").utf8) }
            catch { field.text = nil; parent.bytes.wipe() }
            field.undoManager?.removeAllActions()
            parent.onChange()
        }
    }
}

final class ProtectedTextField: UITextField {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Paste is input only. Never offer copy, cut, share, lookup, writing tools or drag export.
        action == #selector(paste(_:)) && super.canPerformAction(action, withSender: sender)
    }
    override func copy(_ sender: Any?) { }
    override func cut(_ sender: Any?) { }
}
