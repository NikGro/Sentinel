import CoreLocation
import Foundation

// Fachliches Datenmodell. Die Feldnamen entsprechen dem Protokoll des Sentinel-Servers
// (siehe server/src/schemas.ts), deshalb sind sie deutsch.

struct GeoPoint: Codable, Hashable, Sendable {
    var lat: Double
    var lon: Double

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }

    init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(lat: coordinate.latitude, lon: coordinate.longitude)
    }

    func distance(to other: GeoPoint) -> CLLocationDistance {
        CLLocation(latitude: lat, longitude: lon).distance(from: CLLocation(latitude: other.lat, longitude: other.lon))
    }
}

/// Standort mit Zeitpunkt (ms seit 1970), z. B. ein abgestelltes Fahrzeug oder ein von Hand gesetztes Ziel.
struct TimedPoint: Codable, Equatable, Hashable, Sendable {
    var lat: Double
    var lon: Double
    var ts: Double

    var point: GeoPoint { GeoPoint(lat: lat, lon: lon) }
    var date: Date { Date(timeIntervalSince1970: ts / 1000) }

    init(_ point: GeoPoint, at date: Date = .now) {
        lat = point.lat
        lon = point.lon
        ts = (date.timeIntervalSince1970 * 1000).rounded()
    }
}

/// Live-Position eines Fahnders oder Trackers. Zeit in Millisekunden seit 1970.
struct Position: Codable, Equatable, Sendable {
    var lat: Double
    var lon: Double
    var ts: Double
    var acc: Double?
    var spd: Double?
    var hdg: Double?

    var point: GeoPoint { GeoPoint(lat: lat, lon: lon) }
    var date: Date { Date(timeIntervalSince1970: ts / 1000) }
}

/// Ein gemeinsam bearbeitetes Objekt samt Versionsstand.
struct Versioned<T: Codable & Equatable & Sendable>: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var rev: Int
    var updatedAt: Double
    var updatedBy: String
    var data: T

    var updatedDate: Date { Date(timeIntervalSince1970: updatedAt / 1000) }
}

/// Objektarten, die über den Server synchronisiert werden.
protocol LageEntity: Codable, Equatable, Sendable {
    static var kind: String { get }
}

/// Wie ein Fahnder gerade unterwegs ist.
enum Fortbewegung: String, Codable, CaseIterable, Identifiable, Sendable {
    case fuss, fahrzeug, oepnv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fuss: "Zu Fuß"
        case .fahrzeug: "Fahrzeug"
        case .oepnv: "ÖPNV"
        }
    }

    var symbolName: String {
        switch self {
        case .fuss: "figure.walk"
        case .fahrzeug: "car.fill"
        case .oepnv: "tram.fill"
        }
    }
}

/// Gewählte Linie und Fahrtrichtung im öffentlichen Nahverkehr.
struct OepnvFahrt: Codable, Equatable, Hashable, Sendable {
    var linienId: String
    var linie: String
    var richtung: String
}

/// Fahnder. Jeder Fahnder hat ein eigenes Gerät; sein Standort kommt immer vom Telefon.
struct Member: LageEntity {
    static let kind = "member"
    var name: String
    var spitzname: String
    var dienststelle: String
    var telefon: String = ""
    var fotoBlob: String?
    var aktiv: Bool = true
    var fortbewegung: Fortbewegung = .fuss
    var fahrzeugId: String?
    var oepnv: OepnvFahrt?

    init(name: String, spitzname: String, dienststelle: String, telefon: String = "", fotoBlob: String? = nil) {
        self.name = name
        self.spitzname = spitzname
        self.dienststelle = dienststelle
        self.telefon = telefon
        self.fotoBlob = fotoBlob
    }

    private enum CodingKeys: String, CodingKey {
        case name, spitzname, dienststelle, telefon, fotoBlob, aktiv, fortbewegung, fahrzeugId, oepnv
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        spitzname = try c.decodeIfPresent(String.self, forKey: .spitzname) ?? name
        dienststelle = try c.decodeIfPresent(String.self, forKey: .dienststelle) ?? ""
        telefon = try c.decodeIfPresent(String.self, forKey: .telefon) ?? ""
        fotoBlob = try c.decodeIfPresent(String.self, forKey: .fotoBlob)
        aktiv = try c.decodeIfPresent(Bool.self, forKey: .aktiv) ?? true
        fortbewegung = (try? c.decodeIfPresent(Fortbewegung.self, forKey: .fortbewegung)) ?? .fuss
        fahrzeugId = try c.decodeIfPresent(String.self, forKey: .fahrzeugId)
        oepnv = try c.decodeIfPresent(OepnvFahrt.self, forKey: .oepnv)
    }
}

