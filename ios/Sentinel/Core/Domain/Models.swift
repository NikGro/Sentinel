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

struct Member: LageEntity {
    static let kind = "member"
    var name: String
    var funkrufname: String
    var dienststelle: String
    var telefon: String = ""
    var fotoBlob: String?
    var fahrzeugId: String?
}

struct Vehicle: LageEntity {
    static let kind = "vehicle"

    struct Parked: Codable, Equatable, Sendable {
        var lat: Double
        var lon: Double
        var ts: Double
    }

    var bezeichnung: String
    var kennzeichen: String = ""
    var beschreibung: String = ""
    var fotoBlob: String?
    var trackerId: String?
    var abgestellt: Parked?
}

/// Markierung auf der Karte: Marker, Beschriftung, Linie, Fläche oder Kreis.
struct MapObject: LageEntity {
    static let kind = "annotation"

    enum Shape: String, Codable, CaseIterable, Sendable {
        case marker, text, linie, flaeche, kreis

        var title: String {
            switch self {
            case .marker: "Marker"
            case .text: "Beschriftung"
            case .linie: "Linie"
            case .flaeche: "Fläche"
            case .kreis: "Kreis"
            }
        }

        var symbolName: String {
            switch self {
            case .marker: "mappin"
            case .text: "textformat"
            case .linie: "point.topleft.down.to.point.bottomright.curvepath"
            case .flaeche: "pentagon"
            case .kreis: "circle.dashed"
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

    /// Ankerpunkt für Beschriftung und Antippen.
    var anchor: GeoPoint {
        guard typ.isMultiPoint, !punkte.isEmpty else { return punkte.first ?? GeoPoint(lat: 0, lon: 0) }
        let lat = punkte.map(\.lat).reduce(0, +) / Double(punkte.count)
        let lon = punkte.map(\.lon).reduce(0, +) / Double(punkte.count)
        return GeoPoint(lat: lat, lon: lon)
    }
}

struct Target: LageEntity {
    static let kind = "target"
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

    var displayName: String {
        let full = [vorname, nachname].filter { !$0.isEmpty }.joined(separator: " ")
        return full.isEmpty ? "Unbekannte Person" : full
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

    var symbolName: String {
        switch art {
        case "dauerhaft": "pin"
        case "paket": "shippingbox"
        case "argus": "chart.bar.xaxis"
        default: "scope"
        }
    }
}

struct ChatMessage: LageEntity {
    static let kind = "message"
    var text: String
}

enum Modus: String, Codable, CaseIterable, Identifiable, Sendable {
    case observation, fahndung, oberflaeche

    var id: String { rawValue }

    var title: String {
        switch self {
        case .observation: "Observation"
        case .fahndung: "Fahndung"
        case .oberflaeche: "Oberfläche"
        }
    }

    var shortTitle: String {
        switch self {
        case .observation: "OBS"
        case .fahndung: "FHN"
        case .oberflaeche: "OFL"
        }
    }

    var symbolName: String {
        switch self {
        case .observation: "eye"
        case .fahndung: "scope"
        case .oberflaeche: "square.grid.3x3"
        }
    }

    var summary: String {
        switch self {
        case .observation: "A-Position, Navigation zur A, Zielperson im Blick"
        case .fahndung: "Bestreifung, letzter Standort, Weg-Zeit-Berechnung"
        case .oberflaeche: "Nur Kräfte und Markierungen"
        }
    }
}

/// Gemeinsamer Zustand des laufenden Einsatzes.
struct OperationState: Codable, Equatable, Sendable {
    struct APosition: Codable, Equatable, Sendable {
        var memberId: String
        var seit: Double
    }

    struct LastKnownPosition: Codable, Equatable, Sendable {
        var lat: Double
        var lon: Double
        var ts: Double
        var quelle: String
        var targetId: String?

        var point: GeoPoint { GeoPoint(lat: lat, lon: lon) }
        var date: Date { Date(timeIntervalSince1970: ts / 1000) }
    }

    var modus: Modus = .observation
    var funkkanal: String?
    var titel: String = ""
    var hinweise: String = ""
    var a: APosition?
    var lkp: LastKnownPosition?
    var bestreifungSeit: Double?
    var rev: Int = 0
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
