import Foundation

/// Schätzt, wo ein ÖPNV-Fahrzeug gerade ist: Fahrt zwischen den Halten mit typischem Tempo der Verkehrsart
/// (wie beim ÖPNV-Fluchtraum), 30 Sekunden Halt. Keine Echtzeit- oder Fahrplandaten.
enum TransitSimulation {
    static let dwell: TimeInterval = 30
    /// So lange vor der Abfahrt am ersten Halt und nach der Ankunft am letzten Halt ist ein Fahrzeug schon bzw. noch da.
    static let standing: TimeInterval = 300

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

    /// Schnelle Entfernung in Metern (flache Näherung, auf Stadtgröße genau genug). Ohne CLLocation, denn die
    /// Positionen der ÖPNV-Fahrzeuge werden alle zwei Sekunden für viele Punkte berechnet.
    static func meters(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let x = (b.lon - a.lon) * 111_320 * cos((a.lat + b.lat) * .pi / 360)
        let y = (b.lat - a.lat) * 110_540
        return (x * x + y * y).squareRoot()
    }

    private struct IndexKey: Hashable {
        let points: [GeoPoint]
        let count: Int
        let first: GeoPoint?
        let middle: GeoPoint?
        let last: GeoPoint?
    }

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var indexCache: [IndexKey: [Int]?] = [:]

    /// Index des nächstgelegenen Punkts im Fahrweg für jeden Halt, aufsteigend. Zwischengespeichert, denn Halte
    /// und Fahrweg einer Markierung ändern sich selten, die Abfrage kommt aber bei jedem Bildaufbau.
    static func stopIndices(_ points: [GeoPoint], on path: [GeoPoint]) -> [Int]? {
        guard path.count >= 2 else { return nil }
        let key = IndexKey(points: points, count: path.count, first: path.first, middle: path[path.count / 2], last: path.last)
        cacheLock.lock()
        if let hit = indexCache[key] {
            cacheLock.unlock()
            return hit
        }
        cacheLock.unlock()
        let result = computeStopIndices(points, on: path)
        cacheLock.lock()
        if indexCache.count > 400 { indexCache.removeAll() }
        indexCache[key] = result
        cacheLock.unlock()
        return result
    }

    private static func computeStopIndices(_ points: [GeoPoint], on path: [GeoPoint]) -> [Int]? {
        var result: [Int] = []
        var from = 0
        for stop in points {
            var best = from, bestDistance = Double.greatestFiniteMagnitude
            for i in from..<path.count {
                let d = meters(path[i], stop)
                if d < bestDistance { bestDistance = d; best = i }
            }
            guard bestDistance < 250 else { return nil }
            result.append(best)
            from = best
        }
        return result
    }

    static func length(_ path: ArraySlice<GeoPoint>) -> Double {
        zip(path, path.dropFirst()).reduce(0) { $0 + meters($1.0, $1.1) }
    }

    /// Punkt nach einem Anteil der Strecke entlang eines Teilstücks des Fahrwegs.
    static func point(along path: ArraySlice<GeoPoint>, fraction: Double) -> GeoPoint? {
        guard let first = path.first else { return nil }
        var remaining = length(path) * min(max(fraction, 0), 1)
        for (a, b) in zip(path, path.dropFirst()) {
            let d = meters(a, b)
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
            let distance = indices.map { length(path[$0[i - 1]...$0[i]]) / 1.25 } ?? meters(points[i - 1], points[i])
            result.append(previous + distance / v)
        }
        return result
    }

    static func duration(_ points: [GeoPoint], typ: String, path: [GeoPoint] = []) -> TimeInterval { arrivals(points, typ: typ, path: path).last ?? 0 }

    struct State: Equatable {
        let point: GeoPoint
        /// Nächster (oder gerade bediente) Halt.
        let nextIndex: Int
        let atStop: Bool
        /// Zurückgelegte Meter entlang des Fahrwegs (nur mit Fahrweg), für ein gleichmäßiges Nachführen.
        var progress: Double? = nil
    }

    // MARK: Fahrweg mit Kurven

    /// Fahrweg mit aufsummierten Längen und einem Kurvenaufschlag: Jede Richtungsänderung zählt wie zusätzliche
    /// Strecke, so fährt das Fahrzeug in Kurven langsamer und auf Geraden schneller, bei gleicher Gesamtzeit.
    final class PathGeometry: @unchecked Sendable {
        let points: [GeoPoint]
        /// Meter bis zu jedem Punkt.
        let cumulative: [Double]
        /// „Gefühlte“ Meter bis zu jedem Punkt (mit Kurvenaufschlag).
        let effective: [Double]

        /// Aufschlag in Metern je Bogenmaß Richtungsänderung (90° kosten so viel Zeit wie etwa 70 m Gerade).
        static let cornerMeters = 45.0

