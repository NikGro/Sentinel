import SwiftUI

/// Eine Aktion in einem Auswahlblatt (statt einer Sprechblase am Knopf).
struct MediaAction: Identifiable {
    let id: String
    let title: String
    let symbol: String
    var role: ButtonRole?
}

/// Auswahlblatt von unten mit großen Zeilen. Gewählt wird erst nach dem Schließen ausgeführt (`onDismiss` des
/// Aufrufers), damit sich nie zwei Ansichten gleichzeitig öffnen oder schließen.
struct MediaActionSheet: View {
    let title: String
    let actions: [MediaAction]
    let choose: (MediaAction) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(actions) { action in
                    Button(role: action.role) {
                        choose(action)
                        dismiss()
                    } label: {
                        Label(action.title, systemImage: action.symbol)
                            .font(.body.weight(.medium))
                            .frame(minHeight: 36)
                    }
                    .tint(action.role == .destructive ? .red : .primary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Fotoansicht im Vollbild: Bedienelemente bleiben immer sichtbar, Zoomen mit zwei Fingern oder Doppeltipp.
struct PhotoViewer: View {
    let blobId: String
    var title = "Foto"

    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoStore.self) private var photos
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color(.systemBackground)
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnifyGesture()
                                    .onChanged { scale = min(max(lastScale * $0.magnification, 1), 6) }
                                    .onEnded { _ in
                                        lastScale = scale
                                        if scale <= 1 { resetZoom() }
                                    }
                                    .simultaneously(with: DragGesture()
                                        .onChanged { value in
                                            guard scale > 1 else { return }
                                            offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                                        }
                                        .onEnded { _ in lastOffset = offset })
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.snappy) {
                                    if scale > 1 { resetZoom() } else {
                                        scale = 2.5
                                        lastScale = 2.5
                                    }
                                }
                            }
                    } else {
                        ProgressView()
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen", systemImage: "xmark") { dismiss() }
                }
                if let image {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview(title, image: Image(uiImage: image)))
                    }
                }
            }
        }
        .task {
            image = photos.cached(blobId)
            if image == nil { image = await photos.image(id: blobId) }
        }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
