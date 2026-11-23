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
        // Fahrmodell wie auf der Lagekarte: weich anfahren, in Kurven langsamer, vor dem Halt bremsen und dort stehen.
        if let motion = TransitMotion.segment(from: from.point, to: to.point, path: points, dep: dep, arr: arr, typ: osmType) {
            return motion.state(at: t / 1000).point
        }
        let line = points
        guard line.count >= 2 else { return line.first ?? from.point }
        return TransitSimulation.point(along: line[...], fraction: arr > dep ? (t - dep) / (arr - dep) : 1)
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
        /// Weg des Abschnitts als [Breite, Länge].
        var path: [[Double]]?

        var isWalk: Bool { mode == "WALK" }
        var coordinates: [CLLocationCoordinate2D] {
            let points = (path ?? []).compactMap { $0.count == 2 ? CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) : nil }
            return points.count >= 2 ? points : [CLLocationCoordinate2D(latitude: from.lat, longitude: from.lon), CLLocationCoordinate2D(latitude: to.lat, longitude: to.lon)]
        }
        var badge: NearbyStop.Line { NearbyStop.Line(ref: name, typ: LiveSegment.osmType(mode, name: name), farbe: nil) }
        var minutes: Int { max(1, Int(((to.time - from.time) / 60_000).rounded())) }
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
    /// Halte-IDs zu den Punkten, für die sichere Zuordnung der Echtzeit auf dem Server.
    var haltIds: [String]?
    /// Echtzeitdaten vorhanden und wann zuletzt aufgefrischt (ms).
    var echtzeit: Bool?
    var stand: Double?

    /// Wie verlässlich die Position ist.
    enum Reliability {
        case realtime, schedule
    }

    /// Echtzeit, wenn der Server sie in den letzten drei Minuten aufgefrischt hat, sonst Fahrplan.
    func reliability(at now: Date = .now) -> Reliability {
        guard echtzeit == true, let stand, now.timeIntervalSince1970 * 1000 - stand < 180_000 else { return .schedule }
        return .realtime
    }
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

/// Halte und Zeiten einer ÖPNV-Fahrt, um „n Halte voraus“ zu bestimmen.
struct TransitCourse: Equatable {
    var line: String
    var points: [GeoPoint]
    var names: [String]
    var path: [GeoPoint]
    /// Abfahrt bzw. Ankunft je Halt in Millisekunden.
    var times: [Double?]

    init?(_ object: MapObject) {
        guard object.typ.isTransit, object.punkte.count >= 2 else { return nil }
        line = object.linie?.ref ?? object.titel
        points = object.punkte
        names = object.haltNamen ?? []
        path = object.weg ?? []
        if let fahrt = object.fahrt, fahrt.zeiten.count == points.count {
            times = fahrt.zeiten
        } else if object.typ == .oepnvfahrzeug, let typ = object.linie?.typ, let departure = object.since {
            // Ohne echten Fahrplan: geschätzte Zeiten ab der Abfahrt.
            let start = departure.timeIntervalSince1970 * 1000
            times = TransitSimulation.arrivals(points, typ: typ, path: path).map { start + $0 * 1000 }
        } else {
            return nil
        }
    }

    init?(_ trip: TripDetail) {
        guard trip.stops.count >= 2 else { return nil }
        line = trip.name
        points = trip.stops.map(\.point)
        names = trip.stops.map(\.name)
        path = trip.points
        times = trip.stops.map { $0.dep ?? $0.arr }
    }

    /// Der `count`-te noch anzufahrende Halt (1 = nächster), höchstens der Endhalt; `nil` nach der Ankunft.
    func stop(ahead count: Int, at now: Date = .now) -> (point: GeoPoint, name: String)? {
        let t = now.timeIntervalSince1970 * 1000
        let known = times.compactMap { $0 }
        guard let first = known.first, let last = known.last, t <= last else { return nil }
        let next: Int
        if t < first {
            next = 1
        } else if let state = TransitSimulation.state(points, path: path, times: times, at: now) {
            next = state.atStop ? state.nextIndex + 1 : state.nextIndex
        } else {
            return nil
        }
        let index = min(next + max(count, 1) - 1, points.count - 1)
        let name = names.indices.contains(index) && !names[index].isEmpty ? names[index] : "Halt \(index + 1)"
        return (points[index], name)
    }
}
