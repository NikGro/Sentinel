import CoreLocation
import MapKit
import Observation

/// Ziel einer Navigation. Die Koordinate wird laufend neu aufgelöst, damit die Route einem bewegten Ziel folgt.
enum NavigationTarget: Equatable, Sendable {
    case aPosition
    case member(String)
    case vehicle(String)
    case target(String)
    case point(GeoPoint, title: String)
}

/// Eine berechnete Route, unabhängig davon, wer sie berechnet hat (Apple Karten oder das eigene Wegenetz).
struct RouteResult {
    var coordinates: [CLLocationCoordinate2D]
    var distance: CLLocationDistance
    var travelTime: TimeInterval
    var nextInstruction: String?
    /// Wurde mit Sonderrechten gerechnet (Einbahnstraßen und Abbiegeverbote ignoriert)?
    var usesSpecialRights: Bool
}

/// Dynamische Routenführung: Die Route wird neu berechnet, sobald sich das Ziel (z. B. die A-Position)
/// oder der eigene Standort merklich bewegt hat.
///
/// Mit Sonderrechten rechnet das eigene Wegenetz auf dem Server: Einbahnstraßen und Abbiegeverbote werden ignoriert,
/// physische Sperren wie Poller bleiben beachtet. Ohne Sonderrechte rechnet Apple Karten mit Verkehrslage.
@MainActor
@Observable
final class RouteFollower {
    private(set) var target: NavigationTarget?
    private(set) var title = ""
    private(set) var route: RouteResult?
    private(set) var destination: GeoPoint?
    private(set) var isCalculating = false
    private(set) var failure: String?

    var walking = false {
        didSet { if walking != oldValue { lastCalculation = nil } }
    }

    /// Sonderrechte sind bewusst nie voreingestellt und gelten nur für die laufende Führung.
    var specialRights = false {
        didSet { if specialRights != oldValue { lastCalculation = nil } }
    }

    /// Routenberechnung auf dem eigenen Server; `nil`, solange keine Anmeldung besteht.
    @ObservationIgnored var serverRoute: ((GeoPoint, GeoPoint, _ specialRights: Bool, _ walking: Bool) async throws -> RouteResult)?

    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var lastCalculation: (origin: GeoPoint, destination: GeoPoint, at: Date)?
    @ObservationIgnored private var resolve: (NavigationTarget) -> (point: GeoPoint, title: String)? = { _ in nil }
    @ObservationIgnored private var origin: () -> GeoPoint? = { nil }

    private static let tick: Duration = .seconds(3)
    private static let destinationThreshold: CLLocationDistance = 30
    private static let originThreshold: CLLocationDistance = 60
    private static let maximumAge: TimeInterval = 45

    var isActive: Bool { target != nil }

    /// Luftlinie zum Ziel, falls (noch) keine Route vorliegt.
    var beeline: CLLocationDistance? {
        guard let destination, let origin = origin() else { return nil }
        return origin.distance(to: destination)
    }

    func start(
        _ target: NavigationTarget,
        origin: @escaping () -> GeoPoint?,
        resolve: @escaping (NavigationTarget) -> (point: GeoPoint, title: String)?
    ) {
        stop()
        self.target = target
        self.origin = origin
        self.resolve = resolve
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.update()
                try? await Task.sleep(for: Self.tick)
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        target = nil
        route = nil
        destination = nil
        failure = nil
        lastCalculation = nil
        isCalculating = false
        specialRights = false
    }

    private func update() async {
        guard let target else { return }
        guard let resolved = resolve(target) else {
            failure = "Ziel hat derzeit keine Position."
            return
        }
        title = resolved.title
        destination = resolved.point
        guard let from = origin() else {
            failure = "Eigener Standort unbekannt."
            return
        }
        if let last = lastCalculation,
           last.destination.distance(to: resolved.point) < Self.destinationThreshold,
           last.origin.distance(to: from) < Self.originThreshold,
           Date.now.timeIntervalSince(last.at) < Self.maximumAge {
            return
        }
        lastCalculation = (from, resolved.point, .now)
        isCalculating = true
        defer { isCalculating = false }

        let wantsSpecialRights = specialRights && !walking
        do {
            let result: RouteResult
            if wantsSpecialRights {
                guard let serverRoute else { throw RouteError.specialRightsUnavailable }
                result = try await serverRoute(from, resolved.point, true, false)
            } else {
                result = try await Self.appleRoute(from: from, to: resolved.point, walking: walking)
            }
            guard self.target == target else { return }
            route = result
            failure = nil
        } catch {
            guard self.target == target else { return }
            // Eine Route ohne Sonderrechte stillschweigend unterzuschieben wäre irreführend: lieber klar melden.
            route = nil
            failure = wantsSpecialRights ? "Keine Route mit Sonderrechten verfügbar." : "Route konnte nicht berechnet werden."
        }
    }

    private enum RouteError: Error {
        case specialRightsUnavailable
        case noRoute
    }

    private static func appleRoute(from: GeoPoint, to: GeoPoint, walking: Bool) async throws -> RouteResult {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: from.lat, longitude: from.lon), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: to.lat, longitude: to.lon), address: nil)
        request.transportType = walking ? .walking : .automobile
        guard let route = try await MKDirections(request: request).calculate().routes.first else { throw RouteError.noRoute }
        var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: route.polyline.pointCount)
        route.polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: route.polyline.pointCount))
        return RouteResult(
            coordinates: coordinates,
            distance: route.distance,
            travelTime: route.expectedTravelTime,
            nextInstruction: route.steps.first { !$0.instructions.isEmpty && $0.distance > 0 }?.instructions,
            usesSpecialRights: false
        )
    }

    /// Übergibt das aktuelle Ziel an Apple Karten (statische Route ohne Nachführung und ohne Sonderrechte).
    func openInMaps() {
        guard let destination else { return }
        let item = MKMapItem(location: CLLocation(latitude: destination.lat, longitude: destination.lon), address: nil)
        item.name = title
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: walking ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeDriving])
    }
}
