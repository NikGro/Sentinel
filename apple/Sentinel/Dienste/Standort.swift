import CoreLocation
import Foundation
import Observation
import SentinelKern

/// Eigener Standort für Karte und Übertragung.
///
/// Im Vordergrund für die Karte; im Dienst zusätzlich im Hintergrund (Hintergrund-Sitzung, Live-Aktivität). Außer Dienst
/// endet die Hintergrund-Sitzung sofort – dann startet iOS die App nach dem Wegwischen nicht neu. Übertragen wird ab
/// 5 m Bewegung, spätestens alle 15 s, wie auf Android.
@Observable
final class Standort {
    private(set) var aktuell: CLLocation?

    @ObservationIgnored var beiPosition: (Position) -> Void = { _ in }
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private var sitzung: CLBackgroundActivitySession?
    @ObservationIgnored private var zuletzt: CLLocation?
    @ObservationIgnored private var imDienst = false
    /// Zweite Zeile der Live-Aktivität (aus dem Kern); Änderungen werden sofort gezeigt.
    @ObservationIgnored var statuszeile = "" {
        didSet { if imDienst, statuszeile != oldValue { SharingActivity.refresh(detail: statuszeile); zuletztVerlaengert = .now } }
    }
    @ObservationIgnored private var zuletztVerlaengert: Date = .distantPast

    /// Standort für die Karte (Vordergrund), ohne Hintergrund-Sitzung.
    func starten() {
        guard updates == nil else { return }
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        updates = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.otherNavigation) {
                    guard let self, let ort = update.location else { continue }
                    self.aufnehmen(ort)
                }
            } catch {}
        }
    }

    func stoppen() {
        updates?.cancel()
        updates = nil
    }

    /// Dienststatus: im Dienst Hintergrund-Sitzung und Live-Aktivität, außer Dienst sofort beides beenden.
    func dienst(_ an: Bool) {
        guard an != imDienst else { return }
        imDienst = an
        if an {
            starten()
            sitzung = CLBackgroundActivitySession()
            SharingActivity.start(detail: statuszeile)
            zuletztVerlaengert = .now
        } else {
            sitzung?.invalidate()
            sitzung = nil
            SharingActivity.end()
        }
    }

    private func aufnehmen(_ ort: CLLocation) {
        guard ort.horizontalAccuracy >= 0 else { return }
        aktuell = ort
        let abstand = zuletzt.map { ort.distance(from: $0) } ?? .greatestFiniteMagnitude
        let zeit = zuletzt.map { ort.timestamp.timeIntervalSince($0.timestamp) } ?? .greatestFiniteMagnitude
        guard zeit >= 1, abstand >= 5 || zeit >= 15 else { return }
        zuletzt = ort
        let tempo: KotlinDouble? = ort.speed >= 0 ? KotlinDouble(value: min(ort.speed, 200)) : nil
        let kurs: KotlinDouble? = ort.course >= 0 ? KotlinDouble(value: ort.course) : nil
        beiPosition(Position(lat: ort.coordinate.latitude, lon: ort.coordinate.longitude, ts: Int64(ort.timestamp.timeIntervalSince1970 * 1000),
                             acc: KotlinDouble(value: ort.horizontalAccuracy), spd: tempo, hdg: kurs))
        // Verlängern höchstens einmal pro Minute (iOS begrenzt Aktualisierungen der Live-Aktivität).
        if imDienst, Date.now.timeIntervalSince(zuletztVerlaengert) * 1000 >= Double(Statusanzeige.shared.VERLAENGERN_MS) {
            zuletztVerlaengert = .now
            SharingActivity.refresh(detail: statuszeile)
        }
    }

    /// Zurück in der App: Anzeige neu anlegen, falls iOS sie beendet hat (nach spätestens acht Stunden).
    func vordergrund() {
        if imDienst { SharingActivity.start(detail: statuszeile) }
    }
}
