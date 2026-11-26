import CoreLocation
import Foundation

/// Vorlauf-Navigation zu einem fahrenden Ziel: bestimmt aus den letzten Positionen seine Fahrtrichtung und über
/// Umkehrsuche seine Straße, lädt deren Querstraßen vom eigenen Server und wählt die nächste Kreuzung vor ihm.
/// Ist das Ziel an ihr vorbei, gilt die nächste. Annahme: Das Ziel fährt auf seiner Straße geradeaus weiter.
@MainActor
final class LeadPlanner {
    /// Querstraßen einer Straße (Name, Kreuzungspunkte), vom eigenen Server.
    var crossings: ((String, GeoPoint) async -> [(name: String, points: [GeoPoint])]?)?

    private struct Track {
        var points: [(point: GeoPoint, at: Date)] = []
        var street: String?
        var streetLookupAt: GeoPoint?
        var crossings: [(name: String, points: [GeoPoint])] = []
        var crossingsFor: String?
        var loading = false
    }

    private var tracks: [NavigationTarget: Track] = [:]
    private let geocoder = CLGeocoder()

    /// Nächste Kreuzung vor dem Ziel an `point`, oder `nil`, solange Richtung, Straße oder Querstraßen fehlen.
    func crossing(for target: NavigationTarget, at point: GeoPoint) -> (point: GeoPoint, name: String)? {
        var track = tracks[target] ?? Track()
        // Positionen der letzten zwei Minuten; nur neue Stellen merken.
        if track.points.last.map({ $0.point.distance(to: point) > 3 }) ?? true {
            track.points.append((point, .now))
        }
        track.points.removeAll { Date.now.timeIntervalSince($0.at) > 120 }
        lookUpStreet(&track, target: target, at: point)
        loadCrossings(&track, target: target, near: point)
        tracks[target] = track

        guard let heading = Self.heading(track.points) else { return nil }
        return Self.next(crossings: track.crossings, street: track.street, from: point, heading: heading)
    }

    /// Nächste Kreuzung voraus: 40 m bis 1,5 km entfernt, höchstens 50° neben der Fahrtrichtung.
    static func next(crossings: [(name: String, points: [GeoPoint])], street: String?, from point: GeoPoint, heading: Double) -> (point: GeoPoint, name: String)? {
        var best: (point: GeoPoint, name: String, distance: Double)?
        for crossing in crossings where crossing.name != street {
            for candidate in crossing.points {
                let d = point.distance(to: candidate)
                guard d > 40, d < 1500 else { continue }
                var off = abs(bearing(point, candidate) - heading).truncatingRemainder(dividingBy: 360)
                if off > 180 { off = 360 - off }
                guard off < 50 else { continue }
                if best == nil || d < best!.distance { best = (candidate, crossing.name, d) }
            }
        }
        return best.map { ($0.point, $0.name) }
    }

    /// Fahrtrichtung aus der Bewegung der letzten mindestens 30 m (für Tests offen).
    static func heading(of points: [GeoPoint]) -> Double? {
        heading(points.map { ($0, Date.now) })
    }

    func reset() {
        tracks = [:]
    }

    /// Fahrtrichtung aus der Bewegung der letzten mindestens 30 m.
    private static func heading(_ points: [(point: GeoPoint, at: Date)]) -> Double? {
        guard let last = points.last else { return nil }
        guard let from = points.last(where: { $0.point.distance(to: last.point) >= 30 }) else { return nil }
        return bearing(from.point, last.point)
    }

    static func bearing(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let y = sin((b.lon - a.lon) * .pi / 180) * cos(b.lat * .pi / 180)
        let x = cos(a.lat * .pi / 180) * sin(b.lat * .pi / 180) - sin(a.lat * .pi / 180) * cos(b.lat * .pi / 180) * cos((b.lon - a.lon) * .pi / 180)
        let degrees = atan2(y, x) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// Straße des Ziels über Apples Umkehrsuche, höchstens alle 60 m Bewegung.
    private func lookUpStreet(_ track: inout Track, target: NavigationTarget, at point: GeoPoint) {
        guard track.streetLookupAt.map({ $0.distance(to: point) > 60 }) ?? true, !geocoder.isGeocoding else { return }
        track.streetLookupAt = point
        geocoder.reverseGeocodeLocation(CLLocation(latitude: point.lat, longitude: point.lon), preferredLocale: Locale(identifier: "de_DE")) { [weak self] placemarks, _ in
            let street = placemarks?.first?.thoroughfare
            Task { @MainActor in
                guard let self, let street else { return }
                self.tracks[target]?.street = street
            }
        }
    }

    private func loadCrossings(_ track: inout Track, target: NavigationTarget, near point: GeoPoint) {
        guard let street = track.street, track.crossingsFor != street, !track.loading, let crossings else { return }
        track.loading = true
        Task { @MainActor in
            let result = await crossings(street, point)
            self.tracks[target]?.loading = false
            if let result {
                self.tracks[target]?.crossings = result
                self.tracks[target]?.crossingsFor = street
            }
        }
    }
}
