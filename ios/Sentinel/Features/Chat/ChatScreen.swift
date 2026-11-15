import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

/// Einsatz-Chat in mehreren Räumen. Jeder kann Räume anlegen, betreten und löschen; Einladungen gibt es bewusst nicht.
struct ChatScreen: View {
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @State private var path: [String] = []
    @State private var showsNewRoom = false
    @State private var newRoomName = ""
    @State private var roomToDelete: Versioned<ChatRoom>?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(lage.sortedRooms) { room in
                    NavigationLink(value: room.id) {
                        RoomRow(room: room)
                    }
                    .swipeActions {
                        if room.id != ChatRoom.generalId {
                            Button("Löschen", systemImage: "trash", role: .destructive) { roomToDelete = room }
                        }
                    }
                }
            }
            .navigationTitle("Chat")
            .navigationDestination(for: String.self) { roomId in
                ChatRoomView(roomId: roomId)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Raum anlegen", systemImage: "plus") {
                        newRoomName = ""
                        showsNewRoom = true
                    }
                }
            }
            .alert("Neuer Chatraum", isPresented: $showsNewRoom) {
                TextField("Name", text: $newRoomName)
                Button("Anlegen") {
                    let name = newRoomName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    let id = LageStore.newId()
                    if lage.put(ChatRoom(name: String(name.prefix(40))), id: id) { path = [id] }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Jeder im Einsatz kann den Raum betreten und löschen.")
            }
            .confirmationDialog(
                "Chatraum „\(roomToDelete?.data.name ?? "")“ samt Nachrichten für alle löschen?",
                isPresented: Binding(get: { roomToDelete != nil }, set: { if !$0 { roomToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) {
                    if let room = roomToDelete { lage.delete(ChatRoom.self, id: room.id) }
                }
            }
        }
    }
}

private struct RoomRow: View {
    let room: Versioned<ChatRoom>
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings

