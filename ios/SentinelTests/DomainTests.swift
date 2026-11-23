import Foundation
import MapKit
import Testing
@testable import Sentinel

struct CallsignTests {
    @Test(arguments: [("P 35/24", "P 35/24"), ("p35/657", "P 35/657"), ("  flo 1/2 ", "FLO 1/2"), ("Ä 123/456", "Ä 123/456")])
    func normalisiertGueltigeRufnamen(input: String, expected: String) {
        #expect(Callsign.normalize(input) == expected)
    }

    @Test(arguments: ["", "P 3524", "ABCD 1/2", "P 1234/1", "P 35/1234", "35/24", "P  35/24", "P 35/24 x"])
    func lehntUngueltigeRufnamenAb(input: String) {
        #expect(Callsign.normalize(input) == nil)
    }

    @Test func funkkanalHatEinsBisFuenfZiffern() {
        #expect(RadioChannel.isValid("1"))
        #expect(RadioChannel.isValid("47110"))
        #expect(!RadioChannel.isValid(""))
        #expect(!RadioChannel.isValid("123456"))
        #expect(!RadioChannel.isValid("12a"))
    }
}

struct TargetTests {
    @Test func alterWirdAusGeburtsdatumBerechnet() throws {
        var target = Target()
        target.geburtsdatum = "1990-11-16"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let dayBefore = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 12)))
        let birthday = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 12)))
        #expect(target.age(at: dayBefore) == 35)
        #expect(target.age(at: birthday) == 36)
        #expect(Target().age() == nil)
    }

    @Test func geburtsdatumAlsText() throws {
        let date = try #require(Target.parseBirthDate("4.5.1990"))
        var target = Target()
        target.birthDate = date
        #expect(target.geburtsdatum == "1990-05-04")
        #expect(target.birthDateText == "04.05.1990")
        #expect(Target.parseBirthDate("04051990") != nil)
        #expect(Target.parseBirthDate("31.02.1990") == nil)
        #expect(Target.parseBirthDate("") == nil)
        #expect(Target.parseBirthDate("01.01.2999") == nil)
    }

    @Test func freitexteUndFotosWerdenZusammengefuehrt() {
        var target = Target()
        target.merkmale = "groß"
        target.hinweise = "bewaffnet"
        target.fotoBlob = "a"
        target.fahrzeugFotoBlob = "b"
        target.normalize()
        #expect(target.hinweise == "Merkmale: groß\n\nHinweise: bewaffnet")
        #expect(target.merkmale.isEmpty)
        #expect(target.anhaenge.map(\.blobId) == ["a", "b"])
        #expect(target.fotoBlob == "a")
        #expect(target.fahrzeugFotoBlob == nil)
    }

    @Test func anzeigenameFaelltAufPlatzhalterZurueck() {
        #expect(Target().displayName == "Unbekannte Person")
        #expect(Target(vorname: "Max", nachname: "Muster").displayName == "Max Muster")
        #expect(Target(art: .fahrzeug, bezeichnung: "BMW").displayName == "BMW")
        #expect(Target(art: .objekt).displayName == "Zielobjekt")
    }
}

