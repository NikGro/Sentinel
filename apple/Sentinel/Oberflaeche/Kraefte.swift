import SentinelKern
import SwiftUI

/// Kräfte-Tab: Kräfte, eigenes Fahrzeug, Fahrzeuge der Lage (gleich aufgebaut wie auf Android).
struct Kraefteliste: View {
    @Environment(AppModell.self) private var modell
    let aufKarte: (KartenObjekt) -> Void

    var body: some View {
        let stand = modell.stand
        let jetzt = Int64(Date.now.timeIntervalSince1970 * 1000)
        NavigationStack {
            List {
                Section("Kräfte") {
                    ForEach(Kraefteansicht.shared.sortiert(stand: stand), id: \.id) { f in
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
                }

                // Eigenes Fahrzeug: Einsteigen setzt die Fortbewegung auf „Fahrzeug“.
                let waehlbar = Kraefteansicht.shared.waehlbareFahrzeuge(stand: stand)
                if let ich = stand.ich, !waehlbar.isEmpty {
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

                if !stand.fahrzeuge.isEmpty {
                    Section("Fahrzeuge") {
                        ForEach(stand.fahrzeugeSortiert, id: \.id) { v in
                            HStack {
                                Button {
                                    if stand.ortung(fahrzeug: v) != nil { aufKarte(KartenObjekt(art: .fahrzeug, id: v.id)) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(v.data.funkrufname).foregroundStyle(.primary)
                                        Text([v.data.kennzeichen, Kraefteansicht.shared.fahrzeugStatus(stand: stand, v: v)].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Toggle("Im Einsatz", isOn: Binding(get: { stand.imEinsatz(fahrzeug: v) }, set: { _ = modell.lage.fahrzeugImEinsatz(fahrzeugId: v.id, aktiv: $0) }))
                                    .labelsHidden()
                            }
                        }
                    }
                }
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
