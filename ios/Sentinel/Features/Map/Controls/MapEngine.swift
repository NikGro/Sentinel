import MapKit
import Observation
import QuartzCore
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Was die Kartensteuerung meldet (für Messfühler und Bildschirm).
enum MapEngineEvent {
    /// Eine Geste hat begonnen; vorher lag keine.
    case began
    /// Verschieben mit einem Finger, Strecke in Bildpunkten seit Beginn.
    case panned(distance: CGFloat)
    case pinched
    case rotated(degrees: Double)
    case tilted
    case zoomTapped
    /// Alle Gesten sind vorbei.
    case allEnded
    /// Die Kopplung an den eigenen Standort wurde durch eine Geste gelöst (Grund: verschoben bzw. gedreht).
    case released(String)
    /// Hinweis für das Messprotokoll.
    case note(String)
    /// Angeheftet: Zoom oder Neigung des Nutzers ist der neue Sollwert.
    case target(distance: CLLocationDistance, pitch: Double)
}

/// Eigene Kartensteuerung nach dem Prinzip von Google Maps: Eine einzige Stelle bewegt die Kamera. MapKits eigene
/// Gesten sind abgeschaltet (`interactionModes: []`); Verschieben, Zoomen, Drehen und Kippen erkennt die Steuerung
/// selbst und setzt die Kamera der MapKit-Karte direkt, Bild für Bild. Angeheftet folgt sie dem eigenen Standort bei
/// jedem Bild ein Stück (keine langen Kamerafahrten, die hinterherlaufen oder Gesten schlucken); Zoomen und Kippen
/// ändern dann nur Sollabstand und Sollwinkel. Seitliches Verschieben oder Herausdrehen löst die Kopplung.
///
/// Warum: Mit SwiftUIs Kameraposition oder Apples Verfolgung steuerten immer zwei Stellen dieselbe Kamera
/// (siehe `docs/Fehlerprotokoll.md`). Apples Verfolgung setzt zudem beim Einschalten ihren eigenen Abstand (~4,9 km).
@MainActor
@Observable
final class MapEngine {
    /// Angeheftet am eigenen Standort; `nil` = frei.
    private(set) var pin: CameraPin?
    /// Angeheftet und angekommen: Stelle des eigenen Standorts auf dem Bildschirm (Fensterkoordinaten). Dort zeichnet
    /// die App den eigenen Punkt selbst, ruhig und genau in der Mitte; sonst `nil` (MapKits Standortanzeige).
    private(set) var centerPoint: CGPoint?

    @ObservationIgnored fileprivate weak var anchor: UIView?
    @ObservationIgnored private(set) weak var map: MKMapView?
    @ObservationIgnored private var helper: EngineHelper?
    /// Ereignisse für Messfühler und Bildschirm.
    @ObservationIgnored var onEvent: ((MapEngineEvent) -> Void)?
    /// Eigener Standort (für das Anheften).
    @ObservationIgnored var locationProvider: (() -> CLLocation?)?
    /// Fahrt- bzw. Blickrichtung für die Kompass-Ausrichtung.
    @ObservationIgnored var courseProvider: (() -> CLLocationDirection?)?
    /// Sollabstand und Sollwinkel beim Anheften (ändern sich durch Zoomen und Kippen des Nutzers).
    @ObservationIgnored private(set) var followDistance: CLLocationDistance = 550
    @ObservationIgnored private(set) var followPitch: Double = 40
    /// Kamera, die gesetzt wird, sobald die Karte gefunden ist.
    @ObservationIgnored private var pendingCamera: EngineCamera?
    /// Herkunft der Mitte beim Anheften (zur Fehlersuche): Standortsymbol der Karte oder eigene Glättung.
    @ObservationIgnored private(set) var followSource = "–"

    // Geglätteter Stand beim Anheften.
    @ObservationIgnored private var smooth: EngineCamera?
    @ObservationIgnored private var flight: Flight?
    @ObservationIgnored private var momentum: CGPoint = .zero
    @ObservationIgnored private var lastTick: CFTimeInterval = 0

    // Gesten.
    @ObservationIgnored private var active = Set<ObjectIdentifier>()
    @ObservationIgnored private var multi: MultiTouch?
    @ObservationIgnored private var panLast: CGPoint?
    @ObservationIgnored private var panReleased = false
    /// In dieser Geste lagen schon zwei Finger: Verschieben mit einem Finger löst dann nicht (Zoomen, Kippen).
    @ObservationIgnored private var sessionMulti = false
    /// Letzte Bewegung mit zwei Fingern: Das Abheben am Ende eines Zoomens zählt nicht als Tippen mit zwei Fingern.
    @ObservationIgnored private var lastMultiTouchAt: CFTimeInterval = 0
    @ObservationIgnored private var lastTarget: (distance: CLLocationDistance, pitch: Double) = (0, 0)
    @ObservationIgnored private var multiPending: (UIPinchGestureRecognizer, UIRotationGestureRecognizer, UIPanGestureRecognizer)?
    @ObservationIgnored private var quickZoom: (start: CGPoint, distance: CLLocationDistance, moved: Bool)?

