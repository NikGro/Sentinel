import Combine
import CoreLocation
import MapKit
import Observation
@preconcurrency import FerrostarCore
@preconcurrency import FerrostarCoreFFI

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
    /// Nicht zum Fahrzeug selbst, sondern `stops` Halte vor dem ÖPNV-Fahrzeug, in dem das Ziel sitzt; rückt mit dem
    /// Fahrzeug mit.
    indirect case ahead(NavigationTarget, stops: Int)

    /// Das eigentliche Ziel, ohne „Halte voraus“.
    var base: NavigationTarget {
        if case .ahead(let base, _) = self { return base.base }
        return self
    }

    var stopsAhead: Int {
        if case .ahead(_, let stops) = self { return stops }
        return 0
    }
}

/// Die aktuell gefahrene Route.
struct RouteResult {
    var coordinates: [CLLocationCoordinate2D]
    var distance: CLLocationDistance
    /// Wurde gegen Einbahnstraßen oder Abbiegeverbote geführt? Nur dann, wenn es spürbar Zeit spart.
    var usesSpecialRights: Bool
}

/// Kreuzende oder einmündende Straße an der Route, `meter` ab Routenbeginn.
struct CrossStreet: Decodable, Equatable, Sendable {
    let name: String
    let lat: Double
    let lon: Double
    let meter: Double
}

/// Eine Fahrspur am nächsten Manöver.
struct LaneHint: Hashable {
    var directions: [String]
    var active: Bool
}

/// Fortschritt auf der Route bezogen auf den eigenen Standort.
struct RouteProgress: Equatable {
    var nextInstruction: String
    var maneuverSymbol: String
    var distanceToManeuver: CLLocationDistance
    var followingInstruction: String?
    var followingSymbol: String?
    var remainingDistance: CLLocationDistance
    var remainingTime: TimeInterval
    var lanes: [LaneHint]
    var arrived: Bool

    var arrival: Date { .now.addingTimeInterval(remainingTime) }
}

