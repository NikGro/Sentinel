import CoreLocation
import MapKit
import Observation

/// Ziel einer Navigation. Die Koordinate wird laufend neu aufgelöst, damit die Route einem bewegten Ziel folgt.
enum NavigationTarget: Equatable, Hashable, Sendable {
    /// Wer gerade die A hält; wechselt die A, folgt die Führung automatisch der neuen Person.
    case aPosition
    /// Die eigene Haltestelle beim überschlagenden Anfahren.
    case leapfrog
    case member(String)
    case vehicle(String)
    case target(String)
    case object(String)
    case point(GeoPoint, title: String)
}

/// Ein Manöver der Route und die Stelle im Linienzug, an der es beginnt.
struct RouteStep: Equatable, Sendable {
    var instruction: String
    var distance: CLLocationDistance
    var startIndex: Int
}

/// Eine berechnete Route, unabhängig davon, wer sie berechnet hat (Apple Karten oder das eigene Wegenetz).
struct RouteResult {
    var coordinates: [CLLocationCoordinate2D]
    var distance: CLLocationDistance
    var travelTime: TimeInterval
    var steps: [RouteStep]
    /// Wurde mit Sonderrechten gerechnet (Einbahnstraßen und Abbiegeverbote ignoriert)?
    var usesSpecialRights: Bool
}

/// Fortschritt auf der Route bezogen auf den eigenen Standort.
struct RouteProgress: Equatable {
    var nextInstruction: String
    var distanceToManeuver: CLLocationDistance
    var followingInstruction: String?
    var remainingDistance: CLLocationDistance
    var remainingTime: TimeInterval

    var arrival: Date { .now.addingTimeInterval(remainingTime) }
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
    private(set) var progress: RouteProgress?
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
    @ObservationIgnored private var progressIndex = 0

