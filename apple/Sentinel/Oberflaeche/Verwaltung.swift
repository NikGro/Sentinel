import SentinelKern
import SwiftUI

/// Mehr-Tab: Hauptmenü, eigenes Profil, Funkkanal und Lage, Version, Abmelden (gleich aufgebaut wie auf Android).
struct Mehr: View {
    @Environment(AppModell.self) private var modell
    let hauptmenue: () -> Void
    @State private var profil = false
    @State private var lage = false
    @State private var abmelden = false

    var body: some View {
        let stand = modell.stand
        @Bindable var m = modell
        NavigationStack {
            List {
                Section {
                    Button(action: hauptmenue) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hauptmenü").foregroundStyle(.primary)
                            Text("Im Dienst · \(stand.aktuelleInstanz?.data.name ?? "KSOD")").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let ich = stand.ich {
                        Button { profil = true } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mein Profil").foregroundStyle(.primary)
                                Text([ich.data.spitzname, ich.data.dienststelle].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button { lage = true } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Funkkanal und Lage").foregroundStyle(.primary)
                            let text = [stand.einsatz.funkkanal.map { "Kanal \($0)" }, stand.einsatz.titel.isEmpty ? nil : stand.einsatz.titel].compactMap { $0 }.joined(separator: " · ")
                            Text(text.isEmpty ? "Nicht gesetzt" : text).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Toggle("App-Sperre", isOn: $m.sperreAn)
                    if modell.sperreAn {
                        Picker("Sperren", selection: $m.sperreFrist) {
                            ForEach(AppSperre.shared.fristen, id: \.sekunden) { f in Text(f.titel).tag(Int(f.sekunden)) }
                        }
                    }
                } footer: {
                    Text("Fragt nach Face ID oder dem Gerätecode, wenn die App eine Zeit lang im Hintergrund war.")
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    Button("Abmelden", role: .destructive) { abmelden = true }
                }
            }
            .navigationTitle("Mehr")
            .sheet(isPresented: $profil) { if let ich = stand.ich { ProfilEditor(id: ich.id, f: ich.data) } }
            .sheet(isPresented: $lage) { LageEditor() }
            .confirmationDialog("Abmelden?", isPresented: $abmelden, titleVisibility: .visible) {
                Button("Abmelden", role: .destructive) { modell.abmelden() }
            } message: {
                Text("Die Anmeldung und alle Einsatzdaten werden von diesem Gerät entfernt.")
            }
        }
    }
}

private struct ProfilEditor: View {
    @Environment(AppModell.self) private var modell
    @Environment(\.dismiss) private var schliessen
    let id: String
    let f: Fahnder
    @State private var name = ""
    @State private var spitzname = ""
    @State private var dienststelle = ""
    @State private var telefon = ""

    var body: some View {
        let fehlt = Verwaltung.shared.profilFehlt(spitzname: spitzname)
        NavigationStack {
            Form {
                Section {
                    TextField("Spitzname", text: $spitzname)
                    TextField("Name", text: $name)
                    TextField("Dienststelle", text: $dienststelle)
                    TextField("Telefon", text: $telefon).keyboardType(.phonePad)
                } footer: {
                    if let fehlt { Text(fehlt) }
                }
            }
            .navigationTitle("Mein Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        _ = modell.lage.setzen(art: .fahnder, id: id, daten: Verwaltung.shared.profil(f: f, name: name, spitzname: spitzname, dienststelle: dienststelle, telefon: telefon))
                        schliessen()
                    }
                    .disabled(fehlt != nil)
                }
            }
            .onAppear { name = f.name; spitzname = f.spitzname; dienststelle = f.dienststelle; telefon = f.telefon }
        }
    }
}

private struct LageEditor: View {
    @Environment(AppModell.self) private var modell
    @Environment(\.dismiss) private var schliessen
    @State private var kanal = ""
    @State private var titel = ""
    @State private var hinweise = ""

    var body: some View {
        let e = modell.stand.einsatz
        NavigationStack {
            Form {
                TextField("Funkkanal", text: $kanal)
                TextField("Lage", text: $titel)
                Section("Hinweise") { TextField("Hinweise", text: $hinweise, axis: .vertical).lineLimit(3...10) }
            }
            .navigationTitle("Funkkanal und Lage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        let k = kanal.trimmingCharacters(in: .whitespaces)
                        if k != (e.funkkanal ?? "") { _ = modell.lage.funkkanalSetzen(kanal: k.isEmpty ? nil : k) }
                        if titel != e.titel || hinweise != e.hinweise { _ = modell.lage.lageSetzen(titel: titel.trimmingCharacters(in: .whitespaces), hinweise: hinweise) }
                        schliessen()
                    }
                }
            }
            .onAppear { kanal = e.funkkanal ?? ""; titel = e.titel; hinweise = e.hinweise }
        }
    }
}

/// Hauptmenü außerhalb bzw. oberhalb der Instanzen: öffnen, beitreten, anlegen, umbenennen, löschen; Pakete.
struct Hauptmenue: View {
    @Environment(AppModell.self) private var modell
    let schliessen: () -> Void
    @State private var neu: NamenAuswahl?
    @State private var umbenennen: NamenAuswahl?
    @State private var loeschen: Versioniert<Instanz>?

