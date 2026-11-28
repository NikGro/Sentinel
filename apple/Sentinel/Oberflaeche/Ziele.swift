import SentinelKern
import SwiftUI

/// Ziele-Tab: Suche, nach Gruppen geordnet, Antippen öffnet die Zielansicht. „Auswählen“ ordnet mehrere Ziele einer
/// Gruppe zu; Gruppen lassen sich anlegen, umbenennen, umfärben und löschen (gleich wie auf Android).
struct Zielliste: View {
    @Environment(AppModell.self) private var modell
    let aufKarte: (KartenObjekt) -> Void
    @State private var suche = ""
    @State private var auswahl = Set<String>()
    @State private var bearbeitungsmodus: EditMode = .inactive
    @State private var gruppe: GruppenBearbeitung?

    var body: some View {
        let stand = modell.stand
        let abschnitte = Zielverzeichnis.shared.abschnitte(stand: stand, suche: suche)
        NavigationStack {
            List(selection: $auswahl) {
                ForEach(abschnitte, id: \.gruppeId) { a in
                    Section {
                        if a.ziele.isEmpty { Text("Keine Ziele in dieser Gruppe.").foregroundStyle(.secondary) }
                        ForEach(a.ziele, id: \.id) { z in zeile(z.id) }
                    } header: {
                        HStack {
                            if let farbe = a.farbe {
                                Label { Text(a.titel) } icon: { Circle().fill(Color(hex: farbe)).frame(width: 10, height: 10) }
                            } else {
                                Text(a.titel)
                            }
                            Spacer()
                            if let gid = a.gruppeId, let g = stand.zielgruppen[gid] {
                                Button("Bearbeiten", systemImage: "pencil") { gruppe = GruppenBearbeitung(id: gid, gruppe: g.data) }
                                    .labelStyle(.iconOnly)
                            }
                        }
                    }
                }
            }
            .searchable(text: $suche, prompt: "Ziele durchsuchen")
            .environment(\.editMode, $bearbeitungsmodus)
            .overlay {
                if stand.ziele.isEmpty {
                    ContentUnavailableView("Noch keine Ziele", systemImage: "person.crop.rectangle.stack", description: Text("Über „+“ auf der Karte anlegen."))
                } else if abschnitte.isEmpty {
                    ContentUnavailableView.search(text: suche)
                }
            }
            .navigationTitle(bearbeitungsmodus.isEditing ? "\(auswahl.count) ausgewählt" : "Ziele")
            .toolbar {
                if bearbeitungsmodus.isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fertig") { auswahl = []; bearbeitungsmodus = .inactive }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Menu("Zur Gruppe") {
                            ForEach(stand.zielgruppenSortiert, id: \.id) { g in
                                Button(g.data.name) { zuordnen(g.id) }
                            }
                            Button("Neue Gruppe …", systemImage: "plus") { neueGruppe() }
                            Button("Aus der Gruppe nehmen", systemImage: "minus.circle") { zuordnen(nil) }
                        }
                        .disabled(auswahl.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Menu("Mehr", systemImage: "ellipsis") {
                            Button("Auswählen", systemImage: "checkmark.circle") { bearbeitungsmodus = .active }
                            Button("Neue Gruppe", systemImage: "folder.badge.plus") { neueGruppe() }
                        }
                    }
                }
            }
            .navigationDestination(for: String.self) { id in
                Zielansicht(id: id, aufKarte: { aufKarte(KartenObjekt(art: .ziel, id: id)) })
            }
            .sheet(item: $gruppe) { b in
                GruppeBearbeiten(bearbeitung: b) { neueId in
                    if b.id == nil, !auswahl.isEmpty { zuordnen(neueId) }
                }
            }
        }
    }

    private func neueGruppe() {
        gruppe = GruppenBearbeitung(id: nil, gruppe: Zielgruppen.shared.neu(name: "", farbe: Zielgruppen.shared.vorschlag(stand: modell.stand)))
    }

    private func zuordnen(_ gruppeId: String?) {
        for paar in Zielverzeichnis.shared.zuordnen(stand: modell.stand, ids: Array(auswahl), gruppeId: gruppeId) {
            if let id = paar.first as? String, let z = paar.second { _ = modell.lage.setzen(art: .ziel, id: id, daten: z) }
        }
        auswahl = []
        bearbeitungsmodus = .inactive
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
            .tag(id)
            .accessibilityIdentifier("Ziel \(info.titel)")
        }
    }
}

struct GruppenBearbeitung: Identifiable {
    let id: String?
    let gruppe: Zielgruppe
}