        init(_ points: [GeoPoint]) {
            self.points = points
            var cumulative: [Double] = [0], effective: [Double] = [0]
            func bearing(_ a: GeoPoint, _ b: GeoPoint) -> Double {
                atan2((b.lon - a.lon) * cos(a.lat * .pi / 180), b.lat - a.lat)
            }
            func turn(at k: Int) -> Double {
                guard k > 0, k < points.count - 1 else { return 0 }
                var d = abs(bearing(points[k], points[k + 1]) - bearing(points[k - 1], points[k]))
                if d > .pi { d = 2 * .pi - d }
                return d
            }
            for k in 1..<max(points.count, 1) {
                let length = TransitSimulation.meters(points[k - 1], points[k])
                cumulative.append(cumulative[k - 1] + length)
                // Die Hälfte der Kurve an jedem Ende des Teilstücks.
                effective.append(effective[k - 1] + length + Self.cornerMeters * (turn(at: k - 1) + turn(at: k)) / 2)
            }
            self.cumulative = cumulative
            self.effective = effective
        }

        /// Punkt nach so vielen Metern entlang des Wegs.
        func point(atMeters meters: Double) -> GeoPoint {
            guard let last = points.last else { return GeoPoint(lat: 0, lon: 0) }
            let m = min(max(meters, 0), cumulative.last ?? 0)
            guard let k = cumulative.firstIndex(where: { $0 >= m }), k > 0 else { return points.first ?? last }
            let span = cumulative[k] - cumulative[k - 1]
            let f = span > 0 ? (m - cumulative[k - 1]) / span : 1
            let a = points[k - 1], b = points[k]
            return GeoPoint(lat: a.lat + (b.lat - a.lat) * f, lon: a.lon + (b.lon - a.lon) * f)
        }

        /// Echte Meter zu „gefühlten“ Metern (Umkehrung des Kurvenaufschlags).
        func meters(atEffective value: Double) -> Double {
            let e = min(max(value, 0), effective.last ?? 0)
            guard let k = effective.firstIndex(where: { $0 >= e }), k > 0 else { return 0 }
            let span = effective[k] - effective[k - 1]
            let f = span > 0 ? (e - effective[k - 1]) / span : 1
            return cumulative[k - 1] + (cumulative[k] - cumulative[k - 1]) * f
        }

        /// Fahrt von Punkt `a` bis Punkt `b` nach Zeitanteil `x`: anfahren, mit Kurven langsamer fahren, bremsen.
        func progress(from a: Int, to b: Int, timeFraction x: Double) -> Double {
            let start = effective[a], end = effective[b]
            return meters(atEffective: start + (end - start) * TransitSimulation.travelFraction(x))
        }
    }

    nonisolated(unsafe) private static var geometryCache: [IndexKey: PathGeometry] = [:]

