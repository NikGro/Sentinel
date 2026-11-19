import CoreLocation
import Foundation

// Orte und Positionen.

struct GeoPoint: Codable, Hashable, Sendable {
    var lat: Double
    var lon: Double

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }

    init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(lat: coordinate.latitude, lon: coordinate.longitude)
    }

    func distance(to other: GeoPoint) -> CLLocationDistance {
        CLLocation(latitude: lat, longitude: lon).distance(from: CLLocation(latitude: other.lat, longitude: other.lon))
    }
}

/// Standort mit Zeitpunkt (ms seit 1970), z. B. ein abgestelltes Fahrzeug oder ein von Hand gesetztes Ziel.
struct TimedPoint: Codable, Equatable, Hashable, Sendable {
    var lat: Double
    var lon: Double
    var ts: Double

    var point: GeoPoint { GeoPoint(lat: lat, lon: lon) }
    var date: Date { Date(timeIntervalSince1970: ts / 1000) }

    init(_ point: GeoPoint, at date: Date = .now) {
        lat = point.lat
        lon = point.lon
        ts = (date.timeIntervalSince1970 * 1000).rounded()
    }
}

/// Live-Position eines Fahnders oder Trackers. Zeit in Millisekunden seit 1970.
struct Position: Codable, Equatable, Sendable {
    var lat: Double
    var lon: Double
    var ts: Double
    var acc: Double?
    var spd: Double?
    var hdg: Double?

    var point: GeoPoint { GeoPoint(lat: lat, lon: lon) }
    var date: Date { Date(timeIntervalSince1970: ts / 1000) }
}
