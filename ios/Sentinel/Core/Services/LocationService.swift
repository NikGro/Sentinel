import CoreLocation
import Observation

/// Eigener Standort. Läuft, solange die Position geteilt wird, auch im Hintergrund weiter (blaue Statusanzeige).
@MainActor
@Observable
final class LocationService {
    private(set) var current: CLLocation?
    private(set) var authorization: CLAuthorizationStatus
    private(set) var isRunning = false

    /// Wird für jede Position aufgerufen, die an den Server gehen soll.
    var onPosition: (Position) -> Void = { _ in }

    private let manager = CLLocationManager()
    private var updates: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var backgroundSession: CLBackgroundActivitySession?
    private var lastSent: CLLocation?
    private var lastSentAt = Date.distantPast

    private static let minimumInterval: TimeInterval = 2
    private static let minimumDistance: CLLocationDistance = 5
    private static let heartbeatInterval: TimeInterval = 15

    init() {
        authorization = manager.authorizationStatus
    }

    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        // Hintergrund-Sitzung: Das System zeigt dabei die blaue Standortanzeige (Statusleiste bzw. Dynamic Island).
        backgroundSession = CLBackgroundActivitySession()
        // Dazu deutlich sichtbar auf Sperrbildschirm und Dynamic Island: „SENTINEL teilt deinen Standort“.
        SharingActivity.start(detail: "Live an das Einsatzteam")

        updates = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.otherNavigation) {
                    guard let self else { return }
                    self.authorization = self.manager.authorizationStatus
                    if let location = update.location { self.handle(location) }
                }
            } catch {
                // Standortdienst nicht verfügbar; ein erneuter Start erfolgt über `start()`.
            }
        }

        // Auch im Stand regelmäßig melden, damit die Position bei den anderen nicht veraltet.
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.heartbeatInterval))
                guard let self, let current = self.current else { continue }
                if Date.now.timeIntervalSince(self.lastSentAt) >= Self.heartbeatInterval { self.send(current, at: .now) }
            }
        }
    }

    func stop() {
        updates?.cancel()
        heartbeat?.cancel()
        updates = nil
        heartbeat = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        isRunning = false
        SharingActivity.end()
    }

    private func handle(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0 else { return }
        current = location
        let elapsed = location.timestamp.timeIntervalSince(lastSentAt)
        let moved = lastSent.map { location.distance(from: $0) } ?? .greatestFiniteMagnitude
        guard elapsed >= Self.minimumInterval, moved >= Self.minimumDistance || elapsed >= Self.heartbeatInterval else { return }
        send(location, at: location.timestamp)
    }

    private func send(_ location: CLLocation, at date: Date) {
        lastSent = location
        lastSentAt = date
        onPosition(
            Position(
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude,
                ts: (date.timeIntervalSince1970 * 1000).rounded(),
                acc: location.horizontalAccuracy,
                spd: location.speed >= 0 ? min(location.speed, 200) : nil,
                hdg: location.course >= 0 ? min(location.course, 360) : nil
            )
        )
    }
}
