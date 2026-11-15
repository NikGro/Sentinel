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
    let photos = PhotoStore()
    let fahndung = FahndungStore()
    let route = RouteFollower()
    let lock = AppLock()

    private(set) var credentials: Credentials?

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
            guard let self, self.settings.sharesLocation else { return }
            self.lage.sendPosition(position)
        }
        lage.onMemberPosition = { [weak self] memberId, position in
            guard let self, self.lage.operation.modus == .fahndung else { return }
            self.fahndung.appendLive(memberId: memberId, position: position)
        }
        #if DEBUG
        if DemoData.isRequested {
            credentials = DemoData.credentials
            lage.loadDemo(DemoData.snapshot(modus: DemoData.requestedMode))
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
        photos.reset()
        lage.disconnect()
        Credentials.clear()
        credentials = nil
    }

    private func activate() {
        guard let credentials else { return }
        let client = APIClient(baseURL: credentials.serverURL, token: credentials.token)
        photos.client = client
        fahndung.client = client
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

    /// Startet die dynamische Routenführung zu einem (auch bewegten) Ziel.
    func navigate(to target: NavigationTarget) {
        route.start(
            target,
            origin: { [weak self] in self?.location.current.map { GeoPoint($0.coordinate) } },
            resolve: { [weak self] target in self?.resolve(target) }
        )
    }

    private func resolve(_ target: NavigationTarget) -> (point: GeoPoint, title: String)? {
        switch target {
        case .aPosition:
            guard let holder = lage.aHolder, let position = lage.aPosition else { return nil }
            return (position.point, "A-Position (\(holder.data.funkrufname))")
        case .member(let id):
            guard let member = lage.members[id], let position = lage.positions[id] else { return nil }
            return (position.point, member.data.funkrufname)
        case .vehicle(let id):
            guard let vehicle = lage.vehicles[id], let position = lage.position(ofVehicle: vehicle) else { return nil }
            return (position.point, vehicle.data.bezeichnung)
        case .target(let id):
            guard let target = lage.targets[id], let position = lage.position(ofTarget: target) else { return nil }
            return (position.point, target.data.displayName)
        case .point(let point, let title):
            return (point, title)
        }
    }
}
