import CoreLocation
import Observation

/// Aktuelle Straße und Fahrtrichtung als Himmelsrichtung, damit man den eigenen Standort mündlich durchgeben kann.
/// In Bewegung zählt der Kurs, im Stand die Kompassrichtung des Geräts.
@MainActor
@Observable
final class LocationContext: NSObject, CLLocationManagerDelegate {
    private(set) var street: String?
    private(set) var heading: String?
    /// Nächstgelegene Querstraße der aktuellen Straße (vor oder hinter einem), für „Ecke …“.
    private(set) var corner: String?
    /// Fragt die Querstraßen einer Straße beim eigenen Server ab (Name, Kreuzungspunkte); setzt das App-Modell.
    @ObservationIgnored var crossingProvider: ((String, GeoPoint) async -> [(name: String, points: [GeoPoint])]?)?
    @ObservationIgnored private var crossings: [(name: String, points: [GeoPoint])] = []
    @ObservationIgnored private var crossingsFor: String?
    @ObservationIgnored private var crossingsTriedAt = Date.distantPast
    /// Kompassrichtung des Geräts in Grad (nur im Stand), für die Kartenausrichtung „Kurs“.
    private(set) var compassDegrees: CLLocationDirection?

    @ObservationIgnored private let geocoder = CLGeocoder()
    @ObservationIgnored private let compass = CLLocationManager()
    @ObservationIgnored private var lastLookup: CLLocation?
    @ObservationIgnored private var lastLookupAt = Date.distantPast
    @ObservationIgnored private var isMoving = false

    private static let minimumDistance: CLLocationDistance = 40
    private static let minimumInterval: TimeInterval = 8

    override init() {
        super.init()
        compass.delegate = self
        compass.headingFilter = 4
        if CLLocationManager.headingAvailable() { compass.startUpdatingHeading() }
    }

    /// Wird mit jeder neuen eigenen Position aufgerufen; fragt die Straße nur in sinnvollen Abständen nach.
    func update(with location: CLLocation) {
        isMoving = location.course >= 0 && location.speed > 1.5
        if isMoving { setHeading(Self.cardinal(location.course)) }
        updateCorner(at: location)
        let moved = lastLookup.map { location.distance(from: $0) } ?? .greatestFiniteMagnitude
        guard moved >= Self.minimumDistance, Date.now.timeIntervalSince(lastLookupAt) >= Self.minimumInterval, !geocoder.isGeocoding else { return }
        lastLookup = location
        lastLookupAt = .now
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "de_DE")) { [weak self] placemarks, _ in
            let place = placemarks?.first
            let name = place?.thoroughfare ?? place?.name
            Task { @MainActor in
                self?.street = name
                self?.updateCorner(at: location)
            }
        }
    }

    /// Nächste Kreuzung der aktuellen Straße bestimmen; die Querstraßen einer Straße werden einmal geladen.
    private func updateCorner(at location: CLLocation) {
        guard let street else {
            if corner != nil { corner = nil }
            return
        }
        if crossingsFor != street, Date.now.timeIntervalSince(crossingsTriedAt) > 20, let crossingProvider {
            crossingsTriedAt = .now
            let here = GeoPoint(location.coordinate)
            Task { @MainActor in
                guard let result = await crossingProvider(street, here) else { return }
                self.crossings = result
                self.crossingsFor = street
                self.updateCorner(at: location)
            }
        }
        guard crossingsFor == street else {
            if corner != nil { corner = nil }
            return
        }
        let here = GeoPoint(location.coordinate)
        var best: (name: String, distance: Double)?
        for crossing in crossings where crossing.name != street {
            for point in crossing.points {
                let d = here.distance(to: point)
                if best == nil || d < best!.distance { best = (crossing.name, d) }
            }
        }
        // Nur, wenn die Kreuzung in der Nähe liegt (sonst wäre „Ecke“ irreführend).
        let next = best.flatMap { $0.distance < 500 ? $0.name : nil }
        if corner != next { corner = next }
    }

    private func setHeading(_ value: String) {
        if heading != value { heading = value }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let degrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            guard !self.isMoving, degrees >= 0 else { return }
            self.compassDegrees = degrees
            self.setHeading(Self.cardinal(degrees))
        }
    }

    /// Kurs in Grad als Himmelsrichtung, z. B. "Nordost".
    nonisolated static func cardinal(_ degrees: CLLocationDirection) -> String {
        let names = ["Nord", "Nordost", "Ost", "Südost", "Süd", "Südwest", "West", "Nordwest"]
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360 + 22.5) / 45).rounded(.down)) % 8
        return names[index]
    }

    /// Zweite Zeile unter dem eigenen Standort, z. B. "Ecke Steinstraße".
    var cornerLine: String? { street == nil ? nil : corner.map { "Ecke \($0)" } }

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
