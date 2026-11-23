import Foundation
import Observation

/// Schätzt, wo ein ÖPNV-Fahrzeug gerade ist. Grundlage ist ein Fahrmodell wie bei einem echten Fahrzeug
/// (`TransitMotion`): abgerundeter Fahrweg, Höchsttempo je Verkehrsart, langsamer in Kurven, weiches Bremsen davor
/// und Anfahren danach, Halt an jeder Haltestelle. Mit Fahrplan (Echtzeit) wird das Profil an die Zeiten angepasst,
/// ohne Fahrplan gilt es so, wie es ist.
enum TransitSimulation {
    /// Typische Standzeit an Zwischenhalten (Bus); je Verkehrsart siehe `TransitMotion.Kind`.
    static let dwell: TimeInterval = 20
    /// So lange vor der Abfahrt am ersten Halt und nach der Ankunft am letzten Halt ist ein Fahrzeug schon bzw. noch da.
    static let standing: TimeInterval = 300

    /// Schnelle Entfernung in Metern (flache Näherung, auf Stadtgröße genau genug).
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

    /// Index des nächstgelegenen Punkts im Fahrweg für jeden Halt, aufsteigend; `nil`, wenn ein Halt weit neben dem
    /// Fahrweg liegt. Zwischengespeichert.
    static func stopIndices(_ points: [GeoPoint], on path: [GeoPoint]) -> [Int]? {
        guard path.count >= 2 else { return nil }
        let key = IndexKey(points: points, count: path.count, first: path.first, middle: path[path.count / 2], last: path.last)
        cacheLock.lock()
        if let hit = indexCache[key] {
            cacheLock.unlock()
            return hit
        }
        cacheLock.unlock()
        var result: [Int] = []
        var from = 0
        var valid = true
        for stop in points {
            var best = from, bestDistance = Double.greatestFiniteMagnitude
            for i in from..<path.count {
                let d = meters(path[i], stop)
                if d < bestDistance { bestDistance = d; best = i }
            }
            guard bestDistance < 250 else {
                valid = false
                break
            }
            result.append(best)
            from = best
        }
        let value: [Int]? = valid ? result : nil
        cacheLock.lock()
        if indexCache.count > 400 { indexCache.removeAll() }
        indexCache[key] = value
        cacheLock.unlock()
        return value
    }