    /// Hängt die Steuerung an einer Karte?
    var isAttached: Bool { map != nil }
    /// Läuft gerade eine Geste?
    var isGestureActive: Bool { !active.isEmpty }
    /// Letztes Ereignis, für das Kamerawerte-Overlay.
    @ObservationIgnored private(set) var lastEvent = "–"

    // MARK: Befehle

    /// Anheften am eigenen Standort mit Abstand und Winkel. Die Kamera gleitet von der aktuellen Ansicht dorthin und
    /// folgt dann bei jedem Bild.
    func pinTo(_ mode: CameraPin, distance: CLLocationDistance, pitch: Double) {
        flight = nil
        momentum = .zero
        followDistance = distance
        followPitch = pitch
        if pin == nil || smooth == nil { smooth = current }
        pin = mode
        startTicking()
    }

    /// Angeheftet nur den Winkel ändern (2D/3D-Knopf).
    func setFollowPitch(_ pitch: Double) {
        followPitch = pitch
    }

    func unpin() {
        guard pin != nil else { return }
        pin = nil
        smooth = nil
        centerPoint = nil
    }

    /// Kamerafahrt (löst die Kopplung). Eine Geste bricht sie sofort ab.
    func fly(to camera: MapCamera, duration: Double = 0.6) {
        fly(to: EngineCamera(camera), duration: duration)
    }

    /// Kamerafahrt, nach der der Mittelpunkt von `camera` waagerecht mittig und senkrecht mittig zwischen `topY` und
    /// `bottomY` (Fensterkoordinaten) liegt statt in der Bildmitte, z. B. zwischen Suchleiste und einem Fenster unten.
    func fly(to camera: MapCamera, betweenTop topY: CGFloat, bottom bottomY: CGFloat, duration: Double = 0.6) {
        guard let map else {
            fly(to: camera, duration: duration)
            return
        }
        var target = EngineCamera(camera)
        let coordinate = camera.centerCoordinate
        // Kurz unsichtbar auf das Ziel setzen (gleicher Durchlauf, nichts wird gezeichnet) und ausmessen, wo die
        // Koordinate läge; zweimal nachbessern (bei Neigung ist der Maßstab nicht überall gleich).
        let saved = map.camera.copy() as! MKMapCamera
        let windowHeight = map.window?.bounds.height ?? map.bounds.height
        let middleY = (max(topY, 0) + min(bottomY, windowHeight)) / 2
        let wanted = CGPoint(x: map.bounds.midX, y: map.convert(CGPoint(x: 0, y: middleY), from: nil).y)
        for _ in 0..<2 {
            map.camera = MKMapCamera(lookingAtCenter: target.center, fromDistance: target.distance, pitch: target.pitch, heading: target.heading)
            let atWanted = map.convert(wanted, toCoordinateFrom: map)
            guard CLLocationCoordinate2DIsValid(atWanted) else { break }
            let c = MKMapPoint(target.center), a = MKMapPoint(atWanted), k = MKMapPoint(coordinate)
            target.center = MKMapPoint(x: c.x + k.x - a.x, y: c.y + k.y - a.y).coordinate
        }
        map.camera = saved
        fly(to: target, duration: duration)
    }

    /// Ausschnitt zeigen, z. B. Spuren, Cluster oder eine Linie. Ohne Drehung und Neigung, wie bisher bei Regionen.
    func show(_ region: MKCoordinateRegion, padding: UIEdgeInsets = .zero, duration: Double = 0.6) {
        show(Self.mapRect(region), padding: padding, duration: duration)
    }

    func show(_ rect: MKMapRect, padding: UIEdgeInsets = .zero, duration: Double = 0.6) {
        guard let map else {
            let region = MKCoordinateRegion(rect)
            pendingCamera = EngineCamera(center: region.center, distance: max(region.span.latitudeDelta * 111_000 * 1.6, 300), heading: 0, pitch: 0)
            return
        }
        // MapKit rechnet den Abstand aus: kurz unsichtbar setzen (gleicher Durchlauf, nichts wird gezeichnet), lesen,
        // zurücksetzen, dann selbst hinfahren.
        let saved = map.camera.copy() as! MKMapCamera
        map.setVisibleMapRect(rect, edgePadding: padding, animated: false)
        var target = EngineCamera(map.camera)
        map.camera = saved
        target.heading = 0
        target.pitch = 0
        fly(to: target, duration: duration)
    }

    /// Ohne Fahrt setzen.
    func jump(to camera: MapCamera) {
        unpin()
        flight = nil
        momentum = .zero
        apply(EngineCamera(camera))
    }

