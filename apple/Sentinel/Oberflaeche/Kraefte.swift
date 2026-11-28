import SentinelKern
import PhotosUI
import SwiftUI

/// Kräfte-Tab: Kräfte, eigenes Fahrzeug, Fahrzeuge der Lage (gleich aufgebaut wie auf Android).
struct Kraefteliste: View {
    @Environment(AppModell.self) private var modell
    let aufKarte: (KartenObjekt) -> Void
    @State private var suche = ""

    var body: some View {
        let stand = modell.stand
        let jetzt = Int64(Date.now.timeIntervalSince1970 * 1000)
        let kraefte = Kraeftesuche.shared.kraefte(stand: stand, suche: suche)
        let fahrzeuge = Kraeftesuche.shared.fahrzeuge(stand: stand, suche: suche)
        NavigationStack {
            List {
                if !kraefte.isEmpty { Section("Kräfte") {
                    ForEach(kraefte, id: \.id) { f in
                        let info = Kurzinfo.companion.fuer(stand: stand, objekt: KartenObjekt(art: .kraft, id: f.id), jetztMs: jetzt, ich: nil)
                        NavigationLink(value: f.id) {
                            HStack(spacing: 12) {
                                Image(systemName: info?.symbol.sf ?? "person.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color(hex: info?.farbe ?? Farben.shared.KRAEFTE).opacity(f.data.aktiv ? 1 : 0.35), in: .circle)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.data.spitzname + (f.id == stand.ichId ? " (ich)" : ""))
                                    Text(Kraefteansicht.shared.status(stand: stand, f: f, jetztMs: jetzt)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                if stand.istOnline(fahnderId: f.id) { Circle().fill(.green).frame(width: 10, height: 10) }
                            }
                        }
                        .accessibilityIdentifier("Kraft \(f.data.spitzname)")
                    }
                } }

                // Eigenes Fahrzeug: Einsteigen setzt die Fortbewegung auf „Fahrzeug“.
                let waehlbar = Kraefteansicht.shared.waehlbareFahrzeuge(stand: stand)
                if let ich = stand.ich, !waehlbar.isEmpty, suche.isEmpty {
                    Section("Mein Fahrzeug") {
                        Picker("Fahrzeug", selection: Binding(
                            get: { ich.data.fortbewegung == .fahrzeug ? (ich.data.fahrzeugId ?? "") : "" },
                            set: { id in
                                if id.isEmpty { _ = modell.lage.fortbewegungSetzen(art: .fuss, fahrzeugId: nil, oepnv: nil) }
                                else { _ = modell.lage.fortbewegungSetzen(art: .fahrzeug, fahrzeugId: id, oepnv: nil) }
                            }
                        )) {
                            Text("Kein Fahrzeug").tag("")
                            ForEach(waehlbar, id: \.id) { v in Text(v.data.funkrufname).tag(v.id) }
                        }
                    }
                }

                if !fahrzeuge.isEmpty {
                    Section("Fahrzeuge") {
                        ForEach(fahrzeuge, id: \.id) { v in
                            HStack {
                                NavigationLink(value: FahrzeugWahl(id: v.id)) {
                                    HStack(spacing: 12) {
                                        if let foto = v.data.fotoBlob {
                                            ServerBild(blobId: foto).frame(width: 36, height: 36).clipShape(.circle)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(v.data.funkrufname).foregroundStyle(.primary)
                                            Text([v.data.kennzeichen, Kraefteansicht.shared.fahrzeugStatus(stand: stand, v: v)].filter { !$0.isEmpty }.joined(separator: " · "))
                                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                        }
                                    }
                                }
                                Toggle("Im Einsatz", isOn: Binding(get: { stand.imEinsatz(fahrzeug: v) }, set: { _ = modell.lage.fahrzeugImEinsatz(fahrzeugId: v.id, aktiv: $0) }))
                                    .labelsHidden()
                            }
                            .accessibilityIdentifier("Fahrzeug \(v.data.funkrufname)")
                        }
                    }
                }
            }
            .searchable(text: $suche, prompt: "Kräfte und Fahrzeuge durchsuchen")
            .overlay {
                if !suche.isEmpty && kraefte.isEmpty && fahrzeuge.isEmpty { ContentUnavailableView.search(text: suche) }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: FahrzeugWahl(id: nil)) { Label("Neues Fahrzeug", systemImage: "car.badge.plus") }
                }
            }
            .navigationDestination(for: FahrzeugWahl.self) { w in
                Fahrzeugansicht(id: w.id) { if let id = w.id { aufKarte(KartenObjekt(art: .fahrzeug, id: id)) } }
            }
            .navigationTitle("Kräfte")
            .navigationDestination(for: String.self) { id in
                Kraftansicht(id: id) { aufKarte(KartenObjekt(art: .kraft, id: id)) }
            }
        }
    }
}

