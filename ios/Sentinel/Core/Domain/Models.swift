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
        /// Umkreis, in dem alle ÖPNV-Haltestellen angezeigt werden.
        case haltestellen
        /// Abschnitt einer ÖPNV-Linie (Halte von … bis), optional mit Fahrzeugen im Takt.
        case oepnvlinie
        /// Einzelnes ÖPNV-Fahrzeug auf einer Linie, Position nach Regeltempo geschätzt.
        case oepnvfahrzeug
        /// Linie mit Pfeilspitze am Ende, z. B. Fluchtrichtung.
        case pfeil

        var isTransit: Bool { self == .oepnvlinie || self == .oepnvfahrzeug }

        var title: String {
            switch self {
            case .marker: "Marker"
            case .text: "Beschriftung"
            case .linie: "Linie"
            case .flaeche: "Fläche"
            case .kreis: "Kreis"
            case .fahndungsraum: "Fahndungsraum"
            case .haltestellen: "Haltestellen im Umkreis"
            case .oepnvlinie: "ÖPNV-Linie"
            case .oepnvfahrzeug: "ÖPNV-Fahrzeug"
            case .pfeil: "Pfeil"
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
            case .haltestellen: "bus.fill"
            case .oepnvlinie: "point.bottomleft.forward.to.point.topright.scurvepath"
            case .oepnvfahrzeug: "bus.doubledecker.fill"
            case .pfeil: "arrow.up.right"
            }
        }

        /// Anzahl Punkte, ab der die Form gültig ist.
        var minimumPoints: Int {
            switch self {
            case .linie, .pfeil: 2
            case .flaeche: 3
            default: 1
            }
        }

        var isMultiPoint: Bool { self == .linie || self == .flaeche || self == .pfeil }

        /// Flächen und Linien sind selbst antippbar und brauchen keinen Griff in der Mitte.
        var hasHandle: Bool { [.marker, .text, .fahndungsraum].contains(self) }
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
    /// Fotos und Dateien, z. B. ein Foto des verdächtigen Mülleimers.
    var anhaenge: [ChatAttachment]?
    /// Lebensdauer: Zeitpunkt in Millisekunden, zu dem sich die Markierung selbst löscht; `nil` für unbegrenzt.
    var ablauf: Double?
    /// ÖPNV-Linie und -Fahrzeug: befahrene Linie; `punkte` sind die Halte des Abschnitts.
    var linie: TransitRef?
    /// Namen der Halte zu `punkte`.
    var haltNamen: [String]?
    /// Tatsächlicher Fahrweg des Abschnitts.
    var weg: [GeoPoint]?
    /// ÖPNV-Linie: Fahrzeuge im Takt (Minuten) ab der Abfahrt `zeit` am ersten Halt; `nil` aus.
    var takt: Int?

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

    var expiry: Date? { ablauf.map { Date(timeIntervalSince1970: $0 / 1000) } }

    func isExpired(at date: Date = .now) -> Bool { expiry.map { $0 <= date } ?? false }
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
    /// Weitere Fotos und Dateien.
    var anhaenge: [ChatAttachment] = []
    /// Zielperson unterwegs: zu Fuß oder gebunden an ÖPNV-Fahrzeug, Zielfahrzeug oder Zielobjekt.
    var bindung: TargetBinding?

    init(art: ZielArt = .person, bezeichnung: String = "", vorname: String = "", nachname: String = "") {
        self.art = art
        self.bezeichnung = bezeichnung
        self.vorname = vorname
        self.nachname = nachname
    }

    private enum CodingKeys: String, CodingKey {
        case art, bezeichnung, vorname, nachname, geburtsdatum, geburtsort, staatsangehoerigkeit, anschrift, merkmale, fotoBlob
        case kennzeichen, fahrzeugBeschreibung, fahrzeugFotoBlob, sachverhalt, hinweise, massnahmen, trackerId, standort, anhaenge
        case bindung
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
        anhaenge = (try? c.decodeIfPresent([ChatAttachment].self, forKey: .anhaenge)) ?? []
        bindung = try? c.decodeIfPresent(TargetBinding.self, forKey: .bindung)
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

    /// Geburtsdatum als deutscher Text "TT.MM.JJJJ"; leer heißt unbekannt.
    var birthDateText: String {
        guard let birthDate else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: birthDate)
    }

    /// Liest "4.5.1990", "04.05.1990" oder "04051990"; `nil`, wenn kein gültiges Datum.
    static func parseBirthDate(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        var parts = trimmed.split(whereSeparator: { $0 == "." || $0 == "/" || $0 == "-" || $0 == " " }).map(String.init)
        if parts.count == 1, trimmed.count == 8, trimmed.allSatisfy(\.isNumber) {
            let chars = Array(trimmed)
            parts = [String(chars[0..<2]), String(chars[2..<4]), String(chars[4..<8])]
        }
        guard parts.count == 3, let day = Int(parts[0]), let month = Int(parts[1]), var year = Int(parts[2]) else { return nil }
        if parts[2].count == 2 {
            let current = Calendar.current.component(.year, from: .now) % 100
            year += year > current ? 1900 : 2000
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components), date <= .now, year >= 1900 else { return nil }
        return date
    }

    /// Alle Freitexte in einem Feld. Ältere Stände mit getrennten Feldern werden mit Überschriften zusammengeführt.
    var notes: String {
        let extra = [
            (art == .objekt ? "Beschreibung" : "Merkmale", merkmale),
            (art == .fahrzeug ? "Besonderheiten" : "Fahrzeug", fahrzeugBeschreibung),
            ("Sachverhalt", sachverhalt),
        ]
        let after = [("Maßnahmen", massnahmen)]
        let trimmed = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard (extra + after).contains(where: { !trimmed($0.1).isEmpty }) else { return hinweise }
        return (extra + [("Hinweise", hinweise)] + after)
            .filter { !trimmed($0.1).isEmpty }
            .map { "\($0.0): \(trimmed($0.1))" }
            .joined(separator: "\n\n")
    }

    /// Bringt ein Ziel auf das aktuelle Modell: ein Freitextfeld, alle Fotos in einer Liste.
    mutating func normalize() {
        hinweise = notes
        merkmale = ""
        fahrzeugBeschreibung = ""
        sachverhalt = ""
        massnahmen = ""
        for blob in [fahrzeugFotoBlob, fotoBlob].compactMap({ $0 }) where !anhaenge.contains(where: { $0.blobId == blob }) {
            anhaenge.insert(ChatAttachment(blobId: blob, art: .bild, name: "Foto.jpg", mime: "image/jpeg", groesse: 0), at: 0)
        }
        fahrzeugFotoBlob = nil
        fotoBlob = anhaenge.first(where: { $0.art == .bild })?.blobId
    }

    static func age(of birthDate: Date, at reference: Date = .now) -> Int? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return calendar.dateComponents([.year], from: birthDate, to: reference).year
    }

    /// Alter in vollen Jahren zum Stichtag.
    func age(at reference: Date = .now) -> Int? {
        guard let birthDate else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return calendar.dateComponents([.year], from: birthDate, to: reference).year
    }
}

