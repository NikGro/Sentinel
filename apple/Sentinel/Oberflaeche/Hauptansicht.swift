import SentinelKern
import SwiftUI

/// Außer Dienst nur das Hauptmenü (Instanzen); im Dienst die Tabs Lage, Ziele, Kräfte und Mehr.
struct Hauptansicht: View {
    @Environment(AppModell.self) private var modell
    @State private var hauptmenue = false

    var body: some View {
        if !modell.stand.imDienst || hauptmenue {
            Hauptmenue { hauptmenue = false }
        } else {
            TabView {
                Tab("Lage", systemImage: "map") { Lagebildschirm() }
                Tab("Ziele", systemImage: "person.crop.rectangle.stack") { Zielliste() }
                Tab("Kräfte", systemImage: "person.3") { Kraefteliste() }
                Tab("Mehr", systemImage: "ellipsis") { Mehr { hauptmenue = true } }
            }
        }
    }
}

/// Lagekarte mit Suchleiste oben, Knöpfen rechts (SOS, Kompass, Verkehr, Hinzufügen) und unten A-Position,
/// Fortbewegung und Lageleiste. Antippen öffnet die Kurzübersicht.
struct Lagebildschirm: View {
    @Environment(AppModell.self) private var modell
    @State private var steuerung = KartenSteuerung()
    @State private var auswahl: KartenObjektAuswahl?
    @State private var verkehr = false
    @State private var sucht = false
    @State private var ortTreffer: OrtAuswahl?