struct WireCodecTests {
    @Test func dekodiertSnapshot() throws {
        let json = """
        {"t":"snapshot","self":{"id":"g1","role":"fahnder"},"server":{"version":"0.2.0","routing":true},"online":["g1"],
         "members":[{"id":"g1","rev":2,"updatedAt":1763190000000,"updatedBy":"g1","data":{"name":"Test","spitzname":"Falke","dienststelle":"PK 35","telefon":"","fotoBlob":null,"aktiv":true,"fortbewegung":"oepnv","fahrzeugId":null,"oepnv":{"linienId":"7","linie":"U3","richtung":"Barmbek"}}}],
         "vehicles":[{"id":"v1","rev":1,"updatedAt":1,"updatedBy":"g1","data":{"funkrufname":"P 35/24","bezeichnung":"Golf","kennzeichen":"","beschreibung":"","fotoBlob":null,"trackerId":null,"aktiv":false,"abgestellt":{"lat":53.5,"lon":10,"ts":1}}}],
         "annotations":[{"id":"m1","rev":1,"updatedAt":1,"updatedBy":"zentrale","data":{"layerId":"lage","typ":"fahndungsraum","titel":"","notiz":"","farbe":"#FF9F0A","symbol":"","punkte":[{"lat":53.5,"lon":10}],"radius":null,"wert":null,"zeit":1763190000000,"trackerId":null}}],
         "targets":[{"id":"t1","rev":1,"updatedAt":1,"updatedBy":"g1","data":{"art":"objekt","bezeichnung":"Wohnung","standort":{"lat":53.5,"lon":10,"ts":1}}}],
         "trackers":[],"layers":[{"id":"lage","rev":1,"updatedAt":1,"updatedBy":"system","data":{"name":"Lage","art":"lage","status":"live","beschreibung":""}}],
         "rooms":[{"id":"allgemein","rev":1,"updatedAt":1,"updatedBy":"system","data":{"name":"Allgemein"}}],
         "messages":[{"id":"n1","rev":1,"updatedAt":1,"updatedBy":"g1","data":{"roomId":"allgemein","text":"","anhang":{"blobId":"b1","art":"audio","name":"","mime":"audio/mp4","groesse":1200,"dauer":3.5}}}],
         "operation":{"funkkanal":"4711","titel":"","hinweise":"","a":{"memberId":"g1","seit":1},"ueberschlagen":{"teilnehmer":[],"zuweisungen":{},"naechste":[{"name":"Hauptbahnhof","lat":53.55,"lon":10.0}]},"rev":4},
         "positions":[{"id":"g1","p":{"lat":53.5,"lon":10,"ts":1763190000000,"acc":5}}],"trackerPositions":[]}
        """
        guard case .snapshot(let snapshot) = try WireCodec.decode(Data(json.utf8)) else {
            Issue.record("Snapshot erwartet")
            return
        }
        #expect(snapshot.me.id == "g1")
        #expect(snapshot.members.first?.data.spitzname == "Falke")
        #expect(snapshot.members.first?.data.fortbewegung == .oepnv)
        #expect(snapshot.members.first?.data.oepnv?.linie == "U3")
        #expect(snapshot.vehicles.first?.data.aktiv == false)
        #expect(snapshot.annotations.first?.data.typ == .fahndungsraum)
        #expect(snapshot.annotations.first?.data.since != nil)
        #expect(snapshot.targets.first?.data.art == .objekt)
        #expect(snapshot.targets.first?.data.displayName == "Wohnung")
        #expect(snapshot.rooms.first?.data.name == "Allgemein")
        #expect(snapshot.messages.first?.data.anhang?.art == .audio)
        #expect(snapshot.operation.ueberschlagen.naechste.first?.name == "Hauptbahnhof")
        #expect(snapshot.positions.first?.p.spd == nil)
    }

