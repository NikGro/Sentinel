import SentinelKern
import SwiftUI

/// Außer Dienst nur das Hauptmenü (Instanzen); im Dienst die Tabs Lage, Ziele, Kräfte und Mehr.
struct Hauptansicht: View {
    @Environment(AppModell.self) private var modell
    @State private var hauptmenue = false
    @State private var tab = "lage"
    /// Objekt, das die Karte beim Wechsel zum Lage-Tab zeigen soll (z. B. aus der Zielansicht).
    @State private var fokus: KartenObjektAuswahl?

    var body: some View {
        if !modell.stand.imDienst || hauptmenue {
            Hauptmenue { hauptmenue = false }
        } else {
            TabView(selection: $tab) {
                Tab("Lage", systemImage: "map", value: "lage") { Lagebildschirm(fokus: $fokus) }
                Tab("Ziele", systemImage: "person.crop.rectangle.stack", value: "ziele") {
                    Zielliste { objekt in
                        fokus = KartenObjektAuswahl(objekt: objekt)
                        tab = "lage"
                    }
                }
                Tab("Kräfte", systemImage: "person.3", value: "kraefte") {
                    Kraefteliste { objekt in
                        fokus = KartenObjektAuswahl(objekt: objekt)
                        tab = "lage"
                    }
                }
                Tab("Mehr", systemImage: "ellipsis", value: "mehr") { Mehr { hauptmenue = true } }
            }
        }
    }
}

/// Lagekarte mit Suchleiste oben, Knöpfen rechts (SOS, Kompass, Verkehr, Hinzufügen) und unten A-Position,
/// Fortbewegung und Lageleiste. Antippen öffnet die Kurzübersicht.
struct Lagebildschirm: View {
    @Environment(AppModell.self) private var modell
    @Binding var fokus: KartenObjektAuswahl?
    @State private var zielansicht: ZielansichtAuswahl?
    // ÖPNV live
    // Zuschaltbare Ebenen (Verkehr, ÖPNV live, Bestreifung, Weg-Zeit)
    @State private var ebenen = Kartenebenen(verkehr: false, oepnvLive: false, wegZeitFuss: true, wegZeitKfz: true, wegZeitOepnv: false, bestreifung: false)
    @State private var ebenenWahl = false
    @State private var flaechen = Lageflaechen()
    @State private var flaechenStand = 0
    private var liveAn: Bool { ebenen.oepnvLive }
    @State private var live = OepnvLive()
    @State private var liveStand = 0
    @State private var liveAnstoss = 0
    @State private var fahrtAnsicht: ZielansichtAuswahl?
    @State private var abfahrtenHalt: LiveHaltAuswahl?
    // Verlauf und Spur-Markierungen
    @State private var verlauf: Verlauf?
    @State private var verlaufStand = 0
    @State private var verlaufAnteil = 1.0
    @State private var spurenStand = 0

    private func verlaufLaden(_ v: Verlauf, _ z: Zeitraum) {
        guard let api = modell.api else { return }
        Task {
            try? await v.laden(api: api, z: z)
            verlaufAnteil = 1
            verlaufStand += 1
            if let r = v.rahmen() { steuerung.einpassen(r) }
        }
    }
    @State private var steuerung = KartenSteuerung()
    @State private var auswahl: KartenObjektAuswahl?
    @State private var sucht = false
    @State private var ortTreffer: OrtAuswahl?
    // Anlegen: Plus-Menü (optional an einem Ort), Platzierungsmodus, danach Editor
    @State private var plus = false
    @State private var plusOrt: GeoPunkt?
    @State private var platzierung: Platzierung?
    @State private var editor: Markierungsbearbeitung?
    @State private var neuesZiel: NeuesZielAuswahl?
    @State private var sonderrechte = false

    private func hinfuehren(_ ziel: Naviziel) {
        let m = modell
        m.navigator.starten(ziel, sonderrechte: sonderrechte, zuFuss: m.stand.ich?.data.fortbewegung == .fuss) { [weak m] in m?.stand ?? LageStand.companion.leer }
        steuerung.navigation(ort: modell.standort.aktuell)
    }

    private func naviBeenden() {
        modell.navigator.stoppen()
        steuerung.navigation(ort: nil)
    }

    private var jetztMs: Int64 { Int64(Date.now.timeIntervalSince1970 * 1000) }