    private func fly(to target: EngineCamera, duration: Double) {
        unpin()
        momentum = .zero
        guard let start = current else {
            pendingCamera = target
            return
        }
        flight = Flight(from: start, to: target, start: CACurrentMediaTime(), duration: max(duration, 0.05))
        startTicking()
    }

    // MARK: Karte finden

    func attachIfNeeded() {
        if map?.window == nil, map != nil { map = nil }
        guard map == nil, let anchor else { return }
        var ancestor = anchor.superview
        var found: MKMapView?
        for _ in 0..<8 {
            guard let candidate = ancestor else { break }
            if let hit = Self.firstMap(in: candidate) {
                found = hit
                break
            }
            ancestor = candidate.superview
        }
        guard let found else { return }
        map = found
        let helper = self.helper ?? EngineHelper(engine: self)
        self.helper = helper
        helper.install(on: found)
        if let pendingCamera {
            self.pendingCamera = nil
            apply(pendingCamera)
        }
        if pin != nil || flight != nil { startTicking() }
    }

    // MARK: Bild für Bild

    private func startTicking() {
        helper?.startDisplayLink()
    }

    fileprivate func tick(_ time: CFTimeInterval) {
        let dt = lastTick == 0 ? 1.0 / 60 : min(max(time - lastTick, 0.001), 0.1)
        lastTick = time
        if let (pinch, rotation, twoPan) = multiPending {
            multiPending = nil
            processMulti(pinch: pinch, rotation: rotation, twoPan: twoPan)
        }
        if momentum != .zero, let map {
            let center = CGPoint(x: map.bounds.midX, y: map.bounds.midY)
            shift(from: center, to: CGPoint(x: center.x + momentum.x * dt, y: center.y + momentum.y * dt))
            let decay = pow(0.135, dt)
            momentum = CGPoint(x: momentum.x * decay, y: momentum.y * decay)
            if hypot(momentum.x, momentum.y) < 15 { momentum = .zero }
        }
        if let flight {
            let t = min((time - flight.start) / flight.duration, 1)
            apply(flight.from.interpolated(to: flight.to, t: Self.ease(t)))
            if t >= 1 { self.flight = nil }
        } else if pin != nil {
            follow(dt: dt)
        }
        if flight == nil, pin == nil, momentum == .zero, multi == nil {
            lastTick = 0
            helper?.stopDisplayLink()
        }
    }

    private func follow(dt: Double) {
        guard let pin, var smooth = smooth ?? current else { return }
        // Ziel der Mitte: der letzte Standort, vorausgerechnet mit Geschwindigkeit und Richtung. Nicht MapKits
        // gezeichnetes Standortsymbol: Dessen Lage hängt selbst von der Kamera ab, das Folgen schaukelte sich auf
        // (Punkt zitterte angeheftet). Angeheftet zeichnet die App den eigenen Punkt selbst fest in der Mitte.
        var target: CLLocationCoordinate2D?
        let tau = 0.25
        if let fix = locationProvider?() {
            var point = fix.coordinate
            if fix.speed > 0.5, fix.course >= 0 {
                let age = min(max(Date.now.timeIntervalSince(fix.timestamp), 0), 1.5)
                point = Self.offset(point, meters: fix.speed * age, bearing: fix.course)
            }
            target = point
            followSource = "eigen"
        }
        if let target {
            let from = MKMapPoint(smooth.center), to = MKMapPoint(target)
            // Weit weg (Anheften aus der Ferne): schneller hin, sonst dauert es lange.
            let far = from.distance(to: to) > 2000
            let a = 1 - exp(-dt / (far ? 0.18 : tau))
            smooth.center = MKMapPoint(x: from.x + (to.x - from.x) * a, y: from.y + (to.y - from.y) * a).coordinate
        }
        let headingTarget = pin == .heading ? (courseProvider?() ?? smooth.heading) : 0
        smooth.heading = Self.approachAngle(smooth.heading, headingTarget, a: 1 - exp(-dt / 0.35))
        smooth.distance = exp(log(smooth.distance) + (log(followDistance) - log(smooth.distance)) * (1 - exp(-dt / 0.2)))
        smooth.pitch += (followPitch - smooth.pitch) * (1 - exp(-dt / 0.2))
        self.smooth = smooth
        apply(smooth)
        // Angekommen (Mitte nahe am Standort): Ab hier steht der eigene Punkt fest in der Bildmitte.
        if let target, let map {
            let near = MKMapPoint(smooth.center).distance(to: MKMapPoint(target)) < max(25, smooth.distance * 0.03)
            let point = map.convert(smooth.center, toPointTo: nil)
            let locked: CGPoint? = near ? point : nil
            if locked == nil && centerPoint != nil {
                centerPoint = nil
            } else if let locked, centerPoint.map({ hypot($0.x - locked.x, $0.y - locked.y) > 0.5 }) ?? true {
                centerPoint = locked
            }
        }
    }

