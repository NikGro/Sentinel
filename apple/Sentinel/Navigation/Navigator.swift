import Combine
import CoreLocation
import Foundation
import Observation
@preconcurrency import FerrostarCore
@preconcurrency import FerrostarCoreFFI
import SentinelKern

/// Zustand der Navigation für die Oberfläche (gleich aufgebaut wie auf Android).
struct Navistand {
    var ziel: Naviziel
    var titel = ""
    var fortschritt: Fortschritt?
    var route: [GeoPunkt] = []
    /// Eigener Standort, auf die Route gelegt (ohne GPS-Zittern neben der Straße).
    var aufRoute: CLLocation?
    var info = Routeninfo(sonderrechte: false, gemieden: false, verkehr: false, verkehrsfaktor: 1)
    var rechnet = false
    var fehler: String?
    /// Tempolimit an der eigenen Position (km/h), falls bekannt.
    var tempolimit: Int?
}

/// Netzwerkschicht des Navigationskerns: leitet die Anfrage an den eigenen Server, ergänzt sie im gemeinsamen Kern
/// (Sonderrechte, zu Fuß, Straße am Ziel) und merkt sich die Rückmeldung (Sonderrechte, Verkehr, Verkehrsfaktor).
final class NaviLader: URLRequestLoading, @unchecked Sendable {
    private let token: String
    private let lock = NSLock()
    private var optionen = Anfrageoptionen(sonderrechte: false, zuFuss: false, zielstrasse: nil)
    private var info = Routeninfo(sonderrechte: false, gemieden: false, verkehr: false, verkehrsfaktor: 1)

    init(token: String) { self.token = token }

    func setzen(_ o: Anfrageoptionen) { lock.withLock { optionen = o } }
    var letzteInfo: Routeninfo { lock.withLock { info } }

    func loadData(with urlRequest: URLRequest) async throws -> (Data, URLResponse) {
        let o = lock.withLock { optionen }
        var anfrage = urlRequest
        anfrage.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        anfrage.timeoutInterval = 20
        if let body = anfrage.httpBody, let text = String(data: body, encoding: .utf8) {
            anfrage.httpBody = Routenanfrage.shared.anpassen(body: text, o: o).data(using: .utf8)
        }
        let (daten, antwort) = try await URLSession.shared.data(for: anfrage)
        let http = antwort as? HTTPURLResponse
        let neu = Routeninfo.companion.ausKopfzeilen { name in http?.value(forHTTPHeaderField: name) }
        lock.withLock { info = neu }
        return (daten, antwort)
    }
}

/// Reagiert auf Abweichungen: neue Route holen und sofort übernehmen.
private final class KernDelegat: FerrostarCoreDelegate {
    let konfig: SwiftNavigationControllerConfig
    init(konfig: SwiftNavigationControllerConfig) { self.konfig = konfig }

    func core(_: FerrostarCore, didStartWith _: Route) {}

    func core(_: FerrostarCore, correctiveActionForDeviation _: DeviationKind, remainingWaypoints waypoints: [Waypoint]) -> CorrectiveAction {
        .getNewRoutes(waypoints: waypoints)
    }

    func core(_ core: FerrostarCore, loadedAlternateRoutes routes: [Route]) {
        let konfig = konfig
        DispatchQueue.main.async {
            guard core.state?.isCalculatingNewRoute ?? false, let route = routes.first else { return }
            try? core.startNavigation(route: route, config: konfig)
        }
    }
}

/// Navigation mit dem Ferrostar-Kern (gleiche Version und Einstellungen wie auf Android). Zielauflösung, Anfrage und
/// Anzeige stehen im gemeinsamen Kern. Sprachansagen sind bewusst stumm.
@MainActor
@Observable
final class Navigator {
    private(set) var stand: Navistand?

    @ObservationIgnored private var kern: FerrostarCore?
    @ObservationIgnored private var lader: NaviLader?
    @ObservationIgnored private var delegat: KernDelegat?
    @ObservationIgnored private var abos: Set<AnyCancellable> = []
    @ObservationIgnored private var schleife: Task<Void, Never>?
    /// Zählt Starts; eine Route aus einem älteren Lauf wird verworfen.
    @ObservationIgnored private var lauf = 0
    @ObservationIgnored private let nachfuehrung = Nachfuehrung()
    @ObservationIgnored private let vorlauf = Vorlaufplaner()
    @ObservationIgnored private let tempolimit = Tempolimitabfrage()
    /// Serverzugriff für das Straßenverzeichnis (Vorlauf, Tempolimit).
    @ObservationIgnored var api: () -> Api? = { nil }
    @ObservationIgnored private let ortsquelle = CoreLocationProvider(activityType: .automotiveNavigation, allowBackgroundLocationUpdates: true)