    /// Punkt nach einem Anteil der Strecke entlang eines Linienzugs.
    static func point(along path: ArraySlice<GeoPoint>, fraction: Double) -> GeoPoint? {
        guard let first = path.first else { return nil }
        let total = zip(path, path.dropFirst()).reduce(0) { $0 + meters($1.0, $1.1) }
        var remaining = total * min(max(fraction, 0), 1)
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

    /// Ankunft an jedem Halt in Sekunden ab Abfahrt am ersten Halt (ohne Fahrplan, nach dem Fahrmodell).
    static func arrivals(_ points: [GeoPoint], typ: String, path: [GeoPoint] = []) -> [TimeInterval] {
        guard let motion = TransitMotion.estimated(points, path: path, typ: typ) else { return points.isEmpty ? [] : [0] }
        return motion.arrive
    }

    static func duration(_ points: [GeoPoint], typ: String, path: [GeoPoint] = []) -> TimeInterval { arrivals(points, typ: typ, path: path).last ?? 0 }

    struct State: Equatable {
        let point: GeoPoint
        /// Nächster (oder gerade bediente) Halt.
        let nextIndex: Int
        let atStop: Bool
        /// Zurückgelegte Meter entlang des (abgerundeten) Fahrwegs.
        var progress: Double? = nil
        /// Tempo in Metern je Sekunde.
        var speed: Double = 0
    }

    /// Position zur Zeit `now` bei Abfahrt `departure` am ersten Halt (ohne Fahrplan); `nil` vor der Abfahrt und
    /// nach der Ankunft.
    static func state(_ points: [GeoPoint], typ: String, path: [GeoPoint] = [], departure: Date, at now: Date = .now) -> State? {
        guard let motion = TransitMotion.estimated(points, path: path, typ: typ) else { return nil }
        let t = now.timeIntervalSince(departure)
        guard t >= 0, t <= (motion.arrive.last ?? 0) else { return nil }
        return motion.state(at: t)
    }

    /// Motion nach echten Zeiten (Millisekunden je Halt, fehlende werden geschätzt). Die Zeit eines Halts gilt als
    /// Abfahrt, am letzten als Ankunft.
    static func motion(_ points: [GeoPoint], path: [GeoPoint], times: [Double?], typ: String = "bus") -> TransitMotion? {
        TransitMotion.scheduled(points, path: path, times: times, typ: typ)
    }

    /// Position nach echten Zeiten; `nil` vor der ersten Abfahrt und eine halbe Minute nach der Ankunft.
    static func state(_ points: [GeoPoint], path: [GeoPoint], times: [Double?], typ: String = "bus", at now: Date = .now) -> State? {
        guard let motion = motion(points, path: path, times: times, typ: typ) else { return nil }
        let t = now.timeIntervalSince1970
        guard t >= motion.depart[0], t <= (motion.arrive.last ?? 0) + 30 else { return nil }
        return motion.state(at: t)
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
        guard last >= first, let motion = TransitMotion.estimated(object.punkte, path: path, typ: line.typ) else { return [] }
        return (first...last).map { k in
            let departure = reference.addingTimeInterval(TimeInterval(k) * interval)
            return (departure, motion.state(at: now.timeIntervalSince(departure)))
        }
    }
}

/// Fahrmodell einer Fahrt, einmal berechnet und dann bei jedem Bild nur nachgeschlagen.
///
/// 1. Fahrweg: in Stücke von 5 m geteilt und gleitend gemittelt (Ecken abgerundet, keine Zacken aus OpenStreetMap).
/// 2. Tempo: höchstens das der Verkehrsart, in Kurven so langsam, wie der Radius es verlangt (Querbeschleunigung),
///    an Halten null. Vorwärts begrenzt durch die Beschleunigung, rückwärts durch die Bremsverzögerung: so wird
///    rechtzeitig vor Kurven und Halten gebremst und danach weich angefahren.
/// 3. Fahrplan: Je Abschnitt wird das Profil gleichmäßig gestreckt oder gestaucht, bis es zur Zeit passt; dabei
///    bleibt eine realistische Standzeit am Halt. Wäre es viel zu langsam, steht das Fahrzeug stattdessen länger.
final class TransitMotion: @unchecked Sendable {
    struct Kind {
        /// Höchsttempo (m/s), Anfahren und Bremsen (m/s²), Querbeschleunigung in Kurven (m/s²), Standzeit (s).
        let vmax: Double
        let accel: Double
        let decel: Double
        let lateral: Double
        let dwell: Double
        /// Ohne Fahrplan: Anteil des Höchsttempos, der im Verkehr typisch erreicht wird.
        let traffic: Double

        static func of(_ typ: String) -> Kind {
            switch typ {
            case "subway", "light_rail": Kind(vmax: 19.5, accel: 1.1, decel: 1.1, lateral: 1.0, dwell: 25, traffic: 0.9)
            case "train": Kind(vmax: 27, accel: 0.7, decel: 0.8, lateral: 0.8, dwell: 45, traffic: 0.9)
            case "tram": Kind(vmax: 14, accel: 1.0, decel: 1.1, lateral: 1.0, dwell: 20, traffic: 0.65)
            case "ferry": Kind(vmax: 6, accel: 0.25, decel: 0.3, lateral: 0.4, dwell: 60, traffic: 1)
            default: Kind(vmax: 14, accel: 1.0, decel: 1.0, lateral: 1.2, dwell: 20, traffic: 0.6)
            }
        }
    }

    /// Abgerundeter Fahrweg in Metern um einen Bezugspunkt, mit Längen.
    private let originLat: Double
    private let originLon: Double
    private let metersPerLon: Double
    private let xs: [Double]
    private let ys: [Double]
    private let lengths: [Double]
    /// Meter bis zu jedem Halt.
    let stopMeters: [Double]
    /// Ankunft und Abfahrt je Halt (Sekunden; ohne Fahrplan ab der ersten Abfahrt, sonst seit 1970).
    let arrive: [Double]
    let depart: [Double]
    /// Zeitleiste: Zeit und zurückgelegte Meter, aufsteigend.
    private let keyTimes: [Double]
    private let keyMeters: [Double]

