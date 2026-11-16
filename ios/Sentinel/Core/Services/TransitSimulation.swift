import Foundation

/// Schätzt, wo ein ÖPNV-Fahrzeug gerade ist: Fahrt zwischen den Halten mit typischem Tempo der Verkehrsart
/// (wie beim ÖPNV-Fluchtraum), 30 Sekunden Halt. Keine Echtzeit- oder Fahrplandaten.
enum TransitSimulation {
    static let dwell: TimeInterval = 30

    /// Reisegeschwindigkeit in Metern Luftlinie je Sekunde.
    static func speed(_ typ: String) -> Double {
        let perMinute: Double = switch typ {
        case "subway", "light_rail": 520
        case "train": 650
        case "tram": 330
        case "ferry": 230
        default: 300
        }
        return perMinute / 60
    }

    /// Ankunft an jedem Halt in Sekunden ab Abfahrt am ersten Halt.
    static func arrivals(_ points: [GeoPoint], typ: String) -> [TimeInterval] {
        guard !points.isEmpty else { return [] }
        var result: [TimeInterval] = [0]
        let v = speed(typ)
        for i in 1..<points.count {
            let previous = result[i - 1] + (i > 1 ? dwell : 0)
            result.append(previous + points[i - 1].distance(to: points[i]) / v)
        }
        return result
    }

    static func duration(_ points: [GeoPoint], typ: String) -> TimeInterval { arrivals(points, typ: typ).last ?? 0 }

    struct State: Equatable {
        let point: GeoPoint
        /// Nächster (oder gerade bediente) Halt.
        let nextIndex: Int
        let atStop: Bool
    }

    /// Position zur Zeit `now` bei Abfahrt `departure` am ersten Halt; `nil` vor der Abfahrt und nach der Ankunft.
    static func state(_ points: [GeoPoint], typ: String, departure: Date, at now: Date = .now) -> State? {
        let t = now.timeIntervalSince(departure)
        let times = arrivals(points, typ: typ)
        guard points.count >= 2, t >= 0, let end = times.last, t <= end else { return nil }
        for i in 1..<points.count {
            let start = times[i - 1] + (i > 1 ? dwell : 0)
            if t < times[i - 1] + (i > 1 ? dwell : 0), t >= times[i - 1] {
                return State(point: points[i - 1], nextIndex: i - 1, atStop: true)
            }
            if t <= times[i] {
                let fraction = times[i] > start ? (t - start) / (times[i] - start) : 1
                let a = points[i - 1], b = points[i]
                return State(point: GeoPoint(lat: a.lat + (b.lat - a.lat) * fraction, lon: a.lon + (b.lon - a.lon) * fraction), nextIndex: i, atStop: false)
            }
        }
        return State(point: points[points.count - 1], nextIndex: points.count - 1, atStop: true)
    }

    /// Fahrzeuge im Takt, die sich gerade auf dem Abschnitt befinden: jeweils Abfahrtszeit am ersten Halt und Zustand.
    static func vehicles(on object: MapObject, at now: Date = .now) -> [(departure: Date, state: State)] {
        guard object.typ == .oepnvlinie, let takt = object.takt, takt > 0, let line = object.linie, let reference = object.since else { return [] }
        let interval = TimeInterval(takt * 60)
        let total = duration(object.punkte, typ: line.typ)
        // Alle Abfahrten, deren Fahrt jetzt läuft: reference + k * interval in [now - total, now].
        let first = Int(((now.timeIntervalSince(reference) - total) / interval).rounded(.up))
        let last = Int((now.timeIntervalSince(reference) / interval).rounded(.down))
        guard last >= first else { return [] }
        return (first...last).compactMap { k in
            let departure = reference.addingTimeInterval(TimeInterval(k) * interval)
            return state(object.punkte, typ: line.typ, departure: departure, at: now).map { (departure, $0) }
        }
    }
}
