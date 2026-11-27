import Foundation

/// Eigene GPS-Punkte für die Standortspur, auf dem Gerät gespeichert (übersteht einen Neustart der App).
///
/// Die eigene Spur wird daraus gezeichnet, wie ein Pinsel, der malt, wo man war: Der Server speichert gröber (etwa
/// alle 15 s) und lieferte beim Neuladen eine gröbere Linie, die die feine ersetzte – die Spur „rutschte“. Vom Server
/// kommt für die eigene Spur nur noch, was vor der Aufzeichnung auf diesem Gerät liegt.
///
/// Aufgezeichnet wird nur, solange eine eigene Standortspur auf der Karte liegt; gehalten werden 48 Stunden, beim
/// Abmelden wird alles gelöscht.
@MainActor
final class OwnTrailLog {
    static let shared = OwnTrailLog()

    private struct Stored: Codable {
        let lat: Double
        let lon: Double
        let t: Double
        let v: Double?
    }

    private(set) var points: [SpurPunkt] = []
    private var savedAt = Date.distantPast
    private static let keep: TimeInterval = 48 * 3600
    private static let maxPoints = 60_000

    private var url: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("eigene-spur.json")
    }

    private init() {
        guard let url, let data = try? Data(contentsOf: url), let stored = try? JSONDecoder().decode([Stored].self, from: data) else { return }
        let limit = Date.now.addingTimeInterval(-Self.keep)
        points = stored
            .map { SpurPunkt(point: GeoPoint(lat: $0.lat, lon: $0.lon), date: Date(timeIntervalSince1970: $0.t), speed: $0.v, quelle: .gps, info: nil) }
            .filter { $0.date > limit }
    }

    /// Hängt einen Punkt an (ab 3 m Abstand zum letzten); gespeichert wird höchstens alle 20 Sekunden.
    @discardableResult
    func append(_ punkt: SpurPunkt) -> Bool {
        if let last = points.last, last.point.distance(to: punkt.point) < 3 || punkt.date <= last.date { return false }
        points.append(punkt)
        let limit = Date.now.addingTimeInterval(-Self.keep)
        if let first = points.first, first.date < limit { points.removeAll { $0.date < limit } }
        if points.count > Self.maxPoints { points.removeFirst(points.count - Self.maxPoints) }
        if Date.now.timeIntervalSince(savedAt) > 20 { save() }
        return true
    }

    func save() {
        savedAt = .now
        guard let url else { return }
        let stored = points.map { Stored(lat: $0.point.lat, lon: $0.point.lon, t: $0.date.timeIntervalSince1970, v: $0.speed) }
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: url, options: [.atomic, .completeFileProtection])
        }
    }

    func clear() {
        points = []
        if let url { try? FileManager.default.removeItem(at: url) }
    }
}
