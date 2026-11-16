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
