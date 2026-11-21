import CoreLocation
import Observation
import SwiftUI
import UIKit

/// Zusammenbau der App: hält alle Dienste und verbindet sie miteinander.
@MainActor
@Observable
final class AppModel {
    let settings = LocalSettings()
    let lage = LageStore()
    let location = LocationService()
    let locationContext = LocationContext()
    let photos = PhotoStore()
    let fahndung = FahndungStore()
    let route = RouteFollower()
    let search = SearchService()
    let audio = AudioRecorder()
    let lock = AppLock()
    let alerts = AlertCenter()

    private(set) var credentials: Credentials?
    /// HTTP-Zugriff mit der Anmeldung dieses Geräts; `nil`, solange nicht angemeldet.
    private(set) var client: APIClient?

    enum Phase {
        case onboarding
        case connecting
        case profile
        case main
    }

    var phase: Phase {
        guard credentials != nil else { return .onboarding }
        guard lage.hasSnapshot else { return .connecting }
        return lage.me == nil ? .profile : .main
    }

    init() {
        credentials = Credentials.load()
        location.onPosition = { [weak self] position in
            guard let self else { return }
            if let current = self.location.current { self.locationContext.update(with: current) }
            // Im Ruhemodus verlässt der Standort das Gerät nicht.
            guard self.lage.me?.data.aktiv != false else { return }
            self.lage.sendPosition(position)
        }
        lage.onEvent = { [weak self] event in self?.handle(event) }
        alerts.openInstance = { [weak self] id in self?.openInstance(id) }
        lage.onMemberPosition = { [weak self] memberId, position in
            guard let self, self.settings.showsCoverage else { return }
            self.fahndung.appendLive(memberId: memberId, position: position)
        }
        #if DEBUG
        if DemoData.isRequested {
            credentials = DemoData.credentials
            lage.loadDemo(DemoData.snapshot(now: .now))
            // Echter Standortdienst auch im Rundgang, damit Kamera-Nachführung und Straßenschild mitgetestet werden.
            location.start()
            return
        }
        #endif
        if credentials != nil { activate() }
    }

    /// Meldet dieses Gerät mit dem Zugangscode am Server an.
    func enroll(server: String, code: String) async throws {
        guard let url = APIClient.normalizedServerURL(server) else { throw APIError.invalidServer }
        let enrollment = try await APIClient(baseURL: url, token: nil).enroll(code: code, deviceName: UIDevice.current.name)
        let credentials = Credentials(serverURL: url, deviceId: enrollment.deviceId, token: enrollment.token)
        credentials.save()
        self.credentials = credentials
        activate()
    }

    /// Entfernt Anmeldung und alle Einsatzdaten von diesem Gerät.
    func signOut() {
        // Beim Server abmelden (Gerät sperren, eigenes Profil entfernen); ohne Verbindung trotzdem lokal abmelden.
        if let client { Task { try? await client.signOutDevice() } }
        route.stop()
        location.stop()
        fahndung.stopReach()
        fahndung.clearCoverage()
        fahndung.client = nil
        route.disconnect()
        photos.reset()
        lage.disconnect()
        client = nil
        Credentials.clear()
        credentials = nil
    }

    private func activate() {
        guard let credentials else { return }
        let client = APIClient(baseURL: credentials.serverURL, token: credentials.token)
        self.client = client
        photos.client = client
        fahndung.client = client
        route.configure(serverURL: credentials.serverURL, token: credentials.token)
        alerts.requestPermission()
        lage.connect(credentials: credentials) { [weak self] in self?.signOut() }
        location.start()
    }

    // MARK: Lebenszyklus

    func didEnterBackground() {
        if settings.appLockEnabled, credentials != nil { lock.lock() }
    }

    func didBecomeActive() async {
        await lock.unlock()
    }

    // MARK: Hinweise