/// Wo eine Zielperson gerade ist: zu Fuß oder mit einem anderen Objekt unterwegs bzw. darin.
struct TargetBinding: Codable, Equatable, Hashable, Sendable {
    enum Art: String, Codable, CaseIterable, Identifiable, Sendable {
        case fuss, oepnv, fahrzeug, objekt

        var id: String { rawValue }

        var title: String {
            switch self {
            case .fuss: "Zu Fuß"
            case .oepnv: "ÖPNV"
            case .fahrzeug: "Fahrzeug"
            case .objekt: "Gebäude"
            }
        }

        var symbolName: String {
            switch self {
            case .fuss: "figure.walk"
            case .oepnv: "tram.fill"
            case .fahrzeug: "car.fill"
            case .objekt: "building.2.fill"
            }
        }
    }

    var art: Art
    /// Markierung (ÖPNV-Fahrzeug) bzw. Ziel (Zielfahrzeug, Zielobjekt).
    var zielId: String?
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
    /// Sprachnachricht: Lautstärkeverlauf (0 bis 1) für die Wellenform.
    var wellenform: [Double]?
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
    /// Notruf eines Fahnders.
    var sos: APosition?
    var rev: Int = 0

    init() {}

    private enum CodingKeys: String, CodingKey {
        case funkkanal, titel, hinweise, a, ueberschlagen, sos, rev
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        funkkanal = try c.decodeIfPresent(String.self, forKey: .funkkanal)
        titel = try c.decodeIfPresent(String.self, forKey: .titel) ?? ""
        hinweise = try c.decodeIfPresent(String.self, forKey: .hinweise) ?? ""
        a = try c.decodeIfPresent(APosition.self, forKey: .a)
        ueberschlagen = try c.decodeIfPresent(Leapfrog.self, forKey: .ueberschlagen) ?? Leapfrog()
        sos = try c.decodeIfPresent(APosition.self, forKey: .sos)
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

/// Haltestelle in einer Umkreis-Markierung mit den dort haltenden Linien.
struct NearbyStop: Codable, Identifiable, Hashable, Sendable {
    struct Line: Codable, Hashable, Sendable {
        var ref: String
        var typ: String
        /// Offizielle Linienfarbe aus OpenStreetMap.
        var farbe: String?
    }

    var name: String
    var lat: Double
    var lon: Double
    var meter: Double
    var linien: [Line]

    var id: String { "\(name)|\(String(format: "%.4f,%.4f", lat, lon))" }
    var point: GeoPoint { GeoPoint(lat: lat, lon: lon) }
    var lineSummary: String { linien.prefix(8).map(\.ref).joined(separator: " ") + (linien.count > 8 ? " …" : "") }
}

/// Eine Fahrtrichtung einer ÖPNV-Linie aus der Suche.
/// Verweis auf eine ÖPNV-Linie in einer Markierung.
struct TransitRef: Codable, Equatable, Hashable, Sendable {
    var id: String
    var ref: String
    var typ: String
    var richtung: String
    var farbe: String?

    var symbolName: String { LineHit(id: id, ref: ref, typ: typ, richtung: richtung).symbolName }
    var badge: NearbyStop.Line { NearbyStop.Line(ref: ref, typ: typ, farbe: farbe) }
}

/// Vollständige Linie mit allen Halten in Fahrtrichtung.
struct TransitLine: Codable, Identifiable, Sendable {
    var id: String
    var ref: String
    var typ: String
    var von: String
    var nach: String
    var halte: [LeapfrogStop]
    var farbe: String?
    /// Fahrweg als [lat, lon].
    var weg: [[Double]]?

    var path: [GeoPoint] { (weg ?? []).compactMap { $0.count == 2 ? GeoPoint(lat: $0[0], lon: $0[1]) : nil } }
}

struct LineHit: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var ref: String
    var typ: String
    var richtung: String
    var farbe: String?
    var meter: Double?

    var badge: NearbyStop.Line { NearbyStop.Line(ref: ref, typ: typ, farbe: farbe) }

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
