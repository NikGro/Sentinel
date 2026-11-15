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

/// Dynamische Routenführung: Die Route wird neu berechnet, sobald sich das Ziel (z. B. die A-Position)
/// oder der eigene Standort merklich bewegt hat.
@MainActor
@Observable
final class RouteFollower {
    private(set) var target: NavigationTarget?
    private(set) var title = ""
    private(set) var route: MKRoute?
    private(set) var destination: GeoPoint?
    private(set) var isCalculating = false
    private(set) var failure: String?
    var walking = false {
        didSet { if walking != oldValue { lastCalculation = nil } }
    }

    private var loop: Task<Void, Never>?
    private var lastCalculation: (origin: GeoPoint, destination: GeoPoint, at: Date)?
    private var resolve: (NavigationTarget) -> (point: GeoPoint, title: String)? = { _ in nil }
    private var origin: () -> GeoPoint? = { nil }

    private static let tick: Duration = .seconds(3)
    private static let destinationThreshold: CLLocationDistance = 30
    private static let originThreshold: CLLocationDistance = 60
    private static let maximumAge: TimeInterval = 45

    var isActive: Bool { target != nil }

    /// Nächste Fahranweisung der aktuellen Route.
    var nextInstruction: String? {
        route?.steps.first { !$0.instructions.isEmpty && $0.distance > 0 }?.instructions
    }

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

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: resolved.point.coordinate))
        request.transportType = walking ? .walking : .automobile
        do {
            let response = try await MKDirections(request: request).calculate()
            guard self.target == target else { return }
            route = response.routes.first
            failure = route == nil ? "Keine Route gefunden." : nil
        } catch {
            guard self.target == target else { return }
            failure = "Route konnte nicht berechnet werden."
        }
    }

    /// Übergibt das aktuelle Ziel an Apple Karten (statische Route ohne Nachführung).
    func openInMaps() {
        guard let destination else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        item.name = title
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: walking ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeDriving])
    }
}
