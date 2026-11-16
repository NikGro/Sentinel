import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

/// Fotos und Dateien an einer Markierung oder einem Ziel: aufnehmen, aus der Mediathek wählen, Dateien anhängen,
/// antippen zum Ansehen. Ohne `attachments`-Bindung (nur lesen) entfallen Hinzufügen und Entfernen.
struct AttachmentsSection: View {
    var title = "Fotos und Dateien"
    @Binding var attachments: [ChatAttachment]
    var editable = true

    @Environment(AppModel.self) private var model
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showsCamera = false
    @State private var showsFiles = false
    @State private var isUploading = false
    @State private var failure: String?
    @State private var previewURL: URL?

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 8)]

    var body: some View {
        Section {
            if !attachments.isEmpty {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(attachments, id: \.blobId) { attachment in
                        tile(attachment)
                    }
                }
                .padding(.vertical, 4)
            }
            if isUploading {
                HStack {
                    ProgressView()
                    Text("Wird hochgeladen …")
                        .foregroundStyle(.secondary)
                }
            }
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if editable {
                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Foto aufnehmen", systemImage: "camera") { showsCamera = true }
                    }
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                        Label("Aus Mediathek", systemImage: "photo.on.rectangle")
                    }
                    Button("Datei", systemImage: "doc") { showsFiles = true }
                } label: {
                    Label("Foto oder Datei anhängen", systemImage: "paperclip")
                }
                .disabled(isUploading || attachments.count >= 20)
            }
        } header: {
            Text(title)
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        await uploadImage(image)
                    }
                }
                pickerItems = []
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { image in
                showsCamera = false
                if let image { Task { await uploadImage(image) } }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showsFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                Task { for url in urls { await uploadFile(url) } }
            }
        }
        .quickLookPreview($previewURL)
    }

    @ViewBuilder private func tile(_ attachment: ChatAttachment) -> some View {
        Button {
            Task { await open(attachment) }
        } label: {
            ZStack {
                if attachment.art == .bild {
                    RemoteImage(blobId: attachment.blobId) { Color.secondary.opacity(0.15) }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: attachment.art == .audio ? "waveform" : "doc.fill")
                            .font(.title2)
                        Text(attachment.name.isEmpty ? "Datei" : attachment.name)
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.15))
                }
            }
            .frame(height: 76)
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if editable {
                Button("Entfernen", systemImage: "trash", role: .destructive) {
                    attachments.removeAll { $0.blobId == attachment.blobId }
                }
            }
        }
        .accessibilityLabel(attachment.art == .bild ? "Foto" : (attachment.name.isEmpty ? "Datei" : attachment.name))
    }

    // MARK: Hochladen und Ansehen

    private func uploadImage(_ image: UIImage) async {
        // Neu gezeichnet: Metadaten wie der Aufnahmeort gehen dabei verloren.
        guard let jpeg = PhotoStore.prepare(image, maxDimension: 2048) else { return }
        await upload(jpeg, contentType: "image/jpeg", art: .bild, name: "Foto.jpg")
    }

    private func uploadFile(_ url: URL) async {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            failure = "Die Datei konnte nicht gelesen werden."
            return
        }
        let type = UTType(filenameExtension: url.pathExtension)
        let art: ChatAttachment.Art = type?.conforms(to: .image) == true ? .bild : type?.conforms(to: .audio) == true ? .audio : .datei
        await upload(data, contentType: type?.preferredMIMEType ?? "application/octet-stream", art: art, name: url.lastPathComponent)
    }

    private func upload(_ data: Data, contentType: String, art: ChatAttachment.Art, name: String) async {
        guard let client = model.client else { return }
        guard data.count <= 15 * 1024 * 1024 else {
            failure = "Die Datei ist größer als 15 MB."
            return
        }
        isUploading = true
        defer { isUploading = false }
        do {
            let blob = try await client.upload(data, contentType: contentType)
            attachments.append(ChatAttachment(blobId: blob.id, art: art, name: String(name.prefix(120)), mime: blob.mime, groesse: blob.groesse))
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }

    private func open(_ attachment: ChatAttachment) async {
        guard let client = model.client, let data = try? await client.blob(id: attachment.blobId) else { return }
        let name = attachment.name.isEmpty ? attachment.blobId : attachment.name.replacingOccurrences(of: "/", with: "_")
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            previewURL = url
        } catch {
            previewURL = nil
        }
    }
}
