import CoreLocation
import Observation

/// Aktuelle Straße und Fahrtrichtung als Himmelsrichtung, damit man den eigenen Standort mündlich durchgeben kann.
@MainActor
@Observable
final class LocationContext {
    private(set) var street: String?
    private(set) var heading: String?

    @ObservationIgnored private let geocoder = CLGeocoder()
    @ObservationIgnored private var lastLookup: CLLocation?
    @ObservationIgnored private var lastLookupAt = Date.distantPast

    private static let minimumDistance: CLLocationDistance = 40
    private static let minimumInterval: TimeInterval = 8

    /// Wird mit jeder neuen eigenen Position aufgerufen; fragt die Straße nur in sinnvollen Abständen nach.
    func update(with location: CLLocation) {
        heading = location.course >= 0 && location.speed > 1.5 ? Self.cardinal(location.course) : heading
        if location.speed >= 0, location.speed <= 1.5 { heading = nil }
        let moved = lastLookup.map { location.distance(from: $0) } ?? .greatestFiniteMagnitude
        guard moved >= Self.minimumDistance, Date.now.timeIntervalSince(lastLookupAt) >= Self.minimumInterval, !geocoder.isGeocoding else { return }
        lastLookup = location
        lastLookupAt = .now
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "de_DE")) { [weak self] placemarks, _ in
            let place = placemarks?.first
            let name = place?.thoroughfare ?? place?.name
            Task { @MainActor in self?.street = name }
        }
    }

    /// Kurs in Grad als Himmelsrichtung, z. B. "Nordost".
    static func cardinal(_ degrees: CLLocationDirection) -> String {
        let names = ["Nord", "Nordost", "Ost", "Südost", "Süd", "Südwest", "West", "Nordwest"]
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360 + 22.5) / 45).rounded(.down)) % 8
        return names[index]
    }

    /// Zeile unter dem eigenen Standort, z. B. "Mönckebergstraße, Richtung Nordost".
    var summary: String? {
        switch (street, heading) {
        case let (street?, heading?): "\(street), Richtung \(heading)"
        case let (street?, nil): street
        case let (nil, heading?): "Richtung \(heading)"
        case (nil, nil): nil
        }
    }
}