/// Navigation mit dem Ferrostar-Kern (quelloffen): Er legt den Standort auf die Route, erkennt Abweichungen,
/// berechnet neu und schaltet die Hinweise im richtigen Moment weiter. Routen liefert der eigene Server (Valhalla);
/// ohne Sonderrechte gibt Apple Karten den Weg mit aktueller Verkehrslage vor (siehe ``NaviRequestLoader``).
/// Sprachansagen sind bewusst stumm.
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
    /// Stelle im Linienzug, an der man sich gerade befindet; davor liegt der bereits gefahrene Teil.
    private(set) var progressIndex = 0
    /// Eigener Standort, auf die Route gelegt (ohne GPS-Zittern neben der Straße).
    private(set) var snappedLocation: CLLocation?
    /// Erlaubte Höchstgeschwindigkeit auf dem aktuellen Abschnitt in km/h, soweit bekannt.
    private(set) var speedLimit: Int?
    /// Querstraßen entlang der Route (aus OpenStreetMap über den eigenen Server).
    private(set) var crossStreets: [CrossStreet] = []
    /// Entfernung ab Routenbeginn je Routenpunkt.
    @ObservationIgnored private var cumulative: [CLLocationDistance] = []
    @ObservationIgnored private var client: APIClient?
    @ObservationIgnored private var crossTask: Task<Void, Never>?

    /// Nächste Querstraße voraus mit Entfernung, sobald die Route bekannt ist.
    var nextCrossStreet: (name: String, distance: CLLocationDistance)? {
        guard !cumulative.isEmpty else { return nil }
        let here = cumulative[min(progressIndex, cumulative.count - 1)]
        guard let next = crossStreets.first(where: { $0.meter > here + 10 }) else { return nil }
        return (next.name, next.meter - here)
    }

    var walking = false {
        didSet { if walking != oldValue { recalculateSoon() } }
    }

    /// ÖPNV: geführt wird zu Fuß; Apple Karten liefert die Ankunft mit Bus und Bahn und die genaue Verbindung.
    var transit = false {
        didSet {
            guard transit != oldValue else { return }
            if transit { walking = true }
            transitArrival = nil
            if transit { Task { await loadTransitArrival() } }
        }
    }
    private(set) var transitArrival: Date?
    /// Gewählte Verbindung mit Bus und Bahn (Transitous), für die Schritte auf der Karte und in der Liste.
    var transitPlan: TransitPlan?

    private func loadTransitArrival() async {
        guard let destination, let origin = snappedLocation.map({ GeoPoint($0.coordinate) }) ?? origin() else { return }
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: origin.lat, longitude: origin.lon), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: destination.lat, longitude: destination.lon), address: nil)
        request.transportType = .transit
        request.departureDate = .now
        if let eta = try? await MKDirections(request: request).calculateETA(), transit {
            transitArrival = eta.expectedArrivalDate
        }
    }

    /// Sonderrechte sind bewusst nie voreingestellt und gelten nur für die laufende Führung.
    var specialRights = false {
        didSet { if specialRights != oldValue { recalculateSoon() } }
    }

    @ObservationIgnored private var core: FerrostarCore?
    @ObservationIgnored private var loader: NaviRequestLoader?
    @ObservationIgnored private let annotations = AnnotationPublisher<ValhallaExtendedOSRMAnnotation>.valhallaExtendedOSRM()
    @ObservationIgnored private let locationProvider = CoreLocationProvider(activityType: .automotiveNavigation, allowBackgroundLocationUpdates: true)
    @ObservationIgnored private let coreDelegate = CoreDelegate()
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var resolve: (NavigationTarget) -> (point: GeoPoint, title: String)? = { _ in nil }
    @ObservationIgnored private var origin: () -> GeoPoint? = { nil }
    @ObservationIgnored private var routedDestination: GeoPoint?
    @ObservationIgnored private var lastRouteAt = Date.distantPast
    @ObservationIgnored private var needsRoute = true

    /// Bewegt sich das Ziel um mehr als so viele Meter, wird neu berechnet …
    private static let destinationThreshold: CLLocationDistance = 40
    /// … aber höchstens so oft.
    private static let minimumRerouteInterval: TimeInterval = 8

    var isActive: Bool { target != nil }

    /// Luftlinie zum Ziel, falls (noch) keine Route vorliegt.
    var beeline: CLLocationDistance? {
        guard let destination, let origin = origin() else { return nil }
        return origin.distance(to: destination)
    }

    /// Mit Server und Anmeldung verbinden. Ohne diesen Aufruf ist keine Navigation möglich.
    func configure(serverURL: URL, token: String) {
        stop()
        client = APIClient(baseURL: serverURL, token: token)
        let loader = NaviRequestLoader(token: token)
        do {
            let core = try FerrostarCore(
                wellKnownRouteProvider: .valhalla(endpointUrl: serverURL.appending(path: "api/v1/navi/route").absoluteString, profile: "auto"),
                locationProvider: locationProvider,
                navigationControllerConfig: NaviConfig.controller,
                networkSession: loader,
                annotation: annotations,
                spokenInstructionObserver: .initAVSpeechSynthesizer(isMuted: true)
            )
            // Kurz nach dem Start schwankt der Standort noch; nicht bei jedem Ausreißer neu rechnen.
            core.minimumTimeBeforeRecalculation = 8
            core.minimumMovementBeforeRecalculation = 30
            core.delegate = coreDelegate
            cancellables = []
            core.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in MainActor.assumeIsolated { self?.apply(state) } }
                .store(in: &cancellables)
            core.$route
                .receive(on: DispatchQueue.main)
                .sink { [weak self] route in MainActor.assumeIsolated { self?.apply(route) } }
                .store(in: &cancellables)
            annotations.$speedLimit
                .receive(on: DispatchQueue.main)
                .sink { [weak self] limit in
                    MainActor.assumeIsolated {
                        self?.speedLimit = limit.map { Int($0.converted(to: .kilometersPerHour).value.rounded()) }
                    }
                }
                .store(in: &cancellables)
            self.core = core
            self.loader = loader
        } catch {
            self.core = nil
            self.loader = nil
        }
    }

    func disconnect() {
        stop()
        core = nil
        loader = nil
        client = nil
        cancellables = []
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
        needsRoute = true
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        core?.stopNavigation()
        target = nil
        route = nil
        progress = nil
        destination = nil
        failure = nil
        isCalculating = false
        specialRights = false
        progressIndex = 0
        snappedLocation = nil
        speedLimit = nil
        routedDestination = nil
        needsRoute = true
        crossTask?.cancel()
        crossStreets = []
        cumulative = []
    }

    private func recalculateSoon() {
        guard isActive else { return }
        needsRoute = true
        Task { await tick() }
    }

    /// Ziel nachführen und bei Bedarf eine neue Route holen.
    private func tick() async {
        guard let target else { return }
        guard let resolved = resolve(target) else {
            failure = target == .leapfrog ? "Noch keine Haltestelle zugewiesen." : "Ziel hat derzeit keine Position."
            return
        }
        title = resolved.title
        destination = resolved.point
        let moved = routedDestination.map { $0.distance(to: resolved.point) > Self.destinationThreshold } ?? true
        let due = Date.now.timeIntervalSince(lastRouteAt) >= Self.minimumRerouteInterval
        guard !isCalculating, needsRoute || (moved && due) else { return }
        await calculate(to: resolved.point)
    }

    private func calculate(to point: GeoPoint) async {
        guard let core, let loader, let target else {
            failure = "Navigation ist ohne Serververbindung nicht verfügbar."
            return
        }
        guard let start = locationProvider.lastLocation ?? origin().map({ CLLocation(latitude: $0.lat, longitude: $0.lon).userLocation }) else {
            failure = "Eigener Standort unbekannt."
            return
        }
        isCalculating = true
        defer { isCalculating = false }
        loader.configure(specialRights: specialRights && !walking, walking: walking)
        needsRoute = false
        routedDestination = point
        lastRouteAt = .now
        do {
            let routes = try await core.getRoutes(
                initialLocation: start,
                waypoints: [Waypoint(coordinate: GeographicCoordinate(lat: point.lat, lng: point.lon), kind: .break, properties: nil)]
            )
            guard self.target == target, let first = routes.first else { return }
            try core.startNavigation(route: first, config: NaviConfig.controller)
            failure = nil
        } catch {
            guard self.target == target else { return }
            failure = specialRights ? "Keine Route mit Sonderrechten verfügbar." : "Route konnte nicht berechnet werden."
            needsRoute = true
        }
    }

    // MARK: Zustand aus dem Ferrostar-Kern übernehmen

    private func apply(_ route: Route?) {
        guard let route else {
            self.route = nil
            return
        }
        self.route = RouteResult(
            coordinates: route.geometry.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) },
            distance: route.distance,
            usesSpecialRights: loader?.lastRouteUsedSpecialRights ?? false
        )
        progressIndex = 0
        let coordinates = self.route?.coordinates ?? []
        var sum: CLLocationDistance = 0
        cumulative = coordinates.indices.map { i in
            if i > 0 { sum += GeoPoint(coordinates[i - 1]).distance(to: GeoPoint(coordinates[i])) }
            return sum
        }
        loadCrossStreets(coordinates)
    }

    /// Holt die Querstraßen zur neuen Route. Ausgedünnt auf höchstens 500 Punkte; Entfernungen bleiben ab Routenbeginn.
    private func loadCrossStreets(_ coordinates: [CLLocationCoordinate2D]) {
        crossTask?.cancel()
        crossStreets = []
        guard let client, coordinates.count >= 2 else { return }
        let step = max(1, coordinates.count / 500)
        var points = stride(from: 0, to: coordinates.count, by: step).map { GeoPoint(coordinates[$0]) }
        if let last = coordinates.last, points.last != GeoPoint(last) { points.append(GeoPoint(last)) }
        crossTask = Task { [weak self] in
            // Ohne Querstraßen geht die Navigation einfach weiter; ein Fehler ist hier kein Hinweis wert.
            guard let streets = try? await client.crossStreets(along: points), !Task.isCancelled else { return }
            self?.crossStreets = streets
        }
    }

    private func apply(_ state: NavigationState?) {
        guard let state else {
            progress = nil
            snappedLocation = nil
            return
        }
        if state.isCalculatingNewRoute != isCalculating, target != nil { isCalculating = state.isCalculatingNewRoute }
        switch state.tripState {
        case let .navigating(_, _, snapped, remainingSteps, _, tripProgress, _, _, visual, _, _):
            let course = snapped.courseOverGround.map { CLLocationDirection($0.degrees) } ?? -1
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: snapped.coordinates.lat, longitude: snapped.coordinates.lng),
                altitude: 0, horizontalAccuracy: snapped.horizontalAccuracy, verticalAccuracy: -1,
                course: course, speed: snapped.speed?.value ?? -1, timestamp: snapped.timestamp
            )
            snappedLocation = location
            updateProgressIndex(location.coordinate)
            let primary = visual?.primaryContent
            let next = remainingSteps.dropFirst().first
            let ratio = loader?.trafficRatio ?? 1
            progress = RouteProgress(
                nextInstruction: primary?.text ?? remainingSteps.first?.instruction ?? "Dem Straßenverlauf folgen",
                maneuverSymbol: ManeuverSymbol.name(type: primary?.maneuverType, modifier: primary?.maneuverModifier),
                distanceToManeuver: tripProgress.distanceToNextManeuver,
                followingInstruction: next?.visualInstructions.first?.primaryContent.text ?? next?.instruction,
                followingSymbol: next?.visualInstructions.first.map { ManeuverSymbol.name(type: $0.primaryContent.maneuverType, modifier: $0.primaryContent.maneuverModifier) },
                remainingDistance: tripProgress.distanceRemaining,
                remainingTime: tripProgress.durationRemaining * ratio,
                lanes: (primary?.laneInfo ?? []).map { LaneHint(directions: $0.directions, active: $0.active) },
                arrived: false
            )
        case .complete:
            progress = RouteProgress(
                nextInstruction: "Ziel erreicht", maneuverSymbol: "flag.checkered", distanceToManeuver: 0,
                followingInstruction: nil, followingSymbol: nil, remainingDistance: 0, remainingTime: 0, lanes: [], arrived: true
            )
            // Bewegte Ziele (A, Kräfte) weiter verfolgen: bei der nächsten Bewegung neu berechnen.
            needsRoute = false
        case .idle:
            break
        }
    }

    private func updateProgressIndex(_ coordinate: CLLocationCoordinate2D) {
        guard let coordinates = route?.coordinates, !coordinates.isEmpty else { return }
        let here = GeoPoint(coordinate)
        let start = min(progressIndex, coordinates.count - 1)
        var best = start
        var bestDistance = CLLocationDistance.greatestFiniteMagnitude
        for i in start..<min(coordinates.count, start + 300) {
            let d = GeoPoint(coordinates[i]).distance(to: here)
            if d < bestDistance {
                bestDistance = d
                best = i
            }
        }
        progressIndex = best
    }

    /// Übergibt das aktuelle Ziel an Apple Karten.
    func openInMaps() {
        guard let destination else { return }
        let item = MKMapItem(location: CLLocation(latitude: destination.lat, longitude: destination.lon), address: nil)
        item.name = title
        let mode = transit ? MKLaunchOptionsDirectionsModeTransit : walking ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeDriving
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: mode])
    }
}

