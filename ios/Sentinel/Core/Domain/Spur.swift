import CoreLocation
import Foundation
import SwiftUI

// Spuren: aufgezeichneter Standortverlauf (Server) und was die App daraus macht (Abschnitte, Lücken, Standzeiten).

/// Wessen Spur: Fahnder, Ziel, Fahrzeug oder Tracker.
struct SpurSubject: Hashable, Identifiable, Sendable {
    enum Art: String, Sendable { case member, target, vehicle, tracker }
    let art: Art
    let id: String

    var key: String { "\(art.rawValue):\(id)" }
}

/// Woher ein Punkt der Spur kam.
enum SpurQuelle: String, Codable, Sendable {
    case gps, tracker, a, oepnv, hand, besatzung, abgestellt

    var title: String {
        switch self {
        case .gps: "GPS des Telefons"
        case .tracker: "Tracker"
        case .a: "A-Position"
        case .oepnv: "ÖPNV-Fahrt"
        case .hand: "Von Hand gesetzt"
        case .besatzung: "Standort der Besatzung"
        case .abgestellt: "Abgestellt"
        }
    }

    var symbol: String {
        switch self {
        case .gps: "location.fill"
        case .tracker: "sensor.tag.radiowaves.forward.fill"
        case .a: "a.circle.fill"
        case .oepnv: Fortbewegung.oepnv.symbolName
        case .hand: "hand.point.up.left.fill"
        case .besatzung: "car.fill"
        case .abgestellt: "parkingsign"
        }
    }

    /// Farbe des Abschnitts auf der Karte.
    var color: Color {
        switch self {
        case .gps: Color(hex: "#0A84FF")
        case .tracker: Color(hex: "#FF9F0A")
        case .a: Color(hex: "#FF453A")
        case .oepnv: Color(hex: "#30D158")
        case .hand: Color(hex: "#8E8E93")
        case .besatzung: Color(hex: "#5E5CE6")
        case .abgestellt: Color(hex: "#8E8E93")
        }
    }

    /// Meldet sich die Quelle laufend? Dann ist eine lange Pause eine Datenlücke, keine Standzeit.
    var isLive: Bool { self != .hand && self != .abgestellt }
}

struct SpurPunkt: Identifiable, Hashable, Sendable {
    let point: GeoPoint
    let date: Date
    /// Vom Gerät gemeldete Geschwindigkeit in m/s.
    let speed: Double?
    let quelle: SpurQuelle
    let info: String?

    var id: TimeInterval { date.timeIntervalSince1970 }
}

/// Eine Spur im gewählten Zeitraum, aufbereitet für die Karte.
struct Spur: Identifiable, Sendable {
    let subject: SpurSubject
    let punkte: [SpurPunkt]

    var id: String { subject.key }

    /// Zusammenhängender Abschnitt mit einer Quelle; `gap` heißt: dazwischen fehlen Daten.
    struct Abschnitt: Identifiable, Sendable {
        let id: Int
        let quelle: SpurQuelle
        let coordinates: [CLLocationCoordinate2D]
        let gap: Bool
    }

    /// Zeitraum, in dem das Ding (fast) an einer Stelle stand.
    struct Standzeit: Identifiable, Sendable {
        let id: Int
        let point: GeoPoint
        let von: Date
        let bis: Date
        var dauer: TimeInterval { bis.timeIntervalSince(von) }
    }

    static let gapSeconds: TimeInterval = 10 * 60
    static let gapMeters: Double = 250
    static let stopRadius: Double = 40
    static let stopSeconds: TimeInterval = 3 * 60

