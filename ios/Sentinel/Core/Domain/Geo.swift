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

    /// Großkreisentfernung in Metern (Haversine). Ohne `CLLocation`, weil sie beim Zeichnen der Karte sehr oft läuft.
    func distance(to other: GeoPoint) -> CLLocationDistance {
        let rad = Double.pi / 180
        let dLat = (other.lat - lat) * rad
        let dLon = (other.lon - lon) * rad
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat * rad) * cos(other.lat * rad) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * 6_371_008.8 * asin(min(1, h.squareRoot()))
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