/// Kraftansicht: Kurzinfo aus dem Kern, Anrufen, auf der Karte zeigen.
private struct Kraftansicht: View {
    @Environment(AppModell.self) private var modell
    let id: String
    let aufKarte: () -> Void

    var body: some View {
        let ich = modell.standort.aktuell.map { GeoPunkt(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) }
        if let info = Kurzinfo.companion.fuer(stand: modell.stand, objekt: KartenObjekt(art: .kraft, id: id), jetztMs: Int64(Date.now.timeIntervalSince1970 * 1000), ich: ich) {
            List {
                if !info.untertitel.isEmpty { Text(info.untertitel).foregroundStyle(.secondary) }
                Section {
                    if info.ort != nil { Button("Auf der Karte", systemImage: "map", action: aufKarte) }
                    if let t = info.telefon, let url = URL(string: "tel:\(t.filter { !$0.isWhitespace })") {
                        Link(destination: url) { Label("Anrufen (\(t))", systemImage: "phone.fill") }
                    }
                }
                Section {
                    ForEach(info.zeilen.indices, id: \.self) { i in
                        LabeledContent(info.zeilen[i].titel, value: info.zeilen[i].wert)
                    }
                }
            }
            .navigationTitle(info.titel)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct FahrzeugWahl: Hashable { let id: String? }

/// Fahrzeug der Flotte anlegen bzw. bearbeiten: Funkrufname, Kennzeichen, Bezeichnung, Foto, Tracker, Aufzeichnung.
/// Felder und Regeln aus dem Kern (gleich wie auf Android); Änderungen gelten mit „Sichern“.
private struct Fahrzeugansicht: View {
    @Environment(AppModell.self) private var modell
    @Environment(\.dismiss) private var schliessen
    let id: String?
    let aufKarte: () -> Void
    @State private var v: Fahrzeug?
    @State private var loeschen = false
    @State private var fotoAuswahl: PhotosPickerItem?
    @State private var laedt = false

    var body: some View {
        let stand = modell.stand
        let vorhanden = id.flatMap { stand.fahrzeuge[$0] }
        let basis = vorhanden?.data ?? Fahrzeugeditor.shared.neu()
        let aktuell = v ?? basis
        let geaendert = v.map { !$0.isEqual(basis) } ?? false
        let fehlt = Fahrzeugeditor.shared.fehlt(v: aktuell)
        Form {
            Section {
                if let foto = aktuell.fotoBlob {
                    ServerBild(blobId: foto).frame(height: 200).listRowInsets(EdgeInsets())
                }
                PhotosPicker(selection: $fotoAuswahl, matching: .images) {
                    Label(aktuell.fotoBlob == nil ? "Foto hinzufügen" : "Foto ändern", systemImage: "photo.badge.plus")
                }
                .disabled(laedt)
                if aktuell.fotoBlob != nil {
                    Button("Foto entfernen", systemImage: "trash", role: .destructive) { v = Fahrzeugeditor.shared.mitFoto(v: aktuell, blobId: nil) }
                }
            }
            Section("Angaben") {
                ForEach(Fahrzeugeditor.shared.felder(), id: \.schluessel) { f in
                    TextField(f.titel, text: Binding(
                        get: { Fahrzeugeditor.shared.wert(v: v ?? basis, schluessel: f.schluessel) },
                        set: { v = Fahrzeugeditor.shared.setzen(v: v ?? basis, schluessel: f.schluessel, wert: $0) }
                    ), prompt: Text(f.hinweis.isEmpty ? f.titel : "\(f.titel) (\(f.hinweis))"))
                    .textInputAutocapitalization(f.grossbuchstaben ? .characters : .sentences)
                }
            }
            let tracker = stand.tracker.values.sorted { $0.data.name < $1.data.name }
            Section {
                if !tracker.isEmpty {
                    Picker("Tracker", selection: Binding(get: { aktuell.trackerId ?? "" }, set: { t in
                        v = Fahrzeugeditor.shared.mitTracker(v: aktuell, trackerId: t.isEmpty ? nil : t)
                    })) {
                        Text("Kein Tracker").tag("")
                        ForEach(tracker, id: \.id) { t in Text(t.data.name).tag(t.id) }
                    }
                }
                Toggle(isOn: Binding(get: { aktuell.aufzeichnung }, set: { v = Fahrzeugeditor.shared.mitAufzeichnung(v: aktuell, an: $0) })) {
                    Text("Standort aufzeichnen")
                    Text("Für den Verlauf")
                }
            }
            if let vorhanden {
                Section {
                    Toggle("Im Einsatz", isOn: Binding(get: { stand.imEinsatz(fahrzeug: vorhanden) }, set: { _ = modell.lage.fahrzeugImEinsatz(fahrzeugId: vorhanden.id, aktiv: $0) }))
                    Text(Kraefteansicht.shared.fahrzeugStatus(stand: stand, v: vorhanden)).foregroundStyle(.secondary)
                    if stand.ortung(fahrzeug: vorhanden) != nil { Button("Auf der Karte", systemImage: "map", action: aufKarte) }
                }
                Section {
                    Button("Fahrzeug löschen", systemImage: "trash", role: .destructive) { loeschen = true }
                }
            }
        }
        .navigationTitle(vorhanden?.data.funkrufname ?? "Neues Fahrzeug")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(id == nil ? "Anlegen" : "Sichern") {
                    _ = modell.lage.setzen(art: .fahrzeug, id: id ?? Lage.companion.neueId(), daten: Fahrzeugeditor.shared.fertig(v: aktuell))
                    v = nil
                    if id == nil { schliessen() }
                }
                .disabled(!geaendert || fehlt != nil)
                .accessibilityIdentifier("Sichern")
            }
        }
        .confirmationDialog("Fahrzeug löschen?", isPresented: $loeschen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let id { _ = modell.lage.loeschen(art: .fahrzeug, id: id) }
                schliessen()
            }
        } message: {
            Text("„\(aktuell.funkrufname)“ wird aus der Flotte entfernt.")
        }
        .onChange(of: fotoAuswahl) { _, neu in
            guard let neu else { return }
            Task { await hochladen(neu, basis: aktuell) }
        }
    }

    private func hochladen(_ item: PhotosPickerItem, basis: Fahrzeug) async {
        laedt = true
        defer { laedt = false; fotoAuswahl = nil }
        guard let api = modell.api,
              let roh = try? await item.loadTransferable(type: Data.self),
              let klein = Bildspeicher.verkleinern(roh),
              let d = try? await api.hochladen(daten: Bruecke.shared.ausData(d: klein), mime: "image/jpeg") else { return }
        v = Fahrzeugeditor.shared.mitFoto(v: v ?? basis, blobId: d.id)
    }
}
