import PhotosUI
import SwiftUI

/// Formularzeile für ein optionales Foto: aus der Mediathek wählen, aufnehmen oder entfernen.
struct PhotoField: View {
    let title: String
    @Binding var blobId: String?

    @Environment(PhotoStore.self) private var photos
    @State private var pickerItem: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var isUploading = false
    @State private var failure: String?

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(blobId: blobId) {
                ZStack {
                    Color.secondary.opacity(0.15)
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(.rect(cornerRadius: 12))
            .overlay { if isUploading { ProgressView() } }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                if let failure {
                    Text(failure)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            Menu {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Aus Mediathek wählen", systemImage: "photo.on.rectangle")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Foto aufnehmen", systemImage: "camera") { showsCamera = true }
                }
                if blobId != nil {
                    Button("Foto entfernen", systemImage: "trash", role: .destructive) { blobId = nil }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .accessibilityLabel("\(title) ändern")
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await upload(image)
                } else {
                    failure = "Bild konnte nicht geladen werden."
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { image in
                showsCamera = false
                if let image { Task { await upload(image) } }
            }
            .ignoresSafeArea()
        }
    }

    private func upload(_ image: UIImage) async {
        isUploading = true
        defer { isUploading = false }
        do {
            blobId = try await photos.upload(image)
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }
}

/// Kameraaufnahme über die Systemkamera.
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
