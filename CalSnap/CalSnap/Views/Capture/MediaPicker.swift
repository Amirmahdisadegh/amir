import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Media returned by a picker.
enum PickedMedia: Equatable {
    case image(UIImage)
    case video(URL)
}

// MARK: - Camera (photo or video) via UIImagePickerController

struct CameraPicker: UIViewControllerRepresentable {
    enum Mode { case photo, video }
    var mode: Mode
    var onPick: (PickedMedia) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera : .photoLibrary
        picker.mediaTypes = mode == .video ? ["public.movie"] : ["public.image"]
        picker.cameraCaptureMode = mode == .video ? .video : .photo
        picker.videoQuality = .typeMedium
        picker.videoMaximumDuration = 15
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL {
                parent.onPick(.video(url))
            } else if let image = info[.originalImage] as? UIImage {
                parent.onPick(.image(image))
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Library (photo or video) via PHPicker

struct LibraryPicker: UIViewControllerRepresentable {
    var onPick: (PickedMedia) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: LibraryPicker
        init(_ parent: LibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else { parent.dismiss(); return }
            let provider = result.itemProvider

            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let url else { DispatchQueue.main.async { self.parent.dismiss() }; return }
                    // Copy to a stable temp location before the source is removed.
                    let dest = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(url.pathExtension.isEmpty ? "mov" : url.pathExtension)
                    try? FileManager.default.copyItem(at: url, to: dest)
                    DispatchQueue.main.async {
                        self.parent.onPick(.video(dest))
                        self.parent.dismiss()
                    }
                }
            } else if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    DispatchQueue.main.async {
                        if let image = object as? UIImage {
                            self.parent.onPick(.image(image))
                        }
                        self.parent.dismiss()
                    }
                }
            } else {
                parent.dismiss()
            }
        }
    }
}