    /// Hinweise und Vibration zu Änderungen der Lage; beim Notruf eines anderen sofort mit Sonderrechten hinführen.
    private func handle(_ event: LageEvent) {
        func name(_ id: String) -> String { lage.members[id]?.data.spitzname ?? "Unbekannt" }
        switch event {
        case .aTaken(let id, let mine):
            if mine {
                alerts.post(.info, "Sie haben die A")
            } else {
                alerts.post(.warning, "A übernommen", "\(name(id)) hat die A-Position.")
            }
        case .aReleased(let previous):
            if previous == lage.selfId {
                alerts.post(.info, "A abgegeben")
            } else {
                alerts.post(.warning, "A ist frei", "\(name(previous)) hat die A-Position abgegeben.")
            }
        case .sosStarted(let id, let mine):
            if mine {
                alerts.post(.critical, "Notruf ausgelöst", "Alle Kräfte werden mit Sonderrechten zu Ihnen geführt.")
            } else {
                alerts.post(.critical, "SOS: \(name(id))", "Navigation mit Sonderrechten wurde gestartet.")
                navigate(to: .member(id))
                route.specialRights = true
            }
        case .sosEnded(let id):
            alerts.post(.info, "Notruf beendet", id == lage.selfId ? "Ihr Notruf ist beendet." : "Notruf von \(name(id)) ist beendet.")
        case .message(let message):
            guard !alerts.chatIsVisible else { return }
            let room = lage.rooms[message.data.roomId]?.data.name
            let text = message.data.text.isEmpty ? (message.data.anhang.map { $0.art == .audio ? "Sprachnachricht" : ($0.art == .bild ? "Foto" : "Datei") } ?? "") : message.data.text
            alerts.post(.info, "\(name(message.updatedBy))\(room.map { " in \($0)" } ?? "")", text)
        case .instanceNotice(let notice):
            if notice.art == "sos" {
                alerts.post(.critical, "SOS in \(notice.name)", "\(notice.spitzname) hat einen Notruf ausgelöst.", instance: notice.instanz)
            } else {
                alerts.post(.warning, "A in \(notice.name)", "\(notice.spitzname) hat die A-Position.", instance: notice.instanz)
            }
        case .geofence(let alarm):
            let area = alarm.titel.isEmpty ? "den Bereich" : "„\(alarm.titel)“"
            alerts.post(.critical, "Geofence: \(alarm.zielName)", "\(alarm.zielName) hat \(area) \(alarm.art == "betreten" ? "betreten" : "verlassen").")
        }
    }

    // MARK: Instanzen

    /// Bereich der App: normale Instanz oder Bearbeitung der dauerhaften Orte (reduzierte Werkzeuge).
    private(set) var editsPermanentLayer = false
    /// Wird hochgezählt, wenn die Karte in den Vordergrund soll (nach einem Wechsel der Instanz).
    private(set) var mapRequest = 0
    /// Einsatz, in den man nach dem Vorbereiten eines Pakets zurückkehrt.
    private(set) var returnInstance: String?

    /// Wechselt in eine Instanz; eine laufende Navigation gehört zur alten Lage und endet.
    /// Hauptmenü statt der Instanz zeigen (Instanzen wechseln, verlassen, Pakete). Außer Dienst ist es immer zu sehen.
    var showsHome = false

    func openInstance(_ id: String) {
        showsHome = false
        editsPermanentLayer = false
        settings.permanentLayerUnlocked = false
        mapRequest += 1
        // Außer Dienst auch die zuletzt geöffnete Instanz neu betreten (der Server schaltet dabei in den Dienst).
        guard id != lage.instanz || lage.me?.data.aktiv == false else { return }
        if lage.instances[id]?.data.isPackage == true, !lage.isPackageArea { returnInstance = lage.instanz }
        if route.isActive { stopNavigation() }
        lage.switchInstance(id)
    }

    func showMap() {
        showsHome = false
        mapRequest += 1
    }

    // MARK: Verlauf

    /// Spuren, die gerade auf der Karte gezeigt werden (Verlaufsmodus).
    var historySubjects: [SpurSubject] = [] {
        didSet { if !historySubjects.isEmpty { historyOpen = true } }
    }
    /// Verlaufsmodus offen, auch wenn noch keine Spur gewählt ist (Spuren kommen über das Plus dazu).
    var historyOpen = false

    func closeHistory() {
        historySubjects = []
        historyOpen = false
    }

    /// Spur auf der Karte zeigen und zur Karte wechseln.
    /// Zeitraum, den die Karte beim nächsten Öffnen des Verlaufs übernimmt (z. B. aus einem Standortverlauf-Objekt).
    var historyIntervalRequest: ClosedRange<Date>?

    /// Gespeicherten Standortverlauf im Verlaufsmodus öffnen: dieselben Spuren im selben Zeitraum.
    func openHistory(of object: MapObject) {
        guard let interval = object.historyInterval else { return }
        historySubjects = object.historySubjects
        historyIntervalRequest = interval
        if route.isActive { stopNavigation() }
        showsHome = false
        mapRequest += 1
    }

    func showHistory(_ subject: SpurSubject) {
        if !historySubjects.contains(subject) { historySubjects.append(subject) }
        if route.isActive { stopNavigation() }
        mapRequest += 1
    }

    /// Anzeigename einer Spur.
    func title(of subject: SpurSubject) -> String {
        switch subject.art {
        case .member: lage.members[subject.id].map { lage.label(of: $0.data) } ?? "Fahnder"
        case .target: lage.targets[subject.id]?.data.displayName ?? "Ziel"
        case .vehicle: lage.vehicles[subject.id]?.data.funkrufname ?? "Fahrzeug"
        case .tracker: lage.trackers[subject.id]?.data.name ?? "Tracker"
        }
    }

    /// Ein neues Paket öffnet der Server gleich; danach geht es in den bisherigen Einsatz zurück.
    func prepareNewPackage() {
        editPermanentLayer(false)
        if !lage.isPackageArea { returnInstance = lage.instanz }
        if route.isActive { stopNavigation() }
    }

