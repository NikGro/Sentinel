import SentinelKern
import SwiftUI

private func uhrzeit(_ ms: Int64) -> String {
    Date(timeIntervalSince1970: Double(ms) / 1000).formatted(date: .omitted, time: .shortened)
}

/// Liniennummer im Schild (Farbe nach Art bzw. Linie, wie auf der Karte).
struct Linienschild: View {
    let name: String
    let mode: String
    var eigene: String?

    var body: some View {
        let hex = Linienart.shared.farbe(typ: Linienart.shared.typ(mode: mode), ref: name, eigene: eigene)
        Text(name)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(hex == "#FFDD00" ? .black : .white)
            .background(Color(hex: hex), in: .rect(cornerRadius: 6))
    }
}

/// Fahrtverlauf eines ÖPNV-Fahrzeugs und Übernehmen in die Lage (gleich aufgebaut wie auf Android).
struct FahrtAnsicht: View {
    @Environment(AppModell.self) private var modell
    @Environment(\.dismiss) private var schliessen
    let tripId: String
    @State private var fahrt: Fahrt?
    @State private var laedt = true
    @State private var strecke = true
    @State private var halte = true

    var body: some View {
        NavigationStack {
            Group {
                if laedt {
                    ProgressView()
                } else if let f = fahrt {
                    List {
                        Section {
                            HStack(spacing: 10) {
                                Linienschild(name: f.name, mode: f.mode, eigene: f.color)
                                Text(f.headsign.isEmpty ? Linienart.shared.titel(typ: Linienart.shared.typ(mode: f.mode), ref: f.name) : f.headsign).font(.headline)
                            }
                            Text(f.realTime ? "Mit Echtzeit" : "Nach Fahrplan").foregroundStyle(.secondary)
                            Toggle("Strecke", isOn: $strecke)
                            Toggle("Halte", isOn: $halte)
                            Button(!strecke && !halte ? "Fahrzeug übernehmen" : "In die Lage übernehmen") {
                                if let m = OepnvLive.companion.alsStrecke(f: f, fahrzeug: true, strecke: strecke, halte: halte, jetztMs: Int64(Date.now.timeIntervalSince1970 * 1000)) {
                                    _ = modell.lage.markierungSichern(m: m, id: Lage.companion.neueId())
                                }
                                schliessen()
                            }
                            .buttonStyle(.glassProminent)
                        }
                        Section("Halte") {
                            let jetzt = Int64(Date.now.timeIntervalSince1970 * 1000)
                            ForEach(f.stops.indices, id: \.self) { i in
                                let h = f.stops[i]
                                let zeit = h.dep?.int64Value ?? h.arr?.int64Value
                                let vorbei = zeit.map { $0 < jetzt } ?? false
                                HStack(spacing: 12) {
                                    Text(zeit.map(uhrzeit) ?? "–").monospacedDigit().frame(width: 52, alignment: .leading)
                                    Text(h.name)
                                }
                                .foregroundStyle(vorbei ? .secondary : .primary)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Fahrt nicht verfügbar", systemImage: "tram", description: Text("Die Fahrt konnte nicht geladen werden."))
                }
            }
            .navigationTitle("Fahrt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { schliessen() } } }
        }
        .task(id: tripId) {
            if let api = modell.api { fahrt = try? await OepnvLive.companion.fahrt(api: api, tripId: tripId) }
            laedt = false
        }
    }
}

/// Abfahrten einer Haltestelle; Antippen zeigt den Fahrtverlauf. Die Haltestelle selbst lässt sich übernehmen.
struct AbfahrtenAnsicht: View {
    @Environment(AppModell.self) private var modell
    @Environment(\.dismiss) private var schliessen
    let halt: LiveHalt
    let fahrtWaehlen: (String) -> Void
    @State private var abfahrten: [Abfahrt]?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Haltestelle übernehmen", systemImage: "plus") {
                        _ = modell.lage.markierungSichern(m: OepnvLive.companion.alsHaltestelle(h: halt), id: Lage.companion.neueId())
                        schliessen()
                    }
                }
                Section("Abfahrten") {
                    if let liste = abfahrten {
                        if liste.isEmpty { Text("Keine Abfahrten in nächster Zeit.").foregroundStyle(.secondary) }
                        ForEach(liste.indices, id: \.self) { i in
                            let a = liste[i]
                            let minuten = max(0, (a.time - Int64(Date.now.timeIntervalSince1970 * 1000)) / 60_000)
                            Button { fahrtWaehlen(a.tripId) } label: {
                                HStack(spacing: 10) {
                                    Linienschild(name: a.name, mode: a.mode, eigene: a.color)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(a.headsign).foregroundStyle(.primary)
                                        Text("\(uhrzeit(a.time)) · \(Linienart.shared.verspaetung(delaySekunden: KotlinInt(int: Int32((a.time - a.scheduled) / 1000)), echtzeit: a.realTime))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(minuten == 0 ? "jetzt" : "\(minuten) Min.").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                }
                            }
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
            .navigationTitle(halt.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { schliessen() } } }
        }
        .task(id: halt.stopId) {
            if let api = modell.api { abfahrten = (try? await OepnvLive.companion.abfahrten(api: api, stopId: halt.stopId)) ?? [] }
        }
    }
}