    var body: some View {
        LageKarte(modell: modell, steuerung: steuerung) { auswahl = KartenObjektAuswahl(objekt: $0) }
            .ignoresSafeArea()
            .safeAreaInset(edge: .top) {
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
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Button(modell.stand.eigenerNotruf ? "Ende" : "SOS") {
                        if modell.stand.eigenerNotruf { _ = modell.lage.notrufBeenden() } else { _ = modell.lage.notrufAusloesen() }
                    }
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.tint(.red).interactive(), in: .circle)
                    GlassEffectContainer(spacing: 8) {
                        VStack(spacing: 8) {
                            // Standort und Kompass in einem Knopf: heftet an (Fahrtrichtung), erneut Norden oben.
                            Kartenknopf(symbol: steuerung.anheftung == .frei ? "location" : (steuerung.anheftung == .norden ? "location.north.fill" : "location.fill"),
                                        titel: "Standort und Kompass", aktiv: steuerung.anheftung != .frei) {
                                steuerung.anheftenUmschalten(ort: modell.standort.aktuell)
                            }
                            Kartenknopf(symbol: "car.side.rear.and.collision.and.car.side.front", titel: "Verkehr", aktiv: verkehr) {
                                verkehr.toggle()
                                steuerung.verkehr(verkehr)
                            }
                            Kartenknopf(symbol: "plus", titel: "Hinzufügen", hervorgehoben: true) {}
                        }
                    }
                }
                .padding(.trailing, 22)
                .padding(.top, 60)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        AKnopf()
                        Fortbewegungswahl()
                    }
                    Lageleiste()
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
            .sheet(item: $ortTreffer, onDismiss: { steuerung.markieren(nil) }) { o in
                VStack(alignment: .leading, spacing: 12) {
                    Text(o.treffer.titel).font(.title3.weight(.semibold))
                    if !o.treffer.untertitel.isEmpty { Text(o.treffer.untertitel).foregroundStyle(.secondary) }
                    HStack(spacing: 12) {
                        Button {} label: { Label("Hinführen", systemImage: "arrow.triangle.turn.up.right.diamond.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(.glassProminent)
                        Button {} label: { Label("Hier anlegen", systemImage: "plus").frame(maxWidth: .infinity) }
                            .buttonStyle(.glass)
                    }
                    .controlSize(.large)
                    Spacer()
                }
                .padding(20)
                .presentationDetents([.fraction(0.28)])
                .presentationBackgroundInteraction(.enabled)
            }
            .sheet(item: $auswahl) { a in
                Kurzuebersicht(objekt: a.objekt)
                    .presentationDetents([.fraction(0.3), .medium, .large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
    }
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

/// Kurzübersicht eines angetippten Objekts: Kopfzeile mit Symbol, Titel und Untertitel, darunter Hinführen.
struct Kurzuebersicht: View {
    @Environment(AppModell.self) private var modell
    let objekt: KartenObjekt

    var body: some View {
        let stand = modell.stand
        let (titel, untertitel, farbe): (String, String, Color) = {
            switch objekt.art {
            case .kraft:
                let f = stand.fahnder[objekt.id]?.data
                return (f?.spitzname ?? "Fahnder", f.map { stand.fortbewegungText(f: $0) } ?? "", Color(red: 0.37, green: 0.36, blue: 0.9))
            case .fahrzeug:
                let f = stand.fahrzeuge[objekt.id]?.data
                return (f?.funkrufname ?? "Fahrzeug", f?.zusatz ?? "", Color(red: 0.37, green: 0.36, blue: 0.9))
            case .ziel:
                let z = stand.ziele[objekt.id]?.data
                return (z?.anzeigename ?? "Ziel", z?.zweiteZeile ?? "", Color(red: 1, green: 0.22, blue: 0.37))
            default:
                let m = stand.markierungen[objekt.id]?.data
                return (m.map { $0.titel.isEmpty ? "Markierung" : $0.titel } ?? "Markierung", m?.notiz ?? "", .accentColor)
            }
        }()
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle().fill(farbe.gradient).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.headline)
                    if !untertitel.isEmpty { Text(untertitel).font(.subheadline).foregroundStyle(.secondary) }
                }
                Spacer()
            }
            Button {} label: {
                Label("Hinführen", systemImage: "arrow.triangle.turn.up.right.diamond.fill").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding(20)
    }
}

struct Zielliste: View {
    @Environment(AppModell.self) private var modell

    var body: some View {
        NavigationStack {
            List(modell.stand.zieleSortiert, id: \.id) { z in
                VStack(alignment: .leading) {
                    Text(z.data.anzeigename)
                    if let zweite = z.data.zweiteZeile { Text(zweite).font(.caption).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Ziele")
        }
    }
}

struct Kraefteliste: View {
    @Environment(AppModell.self) private var modell

    var body: some View {
        NavigationStack {
            List(modell.stand.kraefte, id: \.id) { f in
                HStack {
                    VStack(alignment: .leading) {
                        Text(f.data.spitzname)
                        Text(f.data.aktiv ? modell.stand.fortbewegungText(f: f.data) : "Ruhemodus").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if modell.stand.istOnline(fahnderId: f.id) { Circle().fill(.green).frame(width: 10, height: 10) }
                }
            }
            .navigationTitle("Kräfte")
        }
    }
}

struct Mehr: View {
    @Environment(AppModell.self) private var modell
    let hauptmenue: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Button("Hauptmenü", action: hauptmenue)
                Button("Abmelden", role: .destructive) { modell.abmelden() }
            }
            .navigationTitle("Mehr")
        }
    }
}

/// Hauptmenü außerhalb jeder Instanz: eigene Instanzen öffnen, anderen beitreten.
struct Hauptmenue: View {
    @Environment(AppModell.self) private var modell
    let schliessen: () -> Void

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
                            HStack {
                                Text(i.data.name).foregroundStyle(.primary)
                                Spacer()
                                if i.id == stand.instanz && stand.imDienst { Text("Geöffnet").foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
                if !stand.andereInstanzen.isEmpty {
                    Section("Beitreten") {
                        ForEach(stand.andereInstanzen, id: \.id) { i in
                            HStack {
                                Text(i.data.name)
                                Spacer()
                                Button("Beitreten") { _ = modell.lage.instanzBeitreten(id: i.id) }
                                    .buttonStyle(.bordered)
                                    .buttonBorderShape(.capsule)
                            }
                        }
                    }
                }
                Section {
                    Button("Abmelden", role: .destructive) { modell.abmelden() }
                }
            }
            .navigationTitle("SENTINEL")
        }
    }
}