/// Fahrzeug der eigenen Kräfte. Bleibt dauerhaft angelegt und wird je Einsatz aktiv geschaltet.
struct Vehicle: LageEntity {
    static let kind = "vehicle"

    var funkrufname: String
    var bezeichnung: String = ""
    var kennzeichen: String = ""
    var beschreibung: String = ""
    var fotoBlob: String?
    var trackerId: String?
    var aktiv: Bool = true
    var abgestellt: TimedPoint?

    init(funkrufname: String, bezeichnung: String = "", kennzeichen: String = "", beschreibung: String = "") {
        self.funkrufname = funkrufname
        self.bezeichnung = bezeichnung
        self.kennzeichen = kennzeichen
        self.beschreibung = beschreibung
    }

    private enum CodingKeys: String, CodingKey {
        case funkrufname, bezeichnung, kennzeichen, beschreibung, fotoBlob, trackerId, aktiv, abgestellt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bezeichnung = try c.decodeIfPresent(String.self, forKey: .bezeichnung) ?? ""
        funkrufname = try c.decodeIfPresent(String.self, forKey: .funkrufname) ?? (bezeichnung.isEmpty ? "Fahrzeug" : bezeichnung)
        kennzeichen = try c.decodeIfPresent(String.self, forKey: .kennzeichen) ?? ""
        beschreibung = try c.decodeIfPresent(String.self, forKey: .beschreibung) ?? ""
        fotoBlob = try c.decodeIfPresent(String.self, forKey: .fotoBlob)
        trackerId = try c.decodeIfPresent(String.self, forKey: .trackerId)
        aktiv = try c.decodeIfPresent(Bool.self, forKey: .aktiv) ?? true
        abgestellt = try c.decodeIfPresent(TimedPoint.self, forKey: .abgestellt)
    }

    /// Zusatzangabe unter dem Funkrufnamen.
    var subtitle: String {
        [bezeichnung, kennzeichen].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// Markierung auf der Karte: Marker, Beschriftung, Linie, Fläche, Kreis oder Fahndungsraum.
struct MapObject: LageEntity {
    static let kind = "annotation"

    enum Shape: String, Codable, CaseIterable, Sendable {
        case marker, text, linie, flaeche, kreis, fahndungsraum

        var title: String {
            switch self {
            case .marker: "Marker"
            case .text: "Beschriftung"
            case .linie: "Linie"
            case .flaeche: "Fläche"
            case .kreis: "Kreis"
            case .fahndungsraum: "Fahndungsraum"
            }
        }

        var symbolName: String {
            switch self {
            case .marker: "mappin"
            case .text: "textformat"
            case .linie: "point.topleft.down.to.point.bottomright.curvepath"
            case .flaeche: "pentagon"
            case .kreis: "circle.dashed"
            case .fahndungsraum: "scope"
            }
        }

        /// Anzahl Punkte, ab der die Form gültig ist.
        var minimumPoints: Int {
            switch self {
            case .linie: 2
            case .flaeche: 3
            default: 1
            }
        }

        var isMultiPoint: Bool { self == .linie || self == .flaeche }
    }

    var layerId: String
    var typ: Shape
    var titel: String = ""
    var notiz: String = ""
    var farbe: String = "#FF9F0A"
    var symbol: String = ""
    var punkte: [GeoPoint]
    var radius: Double?
    var wert: Double?
    /// Fahndungsraum: Zeitpunkt (ms), ab dem die Weg-Zeit-Flächen wachsen.
    var zeit: Double?
    /// Marker, dessen Standort ein Tracker liefert.
    var trackerId: String?

    init(layerId: String, typ: Shape, titel: String = "", farbe: String = "#FF9F0A", punkte: [GeoPoint], radius: Double? = nil, zeit: Double? = nil) {
        self.layerId = layerId
        self.typ = typ
        self.titel = titel
        self.farbe = farbe
        self.punkte = punkte
        self.radius = radius
        self.zeit = zeit
    }

    /// Ankerpunkt für Beschriftung und Antippen.
    var anchor: GeoPoint {
        guard typ.isMultiPoint, !punkte.isEmpty else { return punkte.first ?? GeoPoint(lat: 0, lon: 0) }
        let lat = punkte.map(\.lat).reduce(0, +) / Double(punkte.count)
        let lon = punkte.map(\.lon).reduce(0, +) / Double(punkte.count)
        return GeoPoint(lat: lat, lon: lon)
    }

    var since: Date? { zeit.map { Date(timeIntervalSince1970: $0 / 1000) } }
}

enum ZielArt: String, Codable, CaseIterable, Identifiable, Sendable {
    case person, fahrzeug, objekt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .person: "Zielperson"
        case .fahrzeug: "Zielfahrzeug"
        case .objekt: "Zielobjekt"
        }
    }

