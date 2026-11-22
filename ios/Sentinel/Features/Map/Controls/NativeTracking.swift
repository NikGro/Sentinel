import MapKit
import SwiftUI
import UIKit

/// Zugriff auf die MapKit-Karte hinter SwiftUIs `Map`, um ihre eingebaute Standortverfolgung zu nutzen
/// (`userTrackingMode`). Die Karte folgt dann selbst flüssig, lässt Zoomen und Kippen zu, ohne die Kopplung zu lösen,
/// beendet sie beim Verschieben sofort, ohne die Wischbewegung zu unterbrechen, und beim Herausdrehen die
/// Kompass-Ausrichtung. So verhalten sich Apple Karten und Google Maps; eine eigene Nachführung kämpft dagegen
/// zwangsläufig mit den Kartengesten (Zittern, verlorenes Zoomen, Lösen zur falschen Zeit).
@MainActor
final class MapViewHandle {
    fileprivate weak var anchor: UIView?
    private weak var cached: MKMapView?

    /// Die Karte neben der Ankerfläche (gleicher Bildschirm, nicht in einem darüberliegenden Fenster).
    var mapView: MKMapView? {
        if let cached, cached.window != nil { return cached }
        guard let anchor else { return nil }
        var ancestor = anchor.superview
        for _ in 0..<8 {
            guard let candidate = ancestor else { break }
            if let found = Self.firstMap(in: candidate) {
                cached = found
                return found
            }
            ancestor = candidate.superview
        }
        return nil
    }

    private static func firstMap(in view: UIView) -> MKMapView? {
        if let map = view as? MKMapView { return map }
        for sub in view.subviews {
            if let map = firstMap(in: sub) { return map }
        }
        return nil
    }

    /// Kamera setzen und danach der Karte die Verfolgung übergeben. Erst die Ansicht (Abstand, Winkel, Richtung), dann
    /// die Verfolgung: Sie behält Abstand und Winkel, und das Setzen einer Kamera würde sie sonst wieder beenden.
    /// Liefert `false`, wenn keine MapKit-Karte gefunden wurde (dann übernimmt die eigene Nachführung).
    @discardableResult
    func track(center: CLLocationCoordinate2D, distance: CLLocationDistance, pitch: Double, heading: CLLocationDirection,
               followsHeading: Bool) -> Bool {
        guard let map = mapView else { return false }
        let camera = MKMapCamera(lookingAtCenter: center, fromDistance: distance, pitch: pitch, heading: heading)
        map.setCamera(camera, animated: true)
        let mode: MKUserTrackingMode = followsHeading ? .followWithHeading : .follow
        Task { @MainActor [weak map] in
            // Nach der Kamerafahrt (MapKit animiert etwa eine halbe Sekunde).
            try? await Task.sleep(for: .milliseconds(550))
            guard let map else { return }
            map.setUserTrackingMode(mode, animated: true)
        }
        return true
    }

    /// Verfolgung beenden; die Karte bleibt, wie sie ist.
    func stopTracking() {
        guard let map = mapView, map.userTrackingMode != .none else { return }
        map.setUserTrackingMode(.none, animated: false)
    }

    var trackingMode: MKUserTrackingMode? { mapView?.userTrackingMode }
}

/// Unsichtbare Fläche hinter der Karte, über die `MapViewHandle` die MapKit-Karte findet.
struct MapViewLocator: UIViewRepresentable {
    let handle: MapViewHandle

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        handle.anchor = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        handle.anchor = view
    }
}
