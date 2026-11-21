import MapKit
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Liest Berührungen auf der Karte mit, ohne einer Geste etwas wegzunehmen: ein Gestenerkenner am Fenster, der nie
/// selbst auslöst, Berührungen nicht abfängt und nur meldet, wie viele Finger höchstens lagen und wie weit einer
/// gewischt hat. SwiftUI-Gesten an der Karte (wie `SpatialEventGesture`) konkurrieren dagegen mit Apples
/// Kartengesten: Übernimmt MapKit, kommt ihr Ende nicht an, und Antipper auf die Karte gehen verloren.
struct TouchObserver: UIViewRepresentable {
    struct Summary: Equatable {
        /// Höchste Zahl gleichzeitig aufliegender Finger.
        var fingers: Int
        /// Weiteste Strecke eines Fingers vom Aufsetzpunkt, in Bildpunkten.
        var travel: CGFloat
    }

    /// Erster Finger setzt auf.
    let began: () -> Void
    /// Letzter Finger hebt ab (oder das System bricht ab).
    let ended: (Summary) -> Void

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.recognizer.began = began
        view.recognizer.ended = ended
        return view
    }

    func updateUIView(_ view: HostView, context: Context) {
        view.recognizer.began = began
        view.recognizer.ended = ended
    }

    /// Unsichtbare Fläche in der Größe der Karte; hängt den Erkenner ans Fenster und zählt nur Berührungen,
    /// die in ihrem Bereich beginnen.
    final class HostView: UIView {
        let recognizer = ObservingRecognizer(target: nil, action: nil)

        override func didMoveToWindow() {
            super.didMoveToWindow()
            recognizer.view?.removeGestureRecognizer(recognizer)
            recognizer.area = self
            window?.addGestureRecognizer(recognizer)
        }
    }

    final class ObservingRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
        weak var area: UIView?
        var began: (() -> Void)?
        var ended: ((Summary) -> Void)?
        private var starts: [ObjectIdentifier: CGPoint] = [:]
        private var summary = Summary(fingers: 0, travel: 0)

        override init(target: Any?, action: Selector?) {
            super.init(target: target, action: action)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
            delegate = self
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool { false }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf other: UIGestureRecognizer) -> Bool { false }

        /// Nur Finger auf genau dieser Karte zählen: nicht auf Knöpfen darüber und nicht in Fenstern, die über ihr
        /// liegen (Suche, Auswahl, ÖPNV-Karte), denn dort würde Wischen sonst die Kopplung lösen.
        private func inside(_ touch: UITouch) -> Bool {
            guard let area, area.bounds.contains(touch.location(in: area)) else { return false }
            var view = touch.view
            while let current = view, !(current is MKMapView) { view = current.superview }
            guard let map = view else { return false }
            // Die Karte muss nah neben der Beobachterfläche hängen (gleicher Bildschirm), nicht in einem anderen Fenster.
            var ancestor = area.superview
            for _ in 0..<8 {
                guard let candidate = ancestor else { return false }
                if map.isDescendant(of: candidate) { return true }
                ancestor = candidate.superview
            }
            return false
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            let fresh = starts.isEmpty
            for touch in touches where inside(touch) {
                starts[ObjectIdentifier(touch)] = touch.location(in: nil)
            }
            guard !starts.isEmpty else { return }
            if fresh {
                summary = Summary(fingers: 0, travel: 0)
                began?()
            }
            summary.fingers = max(summary.fingers, starts.count)
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            for touch in touches {
                guard let start = starts[ObjectIdentifier(touch)] else { continue }
                let p = touch.location(in: nil)
                summary.travel = max(summary.travel, hypot(p.x - start.x, p.y - start.y))
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { finish(touches) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { finish(touches) }

        private func finish(_ touches: Set<UITouch>) {
            let had = !starts.isEmpty
            for touch in touches { starts[ObjectIdentifier(touch)] = nil }
            if had, starts.isEmpty { ended?(summary) }
            // Nie auslösen; nach dem letzten Finger zurücksetzen, damit der Erkenner die nächste Berührung wieder sieht.
            if starts.isEmpty { state = .failed }
        }

        override func reset() {
            super.reset()
            starts = [:]
        }
    }
}