    /// Abschnitte nach Quelle. Fehlen bei einer laufenden Quelle länger Punkte und hat sich das Ding dabei weit bewegt,
    /// wird die Verbindung gestrichelt (Lücke), damit niemand sie für eine gefahrene Strecke hält.
    var abschnitte: [Abschnitt] {
        var result: [Abschnitt] = []
        var current: [CLLocationCoordinate2D] = []
        var quelle = punkte.first?.quelle ?? .gps
        func flush(gap: Bool = false) {
            if current.count >= 2 { result.append(Abschnitt(id: result.count, quelle: quelle, coordinates: current, gap: gap)) }
        }
        for (index, punkt) in punkte.enumerated() {
            guard index > 0 else {
                current = [punkt.point.coordinate]
                continue
            }
            let previous = punkte[index - 1]
            let isGap = punkt.date.timeIntervalSince(previous.date) > Self.gapSeconds && previous.point.distance(to: punkt.point) > Self.gapMeters
            if isGap {
                flush()
                result.append(Abschnitt(id: result.count, quelle: punkt.quelle, coordinates: [previous.point.coordinate, punkt.point.coordinate], gap: true))
                current = [punkt.point.coordinate]
                quelle = punkt.quelle
            } else if punkt.quelle != quelle {
                current.append(punkt.point.coordinate)
                flush()
                current = [punkt.point.coordinate]
                quelle = punkt.quelle
            } else {
                current.append(punkt.point.coordinate)
            }
        }
        flush()
        return result
    }

    /// Standzeiten: mindestens drei Minuten innerhalb von 40 m.
    var standzeiten: [Standzeit] {
        var result: [Standzeit] = []
        var start = 0
        while start < punkte.count {
            var end = start
            while end + 1 < punkte.count, punkte[end + 1].point.distance(to: punkte[start].point) <= Self.stopRadius { end += 1 }
            let von = punkte[start].date
            // Bis zum nächsten Punkt, der woanders liegt: Erst dann hat es sich bewegt.
            let bis = end + 1 < punkte.count ? punkte[end + 1].date : punkte[end].date
            if bis.timeIntervalSince(von) >= Self.stopSeconds, end > start || end + 1 < punkte.count {
                result.append(Standzeit(id: result.count, point: punkte[start].point, von: von, bis: bis))
            }
            start = end + 1
        }
        return result
    }

    /// Geschwindigkeit an einem Punkt: vom Gerät gemeldet, sonst aus dem Abstand zu den Nachbarpunkten geschätzt.
    func speed(at index: Int) -> (value: Double, estimated: Bool)? {
        if let speed = punkte[index].speed { return (speed, false) }
        let neighbours = [index - 1, index + 1].filter { punkte.indices.contains($0) }
        let estimates = neighbours.compactMap { other -> Double? in
            let seconds = abs(punkte[other].date.timeIntervalSince(punkte[index].date))
            guard seconds > 0, seconds < Self.gapSeconds else { return nil }
            return punkte[other].point.distance(to: punkte[index].point) / seconds
        }
        guard !estimates.isEmpty else { return nil }
        return (estimates.reduce(0, +) / Double(estimates.count), true)
    }

    /// Wo das Ding zu einem Zeitpunkt war (zwischen zwei Punkten linear).
    func position(at date: Date) -> GeoPoint? {
        guard let first = punkte.first, let last = punkte.last, date >= first.date, date <= last.date else { return nil }
        guard let next = punkte.firstIndex(where: { $0.date >= date }) else { return last.point }
        guard next > 0 else { return punkte[0].point }
        let a = punkte[next - 1], b = punkte[next]
        let span = b.date.timeIntervalSince(a.date)
        // In einer Lücke keine erfundene Position.
        if span > Self.gapSeconds, a.point.distance(to: b.point) > Self.gapMeters { return nil }
        let f = span > 0 ? date.timeIntervalSince(a.date) / span : 0
        return GeoPoint(lat: a.point.lat + (b.point.lat - a.point.lat) * f, lon: a.point.lon + (b.point.lon - a.point.lon) * f)
    }

    /// Liegt zwischen Punkt `index` und dem nächsten eine Lücke (lange ohne Daten und weit bewegt)?
    func isGap(after index: Int) -> Bool {
        guard punkte.indices.contains(index + 1) else { return true }
        let a = punkte[index], b = punkte[index + 1]
        return b.date.timeIntervalSince(a.date) > Self.gapSeconds && a.point.distance(to: b.point) > Self.gapMeters
    }