    /// Abstand des Standortsymbols vom Kameramittelpunkt auf dem Bildschirm in Punkten (Messfühler: sitzt es
    /// angeheftet genau dort, wohin die Kamera schaut? MapKit legt die Mitte wegen der Leisten etwas tiefer).
    var puckOffset: CGPoint? {
        guard let map, let view = map.view(for: map.userLocation), let superlayer = view.layer.superlayer else { return nil }
        let layer = view.layer.presentation() ?? view.layer
        let point = map.layer.convert(layer.position, from: superlayer)
        let center = map.convert(map.camera.centerCoordinate, toPointTo: map)
        return CGPoint(x: point.x - center.x, y: point.y - center.y)
    }

    // MARK: Kamera lesen und setzen

    private var current: EngineCamera? {
        map.map { EngineCamera($0.camera) }
    }

    private func apply(_ camera: EngineCamera) {
        guard let map else {
            pendingCamera = camera
            return
        }
        map.camera = MKMapCamera(lookingAtCenter: camera.center, fromDistance: camera.distance, pitch: camera.pitch, heading: camera.heading)
    }

    /// Verschiebt die Karte so, dass der Inhalt unter `from` danach unter `to` liegt.
    private func shift(from: CGPoint, to: CGPoint) {
        guard let map else { return }
        let a = map.convert(from, toCoordinateFrom: map), b = map.convert(to, toCoordinateFrom: map)
        guard CLLocationCoordinate2DIsValid(a), CLLocationCoordinate2DIsValid(b) else { return }
        let ma = MKMapPoint(a), mb = MKMapPoint(b)
        guard var camera = current else { return }
        let c = MKMapPoint(camera.center)
        camera.center = MKMapPoint(x: c.x + ma.x - mb.x, y: c.y + ma.y - mb.y).coordinate
        apply(camera)
    }

    // MARK: Gesten

    fileprivate func gestureState(_ recognizer: UIGestureRecognizer) {
        let key = ObjectIdentifier(recognizer)
        switch recognizer.state {
        case .began:
            let wasIdle = active.isEmpty
            active.insert(key)
            if wasIdle {
                flight = nil
                momentum = .zero
                panReleased = false
                sessionMulti = false
                emit(.began)
            }
        case .ended, .cancelled, .failed:
            guard active.remove(key) != nil else { return }
            if active.isEmpty {
                multi = nil
                emit(.allEnded)
            }
        default:
            break
        }
        lastEvent = "\(type(of: recognizer)) \(recognizer.state.rawValue)"
    }

    fileprivate func pan(_ recognizer: UIPanGestureRecognizer) {
        guard let map else { return }
        gestureState(recognizer)
        let location = recognizer.location(in: map)
        if (helper?.maxTouches ?? 1) >= 2 { sessionMulti = true }
        if quickZoom != nil || multi != nil || sessionMulti {
            panLast = nil
            return
        }
        switch recognizer.state {
        case .began:
            panLast = location
        case .changed:
            let total = recognizer.translation(in: map)
            let length = hypot(total.x, total.y)
            emit(.panned(distance: length))
            if pin != nil {
                // Angeheftet bleibt die Karte am Standort, bis die Schwelle überschritten ist; dann frei und ab
                // hier verschieben (kein Sprung).
                guard length > 30 else {
                    panLast = location
                    return
                }
                unpin()
                panReleased = true
                emit(.released("verschoben"))
            }
            if let last = panLast { shift(from: last, to: location) }
            panLast = location
        case .ended:
            panLast = nil
            if pin == nil {
                let v = recognizer.velocity(in: map)
                momentum = hypot(v.x, v.y) > 60 ? v : .zero
                if momentum != .zero { startTicking() }
            }
        default:
            panLast = nil
        }
    }

