import SentinelKern
import SwiftUI

/// Was die Suche zurückgibt: ein Ort (Anschrift, Kreuzung, Einrichtung) oder ein Objekt der Lage.
enum Suchergebnis {
    case ort(Suchtreffer)
    case objekt(KartenObjekt, GeoPunkt?)
}

/// Suche wie in einer Navi-App: Objekte der Lage (A-Position zuerst, Kräfte, Ziele, Markierungen) und Orte aus der
/// eigenen Ortssuche (Anschriften, Kreuzungen, Orte, Einrichtungen). Gleicher Aufbau wie auf Android.
struct Suche: View {
    @Environment(AppModell.self) private var modell
    @Environment(\.dismiss) private var schliessen
    let waehlen: (Suchergebnis) -> Void
    @State private var text = ""
    @State private var orte: [Suchtreffer] = []
    @State private var fehler: String?
    @FocusState private var fokus: Bool

    private struct Objekttreffer: Identifiable {
        let objekt: KartenObjekt
        let punkt: GeoPunkt?
        let titel: String
        let art: String
        var id: String { objekt.schluessel }
    }

    var body: some View {
        NavigationStack {
            List {
                let objekte = objektTreffer()
                if !objekte.isEmpty {
                    Section("In der Lage") {
                        ForEach(objekte) { t in
                            Button {
                                waehlen(.objekt(t.objekt, t.punkt))
                                schliessen()
                            } label: {
                                Label { VStack(alignment: .leading) { Text(t.titel).foregroundStyle(.primary); Text(t.art).font(.caption).foregroundStyle(.secondary) } }
                                    icon: { Image(systemName: "mappin.circle.fill") }
                            }
                        }
                    }
                }
                Section {
                    ForEach(orte, id: \.id) { t in
                        Button {
                            waehlen(.ort(t))
                            schliessen()
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(t.titel).foregroundStyle(.primary)
                                    if !t.untertitel.isEmpty { Text(t.untertitel).font(.caption).foregroundStyle(.secondary) }
                                }
                            } icon: { Image(systemName: symbol(t.art)) }
                        }
                    }
                } footer: {
                    if let fehler { Text(fehler).foregroundStyle(.red) }
                }
            }
            .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Adresse, Kreuzung, Ort oder Objekt")
            .searchFocused($fokus)
            .navigationTitle("Suchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { schliessen() } }
            }
            .onAppear { fokus = true }
            .task(id: text) {
                orte = []
                fehler = nil
                guard text.trimmingCharacters(in: .whitespaces).count >= 2, let api = modell.api else { return }
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                let nahe = modell.standort.aktuell.map { GeoPunkt(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) }
                do { orte = try await api.suche(text: text, nahe: nahe) } catch { fehler = error.localizedDescription }
            }
        }
    }

    private func symbol(_ art: String) -> String {
        switch art {
        case "kreuzung": "arrow.triangle.merge"
        case "adresse": "house.fill"
        case "ort": "building.2.crop.circle"
        case "poi": "building.2.fill"
        default: "mappin.circle"
        }
    }

    /// Objekte der Lage, die zur Eingabe passen; die A-Position steht immer oben.
    private func objektTreffer() -> [Objekttreffer] {
        let stand = modell.stand
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        let jetzt = Int64(Date.now.timeIntervalSince1970 * 1000)
        var ergebnis: [Objekttreffer] = []
        if let a = stand.aHalter, t.isEmpty || "a-position".contains(t) || a.data.spitzname.lowercased().contains(t) {
            ergebnis.append(Objekttreffer(objekt: KartenObjekt(art: .kraft, id: a.id), punkt: stand.positionen[a.id]?.punkt, titel: "A-Position (\(a.data.spitzname))", art: "Fahnder"))
        }
        guard !t.isEmpty else { return ergebnis }
        for f in stand.aktiveKraefte where f.id != stand.einsatz.a?.memberId && f.data.spitzname.lowercased().contains(t) {
            ergebnis.append(Objekttreffer(objekt: KartenObjekt(art: .kraft, id: f.id), punkt: stand.positionen[f.id]?.punkt, titel: f.data.spitzname, art: "Fahnder"))
        }
        for z in stand.zieleSortiert where z.data.anzeigename.lowercased().contains(t) || z.data.kennzeichen.lowercased().contains(t) {
            ergebnis.append(Objekttreffer(objekt: KartenObjekt(art: .ziel, id: z.id), punkt: stand.ortung(ziel: z, jetztMs: jetzt, tiefe: 0)?.punkt, titel: z.data.anzeigename, art: "Ziel"))
        }
        for m in stand.sichtbareMarkierungen(jetztMs: jetzt, ausgeblendeteEbenen: []) where !m.data.titel.isEmpty && m.data.titel.lowercased().contains(t) {
            ergebnis.append(Objekttreffer(objekt: KartenObjekt(art: .markierung, id: m.id), punkt: m.data.anker, titel: m.data.titel, art: "Markierung"))
        }
        return Array(ergebnis.prefix(8))
    }
}
