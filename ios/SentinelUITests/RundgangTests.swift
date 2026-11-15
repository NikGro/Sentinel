import XCTest

/// Rundgang durch die App mit Beispieldaten: prüft, dass jede Hauptansicht startet und ihre Kernelemente zeigt.
/// Die Bildschirmfotos hängen am Testergebnis und werden in der Pipeline als Artefakt abgelegt.
final class RundgangTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func launch(modus: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-demo-modus", modus]
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

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testObservationUndAlleBereiche() {
        let app = launch(modus: "observation")
        XCTAssertTrue(app.tabBars.buttons["Lage"].waitForExistence(timeout: 20), "Hauptansicht erscheint")
        app.tap()
        sleep(3)
        XCTAssertTrue(app.buttons["A übernehmen"].exists, "A-Position lässt sich übernehmen")
        capture("01-observation")

        // Zweistufige Übernahme: Der erste Druck schärft nur.
        app.buttons["A übernehmen"].tap()
        XCTAssertTrue(app.buttons["Bestätigen: Ich habe A"].waitForExistence(timeout: 2), "Zweiter Druck wird verlangt")
        capture("02-a-bestaetigen")

        app.tabBars.buttons["Ziele"].tap()
        XCTAssertTrue(app.staticTexts["Max Mustermann"].waitForExistence(timeout: 5))
        capture("03-ziele")
        app.staticTexts["Max Mustermann"].tap()
        sleep(1)
        capture("04-zielperson")

        app.tabBars.buttons["Team"].tap()
        XCTAssertTrue(app.staticTexts["P 35/31"].waitForExistence(timeout: 5))
        capture("05-team")

        app.tabBars.buttons["Chat"].tap()
        XCTAssertTrue(app.staticTexts["Bin auf Position, Sicht auf den Eingang."].waitForExistence(timeout: 5))
        capture("06-chat")

        app.tabBars.buttons["Mehr"].tap()
        XCTAssertTrue(app.staticTexts["App-Sperre"].waitForExistence(timeout: 5))
        capture("07-mehr")
    }

    func testFahndung() {
        let app = launch(modus: "fahndung")
        XCTAssertTrue(app.tabBars.buttons["Lage"].waitForExistence(timeout: 20))
        app.tap()
        sleep(3)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Letzter Standort'")).firstMatch.exists, "Letzter Standort wird angezeigt")
        XCTAssertFalse(app.buttons["A übernehmen"].exists, "Im Fahndungsmodus gibt es keine A-Position")
        capture("08-fahndung")
    }

    func testOberflaeche() {
        let app = launch(modus: "oberflaeche")
        XCTAssertTrue(app.tabBars.buttons["Lage"].waitForExistence(timeout: 20))
        app.tap()
        sleep(3)
        XCTAssertFalse(app.buttons["A übernehmen"].exists)
        capture("09-oberflaeche")
    }
}