    /// Gleiche Einstellungen wie auf Android.
    static let konfig = SwiftNavigationControllerConfig(
        waypointAdvance: .waypointWithinRange(30),
        stepAdvanceCondition: stepAdvanceDistanceEntryAndExit(distanceToEndOfStep: 25, distanceAfterEndOfStep: 5, minimumHorizontalAccuracy: 32),
        arrivalStepAdvanceCondition: stepAdvanceDistanceToEndOfStep(distance: 20, minimumHorizontalAccuracy: 32),
        // Ab 30 m neben der Route gilt man als abgewichen; geprüft bis zu einer GPS-Ungenauigkeit von 50 m.
        routeDeviationTracking: .staticThreshold(minimumHorizontalAccuracy: 50, maxAcceptableDeviation: 30),
        snappedLocationCourseFiltering: .snapToRoute
    )

    /// Mit Server und Anmeldung verbinden (beim Anmelden); `nil` trennt.
    func verbinden(server: String?, token: String?) {
        stoppen()
        abos = []
        kern = nil
        lader = nil
        guard let server, let token else { return }
        let lader = NaviLader(token: token)
        let delegat = KernDelegat(konfig: Self.konfig)
        do {
            let kern = try FerrostarCore(
                wellKnownRouteProvider: .valhalla(endpointUrl: Routenanfrage.shared.adresse(server: server), profile: "auto"),
                locationProvider: ortsquelle,
                navigationControllerConfig: Self.konfig,
                networkSession: lader,
                spokenInstructionObserver: .initAVSpeechSynthesizer(isMuted: true)
            )
            // Kurz nach dem Start schwankt der Standort noch; nicht bei jedem Ausreißer neu rechnen.
            kern.minimumTimeBeforeRecalculation = 8
            kern.minimumMovementBeforeRecalculation = 30
            kern.delegate = delegat
            kern.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] s in MainActor.assumeIsolated { self?.uebernehmen(s) } }
                .store(in: &abos)
            self.kern = kern
            self.lader = lader
            self.delegat = delegat
        } catch {
            self.kern = nil
        }
    }

    /// Navigation starten; `lage` liefert jeweils den aktuellen Lagestand (bewegte Ziele werden nachgeführt).
    func starten(_ ziel: Naviziel, sonderrechte: Bool, zuFuss: Bool, lage: @escaping () -> LageStand) {
        stoppen()
        stand = Navistand(ziel: ziel)
        nachfuehrung.zuruecksetzen()
        vorlauf.zuruecksetzen()
        tempolimit.zuruecksetzen()
        ortsquelle.startUpdating()
        lauf += 1
        let nummer = lauf
        schleife = Task { [weak self] in
            while !Task.isCancelled {
                await self?.nachfuehren(ziel, nummer: nummer, sonderrechte: sonderrechte, zuFuss: zuFuss, lage: lage())
                try? await Task.sleep(for: .milliseconds(Int(Nachfuehrung.companion.TAKT_MS)))
            }
        }
    }

    func stoppen() {
        schleife?.cancel()
        schleife = nil
        kern?.stopNavigation()
        if stand != nil { ortsquelle.stopUpdating() }
        stand = nil
    }

    private func nachfuehren(_ ziel: Naviziel, nummer: Int, sonderrechte: Bool, zuFuss: Bool, lage: LageStand) async {
        let jetzt = Int64(Date.now.timeIntervalSince1970 * 1000)
        // Tempolimit an der eigenen Position (nicht zu Fuß)
        if !zuFuss, let l = ortsquelle.lastLocation, let a = api(),
           (try? await tempolimit.aktualisieren(api: a, ort: GeoPunkt(lat: l.coordinates.lat, lon: l.coordinates.lng), jetztMs: jetzt))?.boolValue == true {
            stand?.tempolimit = tempolimit.kmh.map { Int($0.int32Value) }
        }
        guard let aufgeloest = try? await Navizielaufloesung.shared.aufloesenMitVorlauf(ziel: ziel, stand: lage, jetztMs: jetzt, planer: vorlauf, api: api()) else {
            stand?.fehler = Navizielaufloesung.shared.fehlertext(ziel: ziel)
            return
        }
        let ort = aufgeloest.first!
        let parallel = aufgeloest.second
        stand?.titel = ort.titel
        guard stand?.rechnet == false, nachfuehrung.faellig(ziel: ort.punkt, jetztMs: jetzt) else { return }
        guard let kern, let lader else {
            stand?.fehler = "Navigation ist ohne Serververbindung nicht verfügbar."
            return
        }
        guard let start = ortsquelle.lastLocation else {
            stand?.fehler = "Eigener Standort unbekannt."
            return
        }
        lader.setzen(Anfrageoptionen(sonderrechte: sonderrechte, zuFuss: zuFuss, zielstrasse: ort.strasse, parallel: parallel))
        nachfuehrung.gerechnet(ziel: ort.punkt, jetztMs: jetzt)
        stand?.rechnet = true
        defer { stand?.rechnet = false }
        do {
            let routen = try await kern.getRoutes(
                initialLocation: start,
                waypoints: [Waypoint(coordinate: GeographicCoordinate(lat: ort.punkt.lat, lng: ort.punkt.lon), kind: .break, properties: nil)]
            )
            guard nummer == lauf, stand != nil, let erste = routen.first else { return }
            try kern.startNavigation(route: erste, config: Self.konfig)
            stand?.fehler = nil
            stand?.info = lader.letzteInfo
            stand?.route = erste.geometry.map { GeoPunkt(lat: $0.lat, lon: $0.lng) }
        } catch {
            nachfuehrung.fehlgeschlagen()
            stand?.fehler = sonderrechte ? "Keine Route mit Sonderrechten verfügbar." : "Route konnte nicht berechnet werden."
        }
    }

    private func uebernehmen(_ s: NavigationState?) {
        guard var aktuell = stand, let s else { return }
        if !s.routeGeometry.isEmpty { aktuell.route = s.routeGeometry.map { GeoPunkt(lat: $0.lat, lon: $0.lng) } }
        if let info = lader?.letzteInfo { aktuell.info = info }
        switch s.tripState {
        case let .navigating(_, _, snapped, remainingSteps, _, tripProgress, _, _, visual, _, _):
            let kurs = snapped.courseOverGround.map { CLLocationDirection($0.degrees) } ?? -1
            aktuell.aufRoute = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: snapped.coordinates.lat, longitude: snapped.coordinates.lng),
                altitude: 0, horizontalAccuracy: snapped.horizontalAccuracy, verticalAccuracy: -1,
                course: kurs, speed: snapped.speed?.value ?? -1, timestamp: snapped.timestamp
            )
            let primaer = visual?.primaryContent
            let naechster = remainingSteps.dropFirst().first
            let naechsteAnzeige = naechster?.visualInstructions.first?.primaryContent
            aktuell.fortschritt = Fortschritt.companion.aus(
                anweisung: primaer?.text ?? remainingSteps.first?.instruction,
                art: primaer.flatMap { $0.maneuverType.map { String(describing: $0) } },
                richtung: primaer.flatMap { $0.maneuverModifier.map { String(describing: $0) } },
                bisManoever: tripProgress.distanceToNextManeuver,
                danach: naechsteAnzeige?.text ?? naechster?.instruction,
                danachArt: naechsteAnzeige.flatMap { $0.maneuverType.map { String(describing: $0) } },
                danachRichtung: naechsteAnzeige.flatMap { $0.maneuverModifier.map { String(describing: $0) } },
                restMeter: tripProgress.distanceRemaining,
                restSekunden: tripProgress.durationRemaining,
                faktor: aktuell.info.verkehrsfaktor,
                spuren: (primaer?.laneInfo ?? []).map { Fahrspur(richtungen: $0.directions, aktiv: $0.active) }
            )
            aktuell.rechnet = s.isCalculatingNewRoute || aktuell.rechnet
        case .complete:
            aktuell.fortschritt = Fortschritt.companion.angekommenStand
        default:
            break
        }
        stand = aktuell
    }
}