    /// Zwei Finger: Zoomen, Drehen, Verschieben und (beide senkrecht in dieselbe Richtung) Kippen, gemeinsam
    /// ausgewertet. Frei bleibt der Punkt zwischen den Fingern unter den Fingern; angeheftet bleibt der Standort in
    /// der Mitte.
    fileprivate func multiTouch(_ recognizer: UIGestureRecognizer, pinch: UIPinchGestureRecognizer, rotation: UIRotationGestureRecognizer, twoPan: UIPanGestureRecognizer) {
        guard let map else { return }
        gestureState(recognizer)
        guard recognizer.state == .began || recognizer.state == .changed, recognizer.numberOfTouches >= 2 else { return }
        sessionMulti = true
        lastMultiTouchAt = CACurrentMediaTime()
        let centroid = recognizer.location(in: map)
        if multi == nil {
            guard let start = current else { return }
            let anchor = map.convert(centroid, toCoordinateFrom: map)
            multi = MultiTouch(start: start, anchor: CLLocationCoordinate2DIsValid(anchor) ? anchor : nil,
                               scaleBase: pinch.state == .began || pinch.state == .changed ? pinch.scale : 1,
                               rotationBase: rotation.state == .began || rotation.state == .changed ? rotation.rotation : 0,
                               panBase: twoPan.translation(in: map),
                               startDistance: pin != nil ? (smooth?.distance ?? start.distance) : start.distance,
                               startPitch: pin != nil ? (smooth?.pitch ?? start.pitch) : start.pitch)
        }
        guard var m = multi else { return }
        // Erkenner, die mitten in der Geste (neu) beginnen, setzen ihren Wert zurück (Drehung 0, Zoom 1). Damit die
        // Karte nicht springt, setzt ihr Beginn den Bezug so, dass der bisherige Wert bleibt; ein beendeter Erkenner
        // behält seinen letzten Wert.
        if recognizer === rotation, rotation.state == .began { m.rotationBase = rotation.rotation - m.lastRotation }
        if recognizer === pinch, pinch.state == .began { m.scaleBase = pinch.scale / max(m.lastScale, 0.01) }
        multi = m
        // Ausgewertet wird einmal je Bild (im Bildtakt), nicht bei jeder Meldung der drei Erkenner: sonst setzt die
        // Karte je Bild mehrmals die Kamera mit teils veralteten Werten des jeweils anderen Erkenners.
        multiPending = (pinch, rotation, twoPan)
        startTicking()
    }

    private func processMulti(pinch: UIPinchGestureRecognizer, rotation: UIRotationGestureRecognizer, twoPan: UIPanGestureRecognizer) {
        guard let map, var m = multi else { return }
        let all: [UIGestureRecognizer] = [pinch, rotation, twoPan]
        guard let touching = all.first(where: { ($0.state == .began || $0.state == .changed) && $0.numberOfTouches >= 2 }) else { return }
        let centroid = touching.location(in: map)
        if rotation.state == .began || rotation.state == .changed { m.lastRotation = rotation.rotation - m.rotationBase }
        if pinch.state == .began || pinch.state == .changed { m.lastScale = pinch.scale / m.scaleBase }
        multi = m
        let scale = m.lastScale
        let rotationDegrees = Double(m.lastRotation) * 180 / .pi
        let t = twoPan.translation(in: map)
        let move = CGPoint(x: t.x - m.panBase.x, y: t.y - m.panBase.y)

        // Kippen erkennen: beide Finger senkrecht, kaum Zoom und Drehung.
        if m.mode == .undecided {
            if abs(move.y) > 12, abs(move.y) > 2 * abs(move.x), abs(scale - 1) < 0.08, abs(rotationDegrees) < 6 {
                m.mode = .tilt
                m.panBase = t
            } else if abs(scale - 1) > 0.05 || abs(rotationDegrees) > 6 || hypot(move.x, move.y) > 20 {
                m.mode = .transform
            }
        }
        multi = m

        switch m.mode {
        case .undecided:
            return
        case .tilt:
            let dy = t.y - m.panBase.y
            let pitch = min(max(m.startPitch - Double(dy) * 0.35, 0), 80)
            emit(.tilted)
            if pin != nil {
                followPitch = pitch
                smooth?.pitch = pitch
                if let smooth { apply(smooth) }
                emit(.target(distance: followDistance, pitch: pitch))
            } else if var camera = current {
                camera.pitch = pitch
                apply(camera)
            }
        case .transform:
            if scale != 1 { emit(.pinched) }
            // Absicht festlegen, je nachdem, was zuerst deutlich wird: Wer zoomt, dreht oft unabsichtlich ein Stück mit.
            if m.intent == .none {
                if abs(scale - 1) > 0.08 { m.intent = .zoom } else if abs(rotationDegrees) > 8 { m.intent = .rotate }
                if m.intent != .none {
                    emit(.note(String(format: "absicht %@ zoom=%.2f drehung=%.0f°", m.intent == .zoom ? "zoom" : "drehen", scale, rotationDegrees)))
                }
                multi = m
            }
            // Drehen erst ab einigen Grad (beim Zoomen deutlich mehr), damit Zoomen nicht nebenbei dreht. Je stärker
            // gezoomt wird, desto mehr Drehung braucht das Lösen.
            let zoomAmount = abs(log(Double(max(scale, 0.01))))
            // Feste Drehschwelle: Eine höhere Schwelle beim Zoomen ließ die Karte mitten in der Geste stehen, bis
            // 25° erreicht waren (Gerätedaten: hing bei 290°, „in beide Richtungen“).
            let turnThreshold = 10.0
            let releaseThreshold = max(m.intent == .zoom ? 45.0 : 20.0, 20 + 60 * zoomAmount)
            // Ab der Schwelle dreht die Karte, von dort an ohne Sprung (Versatz merken statt abziehen).
            if m.turnOffset == nil, abs(rotationDegrees) > turnThreshold {
                m.turnOffset = rotationDegrees
                multi = m
            }
            var turn = 0.0
            if let offset = m.turnOffset {
                turn = rotationDegrees - offset
                emit(.rotated(degrees: rotationDegrees))
            }
            if pin != nil, abs(rotationDegrees) > releaseThreshold {
                // Herausdrehen löst; ab hier frei weiterdrehen, vom aktuellen Stand aus.
                unpin()
                emit(.released(String(format: "gedreht %.0f° zoom=%.2f", rotationDegrees, scale)))
                if let now = current {
                    // Ab hier frei weiterdrehen und -zoomen, ohne neue Schwelle (die Geste läuft ohne Pause weiter).
                    m.start = now
                    m.startDistance = now.distance
                    m.rotationBase = rotation.rotation
                    m.lastRotation = 0
                    m.scaleBase = pinch.scale
                    m.lastScale = 1
                    m.turnOffset = 0
                    m.anchor = map.convert(centroid, toCoordinateFrom: map)
                    multi = m
                }
                return
            }
            let distance = min(max(m.startDistance / Double(max(scale, 0.01)), 40), 40_000_000)
            if pin != nil {
                followDistance = distance
                smooth?.distance = distance
                if let smooth { apply(smooth) }
                emit(.target(distance: distance, pitch: followPitch))
            } else {
                var camera = m.start
                camera.center = current?.center ?? camera.center
                camera.distance = distance
                camera.heading = m.start.heading - turn
                camera.pitch = current?.pitch ?? camera.pitch
                apply(camera)
                if let anchor = m.anchor {
                    let now = map.convert(anchor, toPointTo: map)
                    // Nahe am Horizont (stark gekippt) ist die Umrechnung unzuverlässig: dann nicht nachziehen.
                    if hypot(now.x - centroid.x, now.y - centroid.y) < 150 { shift(from: now, to: centroid) }
                }
                if let last = m.lastHeading {
                    var jump = abs(camera.heading - last).truncatingRemainder(dividingBy: 360)
                    if jump > 180 { jump = 360 - jump }
                    if jump > 12 { emit(.note(String(format: "sprung drehung %.0f° roh=%.0f° zoom=%.2f", jump, rotationDegrees, scale))) }
                }
                m.lastHeading = camera.heading
                multi = m
            }
        }
    }

