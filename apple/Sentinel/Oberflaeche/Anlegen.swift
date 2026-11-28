import SentinelKern
import SwiftUI

extension Color {
    /// Farbe aus „#RRGGBB“.
    init(hex: String) {
        let wert = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x0A84FF
        self.init(red: Double((wert >> 16) & 0xFF) / 255, green: Double((wert >> 8) & 0xFF) / 255, blue: Double(wert & 0xFF) / 255)
    }

    static let setzen = Color(hex: "#FFD60A")
    static let ziele = Color(hex: Farben.shared.ZIELE)
}

/// Plus-Menü: Ziele und Markierungen anlegen, gleiche Reihenfolge und Begriffe wie auf Android (aus dem Kern).
struct PlusMenue: View {
    let waehlen: (Anlegbar) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    abschnitt("Ziel", AnlegbarCompanion.shared.ziele)
                    abschnitt("Markierung", AnlegbarCompanion.shared.markierungen)
                }
                .padding(20)
            }
            .navigationTitle("Hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func abschnitt(_ titel: String, _ eintraege: [Anlegbar]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titel).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                ForEach(eintraege.indices, id: \.self) { i in
                    let e = eintraege[i]
                    Button { waehlen(e) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: e.symbol.sf)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(farbe(e))
                                .frame(width: 52, height: 52)
                                .background(farbe(e).opacity(0.18), in: .circle)
                            Text(e.titel).font(.caption).multilineTextAlignment(.center).lineLimit(2).foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Anlegen \(e.titel)")
                }
            }
        }
    }

    private func farbe(_ e: Anlegbar) -> Color {
        if let f = e as? AnlegbarNeueForm { return Color(hex: Formen.shared.farbe(f: f.form)) }
        return .ziele
    }
}

/// Gelbe Leiste oben im Platzierungsmodus: Hinweis, Zurücknehmen, Abbrechen, Fertig.
struct Platzierungsleiste: View {
    let p: Platzierung
    let zuruecknehmen: () -> Void
    let abbrechen: () -> Void
    let fertig: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: abbrechen) {
                Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 40, height: 40)
            }
            .accessibilityLabel("Abbrechen")
            Text(p.hinweis).font(.subheadline.weight(.semibold)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            if p.mehrpunkt {
                Button(action: zuruecknehmen) {
                    Image(systemName: "arrow.uturn.backward").font(.body.weight(.semibold)).frame(width: 40, height: 40)
                }
                .disabled(!p.kannZuruecknehmen)
                .accessibilityLabel("Letzten Punkt entfernen")
            }
            Button(p.mehrpunkt ? "Fertig" : "Bestätigen", action: fertig)
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .foregroundStyle(Color.setzen)
                .background(.black, in: .capsule)
                .disabled(!p.kannBestaetigen)
                .opacity(p.kannBestaetigen ? 1 : 0.4)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 8)
        .frame(minHeight: 52)
        .glassEffect(.regular.tint(.setzen), in: .capsule)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("Platzierungsleiste")
    }
}

/// Offener Markierungseditor: Kennung, Ausgangsstand, neu angelegt oder bestehend.
struct Markierungsbearbeitung: Identifiable {
    let id: String
    let markierung: Markierung
    let neu: Bool
}

/// Editor einer Markierung (neu oder bestehend). Felder je nach Form, Prüfen und Bereinigen im Kern.
struct MarkierungsEditor: View {
    @Environment(AppModell.self) private var modell
    @Environment(\.dismiss) private var schliessen
    let bearbeitung: Markierungsbearbeitung
    let verschieben: (String) -> Void

    @State private var titel = ""
    @State private var notiz = ""
    @State private var farbe = ""
    @State private var symbol = ""
    @State private var radius: Double = 150
    @State private var ebene = ""
    @State private var ausloeser: Ausloeser = .verlassen
    @State private var ziele: Set<String> = []
    @State private var lebensdauer: Int = 0

    /// −1 = Ablauf unverändert lassen (nur bei bestehenden Markierungen).
    private static let unveraendert = -1

