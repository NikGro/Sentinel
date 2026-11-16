import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

/// Fotos und Dateien an einer Markierung oder einem Ziel, einheitlich überall in der App.
/// Das leere Bild mit Kamera fügt hinzu (aufnehmen, aus der Mediathek, Datei); Antippen eines Fotos bietet
/// Ansehen, Ersetzen, Titelbild und Entfernen an. Ohne `editable` nur ansehen.
struct AttachmentsSection: View {
    var title = "Fotos und Dateien"
    @Binding var attachments: [ChatAttachment]
    var editable = true
    /// Das erste Foto als Titelbild kennzeichnen (Ziele).
    var marksTitlePhoto = false

    static let limit = 100

    @Environment(AppModel.self) private var model
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showsSources = false
    @State private var showsLibrary = false
    @State private var showsCamera = false
    @State private var showsFiles = false
    /// Angetipptes Foto bzw. angetippte Datei, für das Aktionsmenü.
    @State private var selected: ChatAttachment?
    /// Wird gerade ein bestimmtes Foto ersetzt?
    @State private var replacing: String?
    @State private var uploads = 0
    @State private var failure: String?
    @State private var previewURL: URL?

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 8)]

    var body: some View {
        Section {
            if !attachments.isEmpty || editable {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(attachments, id: \.blobId) { attachment in
                        tile(attachment)
                    }
                    if editable, attachments.count < Self.limit {
                        Button {
                            replacing = nil
                            showsSources = true
                        } label: {
                            PhotoPlaceholder(label: uploads > 0 ? nil : "Hinzufügen")
                                .overlay { if uploads > 0 { ProgressView() } }
                                .frame(height: 84)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .disabled(uploads > 0)
                        .accessibilityLabel("Foto oder Datei hinzufügen")
                    }
                }
                .padding(.vertical, 4)
            }
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        } header: {
            Text(attachments.isEmpty ? title : "\(title) (\(attachments.count))")
        } footer: {
            if editable, marksTitlePhoto, attachments.contains(where: { $0.art == .bild }) {
                Text("Das erste Foto ist das Titelbild. Foto antippen zum Ansehen, Ersetzen oder Entfernen.")
            }
        }
        .confirmationDialog(replacing == nil ? "Hinzufügen" : "Foto ersetzen", isPresented: $showsSources, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Foto aufnehmen") { showsCamera = true }
            }
            Button(replacing == nil ? "Fotos aus Mediathek" : "Foto aus Mediathek") { showsLibrary = true }
            if replacing == nil {
                Button("Datei") { showsFiles = true }
            }
        }
        .confirmationDialog(
            selected.map { label($0) } ?? "",
            isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }),
            titleVisibility: .visible,
            presenting: selected
        ) { attachment in
            Button("Ansehen") { Task { await open(attachment) } }
            if attachment.art == .bild {
                if marksTitlePhoto, attachments.first(where: { $0.art == .bild })?.blobId != attachment.blobId {
                    Button("Als Titelbild verwenden") {
                        attachments.removeAll { $0.blobId == attachment.blobId }
                        attachments.insert(attachment, at: 0)
                    }
                }
                Button("Ersetzen") {
                    replacing = attachment.blobId
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        showsSources = true
                    }
                }
            }
            Button("Entfernen", role: .destructive) {
                attachments.removeAll { $0.blobId == attachment.blobId }
            }
        }
        .photosPicker(isPresented: $showsLibrary, selection: $pickerItems, maxSelectionCount: replacing == nil ? 30 : 1, matching: .images)
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

    private func label(_ attachment: ChatAttachment) -> String {
        attachment.art == .bild ? "Foto" : (attachment.name.isEmpty ? "Datei" : attachment.name)
    }

    @ViewBuilder private func tile(_ attachment: ChatAttachment) -> some View {
        let isTitle = marksTitlePhoto && attachments.first(where: { $0.art == .bild })?.blobId == attachment.blobId
        Button {
            if editable { selected = attachment } else { Task { await open(attachment) } }
        } label: {
            ZStack(alignment: .bottomLeading) {
                if attachment.art == .bild {
                    // Das Bild füllt die Kachel, bestimmt aber nicht ihre Größe (sehr breite Fotos sprengten sie).
                    Color.secondary.opacity(0.15)
                        .overlay { RemoteImage(blobId: attachment.blobId) { Color.clear } }
                        .clipped()
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
                if isTitle {
                    Text("Titelbild")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: .capsule)
                        .padding(5)
                }
            }
            .frame(height: 84)
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: 12))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isTitle ? "Titelbild" : label(attachment))
        .accessibilityHint(editable ? "Ansehen, ersetzen oder entfernen" : "Ansehen")
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
        uploads += 1
        defer { uploads -= 1 }
        do {
            let blob = try await client.upload(data, contentType: contentType)
            let attachment = ChatAttachment(blobId: blob.id, art: art, name: String(name.prefix(120)), mime: blob.mime, groesse: blob.groesse)
            if let replacing, let index = attachments.firstIndex(where: { $0.blobId == replacing }) {
                attachments[index] = attachment
                self.replacing = nil
            } else if attachments.count < Self.limit {
                attachments.append(attachment)
            }
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }

    private func open(_ attachment: ChatAttachment) async {
        guard let client = model.client, let data = try? await client.blob(id: attachment.blobId) else { return }
        let name = attachment.name.isEmpty ? attachment.blobId : attachment.name.replacingOccurrences(of: "/", with: "_")
        let url = FileManager.default.temporaryDirectory.appending(path: "\(attachment.blobId.prefix(8))-\(name)")
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            previewURL = url
        } catch {
            previewURL = nil
        }
    }
}