    /// Doppeltippen (hineinzoomen) bzw. Doppeltippen und Ziehen (mit einem Finger zoomen, nach unten hinein).
    fileprivate func handleQuickZoom(_ recognizer: UILongPressGestureRecognizer) {
        guard let map else { return }
        gestureState(recognizer)
        let location = recognizer.location(in: map)
        switch recognizer.state {
        case .began:
            quickZoom = (location, pin != nil ? followDistance : (current?.distance ?? 1000), false)
        case .changed:
            guard var zoom = quickZoom else { return }
            let dy = location.y - zoom.start.y
            if abs(dy) > 8 { zoom.moved = true }
            quickZoom = zoom
            guard zoom.moved else { return }
            let distance = min(max(zoom.distance * exp(-Double(dy) * 0.01), 40), 40_000_000)
            setDistance(distance, keeping: zoom.start)
        case .ended:
            if let zoom = quickZoom, !zoom.moved {
                emit(.zoomTapped)
                zoomStep(factor: 0.5, at: zoom.start)
            }
            quickZoom = nil
        default:
            quickZoom = nil
        }
    }

    /// Mit zwei Fingern tippen: herauszoomen.
    fileprivate func twoFingerTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let map, CACurrentMediaTime() - lastMultiTouchAt > 0.4, multi == nil else { return }
        emit(.zoomTapped)
        zoomStep(factor: 2, at: recognizer.location(in: map))
    }

    private func zoomStep(factor: Double, at point: CGPoint) {
        if pin != nil {
            followDistance = min(max(followDistance * factor, 40), 40_000_000)
            emit(.target(distance: followDistance, pitch: followPitch))
            return
        }
        guard let map, let start = current else { return }
        var target = start
        target.distance = min(max(start.distance * factor, 40), 40_000_000)
        // Der angetippte Punkt bleibt stehen.
        let tapped = map.convert(point, toCoordinateFrom: map)
        if CLLocationCoordinate2DIsValid(tapped) {
            let c = MKMapPoint(start.center), p = MKMapPoint(tapped)
            target.center = MKMapPoint(x: p.x + (c.x - p.x) * factor, y: p.y + (c.y - p.y) * factor).coordinate
        }
        flight = Flight(from: start, to: target, start: CACurrentMediaTime(), duration: 0.3)
        startTicking()
    }

    private func setDistance(_ distance: CLLocationDistance, keeping point: CGPoint) {
        if pin != nil {
            followDistance = distance
            smooth?.distance = distance
            if let smooth { apply(smooth) }
            emit(.target(distance: distance, pitch: followPitch))
            return
        }
        guard let map, var camera = current else { return }
        let anchor = map.convert(point, toCoordinateFrom: map)
        camera.distance = distance
        apply(camera)
        if CLLocationCoordinate2DIsValid(anchor) {
            shift(from: map.convert(anchor, toPointTo: map), to: point)
        }
    }

    private func emit(_ event: MapEngineEvent) {
        if case .target(let distance, let pitch) = event {
            // Zwei Erkenner melden je Bild; nur merkliche Änderungen weitergeben.
            guard abs(distance - lastTarget.distance) > 1 || abs(pitch - lastTarget.pitch) > 0.5 else { return }
            lastTarget = (distance, pitch)
        }
        onEvent?(event)
    }

    // MARK: Hilfen

    private static func firstMap(in view: UIView) -> MKMapView? {
        if let map = view as? MKMapView { return map }
        for sub in view.subviews {
            if let map = firstMap(in: sub) { return map }
        }
        return nil
    }

    nonisolated private static func ease(_ t: Double) -> Double {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    nonisolated static func approachAngle(_ from: Double, _ to: Double, a: Double) -> Double {
        var delta = (to - from).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        var result = (from + delta * a).truncatingRemainder(dividingBy: 360)
        if result < 0 { result += 360 }
        return result
    }

    nonisolated private static func offset(_ coordinate: CLLocationCoordinate2D, meters: Double, bearing: Double) -> CLLocationCoordinate2D {
        let r = bearing * .pi / 180
        let dLat = meters * cos(r) / 111_320
        let dLon = meters * sin(r) / (111_320 * max(cos(coordinate.latitude * .pi / 180), 0.01))
        return CLLocationCoordinate2D(latitude: coordinate.latitude + dLat, longitude: coordinate.longitude + dLon)
    }

    nonisolated static func mapRect(_ region: MKCoordinateRegion) -> MKMapRect {
        let a = MKMapPoint(CLLocationCoordinate2D(latitude: region.center.latitude + region.span.latitudeDelta / 2,
                                                  longitude: region.center.longitude - region.span.longitudeDelta / 2))
        let b = MKMapPoint(CLLocationCoordinate2D(latitude: region.center.latitude - region.span.latitudeDelta / 2,
                                                  longitude: region.center.longitude + region.span.longitudeDelta / 2))
        return MKMapRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}

/// Kamerawerte der Steuerung.
struct EngineCamera {
    var center: CLLocationCoordinate2D
    var distance: CLLocationDistance
    var heading: CLLocationDirection
    var pitch: Double

    init(center: CLLocationCoordinate2D, distance: CLLocationDistance, heading: CLLocationDirection, pitch: Double) {
        self.center = center
        self.distance = distance
        self.heading = heading
        self.pitch = pitch
    }

    init(_ camera: MKMapCamera) {
        self.init(center: camera.centerCoordinate, distance: camera.centerCoordinateDistance, heading: camera.heading, pitch: camera.pitch)
    }

    init(_ camera: MapCamera) {
        self.init(center: camera.centerCoordinate, distance: camera.distance, heading: camera.heading, pitch: camera.pitch)
    }

    func interpolated(to other: EngineCamera, t: Double) -> EngineCamera {
        let a = MKMapPoint(center), b = MKMapPoint(other.center)
        return EngineCamera(
            center: MKMapPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t).coordinate,
            distance: exp(log(distance) + (log(other.distance) - log(distance)) * t),
            heading: MapEngine.approachAngle(heading, other.heading, a: t),
            pitch: pitch + (other.pitch - pitch) * t
        )
    }
}