    /// Verlässt den Sonderbereich (dauerhafte Orte oder Paket) zurück in den Einsatz.
    func leaveSpecialArea() {
        if editsPermanentLayer {
            editPermanentLayer(false)
        } else if lage.isPackageArea {
            let back = returnInstance.flatMap { lage.instances[$0] }.map(\.id) ?? Instance.mainId
            returnInstance = nil
            openInstance(back)
        }
    }

    func editPermanentLayer(_ on: Bool) {
        if on { showsHome = false }
        if on, route.isActive { stopNavigation() }
        // Dauerhafte Orte werden aus einem Einsatz heraus bearbeitet, nicht aus einem Paket.
        if on, lage.isPackageArea { openInstance(returnInstance ?? Instance.mainId) }
        editsPermanentLayer = on
        settings.permanentLayerUnlocked = on
        if on { mapRequest += 1 }
    }

    // MARK: Navigation

    var myPoint: GeoPoint? { location.current.map { GeoPoint($0.coordinate) } }

    /// Fahrten von Fahndern im ÖPNV (nach Fahrt-ID), für „Halte voraus“; nur geladen, wenn man zu ihnen navigiert.
    private(set) var memberTrips: [String: TripDetail] = [:]

    /// Startet die dynamische Routenführung zu einem (auch bewegten) Ziel.
    func navigate(to target: NavigationTarget) {
        loadTripIfNeeded(for: target.base)
        if target == .leapfrog, !lage.joinedLeapfrog { lage.joinLeapfrog() }
        if case .leapfrog = route.target, target != .leapfrog { lage.leaveLeapfrog() }
        route.start(
            target,
            origin: { [weak self] in self?.myPoint },
            resolve: { [weak self] target in self?.resolve(target) }
        )
    }

    /// Die ÖPNV-Fahrt, in der ein Ziel gerade sitzt: das Fahrzeug selbst, eine Zielperson darin (auch über ein
    /// Zielfahrzeug) oder ein Fahnder, der ÖPNV als Fortbewegung gewählt hat.
    func transitCourse(of target: NavigationTarget) -> TransitCourse? {
        switch target {
        case .object(let id):
            return lage.mapObjects[id].flatMap { TransitCourse($0.data) }
        case .target(let id):
            var current = lage.targets[id]
            for _ in 0..<3 {
                guard let binding = current?.data.bindung, let next = binding.zielId else { return nil }
                switch binding.art {
                case .oepnv: return lage.mapObjects[next].flatMap { TransitCourse($0.data) }
                case .fahrzeug: current = lage.targets[next]
                case .fuss, .objekt: return nil
                }
            }
            return nil
        case .member(let id):
            guard let member = lage.members[id]?.data, member.fortbewegung == .oepnv, let trip = member.oepnv else { return nil }
            if let object = lage.mapObjects.values.first(where: { $0.data.fahrt?.id == trip.linienId }), let course = TransitCourse(object.data) {
                return course
            }
            return memberTrips[trip.linienId].flatMap { TransitCourse($0) }
        default:
            return nil
        }
    }

    private func loadTripIfNeeded(for target: NavigationTarget) {
        guard case .member(let id) = target, let member = lage.members[id]?.data, member.fortbewegung == .oepnv,
              let tripId = member.oepnv?.linienId, memberTrips[tripId] == nil,
              !lage.mapObjects.values.contains(where: { $0.data.fahrt?.id == tripId }), let client else { return }
        Task { [weak self] in
            if let trip = try? await client.trip(id: tripId) { self?.memberTrips[tripId] = trip }
        }
    }

    func stopNavigation() {
        if route.target == .leapfrog { lage.leaveLeapfrog() }
        route.stop()
    }

    func resolve(_ target: NavigationTarget) -> (point: GeoPoint, title: String)? {
        switch target {
        case .aPosition:
            guard let holder = lage.aHolder, let position = lage.aPosition else { return nil }
            return (position.point, "A-Position (\(lage.label(of: holder.data)))")
        case .leapfrog:
            guard let stop = lage.myLeapfrogStop else { return nil }
            return (stop.point, "Haltestelle \(stop.name)")
        case .member(let id):
            guard let member = lage.members[id], let position = lage.positions[id] else { return nil }
            return (position.point, lage.label(of: member.data))
        case .vehicle(let id):
            guard let vehicle = lage.vehicles[id], let position = lage.position(ofVehicle: vehicle) else { return nil }
            return (position.point, vehicle.data.funkrufname)
        case .target(let id):
            guard let target = lage.targets[id], let position = lage.position(ofTarget: target) else { return nil }
            return (position.point, target.data.displayName)
        case .object(let id):
            guard let object = lage.mapObjects[id]?.data else { return nil }
            return (lage.position(ofObject: object), object.titel.isEmpty ? object.typ.title : object.titel)
        case .point(let point, let title):
            return (point, title)
        case .ahead(let base, let stops):
            // Fahrzeug schon angekommen oder Fahrt unbekannt: dann zum Ziel selbst.
            guard let stop = transitCourse(of: base)?.stop(ahead: stops) else { return resolve(base) }
            return (stop.point, "Haltestelle \(stop.name)")
        }
    }
}