/// Gruppe anlegen bzw. bearbeiten: Name, Farbe, Löschen (die Ziele bleiben, ohne Gruppe).
private struct GruppeBearbeiten: View {
    @Environment(AppModell.self) private var modell
    @Environment(\.dismiss) private var schliessen
    let bearbeitung: GruppenBearbeitung
    let angelegt: (String) -> Void
    @State private var name = ""
    @State private var farbe = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Section("Farbe") {
                    HStack(spacing: 10) {
                        ForEach(Zielgruppen.shared.farben, id: \.self) { f in
                            Button { farbe = f } label: {
                                Circle().fill(Color(hex: f)).frame(width: 30, height: 30)
                                    .overlay { if f == farbe { Circle().strokeBorder(.primary, lineWidth: 3) } }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(f == farbe ? "Farbe gewählt" : "Farbe")
                        }
                    }
                }
                if let id = bearbeitung.id {
                    Section {
                        Button("Gruppe löschen", systemImage: "trash", role: .destructive) {
                            for paar in Zielverzeichnis.shared.gruppeLoesen(stand: modell.stand, gruppeId: id) {
                                if let zid = paar.first as? String, let z = paar.second { _ = modell.lage.setzen(art: .ziel, id: zid, daten: z) }
                            }
                            _ = modell.lage.loeschen(art: .zielgruppe, id: id)
                            schliessen()
                        }
                    } footer: { Text("Die Ziele bleiben erhalten, ohne Gruppe.") }
                }
            }
            .navigationTitle(bearbeitung.id == nil ? "Neue Gruppe" : "Gruppe bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(bearbeitung.id == nil ? "Anlegen" : "Sichern") {
                        let id = bearbeitung.id ?? Lage.companion.neueId()
                        _ = modell.lage.setzen(art: .zielgruppe, id: id, daten: Zielgruppen.shared.aendern(g: bearbeitung.gruppe, name: name, farbe: farbe))
                        angelegt(id)
                        schliessen()
                    }
                    .disabled(!Zielgruppen.shared.gueltig(name: name))
                }
            }
            .onAppear { name = bearbeitung.gruppe.name; farbe = bearbeitung.gruppe.farbe }
        }
        .presentationDetents([.medium])
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
                        if Zieleditor.shared.mitVorschlaegen(schluessel: f.schluessel) {
                            AnschriftFeld(titel: f.titel, text: bindung) { t in
                                z = Zieleditor.shared.anschriftUebernehmen(z: z ?? v.data, t: t, jetztMs: Int64(Date.now.timeIntervalSince1970 * 1000))
                            }
                        } else if f.mehrzeilig {
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

                Section {
                    Toggle(isOn: Binding(get: { v.data.aufzeichnung }, set: { an in
                        _ = modell.lage.setzen(art: .ziel, id: id, daten: Zieleditor.shared.mitAufzeichnung(z: v.data, an: an))
                        if let z0 = z { z = Zieleditor.shared.mitAufzeichnung(z: z0, an: an) }
                    })) {
                        Text("Standort aufzeichnen")
                        Text("Für den Verlauf")
                    }
                }

                if aktuell.art != .person {
                    Section(aktuell.art == .fahrzeug ? "Insassen" : "Im Gebäude") {
                        let insassen = Zielverzeichnis.shared.insassen(stand: stand, zielId: id)
                        if insassen.isEmpty { Text("Niemand bekannt.").foregroundStyle(.secondary) }
                        ForEach(insassen, id: \.id) { p in
                            NavigationLink(value: p.id) { Text(p.data.anzeigename) }
                        }
                    }
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

/// Anschrift mit Vorschlägen aus der Ortssuche; ein Vorschlag übernimmt die Anschrift und setzt den Standort.
private struct AnschriftFeld: View {
    @Environment(AppModell.self) private var modell
    let titel: String
    @Binding var text: String
    let waehlen: (Suchtreffer) -> Void
    @State private var tippt = false
    @State private var vorschlaege: [Suchtreffer] = []

    var body: some View {
        TextField(titel, text: Binding(get: { text }, set: { tippt = true; text = $0 }))
        ForEach(vorschlaege, id: \.id) { t in
            Button {
                tippt = false
                vorschlaege = []
                waehlen(t)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.titel).foregroundStyle(.primary)
                        if !t.untertitel.isEmpty { Text(t.untertitel).font(.caption).foregroundStyle(.secondary) }
                    }
                } icon: { Image(systemName: "mappin.and.ellipse") }
            }
        }
        .task(id: tippt ? text : "") {
            guard tippt, text.trimmingCharacters(in: .whitespaces).count >= 3, let api = modell.api else { vorschlaege = []; return }
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            vorschlaege = Array(((try? await api.suche(text: text, nahe: nil)) ?? []).prefix(5))
        }
    }
}