private struct Flight {
    let from: EngineCamera
    let to: EngineCamera
    let start: CFTimeInterval
    let duration: Double
}

private struct MultiTouch {
    enum Mode { case undecided, tilt, transform }
    enum Intent { case none, zoom, rotate }
    var start: EngineCamera
    var anchor: CLLocationCoordinate2D?
    var scaleBase: CGFloat
    var rotationBase: CGFloat
    var panBase: CGPoint
    var startDistance: CLLocationDistance
    var startPitch: Double
    var mode: Mode = .undecided
    var intent: Intent = .none
    /// Bisherige Drehung (Bogenmaß) und Zoom der Geste, auch über Neubeginn eines Erkenners hinweg.
    var lastRotation: CGFloat = 0
    var lastScale: CGFloat = 1
    /// Drehung beim Überschreiten der Schwelle; ab da dreht die Karte.
    var turnOffset: Double?
    /// Zuletzt gesetzte Richtung (Messfühler: Sprünge erkennen).
    var lastHeading: Double?
}

/// UIKit-Seite: Gestenerkenner an der MapKit-Karte und Bildtakt. Eigenes Objekt, weil UIKit Ziele als `NSObject`
/// erwartet.
@MainActor
private final class EngineHelper: NSObject, UIGestureRecognizerDelegate {
    weak var engine: MapEngine?
    private weak var installedOn: MKMapView?
    private var link: CADisplayLink?
    private let pan = UIPanGestureRecognizer()
    private let twoPan = UIPanGestureRecognizer()
    private let pinch = UIPinchGestureRecognizer()
    private let rotation = UIRotationGestureRecognizer()
    private let quickZoom = UILongPressGestureRecognizer()
    private let twoTap = UITapGestureRecognizer()
    private let counter = TouchCounter()
    /// Höchste Fingerzahl seit dem ersten Aufsetzen (bis alle Finger weg sind).
    var maxTouches: Int { counter.maxTouches }