/// Einstellungen des Navigationskerns.
enum NaviConfig {
    static let controller = SwiftNavigationControllerConfig(
        waypointAdvance: .waypointWithinRange(30),
        stepAdvanceCondition: stepAdvanceDistanceEntryAndExit(distanceToEndOfStep: 25, distanceAfterEndOfStep: 5, minimumHorizontalAccuracy: 32),
        arrivalStepAdvanceCondition: stepAdvanceDistanceToEndOfStep(distance: 20, minimumHorizontalAccuracy: 32),
        // Ab 30 m neben der Route gilt man als abgewichen, dann wird sofort neu berechnet.
        routeDeviationTracking: .staticThreshold(minimumHorizontalAccuracy: 25, maxAcceptableDeviation: 30),
        snappedLocationCourseFiltering: .snapToRoute
    )
}

/// Reagiert auf Abweichungen: neue Route holen und sofort übernehmen.
private final class CoreDelegate: FerrostarCoreDelegate {
    func core(_: FerrostarCore, didStartWith _: Route) {}

    func core(_: FerrostarCore, correctiveActionForDeviation _: DeviationKind, remainingWaypoints waypoints: [Waypoint]) -> CorrectiveAction {
        .getNewRoutes(waypoints: waypoints)
    }

    func core(_ core: FerrostarCore, loadedAlternateRoutes routes: [Route]) {
        // Kann aus einem Hintergrund-Task kommen: Zustand des Kerns nur auf dem Hauptthread ändern.
        DispatchQueue.main.async {
            guard core.state?.isCalculatingNewRoute ?? false, let route = routes.first else { return }
            try? core.startNavigation(route: route, config: NaviConfig.controller)
        }
    }
}

