import PhotosUI
import SentinelKern
import SwiftUI
import UIKit

/// Bilder vom eigenen Server, im Speicher zwischengehalten.
@MainActor
enum Bildspeicher {
    private static let speicher: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 32 * 1024 * 1024
        return c
    }()

    static func laden(_ modell: AppModell, _ blobId: String) async -> UIImage? {
        if let b = speicher.object(forKey: blobId as NSString) { return b }
        guard let api = modell.api, let bytes = try? await api.datei(id: blobId) else { return nil }
        guard let bild = UIImage(data: Bruecke.shared.alsData(b: bytes)) else { return nil }
        speicher.setObject(bild, forKey: blobId as NSString, cost: Int(bild.size.width * bild.size.height * 4))
        return bild
    }

    /// Foto verkleinern (längste Kante wie auf Android) und als JPEG verpacken.
    static func verkleinern(_ daten: Data) -> Data? {
        guard let bild = UIImage(data: daten) else { return nil }
        let kante = CGFloat(Anhaenge.shared.FOTO_KANTE)
        let faktor = min(1, kante / max(bild.size.width, bild.size.height))
        let groesse = CGSize(width: (bild.size.width * faktor).rounded(), height: (bild.size.height * faktor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let klein = UIGraphicsImageRenderer(size: groesse, format: format).image { _ in bild.draw(in: CGRect(origin: .zero, size: groesse)) }
        return klein.jpegData(compressionQuality: Anhaenge.shared.FOTO_QUALITAET)
    }
}

/// Bild vom Server; zeigt bis zum Laden einen Platzhalter.
struct ServerBild: View {
    @Environment(AppModell.self) private var modell
    let blobId: String
    var fuellen = true
    @State private var bild: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.fill.tertiary)
            if let bild {
                Image(uiImage: bild).resizable().aspectRatio(contentMode: fuellen ? .fill : .fit)
            } else {
                ProgressView()
            }
        }
        .clipped()
        .task(id: blobId) { bild = await Bildspeicher.laden(modell, blobId) }
    }
}

/// Fotos und Dateien eines Ziels: Vorschaubilder, Antippen zeigt das Bild groß, das Menü bietet Titelfoto und
/// Entfernen. Änderungen wirken sofort (`aendern` erhält eine Änderung am jeweils aktuellen Stand).
struct AnhaengeAbschnitt: View {
    @Environment(AppModell.self) private var modell
    let ziel: Ziel
    let aendern: (@escaping (Ziel) -> Ziel) -> Void
    @State private var auswahl: PhotosPickerItem?
    @State private var laedt = false
    @State private var fehler: String?
    @State private var gross: GrossesBild?

    struct GrossesBild: Identifiable { let id: String }

    var body: some View {
        let bilder = Anhaenge.shared.bilder(z: ziel)
        let titel = Anhaenge.shared.titelfoto(z: ziel)
        if !bilder.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(bilder, id: \.blobId) { a in
                    ServerBild(blobId: a.blobId)
                        .frame(height: 88)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                            if titel == a.blobId { Image(systemName: "star.fill").foregroundStyle(.yellow).padding(5).shadow(radius: 2) }
                        }
                        .onTapGesture { gross = GrossesBild(id: a.blobId) }
                        .contextMenu {
                            Button("Als Titelfoto", systemImage: "star") { aendern { Anhaenge.shared.alsTitelfoto(z: $0, blobId: a.blobId) } }
                            Button("Entfernen", systemImage: "trash", role: .destructive) { aendern { Anhaenge.shared.entfernen(z: $0, blobId: a.blobId) } }
                        }
                }
            }
            .padding(.vertical, 4)
        }
        ForEach(Anhaenge.shared.dateien(z: ziel), id: \.blobId) { a in
            HStack {
                Label(a.name.isEmpty ? "Datei" : a.name, systemImage: "doc")
                Spacer()
                Text(Anhaenge.shared.groesseText(bytes: a.groesse)).foregroundStyle(.secondary)
            }
            .swipeActions { Button("Entfernen", role: .destructive) { aendern { Anhaenge.shared.entfernen(z: $0, blobId: a.blobId) } } }
        }
        HStack {
            PhotosPicker(selection: $auswahl, matching: .images) { Label("Foto hinzufügen", systemImage: "photo.badge.plus") }
                .disabled(laedt)
            if laedt { Spacer(); ProgressView() }
        }
        .onChange(of: auswahl) { _, neu in
            guard let neu else { return }
            Task { await hochladen(neu) }
        }
        .fullScreenCover(item: $gross) { g in
            ZStack {
                Color.black.ignoresSafeArea()
                ServerBild(blobId: g.id, fuellen: false)
            }
            .onTapGesture { gross = nil }
        }
        if let fehler { Text(fehler).foregroundStyle(.red) }
    }

    private func hochladen(_ item: PhotosPickerItem) async {
        laedt = true
        fehler = nil
        defer { laedt = false; auswahl = nil }
        guard let api = modell.api else { return }
        do {
            guard let roh = try await item.loadTransferable(type: Data.self), let klein = Bildspeicher.verkleinern(roh) else {
                fehler = "Foto konnte nicht gelesen werden."
                return
            }
            let d = try await api.hochladen(daten: Bruecke.shared.ausData(d: klein), mime: "image/jpeg")
            let a = Anhaenge.shared.aus(d: d, name: "Foto.jpg")
            aendern { Anhaenge.shared.hinzufuegen(z: $0, a: a) }
        } catch {
            fehler = "Hochladen fehlgeschlagen."
        }
    }
}