    /// Stelle auf der Spur: zwischen Punkt `index` und dem nächsten beim Anteil `fraction` (0 = genau der Punkt).
    /// Zwischen zwei echten Punkten werden Ort, Zeit und Tempo gleichmäßig angenommen.
    func sample(index: Int, fraction: Double) -> (punkt: SpurPunkt, speed: (value: Double, estimated: Bool)?, between: Bool) {
        let f = min(max(fraction, 0), 1)
        guard f > 0, punkte.indices.contains(index + 1), !isGap(after: index) else { return (punkte[index], speed(at: index), false) }
        let a = punkte[index], b = punkte[index + 1]
        let point = GeoPoint(lat: a.point.lat + (b.point.lat - a.point.lat) * f, lon: a.point.lon + (b.point.lon - a.point.lon) * f)
        let date = a.date.addingTimeInterval(b.date.timeIntervalSince(a.date) * f)
        var speed: (value: Double, estimated: Bool)?
        if let va = a.speed, let vb = b.speed {
            speed = (va + (vb - va) * f, true)
        } else {
            let seconds = b.date.timeIntervalSince(a.date)
            if seconds > 0 { speed = (a.point.distance(to: b.point) / seconds, true) }
        }
        let punkt = SpurPunkt(point: point, date: date, speed: speed?.value, quelle: a.quelle, info: a.info)
        return (punkt, speed, true)
    }

    /// Angetippte Stelle: nächste Stelle auf der Linie (nicht nur der nächste echte Punkt), gemessen auf dem
    /// Bildschirm. `screen` rechnet einen Ort in Bildschirmpunkte um. Über Lücken nur die echten Punkte.
    func hit(at tap: CGPoint, screen: (GeoPoint) -> CGPoint?) -> (index: Int, fraction: Double, distance: CGFloat)? {
        let points = punkte.map { screen($0.point) }
        var best: (index: Int, fraction: Double, distance: CGFloat)?
        func consider(_ index: Int, _ fraction: Double, _ d: CGFloat) {
            if best == nil || d < best!.distance { best = (index, fraction, d) }
        }
        for i in points.indices {
            guard let a = points[i] else { continue }
            consider(i, 0, hypot(tap.x - a.x, tap.y - a.y))
            guard i + 1 < points.count, let b = points[i + 1], !isGap(after: i) else { continue }
            let dx = b.x - a.x, dy = b.y - a.y
            let length2 = dx * dx + dy * dy
            guard length2 > 0 else { continue }
            let t = min(max(((tap.x - a.x) * dx + (tap.y - a.y) * dy) / length2, 0), 1)
            let px = a.x + dx * t, py = a.y + dy * t
            consider(i, Double(t), hypot(tap.x - px, tap.y - py))
        }
        // Am Ende eines Abschnitts als der nächste Punkt selbst.
        if let hit = best, hit.fraction > 0.999, punkte.indices.contains(hit.index + 1) { return (hit.index + 1, 0, hit.distance) }
        return best
    }

    /// Nächster Punkt zu einer Stelle, mit Abstand in Metern.
    func nearest(to point: GeoPoint) -> (index: Int, distance: Double)? {
        var best: (Int, Double)?
        for (index, punkt) in punkte.enumerated() {
            let d = punkt.point.distance(to: point)
            if best == nil || d < best!.1 { best = (index, d) }
        }
        return best.map { (index: $0.0, distance: $0.1) }
    }
}

/// Zustand eines Trackers, so weit er ihn meldet.
struct TrackerStatus: Decodable, Sendable {
    struct Nachricht: Decodable, Hashable, Sendable {
        let ts: Double
        let text: String
        let richtung: String
        var date: Date { Date(timeIntervalSince1970: ts / 1000) }
    }

    struct Fix: Decodable, Sendable {
        let lat: Double
        let lon: Double
        let ts: Double
        let spd: Double?
        var date: Date { Date(timeIntervalSince1970: ts / 1000) }
    }

    let zuletzt: Double?
    let verbunden: Bool
    let gps: Bool?
    let akku: Int?
    /// Akkuspannung in Volt.
    let spannung: Double?
    let signal: Int?
    let satelliten: Int?
    let zuendung: Bool?
    let stromAus: Bool?
    let alarm: String?
    let statusRoh: String?
    let position: Fix?
    let nachrichten: [Nachricht]

    var lastContact: Date? { zuletzt.map { Date(timeIntervalSince1970: $0 / 1000) } }

    /// Akkusymbol passend zum Ladestand.
    var batterySymbol: String {
        guard let akku else { return "battery.0percent" }
        switch akku {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
