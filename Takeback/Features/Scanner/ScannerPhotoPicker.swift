import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ScannerPhotoPicker: UIViewControllerRepresentable {
    @ObservedObject var model: ScannerModel
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images; configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }
    static func dismantleUIViewController(_ controller: PHPickerViewController, coordinator: Coordinator) {
        coordinator.cancelPendingLoad(); controller.delegate = nil
    }
    @MainActor final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let model: ScannerModel
        private var selection = UUID()
        func cancelPendingLoad() {
            selection = UUID(); model.cancelPhotoLoad?(); model.cancelPhotoLoad = nil
        }
        init(model: ScannerModel) { self.model = model }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            cancelPendingLoad()
            guard let provider = results.first?.itemProvider else { model.receivePhoto(nil); return }
            let expected = selection
            guard let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) else { model.photoFailed(); return }
            // Load directly into memory, never request a file representation or a cache path.
            let progress = provider.loadDataRepresentation(forTypeIdentifier: type) { [weak self] data, _ in
                Task { @MainActor in
                    guard let self, self.selection == expected, !self.model.isClosed, self.model.choosingPhoto else { return }
                    let model = self.model
                    model.cancelPhotoLoad = nil
                    if let data, data.count <= 32*1024*1024 { model.receivePhoto(data) }
                    else { model.photoFailed() }
                }
            }
            model.cancelPhotoLoad = { progress.cancel() }
        }
    }
}
