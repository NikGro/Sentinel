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

    /// Index des nächstgelegenen Punkts im Fahrweg für jeden Halt, aufsteigend.
    static func stopIndices(_ points: [GeoPoint], on path: [GeoPoint]) -> [Int]? {
        guard path.count >= 2 else { return nil }
        var result: [Int] = []
        var from = 0
        for stop in points {
            var best = from, bestDistance = Double.greatestFiniteMagnitude
            for i in from..<path.count {
                let d = path[i].distance(to: stop)
                if d < bestDistance { bestDistance = d; best = i }
            }
            guard bestDistance < 250 else { return nil }
            result.append(best)
            from = best
        }
        return result
    }

    static func length(_ path: ArraySlice<GeoPoint>) -> Double {
        zip(path, path.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
    }

    /// Punkt nach einem Anteil der Strecke entlang eines Teilstücks des Fahrwegs.
    static func point(along path: ArraySlice<GeoPoint>, fraction: Double) -> GeoPoint? {
        guard let first = path.first else { return nil }
        var remaining = length(path) * min(max(fraction, 0), 1)
        for (a, b) in zip(path, path.dropFirst()) {
            let d = a.distance(to: b)
            if remaining <= d, d > 0 {
                let f = remaining / d
                return GeoPoint(lat: a.lat + (b.lat - a.lat) * f, lon: a.lon + (b.lon - a.lon) * f)
            }
            remaining -= d
        }
        return path.last ?? first
    }

    /// Ankunft an jedem Halt in Sekunden ab Abfahrt am ersten Halt; mit Fahrweg nach dessen Länge.
    static func arrivals(_ points: [GeoPoint], typ: String, path: [GeoPoint] = []) -> [TimeInterval] {
        guard !points.isEmpty else { return [] }
        let indices = stopIndices(points, on: path)
        var result: [TimeInterval] = [0]
        let v = speed(typ)
        for i in 1..<points.count {
            let previous = result[i - 1] + (i > 1 ? dwell : 0)
            // Fahrweg ist länger als die Luftlinie: Tempo darauf etwa ein Viertel höher.
            let meters = indices.map { length(path[$0[i - 1]...$0[i]]) / 1.25 } ?? points[i - 1].distance(to: points[i])
            result.append(previous + meters / v)
        }
        return result
    }

    static func duration(_ points: [GeoPoint], typ: String, path: [GeoPoint] = []) -> TimeInterval { arrivals(points, typ: typ, path: path).last ?? 0 }

    struct State: Equatable {
        let point: GeoPoint
        /// Nächster (oder gerade bediente) Halt.
        let nextIndex: Int
        let atStop: Bool
    }

    /// Position zur Zeit `now` bei Abfahrt `departure` am ersten Halt; `nil` vor der Abfahrt und nach der Ankunft.
    static func state(_ points: [GeoPoint], typ: String, path: [GeoPoint] = [], departure: Date, at now: Date = .now) -> State? {
        let t = now.timeIntervalSince(departure)
        let times = arrivals(points, typ: typ, path: path)
        let indices = stopIndices(points, on: path)
        guard points.count >= 2, t >= 0, let end = times.last, t <= end else { return nil }
        for i in 1..<points.count {
            let start = times[i - 1] + (i > 1 ? dwell : 0)
            if t < times[i - 1] + (i > 1 ? dwell : 0), t >= times[i - 1] {
                return State(point: points[i - 1], nextIndex: i - 1, atStop: true)
            }
            if t <= times[i] {
                let fraction = times[i] > start ? (t - start) / (times[i] - start) : 1
                let a = points[i - 1], b = points[i]
                if let indices, let along = point(along: path[indices[i - 1]...indices[i]], fraction: fraction) {
                    return State(point: along, nextIndex: i, atStop: false)
                }
                return State(point: GeoPoint(lat: a.lat + (b.lat - a.lat) * fraction, lon: a.lon + (b.lon - a.lon) * fraction), nextIndex: i, atStop: false)
            }
        }
        return State(point: points[points.count - 1], nextIndex: points.count - 1, atStop: true)
    }

    /// Fahrzeuge im Takt, die sich gerade auf dem Abschnitt befinden: jeweils Abfahrtszeit am ersten Halt und Zustand.
    static func vehicles(on object: MapObject, at now: Date = .now) -> [(departure: Date, state: State)] {
        guard object.typ == .oepnvlinie, let takt = object.takt, takt > 0, let line = object.linie, let reference = object.since else { return [] }
        let interval = TimeInterval(takt * 60)
        let path = object.weg ?? []
        let total = duration(object.punkte, typ: line.typ, path: path)
        // Alle Abfahrten, deren Fahrt jetzt läuft: reference + k * interval in [now - total, now].
        let first = Int(((now.timeIntervalSince(reference) - total) / interval).rounded(.up))
        let last = Int((now.timeIntervalSince(reference) / interval).rounded(.down))
        guard last >= first else { return [] }
        return (first...last).compactMap { k in
            let departure = reference.addingTimeInterval(TimeInterval(k) * interval)
            return state(object.punkte, typ: line.typ, path: path, departure: departure, at: now).map { (departure, $0) }
        }
    }
}