    init(engine: MapEngine) {
        self.engine = engine
        super.init()
        pan.maximumNumberOfTouches = 1
        pan.addTarget(self, action: #selector(onPan(_:)))
        twoPan.minimumNumberOfTouches = 2
        twoPan.maximumNumberOfTouches = 2
        twoPan.addTarget(self, action: #selector(onMulti(_:)))
        pinch.addTarget(self, action: #selector(onMulti(_:)))
        rotation.addTarget(self, action: #selector(onMulti(_:)))
        quickZoom.numberOfTapsRequired = 1
        quickZoom.minimumPressDuration = 0
        quickZoom.allowableMovement = .greatestFiniteMagnitude
        quickZoom.addTarget(self, action: #selector(onQuickZoom(_:)))
        twoTap.numberOfTouchesRequired = 2
        twoTap.addTarget(self, action: #selector(onTwoTap(_:)))
        for recognizer in [pan, twoPan, pinch, rotation, quickZoom, twoTap, counter] as [UIGestureRecognizer] {
            recognizer.delegate = self
            // Antippen von Symbolen und SwiftUIs eigene Gesten bleiben unberührt.
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
        }
    }

    func install(on map: MKMapView) {
        guard installedOn !== map else { return }
        installedOn = map
        // MapKits eigene Gesten aus (SwiftUI setzt das mit `interactionModes: []` ebenfalls).
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        for recognizer in [pan, twoPan, pinch, rotation, quickZoom, twoTap, counter] as [UIGestureRecognizer] {
            recognizer.view?.removeGestureRecognizer(recognizer)
            map.addGestureRecognizer(recognizer)
        }
    }

    func startDisplayLink() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(onFrame(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stopDisplayLink() {
        link?.invalidate()
        link = nil
    }

    @objc private func onFrame(_ link: CADisplayLink) {
        guard let engine else {
            stopDisplayLink()
            return
        }
        engine.tick(link.targetTimestamp)
    }

    @objc private func onPan(_ recognizer: UIPanGestureRecognizer) {
        engine?.pan(recognizer)
    }

    @objc private func onMulti(_ recognizer: UIGestureRecognizer) {
        engine?.multiTouch(recognizer, pinch: pinch, rotation: rotation, twoPan: twoPan)
    }

    @objc private func onQuickZoom(_ recognizer: UILongPressGestureRecognizer) {
        engine?.handleQuickZoom(recognizer)
    }

    @objc private func onTwoTap(_ recognizer: UITapGestureRecognizer) {
        engine?.twoFingerTap(recognizer)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

/// Zählt nur die Finger auf der Karte, erkennt selbst nie etwas. So weiß die Steuerung, ob in einer Geste schon zwei
/// Finger lagen (dann löst Verschieben nicht, auch wenn der erste Finger beim Zoomen weit wandert).
private final class TouchCounter: UIGestureRecognizer {
    private var touching = 0
    private(set) var maxTouches = 0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if touching == 0 { maxTouches = 0 }
        touching += touches.count
        maxTouches = max(maxTouches, touching)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        lift(touches.count)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        lift(touches.count)
    }

    private func lift(_ count: Int) {
        touching = max(touching - count, 0)
        if touching == 0 { state = .failed }
    }

    override func reset() {
        touching = 0
    }
}

/// Unsichtbare Fläche hinter der Karte, über die `MapEngine` die MapKit-Karte findet.
struct MapEngineAnchor: UIViewRepresentable {
    let engine: MapEngine

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        engine.anchor = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        engine.anchor = view
        Task { @MainActor in engine.attachIfNeeded() }
    }
}

extension View {
    /// Hängt die eigene Kartensteuerung an die Karte. Die Karte muss mit `interactionModes: []` erzeugt sein.
    func mapEngine(_ engine: MapEngine) -> some View {
        background { MapEngineAnchor(engine: engine) }
            .onMapCameraChange(frequency: .continuous) { _ in
                if !engine.isAttached { engine.attachIfNeeded() }
            }
    }
}