    @Test func alteDatenOhneNeueFelderWerdenGelesen() throws {
        let member = try JSONDecoder().decode(Member.self, from: Data(#"{"name":"Nikki","funkrufname":"P 35/24","dienststelle":"ZF 35"}"#.utf8))
        #expect(member.spitzname == "Nikki")
        #expect(member.aktiv)
        #expect(member.fortbewegung == .fuss)
        let vehicle = try JSONDecoder().decode(Vehicle.self, from: Data(#"{"bezeichnung":"Volvo"}"#.utf8))
        #expect(vehicle.funkrufname == "Volvo")
    }

    @Test func dekodiertEinzelneEreignisse() throws {
        let put = #"{"t":"put","kind":"message","entity":{"id":"n1","rev":1,"updatedAt":5,"updatedBy":"zentrale","data":{"roomId":"r1","text":"Hallo"}}}"#
        guard case .putMessage(let message) = try WireCodec.decode(Data(put.utf8)) else {
            Issue.record("Nachricht erwartet")
            return
        }
        #expect(message.data.text == "Hallo")
        #expect(message.data.roomId == "r1")

        guard case .delete(let kind, let id) = try WireCodec.decode(Data(#"{"t":"del","kind":"annotation","id":"m1"}"#.utf8)) else {
            Issue.record("Löschung erwartet")
            return
        }
        #expect(kind == MapObject.kind)
        #expect(id == "m1")

        guard case .unknown = try WireCodec.decode(Data(#"{"t":"zukunft"}"#.utf8)) else {
            Issue.record("Unbekannte Nachrichten dürfen nicht stören")
            return
        }
    }

    @Test func kodiertKommandosUndPositionen() throws {
        let command = try #require(WireCodec.command("funkkanal.setzen", args: ["kanal": "4711"], ref: "r1"))
        let object = try #require(JSONSerialization.jsonObject(with: command) as? [String: Any])
        #expect(object["t"] as? String == "cmd")
        #expect((object["args"] as? [String: String])?["kanal"] == "4711")

        let position = try #require(WireCodec.position(Position(lat: 53.5, lon: 10, ts: 1_763_190_000_000)))
        let body = try #require(JSONSerialization.jsonObject(with: position) as? [String: Any])
        #expect(body["t"] as? String == "pos")
        #expect((body["p"] as? [String: Any])?["acc"] == nil, "Fehlende Werte werden weggelassen")
    }
}

struct ServerURLTests {
    @Test func akzeptiertNurVerschluesselteAdressen() {
        #expect(APIClient.normalizedServerURL("sentinel.ng-lab.de")?.absoluteString == "https://sentinel.ng-lab.de")
        #expect(APIClient.normalizedServerURL(" https://sentinel.ng-lab.de/ ")?.absoluteString == "https://sentinel.ng-lab.de")
        #expect(APIClient.normalizedServerURL("http://sentinel.ng-lab.de") == nil)
        #expect(APIClient.normalizedServerURL("") == nil)
    }
}

struct SearchTests {
    @Test func hausnummerZuerstWirdUmgestellt() {
        #expect(SearchService.normalizedAddress("12 Musterstraße") == "Musterstraße 12")
        #expect(SearchService.normalizedAddress("12a Musterstraße") == "Musterstraße 12a")
        #expect(SearchService.normalizedAddress("Musterstraße 12") == "Musterstraße 12")
        #expect(SearchService.normalizedAddress("Hauptbahnhof") == "Hauptbahnhof")
    }

    @Test func kreuzungenMitUndOderSchraegstrich() {
        #expect(SearchService.intersectionParts("Mönckebergstraße / Steinstraße")?.1 == "Steinstraße")
        #expect(SearchService.intersectionParts("A & B")?.0 == "A")
        #expect(SearchService.intersectionParts("Musterstraße 12") == nil)
        #expect(SearchService.intersectionParts("Hegbark Ecke Wenzelplatz")?.0 == "Hegbark")
        #expect(SearchService.intersectionParts("Hegbark ecke Wenzelplatz")?.1 == "Wenzelplatz")
        #expect(SearchService.intersectionParts("Heegbarg x Saseler Damm")?.1 == "Saseler Damm")
        #expect(SearchService.intersectionParts("Heegbarg Ecke")?.1 == "")
        #expect(SearchService.intersectionParts("Eckernförder Straße 3") == nil, "„Ecke“ nur als eigenes Wort")
    }
}

struct NavigationTests {
    @Test func himmelsrichtungen() {
        #expect(LocationContext.cardinal(0) == "Nord")
        #expect(LocationContext.cardinal(44) == "Nordost")
        #expect(LocationContext.cardinal(180) == "Süd")
        #expect(LocationContext.cardinal(359) == "Nord")
        #expect(LocationContext.cardinal(270) == "West")
    }

    @Test func manoeverSymbole() {
        #expect(ManeuverSymbol.lane("slight left") == "arrow.up.left")
        #expect(ManeuverSymbol.lane("right") == "arrow.turn.up.right")
        #expect(ManeuverSymbol.lane("straight") == "arrow.up")
    }

    @Test func verkehrsvorgabeMitFahrtrichtung() {
        // Gerade Strecke nach Osten, etwa 5 km: Durchfahrtspunkte mit Richtung Ost (90°).
        var coordinates = (0...50).map { CLLocationCoordinate2D(latitude: 53.55, longitude: 9.9 + Double($0) * 0.0015) }
        let polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)
        let vias = TrafficGuide.vias(along: polyline)
        #expect(!vias.isEmpty)
        #expect(vias.allSatisfy { ($0["type"] as? String) == "through" })
        #expect(vias.allSatisfy { abs(($0["heading"] as? Int ?? 0) - 90) <= 1 })
    }

    @Test func dauerAlsUhrzeit() {
        #expect(Format.clock(65) == "1:05")
        #expect(Format.clock(0) == "0:00")
    }
}

struct Version03Tests {
    @Test func hausnummerVornWirdFuerVorschlaegeAbgetrennt() {
        #expect(SearchService.leadingNumber("3 Heg")?.number == "3")
        #expect(SearchService.leadingNumber("3 Heg")?.street == "Heg")
        #expect(SearchService.leadingNumber("12 a Musterweg")?.number == "12a")
        #expect(SearchService.leadingNumber("Hegpark 3") == nil)
    }

    @Test func wellenformHatFesteBalkenzahlUndBleibtImBereich() {
        let levels = (0..<137).map { Double($0 % 10) / 10 }
        let bars = AudioRecorder.waveform(levels, bars: 48)
        #expect(bars.count == 48)
        #expect(bars.allSatisfy { $0 >= 0 && $0 <= 1 })
        #expect(AudioRecorder.waveform([]).isEmpty)
        #expect(AudioRecorder.normalized(-80) == 0)
        #expect(AudioRecorder.normalized(0) == 1)
    }

    @Test func unbekannteMarkierungsartMachtDenLagestandNichtUnbrauchbar() throws {
        let json = ##"{"self":{"id":"a","role":"device"},"server":{"version":"9","routing":false},"online":[],"members":[],"vehicles":[],"annotations":[{"id":"x","rev":1,"updatedAt":1,"updatedBy":"a","data":{"layerId":"lage","typ":"zukunft","punkte":[{"lat":1,"lon":2}]}},{"id":"y","rev":1,"updatedAt":1,"updatedBy":"a","data":{"layerId":"lage","typ":"haltestellen","titel":"","notiz":"","farbe":"#0A84FF","symbol":"","punkte":[{"lat":1,"lon":2}],"radius":500}}],"targets":[],"trackers":[],"layers":[],"rooms":[],"messages":[],"operation":{},"positions":[],"trackerPositions":[]}"##
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(json.utf8))
        #expect(snapshot.annotations.map(\.id) == ["y"])
    }
}

struct TransitSimulationTests {
    @Test func fahrzeugFaehrtZwischenDenHalten() throws {
        let points = [GeoPoint(lat: 53.55, lon: 10.0), GeoPoint(lat: 53.56, lon: 10.0), GeoPoint(lat: 53.57, lon: 10.0)]
        let departure = Date(timeIntervalSince1970: 1_000_000)
        let times = TransitSimulation.arrivals(points, typ: "bus")
        #expect(times.count == 3)
        #expect(times[2] > times[1] + TransitSimulation.dwell)
        #expect(TransitSimulation.state(points, typ: "bus", departure: departure, at: departure.addingTimeInterval(-10)) == nil)
        let halfway = try #require(TransitSimulation.state(points, typ: "bus", departure: departure, at: departure.addingTimeInterval(times[1] / 2)))
        #expect(halfway.nextIndex == 1)
        #expect(abs(halfway.point.lat - 53.555) < 0.0005)
        let waiting = try #require(TransitSimulation.state(points, typ: "bus", departure: departure, at: departure.addingTimeInterval(times[1] + 10)))
        #expect(waiting.atStop && waiting.nextIndex == 1)
        #expect(TransitSimulation.state(points, typ: "bus", departure: departure, at: departure.addingTimeInterval(times[2] + 1)) == nil)
    }

    @Test func taktBlendetLaufendeFahrtenEin() {
        var object = MapObject(layerId: "lage", typ: .oepnvlinie, punkte: [GeoPoint(lat: 53.55, lon: 10.0), GeoPoint(lat: 53.60, lon: 10.0)])
        object.linie = TransitRef(id: "1", ref: "U3", typ: "subway", richtung: "Barmbek")
        object.takt = 5
        let now = Date(timeIntervalSince1970: 2_000_000)
        object.zeit = (now.addingTimeInterval(-3600).timeIntervalSince1970 * 1000)
        // 5,5 km mit etwa 63 km/h ≈ 5,5 min Fahrt, dazu je fünf Minuten Stehen an den Endhalten: ≈ 15,5 min bei
        // 5-Minuten-Takt, also drei oder vier Fahrzeuge gleichzeitig.
        let count = TransitSimulation.vehicles(on: object, at: now).count
        #expect((3...4).contains(count))
    }

    @Test func fahrmodellHaeltBremstUndFaehrtWeichAn() throws {
        // Drei Halte je etwa 1,1 km auf gerader Strecke, Fahrplan je 4 Minuten.
        let path = (0...100).map { GeoPoint(lat: 53.55 + Double($0) * 0.0002, lon: 10.0) }
        let stops = [path[0], path[50], path[100]]
        let start = 1_700_000_000_000.0
        let motion = try #require(TransitSimulation.motion(stops, path: path, times: [start, start + 240_000, start + 480_000], typ: "bus"))
        // Realistische Standzeit am Zwischenhalt (Bus etwa 20 s).
        let stand = motion.depart[1] - motion.arrive[1]
        #expect(stand >= 15 && stand <= 25, "Standzeit \(stand) s")
        // Weich: Das Tempo ändert sich nie sprunghaft (Abtastung alle 0,2 s).
        var previous = motion.speed(at: start / 1000)
        var t = start / 1000
        var maxChange = 0.0
        while t < start / 1000 + 480 {
            t += 0.2
            let v = motion.speed(at: t)
            maxChange = max(maxChange, abs(v - previous))
            previous = v
        }
        #expect(maxChange < 0.6, "größte Tempoänderung in 0,2 s: \(maxChange) m/s")
        // Kurz vor dem Halt deutlich langsamer als in der Mitte der Fahrt.
        let middle = motion.speed(at: (motion.depart[0] + motion.arrive[1]) / 2)
        let beforeStop = motion.speed(at: motion.arrive[1] - 3)
        #expect(beforeStop < middle * 0.5)
    }

    @Test func fahrmodellIstInKurvenLangsamer() throws {
        // Gerade nach Norden, dann scharf nach Osten.
        let north = (0...60).map { GeoPoint(lat: 53.55 + Double($0) * 0.0002, lon: 10.0) }
        let east = (1...60).map { GeoPoint(lat: 53.562, lon: 10.0 + Double($0) * 0.0003) }
        let path = north + east
        let motion = try #require(TransitMotion.estimated([path[0], path[path.count - 1]], path: path, typ: "bus"))
        let corner = motion.stopMeters[0] + 1330
        var cornerSpeed = Double.greatestFiniteMagnitude, straightSpeed = 0.0
        var t = 0.0
        while t < (motion.arrive.last ?? 0) {
            let m = motion.meters(at: t), v = motion.speed(at: t)
            if abs(m - corner) < 15 { cornerSpeed = min(cornerSpeed, v) }
            if abs(m - 600) < 15 { straightSpeed = max(straightSpeed, v) }
            t += 0.5
        }
        #expect(cornerSpeed < straightSpeed * 0.8, "Kurve \(cornerSpeed) m/s, Gerade \(straightSpeed) m/s")
    }

}

struct SpurTests {
    @Test func zwischenZweiPunktenWerdenWerteAngenommen() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let a = SpurPunkt(point: GeoPoint(lat: 53.55, lon: 10.0), date: start, speed: 10, quelle: .gps, info: nil)
        let b = SpurPunkt(point: GeoPoint(lat: 53.56, lon: 10.0), date: start.addingTimeInterval(120), speed: 20, quelle: .gps, info: nil)
        let spur = Spur(subject: SpurSubject(art: .member, id: "x"), punkte: [a, b])
        let middle = spur.sample(index: 0, fraction: 0.5)
        #expect(middle.between)
        #expect(abs(middle.punkt.point.lat - 53.555) < 1e-9)
        #expect(middle.punkt.date == start.addingTimeInterval(60))
        #expect(abs((middle.speed?.value ?? 0) - 15) < 1e-9)
        // Angetippt nah an der Linie, weit weg von beiden Punkten: Stelle in der Mitte (Bildschirm wie Meter).
        let hit = try #require(spur.hit(at: CGPoint(x: 3, y: 555)) { CGPoint(x: 0, y: ($0.lat - 53.55) * 111_000) })
        #expect(hit.index == 0 && abs(hit.fraction - 0.5) < 0.01 && hit.distance < 4)
    }
}

