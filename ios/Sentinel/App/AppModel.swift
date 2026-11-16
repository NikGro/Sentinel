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

    // MARK: Navigation

    var myPoint: GeoPoint? { location.current.map { GeoPoint($0.coordinate) } }

    /// Startet die dynamische Routenführung zu einem (auch bewegten) Ziel.
    func navigate(to target: NavigationTarget) {
        if target == .leapfrog, !lage.joinedLeapfrog { lage.joinLeapfrog() }
        if case .leapfrog = route.target, target != .leapfrog { lage.leaveLeapfrog() }
        route.start(
            target,
            origin: { [weak self] in self?.myPoint },
            resolve: { [weak self] target in self?.resolve(target) }
        )
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
        }
    }
}