    /// Zwischengespeicherte Geometrie eines Fahrwegs (ändert sich selten, wird aber zehnmal je Sekunde gebraucht).
    static func geometry(_ path: [GeoPoint]) -> PathGeometry? {
        guard path.count >= 2 else { return nil }
        let key = IndexKey(points: [], count: path.count, first: path.first, middle: path[path.count / 2], last: path.last)
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let hit = geometryCache[key] { return hit }
        if geometryCache.count > 200 { geometryCache.removeAll() }
        let geometry = PathGeometry(path)
        geometryCache[key] = geometry
        return geometry
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
                let x = times[i] > start ? (t - start) / (times[i] - start) : 1
                if let indices, let geometry = TransitSimulation.geometry(path) {
                    let meters = geometry.progress(from: indices[i - 1], to: indices[i], timeFraction: x)
                    return State(point: geometry.point(atMeters: meters), nextIndex: i, atStop: false, progress: meters)
                }
                let fraction = travelFraction(x)
                let a = points[i - 1], b = points[i]
                return State(point: GeoPoint(lat: a.lat + (b.lat - a.lat) * fraction, lon: a.lon + (b.lon - a.lon) * fraction), nextIndex: i, atStop: false)
            }
        }
        return State(point: points[points.count - 1], nextIndex: points.count - 1, atStop: true)
    }

    /// Anteil des Wegs nach Anteil der Fahrzeit zwischen zwei Halten: Trapezprofil mit je einem Fünftel der Zeit zum
    /// Beschleunigen und Bremsen (wie auf dem Server).
    static func travelFraction(_ t: Double, ramp: Double = 0.2) -> Double {
        let x = min(max(t, 0), 1)
        let vmax = 1 / (1 - ramp)
        if x < ramp { return vmax * x * x / (2 * ramp) }
        if x > 1 - ramp { return 1 - vmax * (1 - x) * (1 - x) / (2 * ramp) }
        return vmax * (x - ramp / 2)
    }

    /// Standzeit an Zwischenhalten bei echten Zeiten: höchstens 20 Sekunden, bei kurzen Abständen ein Viertel davon.
    static func realDwell(between ti: Double, and tj: Double) -> Double { min(20_000, max(0, tj - ti) * 0.25) }

    /// Position nach echten Zeiten (Fahrplan mit Echtzeit) an jedem Halt; fehlende Zeiten werden übersprungen. Die Zeit
    /// eines Halts gilt als Abfahrt: Davor steht das Fahrzeug kurz am Halt (Zwischenhalte), dazwischen fährt es an,
    /// wird in Kurven langsamer und bremst vor dem nächsten Halt.
    static func state(_ points: [GeoPoint], path: [GeoPoint], times: [Double?], at now: Date = .now) -> State? {
        guard points.count >= 2, times.count == points.count else { return nil }
        let t = now.timeIntervalSince1970 * 1000
        let known = times.enumerated().compactMap { index, time in time.map { (index, $0) } }
        guard let first = known.first, let last = known.last, t >= first.1, t <= last.1 + 30_000 else { return nil }
        let indices = stopIndices(points, on: path)
        let geometry = indices == nil ? nil : TransitSimulation.geometry(path)
        func atStop(_ k: Int) -> State {
            if let indices, let geometry {
                let meters = geometry.cumulative[indices[k]]
                return State(point: geometry.point(atMeters: meters), nextIndex: k, atStop: true, progress: meters)
            }
            return State(point: points[k], nextIndex: k, atStop: true)
        }
        for pair in zip(known, known.dropFirst()) {
            let (i, ti) = pair.0, (j, tj) = pair.1
            guard t <= tj else { continue }
            let arrive = j == last.0 ? tj : tj - realDwell(between: ti, and: tj)
            if t >= arrive { return atStop(j) }
            let x = arrive > ti ? (t - ti) / (arrive - ti) : 1
            if let indices, let geometry {
                let meters = geometry.progress(from: indices[i], to: indices[j], timeFraction: x)
                return State(point: geometry.point(atMeters: meters), nextIndex: j, atStop: x <= 0, progress: meters)
            }
            let fraction = travelFraction(x)
            let a = points[i], b = points[j]
            return State(point: GeoPoint(lat: a.lat + (b.lat - a.lat) * fraction, lon: a.lon + (b.lon - a.lon) * fraction), nextIndex: j, atStop: false)
        }
        return atStop(last.0)
    }

    /// Ankunft am Endhalt: echte Zeit, sonst geschätzt.
    static func endTime(of object: MapObject) -> Date? {
        if let last = object.fahrt?.zeiten.compactMap({ $0 }).last { return Date(timeIntervalSince1970: last / 1000) }
        guard let line = object.linie, let departure = object.since else { return nil }
        return departure.addingTimeInterval(duration(object.punkte, typ: line.typ, path: object.weg ?? []))
    }

    /// Fahrzeuge im Takt, die sich gerade auf dem Abschnitt befinden: jeweils Abfahrtszeit am ersten Halt und Zustand.
    static func vehicles(on object: MapObject, at now: Date = .now) -> [(departure: Date, state: State)] {
        guard object.typ == .oepnvlinie, let takt = object.takt, takt > 0, let line = object.linie, let reference = object.since else { return [] }
        let interval = TimeInterval(takt * 60)
        let path = object.weg ?? []
        let total = duration(object.punkte, typ: line.typ, path: path)
        // Alle Fahrten, deren Fahrzeug jetzt da ist: unterwegs oder bis zu fünf Minuten vor der Abfahrt bzw. nach der
        // Ankunft an den Endhalten stehend.
        let elapsed = now.timeIntervalSince(reference)
        let first = Int(((elapsed - total - standing) / interval).rounded(.up))
        let last = Int(((elapsed + standing) / interval).rounded(.down))
        guard last >= first, let start = object.punkte.first, let end = object.punkte.last else { return [] }
        return (first...last).compactMap { k in
            let departure = reference.addingTimeInterval(TimeInterval(k) * interval)
            if let running = state(object.punkte, typ: line.typ, path: path, departure: departure, at: now) { return (departure, running) }
            if now < departure { return (departure, State(point: start, nextIndex: 0, atStop: true)) }
            return (departure, State(point: end, nextIndex: object.punkte.count - 1, atStop: true))
        }
    }
}

/// Hält die angezeigten ÖPNV-Fahrzeuge ruhig: Korrigiert die Echtzeit ein Fahrzeug ein Stück zurück (neue Verspätung),
/// wartet es, statt zurückzuspringen, bis die Berechnung es wieder einholt. Größere Sprünge nach vorn werden über
/// einige Schritte verteilt. Große Abweichungen (über 150 m) gelten als echte Korrektur und werden übernommen.
@MainActor
final class TransitSmoother {
    private var shown: [String: Double] = [:]

    func point(id: String, state: TransitSimulation.State, path: [GeoPoint]) -> GeoPoint {
        guard let target = state.progress, let geometry = TransitSimulation.geometry(path) else { return state.point }
        var next = target
        if let previous = shown[id] {
            let delta = target - previous
            if delta < 0, delta > -150 {
                next = previous
            } else if delta > 25, delta < 150 {
                // Etwa ein Fünftel je Schritt (zehn Schritte je Sekunde): nach einer halben Sekunde fast eingeholt.
                next = previous + delta * 0.2
            }
        }
        shown[id] = next
        if shown.count > 300 { shown.removeAll() }
        return geometry.point(atMeters: next)
    }
}
