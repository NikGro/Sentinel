import CoreLocation
import Foundation

// ÖPNV: Haltestellen, Linien und Fahrten aus OpenStreetMap (eigener Bereich) und Transitous (deutschlandweit).

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

struct LiveStop: Codable, Hashable, Identifiable, Sendable {
    var name: String
    var stopId: String
    var lat: Double
    var lon: Double

    var id: String { stopId.isEmpty ? "\(name)|\(lat)|\(lon)" : stopId }
    var point: GeoPoint { GeoPoint(lat: lat, lon: lon) }
}

/// Ein fahrendes Fahrzeug auf einem Abschnitt zwischen zwei Halten.
struct LiveSegment: Codable, Hashable, Identifiable, Sendable {
    var tripId: String
    var name: String
    var mode: String
    var from: LiveStop
    var to: LiveStop
    var dep: Double
    var arr: Double
    var realTime: Bool
    var delay: Int?
    var path: [[Double]]

    var id: String { "\(tripId)|\(dep)" }
    var points: [GeoPoint] { path.compactMap { $0.count == 2 ? GeoPoint(lat: $0[0], lon: $0[1]) : nil } }
    /// Verkehrsart im Sentinel-Format (wie OpenStreetMap: bus, tram, subway, train, ferry).
    var osmType: String { LiveSegment.osmType(mode, name: name) }

    static func osmType(_ mode: String, name: String) -> String {
        switch mode {
        case "SUBWAY": "subway"
        case "TRAM": "tram"
        case "FERRY": "ferry"
        case "SUBURBAN", "REGIONAL_RAIL", "RAIL": "train"
        default: "bus"
        }
    }

    var badge: NearbyStop.Line { NearbyStop.Line(ref: name, typ: osmType, farbe: nil) }

    /// Position zur Zeit `now` auf diesem Abschnitt, `nil` außerhalb.
    func position(at now: Date) -> GeoPoint? {
        let t = now.timeIntervalSince1970 * 1000
        guard t >= dep - 1000, t <= arr + 1000 else { return nil }
        let fraction = arr > dep ? (t - dep) / (arr - dep) : 1
        let line = points
        guard line.count >= 2 else { return line.first ?? from.point }
        return TransitSimulation.point(along: line[...], fraction: fraction)
    }
}

struct TripDetail: Codable, Hashable, Sendable {
    struct Stop: Codable, Hashable, Sendable {
        var name: String
        var stopId: String
        var lat: Double
        var lon: Double
        var arr: Double?
        var dep: Double?

        var point: GeoPoint { GeoPoint(lat: lat, lon: lon) }
    }

    var tripId: String
    var name: String
    var mode: String
    var headsign: String
    var color: String?
    var stops: [Stop]
    var path: [[Double]]
    var realTime: Bool

    var points: [GeoPoint] { path.compactMap { $0.count == 2 ? GeoPoint(lat: $0[0], lon: $0[1]) : nil } }
}

struct LiveDeparture: Codable, Hashable, Identifiable, Sendable {
    var tripId: String
    var name: String
    var mode: String
    var headsign: String
    var time: Double
    var scheduled: Double
    var realTime: Bool
    var color: String?

    var id: String { "\(tripId)|\(time)" }
    var delayMinutes: Int { Int(((time - scheduled) / 60_000).rounded()) }
}

/// Verbindung mit Bus und Bahn (Transitous).
struct TransitPlan: Codable, Hashable, Sendable {
    struct Place: Codable, Hashable, Sendable {
        var name: String
        var lat: Double
        var lon: Double
        var time: Double
    }

    struct Leg: Codable, Hashable, Sendable {
        var mode: String
        var name: String
        var headsign: String
        var from: Place
        var to: Place
        var stops: Int
        var realTime: Bool
    }

    var start: Double
    var end: Double
    var transfers: Int
    var legs: [Leg]
}

/// Echte Fahrt: Kennung bei Transitous und Zeit (ms) an jedem Halt.
struct TransitTrip: Codable, Equatable, Hashable, Sendable {
    var id: String
    var zeiten: [Double?]
}

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
