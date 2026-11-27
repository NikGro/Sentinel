import XCTest

/// Rundgang der neuen App: startet, zeigt die Einrichtung und legt Bildschirmfotos ab.
final class StartTest: XCTestCase {
    func testStartZeigtEinrichtung() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.textFields["Serveradresse"].waitForExistence(timeout: 20), "Einrichtung erscheint")
        let bild = XCTAttachment(screenshot: app.screenshot())
        bild.name = "01-einrichtung"
        bild.lifetime = .keepAlways
        add(bild)
    }
}
