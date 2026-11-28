import SentinelKern
import SwiftUI

/// Ziele-Tab: nach Gruppen geordnet, Antippen öffnet die Zielansicht (gleich wie auf Android).
struct Zielliste: View {
    @Environment(AppModell.self) private var modell
    let aufKarte: (KartenObjekt) -> Void

    var body: some View {
        let stand = modell.stand
        NavigationStack {
            List {
                ForEach(stand.zielgruppenSortiert, id: \.id) { g in
                    let drin = stand.zieleSortiert.filter { $0.data.gruppeId == g.id }
                    Section {
                        ForEach(drin, id: \.id) { z in zeile(z.id) }
                    } header: {
                        Label { Text(g.data.name) } icon: { Circle().fill(Color(hex: g.data.farbe)).frame(width: 10, height: 10) }
                    }
                }
                let ohne = stand.zieleSortiert.filter { z in z.data.gruppeId.map { stand.zielgruppen[$0] == nil } ?? true }
                if !ohne.isEmpty {
                    Section(stand.zielgruppen.isEmpty ? "" : "Ohne Gruppe") {
                        ForEach(ohne, id: \.id) { z in zeile(z.id) }
                    }
                }
            }
            .overlay {
                if stand.ziele.isEmpty {
                    ContentUnavailableView("Noch keine Ziele", systemImage: "person.crop.rectangle.stack", description: Text("Über „+“ auf der Karte anlegen."))
                }
            }
            .navigationTitle("Ziele")
            .navigationDestination(for: String.self) { id in
                Zielansicht(id: id, aufKarte: { aufKarte(KartenObjekt(art: .ziel, id: id)) })
            }
        }
    }

    @ViewBuilder
    private func zeile(_ id: String) -> some View {
        let stand = modell.stand
        if let info = Kurzinfo.companion.fuer(stand: stand, objekt: KartenObjekt(art: .ziel, id: id), jetztMs: Int64(Date.now.timeIntervalSince1970 * 1000), ich: nil) {
            let sichtbar = stand.zielEingeblendet(id: id)
            NavigationLink(value: id) {
                HStack(spacing: 12) {
                    if let foto = stand.ziele[id].flatMap({ Anhaenge.shared.titelfoto(z: $0.data) }) {
                        ServerBild(blobId: foto).frame(width: 36, height: 36).clipShape(.circle)
                    } else {
                        Image(systemName: info.symbol.sf)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color(hex: info.farbe).opacity(sichtbar ? 1 : 0.35), in: .circle)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.titel)
                        Text(info.zeilen.first { $0.titel == "Stand" }?.wert ?? info.untertitel).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .accessibilityIdentifier("Ziel \(info.titel)")
        }
    }
}

/// Zielansicht: alle Angaben eines Ziels, Standortquelle, Unterwegs (Personen), Gruppe, Beziehungen, Sichtbarkeit.
/// Felder und Regeln kommen aus dem Kern (gleich wie auf Android). Änderungen gelten erst mit „Sichern“; Unterwegs,
/// Sichtbarkeit und Beziehungen wirken sofort.
struct Zielansicht: View {
    @Environment(AppModell.self) private var modell
    @Environment(\.dismiss) private var schliessen
    let id: String
    let aufKarte: () -> Void
    var standortSetzen: (() -> Void)?

    @State private var z: Ziel?
    @State private var loeschen = false
    @State private var beziehungNeu = false