    /// Nächstes Blatt erst zeigen, wenn das vorige ganz geschlossen ist (sonst verwirft SwiftUI die Darstellung).
    private func nachSchliessen(_ aktion: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            aktion()
        }
    }

    private func ergebnis(_ e: PlatzierungErgebnis?) {
        switch e {
        case let e as PlatzierungErgebnisNeueMarkierung:
            editor = Markierungsbearbeitung(id: Lage.companion.neueId(), markierung: e.markierung, neu: true)
        case let e as PlatzierungErgebnisNeuesZiel:
            neuesZiel = NeuesZielAuswahl(ziel: e.ziel)
        case let e as PlatzierungErgebnisVerschoben:
            _ = modell.lage.markierungSichern(m: e.markierung, id: e.id)
        case let e as PlatzierungErgebnisZielVersetzt:
            _ = modell.lage.setzen(art: .ziel, id: e.id, daten: e.ziel)
        default:
            break
        }
    }

    private func anlegen(_ was: Anlegbar) {
        plus = false
        if was is AnlegbarStandortspur {
            if let o = modell.standort.aktuell,
               let m = Verlauf.companion.standortspur(stand: modell.stand, ort: GeoPunkt(lat: o.coordinate.latitude, lon: o.coordinate.longitude), jetztMs: jetztMs) {
                _ = modell.lage.markierungSichern(m: m, id: Lage.companion.neueId())
            }
            plusOrt = nil
            return
        }
        let ort = plusOrt
        plusOrt = nil
        steuerung.markieren(nil)
        let p = Platzierung.companion.anlegen(was: was, start: ort)
        // Einzelner Ort schon bekannt (Suchtreffer): direkt weiter, sonst Platzierungsmodus.
        if ort != nil && !p.mehrpunkt {
            let e = p.bestaetigen(jetztMs: jetztMs, ebene: Ebene.companion.LAGE, markierung: nil, ziel: nil)
            nachSchliessen { ergebnis(e) }
        } else {
            platzierung = p
        }
    }

    private func platzierungFertig(_ p: Platzierung) {
        platzierung = nil
        let stand = modell.stand
        let m = (p.zweck as? PlatzierungZweckVerschieben).flatMap { stand.markierungen[$0.markierungId]?.data }
        let z = (p.zweck as? PlatzierungZweckZielOrt).flatMap { stand.ziele[$0.zielId]?.data }
        ergebnis(p.bestaetigen(jetztMs: jetztMs, ebene: Ebene.companion.LAGE, markierung: m, ziel: z))
    }

    var body: some View {
        LageKarte(modell: modell, steuerung: steuerung, platzierung: platzierung, beiTipp: { punkt in platzierung = platzierung?.tippen(p: punkt) },
                  live: liveAn ? live : nil, liveStand: liveStand, beiKameraRuhe: { if liveAn { liveAnstoss += 1 } },
                  spurenJson: { let _ = (spurenStand, verlaufStand); return modell.spuren.geoJson(stand: modell.stand, verlauf: verlauf) }(),
                  wegZeitJson: { let _ = flaechenStand; return flaechen.wegZeitGeoJson() }(),
                  bestreifungJson: { let _ = flaechenStand; return flaechen.bestreifungGeoJson(jetztMs: jetztMs) }()) {
            auswahl = KartenObjektAuswahl(objekt: $0)
        }
            .ignoresSafeArea()
            .safeAreaInset(edge: .top) {
                if let n = modell.navigator.stand, platzierung == nil {
                    NaviLeisteOben(n: n)
                } else if let p = platzierung {
                    Platzierungsleiste(p: p, zuruecknehmen: { platzierung = p.zuruecknehmen() }, abbrechen: { platzierung = nil }) { platzierungFertig(p) }
                } else {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                    Text("Suchen oder navigieren").foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .frame(height: 44)
                .glassEffect(.regular.interactive(), in: .capsule)
                .padding(.horizontal, 22)
                .onTapGesture { sucht = true }
                }
            }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    SosKnopf()
                    GlassEffectContainer(spacing: 8) {
                        VStack(spacing: 8) {
                            // Standort und Kompass in einem Knopf: heftet an (Fahrtrichtung), erneut Norden oben.
                            Kartenknopf(symbol: steuerung.anheftung == .frei ? "location" : (steuerung.anheftung == .norden ? "location.north.fill" : "location.fill"),
                                        titel: "Standort und Kompass", aktiv: steuerung.anheftung != .frei) {
                                steuerung.anheftenUmschalten(ort: modell.standort.aktuell)
                            }
                            Kartenknopf(symbol: "square.3.layers.3d", titel: "Ebenen", aktiv: ebenen.verkehr || ebenen.oepnvLive || ebenen.bestreifung) { ebenenWahl = true }
                            Kartenknopf(symbol: "plus", titel: "Hinzufügen", hervorgehoben: true) {
                                plusOrt = nil
                                plus = true
                            }
                        }
                    }
                }
                .padding(.trailing, 22)
                .padding(.top, 60)
            }
            .safeAreaInset(edge: .bottom) {
                Group {
                    if let v = verlauf {
                        VerlaufLeiste(v: v, stand: verlaufStand, anteil: Binding(get: { verlaufAnteil }, set: { a in
                            verlaufAnteil = a
                            if let t = v.zeitBei(anteil: a) { steuerung.markieren(v.ort(zeitMs: t.int64Value)) }
                        }), zeitraumWaehlen: { verlaufLaden(v, $0) }, behalten: {
                            if let m = v.alsMarkierung() { _ = modell.lage.markierungSichern(m: m, id: Lage.companion.neueId()) }
                            verlauf = nil
                            steuerung.markieren(nil)
                        }, schliessen: {
                            verlauf = nil
                            verlaufStand += 1
                            steuerung.markieren(nil)
                        })
                    } else if let n = modell.navigator.stand {
                        NaviLeisteUnten(n: n, sonderrechte: Binding(get: { sonderrechte }, set: { neu in
                            sonderrechte = neu
                            hinfuehren(n.ziel)
                        }), modusWaehlen: { hinfuehren($0) }, beenden: naviBeenden)
                    } else {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                AKnopf()
                                Fortbewegungswahl()
                            }
                            Lageleiste()
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 4)
            }
            .sheet(isPresented: $sucht) {
                Suche { ergebnis in
                    switch ergebnis {
                    case .objekt(let objekt, let punkt):
                        if let punkt { steuerung.zeigen(punkt) }
                        auswahl = KartenObjektAuswahl(objekt: objekt)
                    case .ort(let treffer):
                        steuerung.zeigen(treffer.punkt, zoom: 17)
                        steuerung.markieren(treffer.punkt)
                        ortTreffer = OrtAuswahl(treffer: treffer)
                    }
                }
            }
            .sheet(item: $ortTreffer, onDismiss: { if plusOrt == nil { steuerung.markieren(nil) } }) { o in
                VStack(alignment: .leading, spacing: 12) {
                    Text(o.treffer.titel).font(.title3.weight(.semibold))
                    if !o.treffer.untertitel.isEmpty { Text(o.treffer.untertitel).foregroundStyle(.secondary) }
                    StrassenbildVorschau(ort: o.treffer.punkt)
                    HStack(spacing: 12) {
                        Button {
                            ortTreffer = nil
                            hinfuehren(NavizielOrt(punkt: o.treffer.punkt, titel: o.treffer.titel))
                        } label: { Label("Hinführen", systemImage: "arrow.triangle.turn.up.right.diamond.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(.glassProminent)
                        Button {
                            plusOrt = o.treffer.punkt
                            ortTreffer = nil
                            nachSchliessen { plus = true }
                        } label: { Label("Hier anlegen", systemImage: "plus").frame(maxWidth: .infinity) }
                            .buttonStyle(.glass)
                    }
                    .controlSize(.large)
                    Spacer()
                }
                .padding(20)
                .presentationDetents([.fraction(0.28), .medium])
                .presentationBackgroundInteraction(.enabled)
            }
            .sheet(item: $auswahl) { a in
                Kurzuebersicht(objekt: a.objekt, live: live) { k, info in
                    auswahl = nil
                    // Vergleich über den Kotlin-Namen (Swift-Schreibweise mehrteiliger Namen ist nicht festgelegt).
                    switch k.name {
                    case "Hinfuehren":
                        if ["live", "livehalt"].contains(a.objekt.art.schluessel) {
                            if let p = info.ort { hinfuehren(NavizielOrt(punkt: p, titel: info.titel)) }
                        } else {
                            let istA = a.objekt.art == .kraft && modell.stand.einsatz.a?.memberId == a.objekt.id
                            hinfuehren(istA ? NavizielAPosition.shared : NavizielObjekt(objekt: a.objekt))
                        }
                    case "Bearbeiten":
                        if let v = modell.stand.markierungen[a.objekt.id] {
                            nachSchliessen { editor = Markierungsbearbeitung(id: a.objekt.id, markierung: v.data, neu: false) }
                        }
                    case "Verschieben":
                        platzierung = Platzierung(zweck: PlatzierungZweckVerschieben(markierungId: a.objekt.id), punkte: [])
                    case "StandortSetzen":
                        platzierung = Platzierung(zweck: PlatzierungZweckZielOrt(zielId: a.objekt.id), punkte: [])
                    case "Details":
                        let id = a.objekt.id
                        switch a.objekt.art.schluessel {
                        case "live": nachSchliessen { fahrtAnsicht = ZielansichtAuswahl(id: id) }
                        case "livehalt": if let h = live.halt(stopId: id) { nachSchliessen { abfahrtenHalt = LiveHaltAuswahl(halt: h) } }
                        default: nachSchliessen { zielansicht = ZielansichtAuswahl(id: id) }
                        }
                    case "Verlauf":
                        let v = Verlauf(objekt: a.objekt, titel: info.titel)
                        verlauf = v
                        verlaufLaden(v, Verlauf.companion.zeitraeume(jetztMs: jetztMs, mitternachtMs: mitternachtMs())[1])
                    case "Anrufen":
                        if let t = info.telefon, let url = URL(string: "tel:\(t.filter { !$0.isWhitespace })") { UIApplication.shared.open(url) }
                    default:
                        break
                    }
                }
                .presentationDetents([.fraction(0.3), .medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .sheet(isPresented: $plus, onDismiss: { if platzierung == nil && editor == nil && neuesZiel == nil { plusOrt = nil; steuerung.markieren(nil) } }) {
                PlusMenue { anlegen($0) }
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $editor) { b in
                MarkierungsEditor(bearbeitung: b) { id in
                    platzierung = Platzierung(zweck: PlatzierungZweckVerschieben(markierungId: id), punkte: [])
                }
            }
            .sheet(item: $neuesZiel) { n in
                ZielAnlegen(ziel: n.ziel)
            }
            .sheet(item: $fahrtAnsicht) { f in FahrtAnsicht(tripId: f.id) }
            .sheet(item: $abfahrtenHalt) { h in
                AbfahrtenAnsicht(halt: h.halt) { trip in
                    abfahrtenHalt = nil
                    nachSchliessen { fahrtAnsicht = ZielansichtAuswahl(id: trip) }
                }
            }
            .task {
                // Spur-Markierungen laufend nachladen
                while !Task.isCancelled {
                    if let api = modell.api, (try? await modell.spuren.aktualisieren(api: api, stand: modell.stand, jetztMs: Int64(Date.now.timeIntervalSince1970 * 1000)))?.boolValue == true {
                        spurenStand += 1
                    }
                    try? await Task.sleep(for: .seconds(10))
                }
            }
            .onChange(of: ebenen.verkehr) { _, an in steuerung.verkehr(an) }
            .task(id: ebenen) {
                while !Task.isCancelled {
                    if let api = modell.api, (try? await flaechen.aktualisieren(api: api, stand: modell.stand, ebenen: ebenen, jetztMs: Int64(Date.now.timeIntervalSince1970 * 1000)))?.boolValue == true {
                        flaechenStand += 1
                    }
                    try? await Task.sleep(for: .milliseconds(Int(Lageflaechen.companion.TAKT_MS)))
                }
            }
            .sheet(isPresented: $ebenenWahl) {
                NavigationStack {
                    Form {
                        Section {
                            ForEach(Kartenebenen.companion.schalter.indices, id: \.self) { i in
                                let eintrag = Kartenebenen.companion.schalter[i]
                                let schluessel = (eintrag.first as String?) ?? ""
                                Toggle((eintrag.second as String?) ?? "", isOn: Binding(get: { ebenen.an(schluessel: schluessel) }, set: { ebenen = ebenen.mit(schluessel: schluessel, an: $0) }))
                            }
                        } footer: {
                            Text("Weg-Zeit-Flächen zeigen, wie weit jemand seit einer Sichtung gekommen sein kann.")
                        }
                    }
                    .navigationTitle("Ebenen")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium])
            }
            .task(id: liveAn ? liveAnstoss : -1) {
                guard liveAn else {
                    live.leeren()
                    liveStand += 1
                    return
                }
                while !Task.isCancelled {
                    if let b = steuerung.ausschnitt(), let api = modell.api {
                        try? await live.laden(api: api, sued: b.sued, west: b.west, nord: b.nord, ost: b.ost, zoom: b.zoom)
                        liveStand += 1
                    }
                    try? await Task.sleep(for: .milliseconds(Int(OepnvLive.companion.AKTUALISIEREN_MS)))
                }
            }
            .sheet(item: $zielansicht) { auswahl in
                NavigationStack {
                    Zielansicht(id: auswahl.id, aufKarte: {
                        zielansicht = nil
                        let info = Kurzinfo.companion.fuer(stand: modell.stand, objekt: KartenObjekt(art: .ziel, id: auswahl.id), jetztMs: jetztMs, ich: nil)
                        if let p = info?.ort { steuerung.zeigen(p, zoom: 17) }
                    }, standortSetzen: {
                        zielansicht = nil
                        platzierung = Platzierung(zweck: PlatzierungZweckZielOrt(zielId: auswahl.id), punkte: [])
                    })
                }
            }
            .onChange(of: fokus?.id, initial: true) {
                guard let f = fokus else { return }
                let info = Kurzinfo.companion.fuer(stand: modell.stand, objekt: f.objekt, jetztMs: jetztMs, ich: nil)
                if let p = info?.ort { steuerung.zeigen(p, zoom: 17) }
                auswahl = f
                fokus = nil
            }
    }
}

struct ZielansichtAuswahl: Identifiable {
    let id: String
}

struct LiveHaltAuswahl: Identifiable {
    let halt: LiveHalt
    var id: String { halt.stopId }
}

struct OrtAuswahl: Identifiable {
    let treffer: Suchtreffer
    var id: String { treffer.id }
}

struct KartenObjektAuswahl: Identifiable {
    let objekt: KartenObjekt
    var id: String { objekt.schluessel }
}

private struct Kartenknopf: View {
    let symbol: String
    let titel: String
    var aktiv = false
    var hervorgehoben = false
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(hervorgehoben || aktiv ? .white : .primary)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(hervorgehoben || aktiv ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: .circle)
        .accessibilityLabel(titel)
    }
}

private struct AKnopf: View {
    @Environment(AppModell.self) private var modell

    var body: some View {
        let stand = modell.stand
        Button {
            if stand.haeltA { _ = modell.lage.aFreigeben() } else { _ = modell.lage.aUebernehmen() }
        } label: {
            Text(stand.haeltA ? "A abgeben" : (stand.aHalter.map { "A: \($0.data.spitzname)" } ?? "A übernehmen"))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(stand.haeltA ? .white : .primary)
        .glassEffect(stand.haeltA ? .regular.tint(.red).interactive() : .regular.interactive(), in: .capsule)
    }
}

private struct Fortbewegungswahl: View {
    @Environment(AppModell.self) private var modell

    var body: some View {
        let aktuell = modell.stand.ich?.data.fortbewegung ?? .fuss
        Picker("Fortbewegung", selection: Binding(get: { aktuell }, set: { _ = modell.lage.fortbewegungSetzen(art: $0, fahrzeugId: nil, oepnv: nil) })) {
            Image(systemName: "figure.walk").tag(Fortbewegung.fuss)
            Image(systemName: "car.fill").tag(Fortbewegung.fahrzeug)
            Image(systemName: "tram.fill").tag(Fortbewegung.oepnv)
        }
        .pickerStyle(.segmented)
        .frame(height: 44)
    }
}

private struct Lageleiste: View {
    @Environment(AppModell.self) private var modell

    var body: some View {
        let stand = modell.stand
        HStack(spacing: 12) {
            Text(stand.einsatz.funkkanal.map { "Kanal \($0)" } ?? "Kein Kanal").font(.subheadline.weight(.semibold))
            Text(stand.aktuelleInstanz?.data.name ?? "").foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            if let a = stand.aHalter { Text("A: \(a.data.spitzname)").foregroundStyle(.red).font(.subheadline.weight(.semibold)) }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .glassEffect(.regular, in: .capsule)
    }
}

/// Kurzübersicht eines angetippten Objekts: Inhalt aus dem Kern (gleich wie auf Android), Aktionen als Knöpfe.
struct Kurzuebersicht: View {
    @Environment(AppModell.self) private var modell
    let objekt: KartenObjekt
    var live: OepnvLive?
    var aktion: (Kurzaktion, Kurzinfo) -> Void = { _, _ in }

    /// Aktionen, die es in dieser Ausbaustufe schon gibt (Details folgen mit der Zielansicht).
    private static let umgesetzt: Set<String> = ["Hinfuehren", "Bearbeiten", "Verschieben", "StandortSetzen", "Anrufen", "Details", "Verlauf"]

    var body: some View {
        let ich = modell.standort.aktuell.map { GeoPunkt(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) }
        let jetzt = Int64(Date.now.timeIntervalSince1970 * 1000)
        if let info = live?.kurzinfo(objekt: objekt, jetztMs: jetzt) ?? Kurzinfo.companion.fuer(stand: modell.stand, objekt: objekt, jetztMs: jetzt, ich: ich) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: info.symbol.sf)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(hex: info.farbe).gradient, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.titel).font(.title3.weight(.semibold)).lineLimit(2)
                            if !info.untertitel.isEmpty { Text(info.untertitel).font(.subheadline).foregroundStyle(.secondary) }
                        }
                        Spacer()
                    }
                    let knoepfe = info.aktionen.filter { Self.umgesetzt.contains($0.name) }
                    if !knoepfe.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(knoepfe.indices, id: \.self) { i in
                                let k = knoepfe[i]
                                if i == 0 {
                                    Button { aktion(k, info) } label: { Text(k.titel).font(.headline).lineLimit(1).frame(maxWidth: .infinity) }
                                        .buttonStyle(.glassProminent)
                                } else {
                                    Button { aktion(k, info) } label: { Text(k.titel).font(.headline).lineLimit(1).frame(maxWidth: .infinity) }
                                        .buttonStyle(.glass)
                                }
                            }
                        }
                        .controlSize(.large)
                    }
                    // Straßenbild bei festen Orten (Ziele, Markierungen), nicht bei bewegten Kräften und Fahrzeugen
                    if ["ziel", "markierung"].contains(objekt.art.schluessel), let p = info.ort { StrassenbildVorschau(ort: p) }
                    if !info.zeilen.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(info.zeilen.indices, id: \.self) { i in
                                let z = info.zeilen[i]
                                if i > 0 { Divider() }
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(z.titel).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
                                    Text(z.wert).frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 10)
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(.fill.tertiary, in: .rect(cornerRadius: 16))
                    }
                }
                .padding(20)
            }
        } else {
            Text("Nicht mehr in der Lage").foregroundStyle(.secondary).padding(20)
        }
    }
}

