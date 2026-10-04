import SwiftUI

struct NativeSheet<Content: View>: View {
    let title: String
    var titleImage: String? = nil
    var detents: Set<PresentationDetent> = [.medium, .large]
    var onClose: (() -> Void)? = nil
    var doneEnabled = true
    var doneIdentifier = "passphrase.done"
    var doneSymbol = false
    var onDone: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        sizedSheet
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .takebackStyle()
    }

    @ViewBuilder private var sizedSheet: some View {
        if #available(iOS 18.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            navigation.presentationSizing(.form)
        } else { navigation }
    }

    private var navigation: some View {
        NavigationStack {
            content()
                .toolbar {
                    if let titleImage {
                        ToolbarItem(placement: .principal) {
                            HStack(spacing: 8) {
                                Image(titleImage).resizable().scaledToFit().frame(width: 28, height: 28).accessibilityHidden(true)
                                Text(title).font(.headline)
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        if #available(iOS 26.0, *) {
                            Button(role: .close) { onClose?(); dismiss() }
                        } else {
                            Button { onClose?(); dismiss() } label: { Image(systemName: "xmark") }
                                .accessibilityLabel("Close")
                        }
                    }
                    if let onDone {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: onDone) {
                                if doneSymbol { Image(systemName: "checkmark").accessibilityLabel("Done") }
                                else { Text("Done") }
                            }
                                .font(.body.weight(.semibold))
                                .disabled(!doneEnabled)
                                .accessibilityIdentifier(doneIdentifier)
                        }
                    }
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