    private static let tick: Duration = .seconds(1)
    private static let destinationThreshold: CLLocationDistance = 30
    private static let originThreshold: CLLocationDistance = 60
    /// Weicht man weiter von der Route ab, wird sofort neu berechnet.
    private static let offRouteThreshold: CLLocationDistance = 35
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
        progress = nil
        destination = nil
        failure = nil
        lastCalculation = nil
        isCalculating = false
        specialRights = false
        progressIndex = 0
    }

    private func update() async {
        guard let target else { return }
        guard let resolved = resolve(target) else {
            failure = target == .leapfrog ? "Noch keine Haltestelle zugewiesen." : "Ziel hat derzeit keine Position."
            return
        }
        title = resolved.title
        destination = resolved.point
        guard let from = origin() else {
            failure = "Eigener Standort unbekannt."
            return
        }
        updateProgress(from)
        let offRoute = progress == nil || distanceToRoute(from) > Self.offRouteThreshold
        if let last = lastCalculation, !offRoute,
           last.destination.distance(to: resolved.point) < Self.destinationThreshold,
           last.origin.distance(to: from) < Self.originThreshold || route != nil,
           Date.now.timeIntervalSince(last.at) < Self.maximumAge {
            return
        }
        if let last = lastCalculation, Date.now.timeIntervalSince(last.at) < (offRoute ? 2 : 4) { return }
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
            progressIndex = 0
            failure = nil
            updateProgress(from)
        } catch {
            guard self.target == target else { return }
            // Eine Route ohne Sonderrechte stillschweigend unterzuschieben wäre irreführend: lieber klar melden.
            route = nil
            progress = nil
            failure = wantsSpecialRights ? "Keine Route mit Sonderrechten verfügbar." : "Route konnte nicht berechnet werden."
        }
    }

    // MARK: Fortschritt

    /// Abstand zur Route: kürzester Abstand zu den Teilstücken rund um die aktuelle Stelle, nicht nur zu einem
    /// Stützpunkt. So fällt ein Abbiegen in die falsche Straße oder ein Überfahren des Ziels sofort auf.
    private func distanceToRoute(_ location: GeoPoint) -> CLLocationDistance {
        guard let route, route.coordinates.count > 1, route.coordinates.indices.contains(progressIndex) else { return .greatestFiniteMagnitude }
        let coordinates = route.coordinates
        let lower = max(0, progressIndex - 3)
        let upper = min(coordinates.count - 1, progressIndex + 60)
        var best = CLLocationDistance.greatestFiniteMagnitude
        let k = cos(location.lat * .pi / 180)
        for i in lower..<upper {
            let a = coordinates[i], b = coordinates[i + 1]
            let ax = a.longitude * k, ay = a.latitude
            let dx = b.longitude * k - ax, dy = b.latitude - ay
            let px = location.lon * k, py = location.lat
            let length = dx * dx + dy * dy
            let t = length == 0 ? 0 : max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / length))
            let nearest = GeoPoint(lat: ay + t * dy, lon: (ax + t * dx) / k)
            best = min(best, nearest.distance(to: location))
        }
        return best
    }

    /// Bestimmt den nächstgelegenen Punkt auf der Route (nur vorwärts suchend) und daraus das kommende Manöver.
    private func updateProgress(_ location: GeoPoint) {
        guard let route, !route.coordinates.isEmpty else {
            progress = nil
            return
        }
        let coordinates = route.coordinates
        let window = progressIndex..<min(coordinates.count, progressIndex + 400)
        var best = progressIndex
        var bestDistance = CLLocationDistance.greatestFiniteMagnitude
        for i in window {
            let d = GeoPoint(coordinates[i]).distance(to: location)
            if d < bestDistance {
                bestDistance = d
                best = i
            }
        }
        progressIndex = best

        func along(from start: Int, to end: Int) -> CLLocationDistance {
            guard end > start else { return 0 }
            var sum: CLLocationDistance = 0
            for i in start..<min(end, coordinates.count - 1) {
                sum += GeoPoint(coordinates[i]).distance(to: GeoPoint(coordinates[i + 1]))
            }
            return sum
        }

        let remaining = along(from: best, to: coordinates.count - 1)
        let steps = route.steps.filter { !$0.instruction.isEmpty }
        let nextStep = steps.first { $0.startIndex > best } ?? steps.last
        let followingStep = nextStep.flatMap { step in steps.first { $0.startIndex > step.startIndex } }
        let maneuverIndex = nextStep?.startIndex ?? coordinates.count - 1
        progress = RouteProgress(
            nextInstruction: nextStep?.instruction ?? "Dem Straßenverlauf folgen",
            distanceToManeuver: along(from: best, to: maneuverIndex),
            followingInstruction: followingStep?.instruction,
            remainingDistance: remaining,
            remainingTime: route.distance > 0 ? route.travelTime * remaining / route.distance : 0
        )
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
        // Die Linienzüge der Manöver ergeben aneinandergereiht die Route; daraus folgt, wo jedes Manöver beginnt.
        var steps: [RouteStep] = []
        var index = 0
        for step in route.steps {
            steps.append(RouteStep(instruction: step.instructions, distance: step.distance, startIndex: index))
            index += max(step.polyline.pointCount - 1, 0)
        }
        return RouteResult(coordinates: coordinates, distance: route.distance, travelTime: route.expectedTravelTime, steps: steps, usesSpecialRights: false)
    }

    /// Übergibt das aktuelle Ziel an Apple Karten (statische Route ohne Nachführung und ohne Sonderrechte).
    func openInMaps() {
        guard let destination else { return }
        let item = MKMapItem(location: CLLocation(latitude: destination.lat, longitude: destination.lon), address: nil)
        item.name = title
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: walking ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeDriving])
    }
}

/// Symbol für eine Fahranweisung, abgeleitet aus ihrem Text.
enum ManeuverSymbol {
    static func name(for instruction: String) -> String {
        let text = instruction.lowercased()
        if text.contains("ziel") || text.contains("erreicht") || text.contains("destination") { return "mappin.circle.fill" }
        if text.contains("wenden") || text.contains("u-turn") { return "arrow.uturn.down" }
        if text.contains("kreisverkehr") || text.contains("roundabout") { return "arrow.triangle.turn.up.right.circle" }
        if text.contains("leicht links") || text.contains("halb links") || text.contains("slight left") { return "arrow.up.left" }
        if text.contains("leicht rechts") || text.contains("halb rechts") || text.contains("slight right") { return "arrow.up.right" }
        if text.contains("links") || text.contains("left") { return "arrow.turn.up.left" }
        if text.contains("rechts") || text.contains("right") { return "arrow.turn.up.right" }
        return "arrow.up"
    }
}