    private var aktuell: Markierung {
        let m = bearbeitung.markierung
        return Markierungseditor.shared.aendern(
            m: m, titel: titel, notiz: notiz, farbe: farbe, symbol: symbol,
            radius: Markierungseditor.shared.zeigtRadius(m: m) ? KotlinDouble(value: radius) : m.radius,
            layerId: ebene, ausloeser: m.typ == .geofence ? ausloeser : m.ausloeser, ziele: Array(ziele).sorted()
        )
    }

    var body: some View {
        let m = aktuell
        let stand = modell.stand
        let fehlt = Markierungseditor.shared.fehlt(m: m)
        NavigationStack {
            Form {
                Section {
                    TextField(m.typ == .text ? "Text" : "Bezeichnung", text: $titel)
                    TextField("Notiz", text: $notiz, axis: .vertical).lineLimit(2...6)
                } footer: {
                    if let fehlt { Text(fehlt) }
                }

                if Markierungseditor.shared.zeigtFarbe(m: m) {
                    Section("Farbe") {
                        HStack(spacing: 0) {
                            ForEach(Farben.shared.palette.indices, id: \.self) { i in
                                let eintrag = Farben.shared.palette[i]
                                let hex = (eintrag.second as String?) ?? "#FF9F0A"
                                let gewaehlt = farbe.uppercased() == hex.uppercased()
                                Button { farbe = hex } label: {
                                    Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                                        .overlay { if gewaehlt { Circle().stroke(.primary, lineWidth: 3).padding(-4) } }
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel((eintrag.first as String?) ?? hex)
                                .accessibilityAddTraits(gewaehlt ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if Markierungseditor.shared.zeigtSymbol(m: m) {
                    Section("Symbol") {
                        let gewaehltes = Symbol.companion.vonGespeichert(wert: symbol, ersatz: .nadel)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                            ForEach(Symbol.companion.marker, id: \.self) { s in
                                Button { symbol = s.schluessel } label: {
                                    Image(systemName: s.sf)
                                        .font(.system(size: 16, weight: .semibold))
                                        .frame(width: 34, height: 34)
                                        .background(s == gewaehltes ? Color(hex: farbe).opacity(0.35) : Color.secondary.opacity(0.12), in: .circle)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(s == gewaehltes ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if Markierungseditor.shared.zeigtRadius(m: m) {
                    Section(m.typ == .haltestellen ? "Umkreis" : "Radius") {
                        HStack(spacing: 12) {
                            Slider(value: $radius, in: Markierungseditor.shared.radiusMin(m: m)...Markierungseditor.shared.reglerMax(m: m), step: 10)
                            Text(Format.shared.entfernung(meter: radius)).monospacedDigit().frame(width: 72, alignment: .trailing)
                        }
                    }
                }

                if Markierungseditor.shared.zeigtZiele(m: m) {
                    Section("Alarm beim") {
                        Picker("Alarm beim", selection: $ausloeser) {
                            Text("Verlassen").tag(Ausloeser.verlassen)
                            Text("Betreten").tag(Ausloeser.betreten)
                        }
                        .pickerStyle(.segmented)
                    }
                    Section("Überwachte Ziele") {
                        ForEach(stand.zieleSortiert, id: \.id) { z in
                            Button {
                                if ziele.contains(z.id) { ziele.remove(z.id) } else { ziele.insert(z.id) }
                            } label: {
                                HStack {
                                    Text(z.data.anzeigename).foregroundStyle(.primary)
                                    Spacer()
                                    if ziele.contains(z.id) { Image(systemName: "checkmark").foregroundStyle(.tint) }
                                }
                            }
                        }
                    }
                }

                let ebenen = stand.ebenenSortiert.filter { $0.data.art == Ebene.companion.LAGE || $0.data.art == Ebene.companion.DAUERHAFT }
                if ebenen.count > 1 {
                    Section {
                        Picker("Ebene", selection: $ebene) {
                            ForEach(ebenen, id: \.id) { e in Text(e.data.name).tag(e.id) }
                        }
                    }
                }

                if Markierungseditor.shared.zeigtLebensdauer(m: m) {
                    Section {
                        Picker("Lebensdauer", systemImage: "timer", selection: $lebensdauer) {
                            if !bearbeitung.neu {
                                Text(bearbeitung.markierung.ablauf.map { "Bis \(Date(timeIntervalSince1970: Double($0.int64Value) / 1000).formatted(date: .abbreviated, time: .shortened))" } ?? "Unverändert")
                                    .tag(Self.unveraendert)
                            }
                            ForEach(Markierungseditor.shared.lebensdauern, id: \.sekunden) { l in
                                Text(l.titel).tag(Int(l.sekunden))
                            }
                        }
                    } footer: {
                        Text(lebensdauer == 0 || (lebensdauer == Self.unveraendert && bearbeitung.markierung.ablauf == nil)
                             ? "Bleibt, bis sie jemand löscht." : "Löscht sich danach von selbst, damit die Karte übersichtlich bleibt.")
                    }
                }

                if !bearbeitung.neu {
                    Section {
                        if !m.typ.istOepnv {
                            Button("Auf der Karte verschieben", systemImage: "arrow.up.and.down.and.arrow.left.and.right") {
                                schliessen()
                                verschieben(bearbeitung.id)
                            }
                        }
                        Button("Löschen", systemImage: "trash", role: .destructive) {
                            _ = modell.lage.loeschen(art: .markierung, id: bearbeitung.id)
                            schliessen()
                        }
                    } footer: {
                        if let v = stand.markierungen[bearbeitung.id] { Text("Zuletzt geändert von \(stand.name(akteurId: v.updatedBy))") }
                    }
                }
            }
            .navigationTitle(bearbeitung.neu ? "Neu: \(Formen.shared.titel(f: m.typ))" : Formen.shared.titel(f: m.typ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        let dauer: KotlinInt? = lebensdauer == Self.unveraendert ? nil : KotlinInt(int: Int32(lebensdauer))
                        let fertig = Markierungseditor.shared.sichern(m: m, lebensdauerSekunden: dauer, jetztMs: Int64(Date.now.timeIntervalSince1970 * 1000))
                        _ = modell.lage.markierungSichern(m: fertig, id: bearbeitung.id)
                        schliessen()
                    }
                    .disabled(fehlt != nil)
                    .accessibilityIdentifier("Sichern")
                }
            }
        }
        .onAppear {
            let m = bearbeitung.markierung
            titel = m.titel
            notiz = m.notiz
            farbe = m.farbe
            symbol = m.symbol
            radius = Markierungseditor.shared.radius(m: m)
            ebene = m.layerId
            ausloeser = m.ausloeser ?? .verlassen
            ziele = Set(m.ziele)
            lebensdauer = bearbeitung.neu ? 0 : Self.unveraendert
        }
    }
}

/// Neues Ziel nach dem Platzieren: die Felder, die es auf der Karte benennen.
struct NeuesZielAuswahl: Identifiable {
    let id = UUID()
    let ziel: Ziel
}

struct ZielAnlegen: View {
    @Environment(AppModell.self) private var modell
    @Environment(\.dismiss) private var schliessen
    let ziel: Ziel
    @State private var vorname = ""
    @State private var nachname = ""
    @State private var bezeichnung = ""
    @State private var kennzeichen = ""
    @State private var anschrift = ""
    @State private var hinweise = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    switch ziel.art {
                    case .person:
                        TextField("Vorname", text: $vorname)
                        TextField("Nachname", text: $nachname)
                        TextField("Bezeichnung (falls Name unbekannt)", text: $bezeichnung)
                    case .fahrzeug:
                        TextField("Kennzeichen", text: $kennzeichen).textInputAutocapitalization(.characters)
                        TextField("Fahrzeug (Marke, Modell, Farbe)", text: $bezeichnung)
                    default:
                        TextField("Bezeichnung", text: $bezeichnung)
                        TextField("Anschrift", text: $anschrift)
                    }
                }
                Section("Hinweise") {
                    TextField("Hinweise", text: $hinweise, axis: .vertical).lineLimit(3...10)
                }
            }
            .navigationTitle("Neu: \(AnlegbarNeuesZiel(art: ziel.art).titel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        let fertig = Zielerfassung.shared.fertig(z: ziel, vorname: vorname, nachname: nachname, bezeichnung: bezeichnung,
                                                                 kennzeichen: kennzeichen, anschrift: anschrift, hinweise: hinweise)
                        _ = modell.lage.setzen(art: .ziel, id: Lage.companion.neueId(), daten: fertig)
                        schliessen()
                    }
                    .accessibilityIdentifier("Sichern")
                }
            }
        }
    }
}