/// Symbol für ein Manöver aus Art und Richtung.
enum ManeuverSymbol {
    static func name(type: ManeuverType?, modifier: ManeuverModifier?) -> String {
        switch type {
        case .arrive: return "flag.checkered"
        case .depart: return "arrow.triangle.turn.up.right.diamond.fill"
        case .roundabout, .rotary, .roundaboutTurn, .exitRoundabout, .exitRotary: return "arrow.triangle.turn.up.right.circle"
        default: break
        }
        switch modifier {
        case .uTurn: return "arrow.uturn.down"
        case .sharpRight, .right: return "arrow.turn.up.right"
        case .slightRight: return "arrow.up.right"
        case .slightLeft: return "arrow.up.left"
        case .left, .sharpLeft: return "arrow.turn.up.left"
        default: return "arrow.up"
        }
    }

    /// Pfeil für eine Fahrspur ("left", "slight right", "straight", …).
    static func lane(_ direction: String) -> String {
        switch direction.lowercased() {
        case "left", "sharp left": "arrow.turn.up.left"
        case "slight left": "arrow.up.left"
        case "right", "sharp right": "arrow.turn.up.right"
        case "slight right": "arrow.up.right"
        case "uturn", "u-turn": "arrow.uturn.down"
        default: "arrow.up"
        }
    }
}