/// Notrufknopf: auslösen erst nach 1,5 s Halten (Ring füllt sich), damit ein versehentlicher Tipp nichts auslöst.
/// Den eigenen Notruf beendet ein Tipp mit Rückfrage (gleich wie Android).
private struct SosKnopf: View {
    @Environment(AppModell.self) private var modell
    @State private var gedrueckt = false
    @State private var rueckfrage = false

    var body: some View {
        let eigen = modell.stand.eigenerNotruf
        Text(eigen ? "Ende" : "SOS")
            .font(.headline.weight(.heavy))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .glassEffect(.regular.tint(.red).interactive(), in: .circle)
            .overlay {
                Circle()
                    .trim(from: 0, to: gedrueckt ? 1 : 0)
                    .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 50, height: 50)
                    .animation(gedrueckt ? .linear(duration: 1.5) : .easeOut(duration: 0.15), value: gedrueckt)
            }
            .contentShape(.circle)
            .onTapGesture { if eigen { rueckfrage = true } }
            .onLongPressGesture(minimumDuration: 1.5, perform: {
                guard !eigen else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                _ = modell.lage.notrufAusloesen()
            }, onPressingChanged: { gedrueckt = $0 && !eigen })
            .accessibilityLabel(eigen ? "Notruf beenden" : "Notruf, zum Auslösen 1,5 Sekunden halten")
            .accessibilityIdentifier("SOS")
            .confirmationDialog("Notruf beenden?", isPresented: $rueckfrage, titleVisibility: .visible) {
                Button("Beenden", role: .destructive) { _ = modell.lage.notrufBeenden() }
            }
    }
}