    var body: some View {
        let stand = modell.stand
        if let v = stand.ziele[id] {
            let aktuell = z ?? v.data
            let geaendert = z.map { !$0.isEqual(v.data) } ?? false
            let fehlt = Zieleditor.shared.fehlt(z: aktuell)
            let jetzt = Int64(Date.now.timeIntervalSince1970 * 1000)
            Form {
                if let foto = Anhaenge.shared.titelfoto(z: aktuell) {
                    Section { ServerBild(blobId: foto).frame(height: 220).listRowInsets(EdgeInsets()) }
                }
                if let fehlt { Section { Text(fehlt).foregroundStyle(.red) } }

                Section("Standort") {
                    let o = stand.ortung(ziel: v, jetztMs: jetzt, tiefe: 0)
                    Text(o.map { "Stand \(Format.shared.vor(ms: $0.zeitMs, jetztMs: jetzt))" } ?? "Keine Position").foregroundStyle(.secondary)
                    if o != nil { Button("Auf der Karte", systemImage: "map", action: aufKarte) }
                    if let standortSetzen { Button("Standort setzen", systemImage: "mappin.and.ellipse", action: standortSetzen) }
                    let quellen = Zieleditor.shared.quellen(z: aktuell)
                    if quellen.count > 1 {
                        Picker("Standortquelle", selection: Binding(get: { aktuell.gewaehlteQuelle.name }, set: { name in
                            guard let q = quellen.first(where: { $0.name == name }) else { return }
                            z = Zieleditor.shared.mitQuelle(z: aktuell, quelle: q, trackerId: aktuell.trackerId ?? stand.tracker.keys.first)
                        })) {
                            ForEach(quellen, id: \.name) { q in Text(Zieleditor.shared.quelleTitel(q: q)).tag(q.name) }
                        }
                        if aktuell.gewaehlteQuelle == .tracker {
                            let tracker = stand.tracker.values.sorted { $0.data.name < $1.data.name }
                            if tracker.isEmpty {
                                Text("Kein Tracker angelegt.").foregroundStyle(.secondary)
                            } else {
                                Picker("Tracker", selection: Binding(get: { aktuell.trackerId ?? "" }, set: { t in
                                    z = Zieleditor.shared.mitQuelle(z: aktuell, quelle: .tracker, trackerId: t)
                                })) {
                                    ForEach(tracker, id: \.id) { t in Text(t.data.name).tag(t.id) }
                                }
                            }
                        }
                    }
                }

                let bindungen = Zieleditor.shared.bindungsziele(stand: stand, zielId: id)
                if bindungen.count > 1 {
                    Section("Unterwegs") {
                        Picker("Wo ist die Person?", selection: Binding(
                            get: { Zieleditor.shared.aktuelleBindung(stand: stand, zielId: id)?.schluessel ?? "" },
                            set: { s in
                                guard let b = bindungen.first(where: { $0.schluessel == s }),
                                      let neu = Zieleditor.shared.binden(stand: stand, zielId: id, b: b, jetztMs: Int64(Date.now.timeIntervalSince1970 * 1000)) else { return }
                                _ = modell.lage.setzen(art: .ziel, id: id, daten: neu)
                                if let z0 = z { z = Zieleditor.shared.ortUebernehmen(z: z0, von: neu) }
                            }
                        )) {
                            ForEach(bindungen, id: \.schluessel) { b in Text(b.titel).tag(b.schluessel) }
                        }
                    }
                }

                Section("Angaben") {
                    ForEach(Zieleditor.shared.felder(art: aktuell.art), id: \.schluessel) { f in
                        let bindung = Binding(
                            get: { Zieleditor.shared.wert(z: z ?? v.data, schluessel: f.schluessel) },
                            set: { z = Zieleditor.shared.setzen(z: z ?? v.data, schluessel: f.schluessel, wert: $0) }
                        )
                        if f.mehrzeilig {
                            TextField(f.titel, text: bindung, axis: .vertical).lineLimit(4...20)
                        } else {
                            TextField(f.titel, text: bindung, prompt: Text(f.hinweis.isEmpty ? f.titel : "\(f.titel) (\(f.hinweis))"))
                                .textInputAutocapitalization(f.grossbuchstaben ? .characters : .sentences)
                        }
                    }
                    if aktuell.art == .person {
                        let k = Calendar.current.dateComponents([.year, .month, .day], from: .now)
                        if let a = Zieleditor.shared.alter(geburtsdatum: aktuell.geburtsdatum, jahr: Int32(k.year!), monat: Int32(k.month!), tag: Int32(k.day!)) {
                            Text("\(a.intValue) Jahre").foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Fotos und Dateien") {
                    AnhaengeAbschnitt(ziel: aktuell) { aenderung in
                        if let jetzt = modell.stand.ziele[id]?.data { _ = modell.lage.setzen(art: .ziel, id: id, daten: aenderung(jetzt)) }
                        if let z0 = z { z = aenderung(z0) }
                    }
                }

                if !stand.zielgruppen.isEmpty {
                    Section {
                        Picker("Gruppe", selection: Binding(get: { aktuell.gruppeId ?? "" }, set: { g in
                            z = Zieleditor.shared.mitGruppe(z: aktuell, gruppeId: g.isEmpty ? nil : g)
                        })) {
                            Text("Keine").tag("")
                            ForEach(stand.zielgruppenSortiert, id: \.id) { g in Text(g.data.name).tag(g.id) }
                        }
                    }
                }

                Section {
                    Toggle("Auf der Karte zeigen", isOn: Binding(get: { stand.zielEingeblendet(id: id) }, set: { _ = modell.lage.zielEinblenden(zielId: id, sichtbar: $0) }))
                }

                Section("Beziehungen") {
                    let verbunden = stand.verbundeneZiele(zielId: id)
                    if verbunden.isEmpty {
                        Text("Keine. Halter, Fahrer, Bewohner usw. als eigene Ziele anlegen und hier verbinden.").foregroundStyle(.secondary)
                    }
                    ForEach(verbunden, id: \.beziehung.id) { b in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.anderes.data.anzeigename)
                                Text([b.beziehung.data.bezeichnung, Beziehungen.shared.statusTitel(s: b.beziehung.data.status)].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Lösen") { _ = modell.lage.loeschen(art: .beziehung, id: b.beziehung.id) }
                                .buttonStyle(.borderless)
                        }
                    }
                    if !Beziehungen.shared.kandidaten(stand: stand, zielId: id).isEmpty {
                        Button("Verbinden", systemImage: "link") { beziehungNeu = true }
                    }
                }

                Section {
                    Button("Ziel löschen", systemImage: "trash", role: .destructive) { loeschen = true }
                } footer: {
                    Text("Zuletzt geändert von \(stand.name(akteurId: v.updatedBy)), \(Format.shared.vor(ms: v.updatedAt, jetztMs: jetzt))")
                }
            }
            .navigationTitle(v.data.anzeigename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if geaendert {
                    ToolbarItem(placement: .cancellationAction) { Button("Verwerfen") { z = nil } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        if let z { _ = modell.lage.setzen(art: .ziel, id: id, daten: Zieleditor.shared.fertig(z: z)) }
                        z = nil
                    }
                    .disabled(!geaendert || fehlt != nil)
                    .accessibilityIdentifier("Sichern")
                }
            }
            .confirmationDialog("Ziel löschen?", isPresented: $loeschen, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    _ = modell.lage.loeschen(art: .ziel, id: id)
                    schliessen()
                }
            } message: {
                Text("„\(v.data.anzeigename)“ wird für alle entfernt.")
            }
            .sheet(isPresented: $beziehungNeu) {
                BeziehungAnlegen(id: id)
            }
        } else {
            ContentUnavailableView("Ziel nicht mehr vorhanden", systemImage: "questionmark.circle")
        }
    }
}

private struct BeziehungAnlegen: View {
    @Environment(AppModell.self) private var modell
    @Environment(\.dismiss) private var schliessen
    let id: String
    @State private var anderes = ""
    @State private var bezeichnung = ""

    var body: some View {
        let stand = modell.stand
        let kandidaten = Beziehungen.shared.kandidaten(stand: stand, zielId: id)
        NavigationStack {
            Form {
                Picker("Mit", selection: $anderes) {
                    ForEach(kandidaten, id: \.id) { k in Text(k.data.anzeigename).tag(k.id) }
                }
                Section {
                    TextField("Beziehung, z. B. Halter, Fahrer, Bewohner", text: $bezeichnung)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Beziehungen.shared.vorschlaege, id: \.self) { v in
                                Button(v) { bezeichnung = v }.buttonStyle(.bordered).buttonBorderShape(.capsule)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Verbinden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verbinden") {
                        _ = modell.lage.setzen(art: .beziehung, id: Lage.companion.neueId(), daten: Beziehungen.shared.neu(von: id, nach: anderes, bezeichnung: bezeichnung, ich: stand.ichId))
                        schliessen()
                    }
                    .disabled(anderes.isEmpty)
                }
            }
            .onAppear { anderes = kandidaten.first?.id ?? "" }
        }
        .presentationDetents([.medium])
    }
}