    private init(origin: GeoPoint, metersPerLon: Double, xs: [Double], ys: [Double], lengths: [Double], stopMeters: [Double],
                 arrive: [Double], depart: [Double], keyTimes: [Double], keyMeters: [Double]) {
        originLat = origin.lat
        originLon = origin.lon
        self.metersPerLon = metersPerLon
        self.xs = xs
        self.ys = ys
        self.lengths = lengths
        self.stopMeters = stopMeters
        self.arrive = arrive
        self.depart = depart
        self.keyTimes = keyTimes
        self.keyMeters = keyMeters
    }

    // MARK: Abfragen

    /// Zustand zur Zeit `t` (vor der ersten Abfahrt am ersten Halt, nach der Ankunft am letzten).
    func state(at t: Double) -> TransitSimulation.State {
        let s = meters(at: t)
        let v = speed(at: t)
        let point = point(atMeters: s)
        // Am Halt, solange zwischen Ankunft und Abfahrt.
        for k in stopMeters.indices where t >= arrive[k] - 0.01 && t <= depart[k] + 0.01 {
            return TransitSimulation.State(point: point, nextIndex: k, atStop: true, progress: s, speed: 0)
        }
        if t < depart[0] { return TransitSimulation.State(point: point, nextIndex: 0, atStop: true, progress: s, speed: 0) }
        let next = stopMeters.firstIndex { $0 > s + 0.5 } ?? (stopMeters.count - 1)
        return TransitSimulation.State(point: point, nextIndex: next, atStop: false, progress: s, speed: v)
    }

    /// Zurückgelegte Meter zur Zeit `t`.
    func meters(at t: Double) -> Double {
        guard let first = keyTimes.first, let last = keyTimes.last else { return 0 }
        if t <= first { return keyMeters[0] }
        if t >= last { return keyMeters[keyMeters.count - 1] }
        var lo = 0, hi = keyTimes.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if keyTimes[mid] <= t { lo = mid } else { hi = mid }
        }
        let span = keyTimes[hi] - keyTimes[lo]
        let f = span > 0 ? (t - keyTimes[lo]) / span : 1
        return keyMeters[lo] + (keyMeters[hi] - keyMeters[lo]) * f
    }

    /// Tempo zur Zeit `t` (m/s).
    func speed(at t: Double) -> Double {
        let dt = 0.25
        return max(0, (meters(at: t + dt) - meters(at: t - dt)) / (2 * dt))
    }

    var totalMeters: Double { lengths.last ?? 0 }

