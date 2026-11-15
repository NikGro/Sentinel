import CoreLocation
import XCTest

/// Rundgang durch die App mit Beispieldaten: prüft, dass jede Hauptansicht startet und ihre Kernelemente zeigt.
/// Die Bildschirmfotos hängen am Testergebnis und werden in der Pipeline als Artefakt abgelegt.
final class RundgangTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        // Systemabfragen (Standortfreigabe) dürfen den Rundgang nicht aufhalten.
        addUIInterruptionMonitor(withDescription: "Systemabfrage") { alert in
            for label in ["Beim Verwenden der App erlauben", "Allow While Using App", "Einmal erlauben", "Allow Once"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        return app
    }

    /// Löst eine wartende Systemabfrage aus, ohne die App zu bedienen: Tipp in die Statusleiste, nicht auf die Karte.
    private func settle(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.01)).tap()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testKarteUndAlleBereiche() {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Lage"].waitForExistence(timeout: 20), "Hauptansicht erscheint")
        settle(app)
        // Wie auf dem Gerät: echter Standort, Karte folgt dem eigenen Punkt. Friert die Karte dabei ein, scheitern alle weiteren Schritte.
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 53.5503, longitude: 9.9930))
        if app.buttons["Eigener Standort"].waitForExistence(timeout: 3) { app.buttons["Eigener Standort"].tap() }
        sleep(2)
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 53.5512, longitude: 9.9951))
        sleep(2)
        XCTAssertTrue(app.buttons["A übernehmen"].exists, "A-Position lässt sich übernehmen")
        XCTAssertTrue(app.buttons["Hinzufügen"].exists, "Plus-Knopf ist da")
        XCTAssertTrue(app.buttons["Suchen oder navigieren"].exists, "Suche ist da")
        XCTAssertTrue(app.buttons["Lageübersicht"].exists || app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Funkkanal'")).firstMatch.exists, "Lageleiste auf der Karte")
        capture("01-karte")

        // Zweistufige Übernahme: Der erste Druck schärft nur.
        app.buttons["A übernehmen"].tap()
        XCTAssertTrue(app.buttons["Bestätigen: Ich habe A"].waitForExistence(timeout: 2), "Zweiter Druck wird verlangt")

        app.buttons["Hinzufügen"].tap()
        XCTAssertTrue(app.buttons["Fahndungsraum"].waitForExistence(timeout: 3), "Fahndungsraum im Plus-Menü")
        capture("02-plus-menue")
        app.buttons["Fahndungsraum"].tap()
        sleep(1)
        capture("03-fahndungsraum-setzen")
        app.buttons["Abbrechen"].firstMatch.tap()

        app.buttons["Suchen oder navigieren"].tap()
        XCTAssertTrue(app.staticTexts["Zur A-Position"].waitForExistence(timeout: 5), "A-Position steht oben in der Objektliste")
        XCTAssertTrue(app.staticTexts["Überschlagend: nächste Haltestellen"].exists, "Überschlagen wird angeboten, wenn die A im ÖPNV fährt")
        capture("04-suche-objekte")
        app.buttons["Schließen"].firstMatch.tap()

        app.tabBars.buttons["Ziele"].tap()
        XCTAssertTrue(app.staticTexts["Max Mustermann"].waitForExistence(timeout: 5))
        capture("05-ziele")

        app.tabBars.buttons["Kräfte"].tap()
        XCTAssertTrue(app.staticTexts["P 35/24"].waitForExistence(timeout: 5), "Fahrzeug mit Funkrufname")
        XCTAssertTrue(app.staticTexts["Adler"].exists, "Fahnder mit Spitzname")
        capture("06-kraefte")

        app.tabBars.buttons["Chat"].tap()
        XCTAssertTrue(app.staticTexts["Team Nord"].waitForExistence(timeout: 5), "Chaträume")
        app.staticTexts["Allgemein"].tap()
        XCTAssertTrue(app.staticTexts["Bin auf Position, Sicht auf den Eingang."].waitForExistence(timeout: 5))
        capture("07-chat")

        app.tabBars.buttons["Mehr"].tap()
        XCTAssertTrue(app.navigationBars["Mehr"].waitForExistence(timeout: 5), "Mehr-Ansicht erscheint")
        capture("08-mehr")
        app.swipeUp()
        XCTAssertTrue(app.buttons["GPS-Tracker"].waitForExistence(timeout: 5) || app.staticTexts["GPS-Tracker"].exists, "Verwaltung auch in der App")
    }

    func testFortbewegung() {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Lage"].waitForExistence(timeout: 20))
        settle(app)
        let chip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Fortbewegung'")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()
        XCTAssertTrue(app.navigationBars["Fortbewegung"].waitForExistence(timeout: 3))
        capture("09-fortbewegung")
    }
}