    var symbolName: String {
        switch self {
        case .person: "person.fill"
        case .fahrzeug: "car.side.fill"
        case .objekt: "house.fill"
        }
    }
}

/// Zielperson, Zielfahrzeug oder Zielobjekt. Erscheint auf der Karte, sobald ein Standort oder Tracker bekannt ist.
struct Target: LageEntity {
    static let kind = "target"
    var art: ZielArt = .person
    var bezeichnung: String = ""
    var vorname: String = ""
    var nachname: String = ""
    var geburtsdatum: String?
    var geburtsort: String = ""
    var staatsangehoerigkeit: String = ""
    var anschrift: String = ""
    var merkmale: String = ""
    var fotoBlob: String?
    var kennzeichen: String = ""
    var fahrzeugBeschreibung: String = ""
    var fahrzeugFotoBlob: String?
    var sachverhalt: String = ""
    var hinweise: String = ""
    var massnahmen: String = ""
    var trackerId: String?
    var standort: TimedPoint?

    init(art: ZielArt = .person, bezeichnung: String = "", vorname: String = "", nachname: String = "") {
        self.art = art
        self.bezeichnung = bezeichnung
        self.vorname = vorname
        self.nachname = nachname
    }

    private enum CodingKeys: String, CodingKey {
        case art, bezeichnung, vorname, nachname, geburtsdatum, geburtsort, staatsangehoerigkeit, anschrift, merkmale, fotoBlob
        case kennzeichen, fahrzeugBeschreibung, fahrzeugFotoBlob, sachverhalt, hinweise, massnahmen, trackerId, standort
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) throws -> String { try c.decodeIfPresent(String.self, forKey: key) ?? "" }
        art = (try? c.decodeIfPresent(ZielArt.self, forKey: .art)) ?? .person
        bezeichnung = try text(.bezeichnung)
        vorname = try text(.vorname)
        nachname = try text(.nachname)
        geburtsdatum = try c.decodeIfPresent(String.self, forKey: .geburtsdatum)
        geburtsort = try text(.geburtsort)
        staatsangehoerigkeit = try text(.staatsangehoerigkeit)
        anschrift = try text(.anschrift)
        merkmale = try text(.merkmale)
        fotoBlob = try c.decodeIfPresent(String.self, forKey: .fotoBlob)
        kennzeichen = try text(.kennzeichen)
        fahrzeugBeschreibung = try text(.fahrzeugBeschreibung)
        fahrzeugFotoBlob = try c.decodeIfPresent(String.self, forKey: .fahrzeugFotoBlob)
        sachverhalt = try text(.sachverhalt)
        hinweise = try text(.hinweise)
        massnahmen = try text(.massnahmen)
        trackerId = try c.decodeIfPresent(String.self, forKey: .trackerId)
        standort = try c.decodeIfPresent(TimedPoint.self, forKey: .standort)
    }

    var displayName: String {
        switch art {
        case .person:
            let full = [vorname, nachname].filter { !$0.isEmpty }.joined(separator: " ")
            return full.isEmpty ? "Unbekannte Person" : full
        case .fahrzeug:
            return [kennzeichen, bezeichnung].first { !$0.isEmpty } ?? "Zielfahrzeug"
        case .objekt:
            return [bezeichnung, anschrift].first { !$0.isEmpty } ?? "Zielobjekt"
        }
    }

    private static let birthFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var birthDate: Date? {
        get { geburtsdatum.flatMap { Self.birthFormat.date(from: $0) } }
        set { geburtsdatum = newValue.map { Self.birthFormat.string(from: $0) } }
    }

    /// Alter in vollen Jahren zum Stichtag.
    func age(at reference: Date = .now) -> Int? {
        guard let birthDate else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return calendar.dateComponents([.year], from: birthDate, to: reference).year
    }
}

struct Tracker: LageEntity {
    static let kind = "tracker"
    var name: String
    var anbieter: String
    var kennung: String
    var intervall: Int?

    var providerTitle: String { anbieter == "paj" ? "PAJ" : "SinoTrack" }
}