    /// Punkt nach so vielen Metern entlang des abgerundeten Fahrwegs.
    func point(atMeters value: Double) -> GeoPoint {
        let m = min(max(value, 0), totalMeters)
        var lo = 0, hi = max(lengths.count - 1, 0)
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if lengths[mid] <= m { lo = mid } else { hi = mid }
        }
        let span = lengths.isEmpty ? 0 : lengths[hi] - lengths[lo]
        let f = span > 0 ? (m - lengths[lo]) / span : 0
        let x = xs[lo] + (xs[hi] - xs[lo]) * f, y = ys[lo] + (ys[hi] - ys[lo]) * f
        return GeoPoint(lat: originLat + y / 110_540, lon: originLon + x / metersPerLon)
    }

    // MARK: Erzeugen (zwischengespeichert)

    private struct Key: Hashable {
        let points: [GeoPoint]
        let pathCount: Int
        let pathFirst: GeoPoint?
        let pathMiddle: GeoPoint?
        let pathLast: GeoPoint?
        let times: [Double?]?
        let typ: String
        let endDwell: Bool
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [Key: TransitMotion?] = [:]

    private static func cached(_ key: Key, make: () -> TransitMotion?) -> TransitMotion? {
        lock.lock()
        if let hit = cache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()
        let value = make()
        lock.lock()
        if cache.count > 300 { cache.removeAll() }
        cache[key] = value
        lock.unlock()
        return value
    }

    private static func key(_ points: [GeoPoint], _ path: [GeoPoint], _ times: [Double?]?, _ typ: String, endDwell: Bool = false) -> Key {
        Key(points: points, pathCount: path.count, pathFirst: path.first, pathMiddle: path.isEmpty ? nil : path[path.count / 2],
            pathLast: path.last, times: times, typ: typ, endDwell: endDwell)
    }

    /// Ohne Fahrplan: Abfahrt am ersten Halt zur Zeit 0, Tempo wie im Verkehr üblich.
    static func estimated(_ points: [GeoPoint], path: [GeoPoint], typ: String) -> TransitMotion? {
        cached(key(points, path, nil, typ)) { build(points, path: path, times: nil, typ: typ, endDwell: false) }
    }

    /// Nach Fahrplan: Zeiten in Millisekunden je Halt (Abfahrt, am letzten Ankunft); fehlende werden geschätzt.
    static func scheduled(_ points: [GeoPoint], path: [GeoPoint], times: [Double?], typ: String) -> TransitMotion? {
        guard times.count == points.count, times.compactMap({ $0 }).count >= 2 else { return nil }
        return cached(key(points, path, times, typ)) { build(points, path: path, times: times, typ: typ, endDwell: false) }
    }

    /// Ein Abschnitt zwischen zwei Halten mit Abfahrt und Ankunft (Live-Karte): Das Fahrzeug kommt etwas früher an
    /// und steht dann am Halt, statt ohne Halt weiterzufahren.
    static func segment(from a: GeoPoint, to b: GeoPoint, path: [GeoPoint], dep: Double, arr: Double, typ: String) -> TransitMotion? {
        let times: [Double?] = [dep, arr]
        return cached(key([a, b], path, times, typ, endDwell: true)) { build([a, b], path: path, times: times, typ: typ, endDwell: true) }
    }

    private static func build(_ points: [GeoPoint], path: [GeoPoint], times: [Double?]?, typ: String, endDwell: Bool) -> TransitMotion? {
        guard points.count >= 2 else { return nil }
        let kind = Kind.of(typ)
        // Fahrweg: der angegebene, wenn alle Halte darauf liegen, sonst Luftlinie zwischen den Halten.
        let base: [GeoPoint] = (path.count >= 2 && TransitSimulation.stopIndices(points, on: path) != nil) ? path : points
        let origin = base[0]
        let metersPerLon = 111_320 * cos(origin.lat * .pi / 180)
        func project(_ p: GeoPoint) -> (Double, Double) { ((p.lon - origin.lon) * metersPerLon, (p.lat - origin.lat) * 110_540) }

        // 1. In 5-m-Stücke teilen.
        let step = 5.0
        var rx: [Double] = [], ry: [Double] = []
        var carry = 0.0
        var previous = project(base[0])
        rx.append(previous.0); ry.append(previous.1)
        for p in base.dropFirst() {
            let q = project(p)
            let dx = q.0 - previous.0, dy = q.1 - previous.1
            let d = (dx * dx + dy * dy).squareRoot()
            guard d > 0 else { continue }
            var at = step - carry
            while at <= d {
                rx.append(previous.0 + dx * at / d); ry.append(previous.1 + dy * at / d)
                at += step
            }
            carry = d - (at - step)
            previous = q
        }
        if carry > 0.5 { rx.append(previous.0); ry.append(previous.1) }
        guard rx.count >= 2 else { return nil }

        // 2. Gleitend mitteln (±25 m), Enden fest: rundet Ecken ab.
        let window = 5
        var xs = rx, ys = ry
        if rx.count > 2 * window {
            var sumX = 0.0, sumY = 0.0
            var prefixX = [0.0], prefixY = [0.0]
            for i in rx.indices { sumX += rx[i]; sumY += ry[i]; prefixX.append(sumX); prefixY.append(sumY) }
            for i in 1..<(rx.count - 1) {
                let w = min(window, i, rx.count - 1 - i)
                let lo = i - w, hi = i + w + 1
                xs[i] = (prefixX[hi] - prefixX[lo]) / Double(hi - lo)
                ys[i] = (prefixY[hi] - prefixY[lo]) / Double(hi - lo)
            }
        }
        var lengths = [0.0]
        for i in 1..<xs.count {
            let dx = xs[i] - xs[i - 1], dy = ys[i] - ys[i - 1]
            lengths.append(lengths[i - 1] + (dx * dx + dy * dy).squareRoot())
        }
        let n = xs.count

        // Halte auf dem abgerundeten Weg (aufsteigend, nächster Punkt).
        var stopIndex: [Int] = []
        var from = 0
        for stop in points {
            let q = project(stop)
            var best = from, bestD = Double.greatestFiniteMagnitude
            for i in from..<n {
                let d = (xs[i] - q.0) * (xs[i] - q.0) + (ys[i] - q.1) * (ys[i] - q.1)
                if d < bestD { bestD = d; best = i }
            }
            stopIndex.append(best)
            from = best
        }

        // 3. Tempogrenze aus der Krümmung.
        var limit = [Double](repeating: kind.vmax, count: n)
        for i in 1..<(n - 1) {
            let a0 = atan2(ys[i] - ys[i - 1], xs[i] - xs[i - 1])
            let a1 = atan2(ys[i + 1] - ys[i], xs[i + 1] - xs[i])
            var turn = abs(a1 - a0)
            if turn > .pi { turn = 2 * .pi - turn }
            let ds = (lengths[i + 1] - lengths[i - 1]) / 2
            guard ds > 0, turn > 1e-4 else { continue }
            let radius = ds / turn
            limit[i] = min(kind.vmax, (kind.lateral * radius).squareRoot())
        }
        let vmaxScale = times == nil ? kind.traffic : 1

        // Je Abschnitt: natürliches Profil (Zeit je Punkt ab Abfahrt).
        var natural: [[Double]] = []
        for k in 0..<(points.count - 1) {
            let i0 = stopIndex[k], i1 = max(stopIndex[k + 1], stopIndex[k])
            var v = (i0...i1).map { min(limit[$0] * vmaxScale, kind.vmax * vmaxScale) }
            v[0] = 0
            v[v.count - 1] = 0
            if v.count > 1 {
                for j in 1..<v.count {
                    let ds = lengths[i0 + j] - lengths[i0 + j - 1]
                    v[j] = min(v[j], (v[j - 1] * v[j - 1] + 2 * kind.accel * ds).squareRoot())
                }
                for j in stride(from: v.count - 2, through: 0, by: -1) {
                    let ds = lengths[i0 + j + 1] - lengths[i0 + j]
                    v[j] = min(v[j], (v[j + 1] * v[j + 1] + 2 * kind.decel * ds).squareRoot())
                }
            }
            var t = [0.0]
            for j in 1..<max(v.count, 1) {
                let ds = lengths[i0 + j] - lengths[i0 + j - 1]
                let mean = max((v[j - 1] + v[j]) / 2, 0.3)
                t.append(t[j - 1] + ds / mean)
            }
            natural.append(t)
        }

        // Zeiten je Halt.
        var arrive = [Double](repeating: 0, count: points.count)
        var depart = [Double](repeating: 0, count: points.count)
        var travel = [Double](repeating: 0, count: points.count - 1)
        if let times {
            // Fehlende Zeiten nach der natürlichen Fahrzeit zwischen bekannten Halten verteilen.
            var known = times.map { $0.map { $0 / 1000 } }
            let natTotal = natural.map { ($0.last ?? 0) + kind.dwell }
            let knownIdx = known.indices.filter { known[$0] != nil }
            for (a, b) in zip(knownIdx, knownIdx.dropFirst()) where b > a + 1 {
                let span = known[b]! - known[a]!
                let weights = (a..<b).map { natTotal[$0] }
                let sum = max(weights.reduce(0, +), 1)
                var acc = 0.0
                for k in (a + 1)..<b {
                    acc += weights[k - 1 - a]
                    known[k] = known[a]! + span * acc / sum
                }
            }
            // Vor dem ersten bzw. nach dem letzten bekannten Halt mit natürlicher Zeit fortsetzen.
            if let firstKnown = knownIdx.first, firstKnown > 0 {
                for k in stride(from: firstKnown - 1, through: 0, by: -1) { known[k] = known[k + 1]! - natTotal[k] }
            }
            if let lastKnown = knownIdx.last, lastKnown < points.count - 1 {
                for k in (lastKnown + 1)..<points.count { known[k] = known[k - 1]! + natTotal[k - 1] }
            }
            let t = known.map { $0 ?? 0 }
            depart[0] = t[0]
            arrive[0] = t[0]
            for k in 0..<(points.count - 1) {
                let gap = max(t[k + 1] - depart[k], 1)
                let nat = max(natural[k].last ?? 0, 0.5)
                let isLast = k + 1 == points.count - 1
                // Standzeit am nächsten Halt aus dem Spielraum, den der Fahrplan lässt.
                var stand: Double
                if isLast && !endDwell {
                    stand = 0
                } else {
                    let slack = gap - nat
                    let minimum = 8.0
                    stand = slack >= minimum ? min(slack, kind.dwell) : min(minimum, gap * 0.25)
                    if isLast { stand = min(stand, gap * 0.4) }
                }
                var drive = gap - stand
                // Viel zu viel Zeit bis zu einem Zwischenhalt: nicht kriechen, sondern länger am Halt warten.
                let slowest = nat / 0.4
                if !isLast, drive > slowest {
                    stand += drive - slowest
                    drive = slowest
                }
                travel[k] = drive
                arrive[k + 1] = depart[k] + drive
                depart[k + 1] = arrive[k + 1] + stand
            }
        } else {
            for k in 0..<(points.count - 1) {
                travel[k] = natural[k].last ?? 0
                arrive[k + 1] = depart[k] + travel[k]
                depart[k + 1] = arrive[k + 1] + (k + 1 == points.count - 1 ? 0 : kind.dwell)
            }
        }

        // Zeitleiste.
        var keyTimes: [Double] = [depart[0]], keyMeters: [Double] = [lengths[stopIndex[0]]]
        for k in 0..<(points.count - 1) {
            let i0 = stopIndex[k]
            let nat = natural[k]
            let scale = (nat.last ?? 0) > 0 ? travel[k] / nat.last! : 0
            for j in 1..<max(nat.count, 1) {
                keyTimes.append(depart[k] + nat[j] * scale)
                keyMeters.append(lengths[i0 + j])
            }
            if nat.count <= 1 {
                keyTimes.append(arrive[k + 1])
                keyMeters.append(lengths[stopIndex[k + 1]])
            }
            if depart[k + 1] > arrive[k + 1] {
                keyTimes.append(depart[k + 1])
                keyMeters.append(lengths[stopIndex[k + 1]])
            }
        }
        // Streng aufsteigende Zeiten (gleiche Zeitpunkte zusammenfassen).
        var tsOut: [Double] = [], msOut: [Double] = []
        for (t, m) in zip(keyTimes, keyMeters) {
            if let last = tsOut.last, t <= last {
                msOut[msOut.count - 1] = m
                continue
            }
            tsOut.append(t)
            msOut.append(m)
        }

        return TransitMotion(origin: origin, metersPerLon: metersPerLon, xs: xs, ys: ys, lengths: lengths,
                             stopMeters: stopIndex.map { lengths[$0] }, arrive: arrive, depart: depart,
                             keyTimes: tsOut, keyMeters: msOut)
    }
}