    var body: some View {
        let messages = lage.messages(in: room.id)
        let unread = messages.filter { $0.updatedAt > settings.lastReadMessageAt && $0.updatedBy != lage.selfId }.count
        HStack(spacing: 12) {
            Image(systemName: room.id == ChatRoom.generalId ? "megaphone.fill" : "bubble.left.and.bubble.right.fill")
                .foregroundStyle(.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(room.data.name)
                    .font(.headline)
                if let last = messages.last {
                    Text("\(lage.name(of: last.updatedBy)): \(last.data.text.isEmpty ? attachmentTitle(last.data.anhang) : last.data.text)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if unread > 0 {
                Text("\(unread)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.red, in: .capsule)
            }
        }
    }

    private func attachmentTitle(_ attachment: ChatAttachment?) -> String {
        switch attachment?.art {
        case .bild: "Foto"
        case .audio: "Sprachnachricht"
        case .datei: attachment?.name ?? "Datei"
        case nil: ""
        }
    }
}

/// Ein Chatraum mit Nachrichten und Eingabe samt Anhängen, ähnlich bekannter Messenger.
struct ChatRoomView: View {
    let roomId: String

    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @Environment(PhotoStore.self) private var photos
    @Environment(AppModel.self) private var model
    @Environment(AudioRecorder.self) private var audio

    @State private var draft = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var showsFiles = false
    @State private var isUploading = false
    @State private var failure: String?
    @FocusState private var isComposing: Bool

    private var messages: [Versioned<ChatMessage>] { lage.messages(in: roomId) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        MessageBubble(message: message, isMine: message.updatedBy == lage.selfId, sender: lage.name(of: message.updatedBy))
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                markRead()
                if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
        .overlay {
            if messages.isEmpty {
                ContentUnavailableView("Noch keine Nachrichten", systemImage: "bubble.left.and.bubble.right", description: Text("Nachrichten sehen alle im Einsatz. Sie werden geleert, wenn die Lage zurückgesetzt wird."))
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .navigationTitle(lage.rooms[roomId]?.data.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: markRead)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await sendImage(image)
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { image in
                showsCamera = false
                if let image { Task { await sendImage(image) } }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showsFiles, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result { Task { await sendFile(url) } }
        }
        .alert("Hinweis", isPresented: Binding(get: { failure != nil || audio.failure != nil }, set: { if !$0 { failure = nil; audio.failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? audio.failure ?? "")
        }
    }

    // MARK: Eingabe

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if audio.isRecording {
                Button("Verwerfen", systemImage: "trash") { _ = audio.stop(cancel: true) }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .tint(.red)
                HStack {
                    Circle().fill(.red).frame(width: 10, height: 10)
                    Text("Aufnahme \(Format.clock(audio.elapsed))")
                        .monospacedDigit()
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .glassEffect(.regular, in: .capsule)
                Button("Senden", systemImage: "arrow.up") {
                    if let recording = audio.stop() { Task { await sendVoice(recording.data, duration: recording.duration) } }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
            } else {
                Menu {
                    Button("Kamera", systemImage: "camera") { showsCamera = true }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Fotos", systemImage: "photo.on.rectangle")
                    }
                    Button("Datei", systemImage: "doc") { showsFiles = true }
                } label: {
                    Image(systemName: isUploading ? "hourglass" : "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .disabled(isUploading)
                .accessibilityLabel("Anhang")

                TextField("Nachricht", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($isComposing)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))

                if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Sprachnachricht", systemImage: "mic.fill") { Task { await audio.start() } }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                } else {
                    Button("Senden", systemImage: "arrow.up") {
                        lage.sendMessage(draft, in: roomId)
                        draft = ""
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func markRead() {
        if let last = messages.last, last.updatedAt > settings.lastReadMessageAt {
            settings.lastReadMessageAt = last.updatedAt
        }
    }

    // MARK: Anhänge senden

    private func upload(_ data: Data, contentType: String, art: ChatAttachment.Art, name: String, duration: Double? = nil) async {
        guard let client = model.client else { return }
        guard data.count <= 15 * 1024 * 1024 else {
            failure = "Die Datei ist größer als 15 MB."
            return
        }
        isUploading = true
        defer { isUploading = false }
        do {
            let blob = try await client.upload(data, contentType: contentType)
            let attachment = ChatAttachment(blobId: blob.id, art: art, name: String(name.prefix(120)), mime: blob.mime, groesse: blob.groesse, dauer: duration)
            lage.sendMessage(draft, in: roomId, attachment: attachment)
            draft = ""
        } catch {
            failure = error.localizedDescription
        }
    }

    private func sendImage(_ image: UIImage) async {
        // Neu gezeichnet: Metadaten wie der Aufnahmeort gehen dabei verloren.
        guard let jpeg = PhotoStore.prepare(image, maxDimension: 2048) else { return }
        await upload(jpeg, contentType: "image/jpeg", art: .bild, name: "Foto.jpg")
    }

    private func sendVoice(_ data: Data, duration: TimeInterval) async {
        await upload(data, contentType: "audio/mp4", art: .audio, name: "Sprachnachricht.m4a", duration: duration)
    }

    private func sendFile(_ url: URL) async {
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
}

private struct MessageBubble: View {
    let message: Versioned<ChatMessage>
    let isMine: Bool
    let sender: String

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 4) {
                if !isMine {
                    Text(sender)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tint)
                }
                if let attachment = message.data.anhang {
                    AttachmentView(attachment: attachment, isMine: isMine)
                }
                if !message.data.text.isEmpty {
                    Text(message.data.text)
                        .textSelection(.enabled)
                }
                Text(Format.time(message.updatedDate))
                    .font(.caption2)
                    .foregroundStyle(isMine ? AnyShapeStyle(Color.white.opacity(0.75)) : AnyShapeStyle(.secondary))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isMine ? Color.white : Color.primary)
            .background(isMine ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.fill.tertiary), in: .rect(cornerRadius: 16))
            .frame(maxWidth: 300, alignment: isMine ? .trailing : .leading)
            if !isMine { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Anhang im Chat: Bild zum Antippen, Sprachnachricht zum Abspielen, Datei zum Öffnen.
private struct AttachmentView: View {
    let attachment: ChatAttachment
    let isMine: Bool

    @Environment(AppModel.self) private var model
    @Environment(AudioRecorder.self) private var audio
    @State private var previewURL: URL?
    @State private var isLoading = false

    var body: some View {
        switch attachment.art {
        case .bild where attachment.mime == "image/jpeg" || attachment.mime == "image/png":
            RemoteImage(blobId: attachment.blobId) {
                Color.secondary.opacity(0.2)
                    .overlay { ProgressView() }
            }
            .frame(width: 220, height: 220)
            .clipShape(.rect(cornerRadius: 12))
            .onTapGesture { Task { await open() } }
            .quickLookPreview($previewURL)
            .accessibilityLabel("Foto")
        case .audio:
            Button {
                Task { await play() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: audio.playingId == attachment.blobId ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Sprachnachricht")
                            .font(.subheadline.weight(.semibold))
                        if let duration = attachment.dauer {
                            Text(Format.clock(duration))
                                .font(.caption.monospacedDigit())
                                .opacity(0.8)
                        }
                    }
                    if isLoading { ProgressView() }
                }
            }
            .buttonStyle(.plain)
        default:
            Button {
                Task { await open() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(attachment.name.isEmpty ? "Datei" : attachment.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.groesse), countStyle: .file))
                            .font(.caption)
                            .opacity(0.8)
                    }
                    if isLoading { ProgressView() }
                }
            }
            .buttonStyle(.plain)
            .quickLookPreview($previewURL)
        }
    }

    private func play() async {
        guard let client = model.client else { return }
        isLoading = true
        defer { isLoading = false }
        if let data = try? await client.blob(id: attachment.blobId) { audio.play(data, id: attachment.blobId) }
    }

    /// Lädt die Datei, legt sie geschützt im temporären Ordner ab und zeigt sie in der Vorschau.
    private func open() async {
        guard let client = model.client else { return }
        isLoading = true
        defer { isLoading = false }
        guard let data = try? await client.blob(id: attachment.blobId) else { return }
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
