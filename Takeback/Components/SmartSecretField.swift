import SwiftUI
import UIKit

/// UITextView supplies TextEditor's multiline editing without a retained SwiftUI String binding.
/// The platform's transient text storage is cleared on wipe and dismantle; no restoration or undo.
struct SmartSecretField: View {
    @ObservedObject var model: EnterKeyModel
    let height: CGFloat
    var onFind: (() -> Void)? = nil
    var onEditingChanged: (Bool) -> Void = { _ in }
    var body: some View {
        SmartSecureEditor(model: model, onFind: onFind, onEditingChanged: onEditingChanged)
            .frame(height: height)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(model.hasError ? Theme.red : Theme.fg, lineWidth: 1.5)
                    .opacity(model.hasError || model.canFind ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .secretPrivacy()
    }
}

private struct SmartSecureEditor: UIViewRepresentable {
    @ObservedObject var model: EnterKeyModel
    var onFind: (() -> Void)?
    var onEditingChanged: (Bool) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> ProtectedTextView {
        let editor = ProtectedTextView()
        editor.backgroundColor = .clear
        editor.isScrollEnabled = true
        editor.textContainerInset = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        editor.textContainer.lineFragmentPadding = 0
        editor.autocorrectionType = .no; editor.spellCheckingType = .no
        editor.autocapitalizationType = .none
        editor.smartQuotesType = .no; editor.smartDashesType = .no; editor.smartInsertDeleteType = .no
        editor.textContentType = nil
        editor.keyboardType = .asciiCapable
        editor.textDragInteraction?.isEnabled = false
        if #available(iOS 18.0, *) { editor.writingToolsBehavior = .none }
        editor.adjustsFontForContentSizeCategory = true
        editor.delegate = context.coordinator
        if onFind != nil {
            // iOS hides the screen's bottom toolbar while editing. Use UIKit's
            // native keyboard toolbar for the same action; never draw a footer.
            let toolbar = UIToolbar()
            toolbar.items = [.flexibleSpace(), context.coordinator.findItem]
            toolbar.sizeToFit()
            editor.inputAccessoryView = toolbar
        }
        editor.accessibilityIdentifier = "enterKey.field"
        editor.accessibilityLabel = "Recovery phrase, WIF, hex or extended private key"
        editor.pasteInput = { [weak model] in model?.paste() }
        editor.placeholder.text = "Recovery phrase, WIF, hex or extended private key"
        context.coordinator.clearID = model.session.registerEditorClear { [weak editor] in
            editor?.text = nil; editor?.undoManager?.removeAllActions(); editor?.resignFirstResponder()
            editor?.placeholder.isHidden = false
        }
        return editor
    }
    func updateUIView(_ editor: ProtectedTextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.findItem.isEnabled = model.canFind
        context.coordinator.findItem.title = model.preparing ? "Finding payments…" : "Find pending payments"
        let font = Geist.uiFont(16, traits: editor.traitCollection)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = font.pointSize * 1.55
        paragraph.maximumLineHeight = font.pointSize * 1.55
        paragraph.lineBreakMode = model.detection.isPhrase || !model.hasInput ? .byWordWrapping : .byCharWrapping
        editor.textContainer.lineBreakMode = paragraph.lineBreakMode
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor(Theme.fg)]
        if context.coordinator.revision != model.editorRevision {
            let text = model.session.key.withUnsafeBytes { String(decoding: $0, as: UTF8.self) }
            editor.attributedText = NSAttributedString(string: text, attributes: attributes)
            context.coordinator.revision = model.editorRevision
        } else if editor.textStorage.length > 0 &&
                    (context.coordinator.fontSize != font.pointSize || context.coordinator.wrapping != paragraph.lineBreakMode) {
            // Restyle the existing native storage instead of making another secret string.
            editor.textStorage.addAttributes(attributes, range: NSRange(location: 0, length: editor.textStorage.length))
        }
        editor.typingAttributes = attributes
        context.coordinator.fontSize = font.pointSize
        context.coordinator.wrapping = paragraph.lineBreakMode
        editor.font = font; editor.textColor = UIColor(Theme.fg); editor.tintColor = UIColor(Theme.fg)
        let placeholderParagraph = NSMutableParagraphStyle()
        placeholderParagraph.minimumLineHeight = font.pointSize * 1.55
        placeholderParagraph.maximumLineHeight = font.pointSize * 1.55
        editor.placeholder.attributedText = NSAttributedString(string: "Recovery phrase, WIF, hex or extended private key",
            attributes: [.font: font, .paragraphStyle: placeholderParagraph, .foregroundColor: UIColor(Theme.mute)])
        editor.placeholder.isHidden = model.hasInput
        editor.undoManager?.removeAllActions()
        editor.setNeedsLayout()
    }
    static func dismantleUIView(_ editor: ProtectedTextView, coordinator: Coordinator) {
        editor.text = nil; editor.undoManager?.removeAllActions(); editor.resignFirstResponder(); editor.pasteInput = nil
        if let id = coordinator.clearID { coordinator.parent.model.session.unregisterEditorClear(id) }
    }
    @MainActor final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SmartSecureEditor
        lazy var findItem: UIBarButtonItem = {
            let item = UIBarButtonItem(title: "Find pending payments", style: .done, target: self, action: #selector(findPayments))
            item.accessibilityIdentifier = "enterKey.find"
            return item
        }()
        @objc private func findPayments() { parent.onFind?() }
        var clearID: UUID?
        var revision = -1
        var fontSize: CGFloat = 0
        var wrapping: NSLineBreakMode = .byWordWrapping
        init(_ parent: SmartSecureEditor) { self.parent = parent }
        func textViewDidBeginEditing(_ textView: UITextView) { parent.onEditingChanged(true) }
        func textViewDidEndEditing(_ textView: UITextView) { parent.onEditingChanged(false) }
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let current = textView.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return false }
            return current.utf8.count-current[swiftRange].utf8.count+text.utf8.count <= parent.model.session.key.capacity
        }
        func textViewDidChange(_ textView: UITextView) {
            do { try parent.model.session.key.replace(with: (textView.text ?? "").utf8) }
            catch { textView.text = nil; parent.model.session.key.wipe() }
            (textView as? ProtectedTextView)?.placeholder.isHidden = parent.model.session.key.count > 0
            textView.undoManager?.removeAllActions()
            parent.model.edited()
        }
    }
}

final class ProtectedTextView: UITextView {
    let placeholder = UILabel()
    var pasteInput: (() -> Void)?
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        placeholder.numberOfLines = 0
        placeholder.isUserInteractionEnabled = false
        placeholder.isAccessibilityElement = false
        addSubview(placeholder)
    }
    required init?(coder: NSCoder) { nil }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = max(0, bounds.width-textContainerInset.left-textContainerInset.right)
        placeholder.frame = CGRect(x: textContainerInset.left, y: textContainerInset.top,
            width: width, height: placeholder.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        if !placeholder.isHidden {
            let needed = max(bounds.height, placeholder.frame.maxY + textContainerInset.bottom)
            if abs(contentSize.height - needed) > 0.5 { contentSize = CGSize(width: bounds.width, height: needed) }
        }
    }
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        action == #selector(paste(_:)) && super.canPerformAction(action, withSender: sender)
    }
    override func paste(_ sender: Any?) { pasteInput?() }
    override func copy(_ sender: Any?) { }
    override func cut(_ sender: Any?) { }
}
