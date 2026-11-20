import CoreLocation
import Foundation

// Fachliches Datenmodell. Die Feldnamen entsprechen dem Protokoll des Sentinel-Servers
// (siehe server/src/schemas.ts), deshalb sind sie deutsch.

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
        /// Einzelne Haltestelle (von Hand gesetzt oder aus einer Linie übernommen).
        case haltestelle

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
            case .haltestelle: "Haltestelle"
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
            case .haltestelle: "h.circle.fill"
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
        var hasHandle: Bool { [.marker, .text, .fahndungsraum, .haltestelle].contains(self) }
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
    /// Echte Fahrt (Transitous) mit Zeit an jedem Halt; der Server führt Verspätungen nach.
    var fahrt: TransitTrip?
    /// ÖPNV-Strecke: welche Ebenen gezeigt werden (Fahrzeug, Strecke, Haltestellen); `nil` heißt alle.
    var ebenen: TransitLayerChoice?
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

/// Ebenen einer übernommenen ÖPNV-Strecke, jede einzeln zuschaltbar.
struct TransitLayerChoice: Codable, Equatable, Hashable, Sendable {
    var fahrzeug = true
    var strecke = true
    var halte = true
}

extension MapObject {
    var showsVehicle: Bool { ebenen?.fahrzeug ?? true }
    var showsPath: Bool { ebenen?.strecke ?? true }
    var showsStops: Bool { ebenen?.halte ?? true }

    /// Fährt hier ein Fahrzeug nach echtem Fahrplan (ÖPNV-Fahrzeug oder Strecke mit eingeschaltetem Fahrzeug)?
    var hasRealVehicle: Bool {
        fahrt != nil && (typ == .oepnvfahrzeug || (typ == .oepnvlinie && showsVehicle))
    }
}