    struct NamenAuswahl: Identifiable {
        let id: String
        let titel: String
        let paket: Bool
        let name: String
        let beschreibung: String
    }

    var body: some View {
        let stand = modell.stand
        NavigationStack {
            List {
                Section("Instanzen") {
                    ForEach(stand.eigeneInstanzen, id: \.id) { i in
                        Button {
                            if i.id != stand.instanz || !stand.imDienst { _ = modell.lage.instanzWechseln(id: i.id) }
                            schliessen()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(i.data.name).foregroundStyle(.primary)
                                let b = Verwaltung.shared.beschreibung(stand: stand, i: i)
                                if !b.isEmpty { Text(b).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        .contextMenu { instanzMenue(stand, i) }
                        .swipeActions {
                            if Verwaltung.shared.darfVerlassen(i: i) { Button("Verlassen") { _ = modell.lage.instanzVerlassen(id: i.id) }.tint(.orange) }
                        }
                    }
                    Button("Neue Instanz", systemImage: "plus.circle.fill") {
                        neu = NamenAuswahl(id: "neu", titel: "Neue Instanz", paket: false, name: "", beschreibung: "")
                    }
                }
                if !stand.andereInstanzen.isEmpty {
                    Section("Beitreten") {
                        ForEach(stand.andereInstanzen, id: \.id) { i in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(i.data.name)
                                    let b = Verwaltung.shared.beschreibung(stand: stand, i: i)
                                    if !b.isEmpty { Text(b).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                Button("Beitreten") { _ = modell.lage.instanzBeitreten(id: i.id) }
                                    .buttonStyle(.bordered).buttonBorderShape(.capsule)
                            }
                        }
                    }
                }
                Section("Pakete") {
                    ForEach(stand.pakete, id: \.id) { p in
                        Menu {
                            Button("Bearbeiten", systemImage: "pencil.and.outline") {
                                _ = modell.lage.instanzWechseln(id: p.id)
                                schliessen()
                            }
                            if let ziel = stand.aktuelleInstanz, !ziel.data.istPaket {
                                Button("In „\(ziel.data.name)“ übernehmen", systemImage: "square.and.arrow.down") { _ = modell.lage.paketUebernehmen(paketId: p.id) }
                            }
                            instanzMenue(stand, p)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.data.name).foregroundStyle(.primary)
                                if !p.data.beschreibung.isEmpty { Text(p.data.beschreibung).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                    Button("Neues Paket", systemImage: "plus.circle.fill") {
                        neu = NamenAuswahl(id: "neu", titel: "Neues Paket", paket: true, name: "", beschreibung: "")
                    }
                }
                Section {
                    Button("Abmelden", role: .destructive) { modell.abmelden() }
                }
            }
            .navigationTitle("SENTINEL")
            .toolbar {
                if stand.imDienst { ToolbarItem(placement: .confirmationAction) { Button("Zur Lage", action: schliessen) } }
            }
            .sheet(item: $neu) { a in
                NamenEditor(titel: a.titel, name0: "", beschreibung0: "") { name, beschreibung in
                    _ = modell.lage.instanzErstellen(name: name, beschreibung: beschreibung, paket: a.paket)
                }
            }
            .sheet(item: $umbenennen) { a in
                NamenEditor(titel: a.titel, name0: a.name, beschreibung0: a.beschreibung) { name, beschreibung in
                    _ = modell.lage.instanzBearbeiten(id: a.id, name: name, beschreibung: beschreibung)
                }
            }
            .confirmationDialog("„\(loeschen?.data.name ?? "")“ löschen?", isPresented: Binding(get: { loeschen != nil }, set: { if !$0 { loeschen = nil } }), titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    if let l = loeschen { _ = modell.lage.instanzLoeschen(id: l.id) }
                    loeschen = nil
                }
            } message: {
                Text("Alle Inhalte darin werden für alle entfernt.")
            }
        }
    }

    @ViewBuilder
    private func instanzMenue(_ stand: LageStand, _ i: Versioniert<Instanz>) -> some View {
        if Verwaltung.shared.darfBearbeiten(stand: stand, i: i) {
            Button("Umbenennen", systemImage: "pencil") {
                umbenennen = NamenAuswahl(id: i.id, titel: "Umbenennen", paket: i.data.istPaket, name: i.data.name, beschreibung: i.data.beschreibung)
            }
            Button("Löschen", systemImage: "trash", role: .destructive) { loeschen = i }
        }
        if !i.data.istPaket, Verwaltung.shared.darfVerlassen(i: i) {
            Button("Verlassen", systemImage: "rectangle.portrait.and.arrow.right") { _ = modell.lage.instanzVerlassen(id: i.id) }
        }
    }
}

private struct NamenEditor: View {
    @Environment(\.dismiss) private var schliessen
    let titel: String
    let name0: String
    let beschreibung0: String
    let sichern: (String, String) -> Void
    @State private var name = ""
    @State private var beschreibung = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Beschreibung (optional)", text: $beschreibung, axis: .vertical)
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        sichern(name.trimmingCharacters(in: .whitespaces), beschreibung.trimmingCharacters(in: .whitespaces))
                        schliessen()
                    }
                    .disabled(Verwaltung.shared.nameFehlt(name: name) != nil)
                }
            }
            .onAppear { name = name0; beschreibung = beschreibung0 }
        }
        .presentationDetents([.medium])
    }
}
