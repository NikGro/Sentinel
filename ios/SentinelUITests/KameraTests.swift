import CoreLocation
import XCTest

/// Kamera beim Anheften, automatisch geprüft: Der Test fährt eine Strecke ab, heftet an, zoomt, dreht und wischt und
/// liest dabei den Messfühler der App (`kamera-probe`). Jede Anforderung aus `docs/Fehlerprotokoll.md` ist ein eigener
/// Prüfschritt. Bildschirmfotos und die Messdatei (`kamera.jsonl`) liegen danach als Artefakt bereit.
final class KameraTests: XCTestCase {
    private var app: XCUIApplication!
    /// Fahrt: von hier nach Norden, je Schritt etwa 14 m (50 km/h bei zwei Schritten je Sekunde).
    private var position = CLLocationCoordinate2D(latitude: 53.5503, longitude: 9.9930)

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-demo", "-kameraprobe"]
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: position.latitude, longitude: position.longitude))
        app.launch()
        addUIInterruptionMonitor(withDescription: "Systemabfrage") { alert in
            for label in ["Beim Verwenden der App erlauben", "Allow While Using App", "Einmal erlauben", "Allow Once"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
    }

    // MARK: Messfühler

    private struct Probe {
        var pin = "none"
        var distance = 0.0
        var pitch = 0.0
        var heading = 0.0
        var recognizers = false

        init(_ text: String) {
            for part in text.split(separator: " ") {
                let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
                guard kv.count == 2 else { continue }
                switch kv[0] {
                case "pin": pin = kv[1]
                case "d": distance = Double(kv[1]) ?? 0
                case "p": pitch = Double(kv[1]) ?? 0
                case "h": heading = Double(kv[1]) ?? 0
                case "erkenner": recognizers = kv[1] == "1"
                default: break
                }
            }
        }
    }

    private func probe() -> Probe {
        let element = app.descendants(matching: .any)["kamera-probe"]
        _ = element.waitForExistence(timeout: 5)
        return Probe(element.label)
    }

    /// Ein Schritt der Fahrt nach Norden.
    private func drive(steps: Int = 1, pause: TimeInterval = 0.5) {
        for _ in 0..<steps {
            position.latitude += 0.000126
            XCUIDevice.shared.location = XCUILocation(location: CLLocation(
                coordinate: position, altitude: 10, horizontalAccuracy: 5, verticalAccuracy: 5,
                course: 0, speed: 14, timestamp: .now))
            Thread.sleep(forTimeInterval: pause)
        }
    }

    /// Fährt weiter und sammelt dabei Messwerte, z. B. um Pumpen (schwankenden Zoom) zu erkennen.
    private func samples(seconds: Double) -> [Probe] {
        var result: [Probe] = []
        let steps = Int(seconds / 0.5)
        for _ in 0..<steps {
            drive()
            result.append(probe())
        }
        return result
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Die Karte; falls MapKit sie nicht als Karte meldet, das Fenster (Gesten gehen dann auf die Bildmitte).
    private var map: XCUIElement { app.maps.firstMatch.exists ? app.maps.firstMatch : app.windows.firstMatch }

    private func pinHeading() {
        let button = app.buttons["Auf eigenen Standort anheften"]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Kompassknopf vorhanden")
        // Einmal: angeheftet in Kompass-Ausrichtung; ist schon Kompass aktiv, wechselt es zu Norden, dann zurück.
        button.tap()
        drive(steps: 4)
        if probe().pin == "north" {
            button.tap()
            drive(steps: 4)
        }
    }

    // MARK: Prüfungen

    func testKameraBeimAnheften() {
        XCTAssertTrue(app.tabBars.buttons["Lage"].waitForExistence(timeout: 20), "Karte erscheint")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.01)).tap()
        drive(steps: 4)

        // 1. Anheften in Kompass-Ausrichtung: 550 m, schräg.
        pinHeading()
        var p = probe()
        capture("k1-angeheftet")
        XCTAssertEqual(p.pin, "heading", "angeheftet in Kompass-Ausrichtung")
        XCTAssertEqual(p.distance, 550, accuracy: 120, "Abstand beim Anheften etwa 550 m")
        XCTAssertGreaterThan(p.pitch, 20, "schräg von hinten")
        XCTAssertTrue(p.recognizers, "MapKits Gestenerkenner gefunden")

        // 2. Folgen ohne Pumpen: Abstand bleibt beim Fahren ruhig.
        let ruhig = samples(seconds: 4)
        let ds = ruhig.map(\.distance)
        XCTAssertLessThan((ds.max() ?? 0) - (ds.min() ?? 0), 60, "kein Pumpen beim Folgen: \(ds)")
        XCTAssertTrue(ruhig.allSatisfy { $0.pin == "heading" }, "bleibt angeheftet beim Fahren")

        // 3. Zoomen (Zwei-Finger) löst nicht, der neue Abstand bleibt und pumpt nicht.
        map.pinch(withScale: 2.2, velocity: 1.5)
        drive(steps: 3)
        p = probe()
        capture("k2-nach-zoomen")
        XCTAssertEqual(p.pin, "heading", "Zoomen löst die Kopplung nicht")
        XCTAssertLessThan(p.distance, 420, "hineingezoomt (vorher etwa 550 m)")
        let nachZoom = samples(seconds: 4)
        let zs = nachZoom.map(\.distance)
        XCTAssertLessThan((zs.max() ?? 0) - (zs.min() ?? 0), 60, "Zoom bleibt und pumpt nicht: \(zs)")
        XCTAssertTrue(nachZoom.allSatisfy { $0.pin == "heading" }, "bleibt nach dem Zoomen angeheftet")

        // 4. Herauszoomen ebenso.
        map.pinch(withScale: 0.5, velocity: -1.5)
        drive(steps: 3)
        p = probe()
        XCTAssertEqual(p.pin, "heading", "Herauszoomen löst die Kopplung nicht")
        let weit = samples(seconds: 3).map(\.distance)
        XCTAssertLessThan((weit.max() ?? 0) - (weit.min() ?? 0), 80, "Abstand nach Herauszoomen ruhig: \(weit)")

        // 5. Herausdrehen löst die Kompass-Ausrichtung.
        map.rotate(.pi / 3, withVelocity: 1.5)
        drive(steps: 2)
        p = probe()
        capture("k3-nach-drehen")
        XCTAssertEqual(p.pin, "none", "Herausdrehen löst die Kopplung")

        // 6. Wischen löst, und die Karte bleibt danach, wo sie ist (kein Zurückspringen).
        pinHeading()
        XCTAssertEqual(probe().pin, "heading", "wieder angeheftet")
        map.swipeLeft()
        drive(steps: 2)
        p = probe()
        capture("k4-nach-wischen")
        XCTAssertEqual(p.pin, "none", "Wischen löst die Kopplung")
        let frei = samples(seconds: 3).map(\.heading)
        XCTAssertLessThan((frei.max() ?? 0) - (frei.min() ?? 0), 5, "frei: Karte dreht nicht von selbst: \(frei)")

        // 7. Norden oben: 1500 m von oben.
        let button = app.buttons["Auf eigenen Standort anheften"]
        button.tap()
        drive(steps: 4)
        if probe().pin == "heading" {
            button.tap()
            drive(steps: 4)
        }
        p = probe()
        capture("k5-norden")
        XCTAssertEqual(p.pin, "north", "Norden oben angeheftet")
        XCTAssertEqual(p.distance, 1500, accuracy: 300, "Abstand Norden oben etwa 1500 m")
        XCTAssertLessThan(p.pitch, 10, "von oben")
    }
}