struct Layer: LageEntity {
    static let kind = "layer"
    static let lageId = "lage"
    static let dauerhaftId = "dauerhaft"

    var name: String
    var art: String
    var status: String
    var beschreibung: String = ""

    var isLive: Bool { status == "live" }

    var symbolName: String {
        switch art {
        case "dauerhaft": "pin"
        case "paket": "shippingbox"
        case "argus": "chart.bar.xaxis"
        default: "scope"
        }
    }
}

struct ChatRoom: LageEntity {
    static let kind = "room"
    static let generalId = "allgemein"
    var name: String
}

struct ChatAttachment: Codable, Equatable, Sendable {
    enum Art: String, Codable, Sendable {
        case bild, audio, datei
    }

    var blobId: String
    var art: Art
    var name: String = ""
    var mime: String
    var groesse: Int
    var dauer: Double?
}

struct ChatMessage: LageEntity {
    static let kind = "message"
    var roomId: String = ChatRoom.generalId
    var text: String = ""
    var anhang: ChatAttachment?

    init(roomId: String, text: String, anhang: ChatAttachment? = nil) {
        self.roomId = roomId
        self.text = text
        self.anhang = anhang
    }

    private enum CodingKeys: String, CodingKey {
        case roomId, text, anhang
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        roomId = try c.decodeIfPresent(String.self, forKey: .roomId) ?? ChatRoom.generalId
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        anhang = try c.decodeIfPresent(ChatAttachment.self, forKey: .anhang)
    }
}

struct LeapfrogStop: Codable, Equatable, Hashable, Sendable {
    var name: String
    var lat: Double
    var lon: Double

    var point: GeoPoint { GeoPoint(lat: lat, lon: lon) }
}

/// Gemeinsamer Zustand des laufenden Einsatzes.
struct OperationState: Codable, Equatable, Sendable {
    struct APosition: Codable, Equatable, Sendable {
        var memberId: String
        var seit: Double
    }

    /// Überschlagendes Anfahren der nächsten Haltestellen, solange die A im ÖPNV fährt.
    struct Leapfrog: Codable, Equatable, Sendable {
        var teilnehmer: [String] = []
        var zuweisungen: [String: LeapfrogStop] = [:]
        var naechste: [LeapfrogStop] = []
    }

    var funkkanal: String?
    var titel: String = ""
    var hinweise: String = ""
    var a: APosition?
    var ueberschlagen = Leapfrog()
    var rev: Int = 0

    init() {}

    private enum CodingKeys: String, CodingKey {
        case funkkanal, titel, hinweise, a, ueberschlagen, rev
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        funkkanal = try c.decodeIfPresent(String.self, forKey: .funkkanal)
        titel = try c.decodeIfPresent(String.self, forKey: .titel) ?? ""
        hinweise = try c.decodeIfPresent(String.self, forKey: .hinweise) ?? ""
        a = try c.decodeIfPresent(APosition.self, forKey: .a)
        ueberschlagen = try c.decodeIfPresent(Leapfrog.self, forKey: .ueberschlagen) ?? Leapfrog()
        rev = try c.decodeIfPresent(Int.self, forKey: .rev) ?? 0
    }
}

/// Fortbewegungsarten der Weg-Zeit-Berechnung.
enum ReachMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case fuss, kfz, oepnv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fuss: "Zu Fuß"
        case .kfz: "Kfz"
        case .oepnv: "ÖPNV"
        }
    }

    var symbolName: String {
        switch self {
        case .fuss: "figure.walk"
        case .kfz: "car.fill"
        case .oepnv: "tram.fill"
        }
    }
}

struct ReachArea: Codable, Equatable, Sendable, Identifiable {
    var modus: ReachMode
    var quelle: String
    /// Geschlossene Ringe als [Breite, Länge].
    var ringe: [[[Double]]]

    var id: String { modus.rawValue }
    var isModel: Bool { quelle == "modell" }
}

struct CoverageTrack: Codable, Equatable, Sendable {
    var memberId: String
    /// [Breite, Länge, Zeit in ms]
    var punkte: [[Double]]
}

/// Eine Fahrtrichtung einer ÖPNV-Linie aus der Suche.
struct LineHit: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var ref: String
    var typ: String
    var richtung: String
    var meter: Double?

    var symbolName: String {
        switch typ {
        case "subway": "tram.fill.tunnel"
        case "train", "light_rail": "train.side.front.car"
        case "tram": "tram.fill"
        case "ferry": "ferry.fill"
        default: "bus.fill"
        }
    }
}