/// Takt der ÖPNV-Fahrzeuge auf der Karte (siehe `MapScreen.transitClock`).
@MainActor
@Observable
final class TransitClock {
    var now = Date.now
}

/// Hält angezeigte Fahrzeuge ruhig, wenn sich ihr Fahrplan ändert (neue Echtzeit): Die Abweichung zwischen gezeigter
/// und neu berechneter Position wird über etwa drei Sekunden abgebaut (das Fahrzeug fährt kurz etwas schneller oder
/// langsamer), rückwärts fährt es nie. Sehr große Abweichungen (über 400 m) gelten als echte Korrektur.
@MainActor
final class TransitSmoother {
    private var shown: [String: (meters: Double, offset: Double, time: Double, motion: ObjectIdentifier)] = [:]

    func point(id: String, motion: TransitMotion, at now: Date) -> GeoPoint {
        let t = now.timeIntervalSince1970
        let target = motion.meters(at: t)
        var offset = 0.0
        var next = target
        if let previous = shown[id] {
            let dt = min(max(t - previous.time, 0), 2)
            // Neue Berechnung: Abweichung zur bisher gezeigten Stelle merken und abklingen lassen.
            offset = previous.motion == ObjectIdentifier(motion) ? previous.offset : previous.meters - target
            if abs(offset) > 400 { offset = 0 }
            offset *= exp(-dt / 3)
            if abs(offset) < 0.05 { offset = 0 }
            next = max(target + offset, previous.meters)
            offset = next - target
        }
        shown[id] = (next, offset, t, ObjectIdentifier(motion))
        if shown.count > 300 { shown.removeAll() }
        return motion.point(atMeters: next)
    }
}
