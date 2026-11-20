import PhotosUI
import SwiftUI

/// Formularzeile für ein einzelnes Foto (z. B. Profilbild). Antippen des Bildes bietet Aufnehmen, Auswählen,
/// Ersetzen oder Entfernen an; kein eigener Menüknopf.
struct PhotoField: View {
    let title: String
    @Binding var blobId: String?

    @Environment(PhotoStore.self) private var photos
    @State private var pickerItem: PhotosPickerItem?
    @State private var showsOptions = false
    /// Was nach dem Schließen des Auswahlblatts geöffnet wird: "kamera" oder "mediathek".
    @State private var followup: String?
    @State private var showsLibrary = false
    @State private var showsCamera = false
    @State private var isUploading = false
    @State private var failure: String?

    var body: some View {
        Button { showsOptions = true } label: {
            HStack(spacing: 14) {
                RemoteImage(blobId: blobId) {
                    PhotoPlaceholder()
                }
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 12))
                .overlay { if isUploading { ProgressView() } }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(blobId == nil ? "Tippen, um ein Foto hinzuzufügen" : "Tippen zum Ersetzen oder Entfernen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let failure {
                        Text(failure)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isUploading)
        .accessibilityLabel(title)
        .accessibilityHint(blobId == nil ? "Foto hinzufügen" : "Foto ersetzen oder entfernen")
        // Auswahlblatt statt Sprechblase; Kamera bzw. Mediathek erst, wenn es ganz geschlossen ist.
        .sheet(isPresented: $showsOptions, onDismiss: {
            if followup == "kamera" { showsCamera = true } else if followup == "mediathek" { showsLibrary = true }
            followup = nil
        }) {
            MediaActionSheet(title: title, actions: options) { action in
                if action.id == "entfernen" { blobId = nil } else { followup = action.id }
            }
        }
        .photosPicker(isPresented: $showsLibrary, selection: $pickerItem, matching: .images)
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

    private var options: [MediaAction] {
        var actions: [MediaAction] = []
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            actions.append(MediaAction(id: "kamera", title: blobId == nil ? "Foto aufnehmen" : "Neues Foto aufnehmen", symbol: "camera"))
        }
        actions.append(MediaAction(id: "mediathek", title: blobId == nil ? "Aus Mediathek wählen" : "Durch Foto aus Mediathek ersetzen", symbol: "photo.on.rectangle"))
        if blobId != nil { actions.append(MediaAction(id: "entfernen", title: "Foto entfernen", symbol: "trash", role: .destructive)) }
        return actions
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

/// Leeres Bild mit Plus: hier lässt sich ein Foto hinzufügen.
struct PhotoPlaceholder: View {
    var label: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.12))
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            VStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.title3)
                if let label {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                }
            }
            .foregroundStyle(.secondary)
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
