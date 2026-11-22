import MapKit
import SwiftUI
import UIKit

/// Was MapKits eigene Gestenerkenner gerade melden. Nur gelesen: Die Karte und ihre Gesten bleiben unverändert.
enum MapGestureEvent {
    /// Eine Geste (Verschieben, Zoomen, Drehen, Kippen) hat begonnen; vorher lag keine.
    case began
    /// Verschieben: Strecke in Bildpunkten und Anzahl der Finger (zwei Finger senkrecht heißt Kippen).
    case panned(distance: CGFloat, touches: Int)
    /// Zoomen mit zwei Fingern.
    case pinched
    /// Drehen mit zwei Fingern, in Grad seit Beginn der Geste.
    case rotated(degrees: Double)
    /// Doppeltippen (Zoomen ohne laufende Geste).
    case zoomTapped
    /// Alle Gesten sind vorbei (die Karte kann noch ausschwingen).
    case allEnded
}

/// Findet die MapKit-Karte hinter SwiftUIs `Map` und hängt sich lesend an ihre Gestenerkenner. So weiß die App sicher,
/// welche Geste läuft, statt sie aus Kamerawerten oder Fingern zu erraten. Die Kamera steuert allein die App über
/// SwiftUI; MapKits eigene Standortverfolgung wird bewusst nicht benutzt (zwei Stellen, die dieselbe Kamera steuern,
/// zoomten gegeneinander).
@MainActor
final class MapGestureWatcher: NSObject {
    fileprivate weak var anchor: UIView?
    private weak var map: MKMapView?
    private var watched = Set<ObjectIdentifier>()
    private var active = Set<ObjectIdentifier>()
    var onEvent: ((MapGestureEvent) -> Void)?

    /// Läuft gerade eine Geste?
    var isActive: Bool { !active.isEmpty }
    /// Hängt der Beobachter an einer Karte? Sonst weiß die App nichts über Gesten.
    var isAttached: Bool { map != nil && !watched.isEmpty }
    /// Gefundene Erkenner (Klassen), zur Fehlersuche; leer, solange keine Karte gefunden wurde.
    private(set) var summary = "keine Karte gefunden"
    /// Letztes Ereignis, für das Kamerawerte-Overlay.
    private(set) var lastEvent = "–"
    /// Wird nach dem ersten Anhängen einmal gemeldet (Messfühler).
    var onAttach: ((String) -> Void)?

    /// Karte suchen (gleicher Bildschirm, nicht in einem darüberliegenden Fenster) und neue Erkenner anhängen.
    func attachIfNeeded() {
        if map?.window == nil { map = nil }
        if map == nil, let anchor {
            var ancestor = anchor.superview
            for _ in 0..<8 {
                guard let candidate = ancestor else { break }
                if let found = Self.firstMap(in: candidate) {
                    map = found
                    break
                }
                ancestor = candidate.superview
            }
        }
        guard let map else { return }
        let before = watched.count
        let all = Self.recognizers(in: map, depth: 3)
        for recognizer in all where !watched.contains(ObjectIdentifier(recognizer)) {
            recognizer.addTarget(self, action: #selector(changed(_:)))
            watched.insert(ObjectIdentifier(recognizer))
        }
        if watched.count != before {
            summary = "\(all.count) Erkenner: " + all.map { String(describing: type(of: $0)) }.joined(separator: ",")
            onAttach?(summary)
        }
    }

    @objc private func changed(_ recognizer: UIGestureRecognizer) {
        let key = ObjectIdentifier(recognizer)
        lastEvent = "\(type(of: recognizer)) \(recognizer.state.rawValue)"
        if let tap = recognizer as? UITapGestureRecognizer {
            if tap.state == .ended, tap.numberOfTapsRequired >= 2 { onEvent?(.zoomTapped) }
            return
        }
        switch recognizer.state {
        case .began:
            let wasIdle = active.isEmpty
            active.insert(key)
            if wasIdle { onEvent?(.began) }
        case .changed:
            if let pan = recognizer as? UIPanGestureRecognizer, let view = pan.view {
                let t = pan.translation(in: view)
                onEvent?(.panned(distance: hypot(t.x, t.y), touches: pan.numberOfTouches))
            } else if recognizer is UIPinchGestureRecognizer {
                onEvent?(.pinched)
            } else if let rotation = recognizer as? UIRotationGestureRecognizer {
                onEvent?(.rotated(degrees: rotation.rotation * 180 / .pi))
            }
        case .ended, .cancelled, .failed:
            guard active.remove(key) != nil else { return }
            if active.isEmpty { onEvent?(.allEnded) }
        default:
            break
        }
    }

    private static func firstMap(in view: UIView) -> MKMapView? {
        if let map = view as? MKMapView { return map }
        for sub in view.subviews {
            if let map = firstMap(in: sub) { return map }
        }
        return nil
    }

    /// MapKits Erkenner sitzen an der Karte und ihren obersten Ebenen; tiefer liegen nur Symbole (nicht nötig, teuer).
    private static func recognizers(in view: UIView, depth: Int) -> [UIGestureRecognizer] {
        let own = view.gestureRecognizers ?? []
        guard depth > 0 else { return own }
        return own + view.subviews.flatMap { recognizers(in: $0, depth: depth - 1) }
    }
}

/// Unsichtbare Fläche hinter der Karte, über die `MapGestureWatcher` die MapKit-Karte findet.
struct MapGestureAnchor: UIViewRepresentable {
    let watcher: MapGestureWatcher

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        watcher.anchor = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        watcher.anchor = view
    }
}
