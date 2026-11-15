import Foundation
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

struct UndoStackTests {
    private func marker(_ title: String) -> MapObject {
        MapObject(layerId: Layer.lageId, typ: .marker, titel: title, punkte: [GeoPoint(lat: 53.55, lon: 9.99)])
    }

    @Test func rueckgaengigUndWiederholen() {
        var stack = UndoStack()
        stack.record(MapEdit(id: "m1", before: nil, after: marker("A")))
        stack.record(MapEdit(id: "m1", before: marker("A"), after: marker("B")))

        let first = stack.undo()
        #expect(first?.restore == marker("A"))
        let second = stack.undo()
        #expect(second?.id == "m1")
        #expect(second?.restore == nil, "Anlegen rückgängig machen heißt löschen")
        #expect(!stack.canUndo)

        #expect(stack.redo()?.restore == marker("A"))
        #expect(stack.redo()?.restore == marker("B"))
        #expect(!stack.canRedo)
    }

    @Test func neueBearbeitungVerwirftWiederholen() {
        var stack = UndoStack()
        stack.record(MapEdit(id: "m1", before: nil, after: marker("A")))
        _ = stack.undo()
        stack.record(MapEdit(id: "m2", before: nil, after: marker("C")))
        #expect(!stack.canRedo)
    }

    @Test func unveraenderteSchritteUndGrenzeWerdenBeachtet() {
        var stack = UndoStack(limit: 2)
        stack.record(MapEdit(id: "m1", before: marker("A"), after: marker("A")))
        #expect(!stack.canUndo)
        for index in 0..<5 { stack.record(MapEdit(id: "m\(index)", before: nil, after: marker("\(index)"))) }
        #expect(stack.done.count == 2)
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
    }
}

struct WireCodecTests {
    @Test func dekodiertSnapshot() throws {
        let json = """
        {"t":"snapshot","self":{"id":"g1","role":"fahnder"},"server":{"version":"0.1.0","routing":true},"online":["g1"],
         "members":[{"id":"g1","rev":2,"updatedAt":1763190000000,"updatedBy":"g1","data":{"name":"Test","funkrufname":"P 35/24","dienststelle":"PK 35","telefon":"","fotoBlob":null,"fahrzeugId":null}}],
         "vehicles":[],"annotations":[{"id":"m1","rev":1,"updatedAt":1,"updatedBy":"zentrale","data":{"layerId":"lage","typ":"kreis","titel":"","notiz":"","farbe":"#FF9F0A","symbol":"","punkte":[{"lat":53.5,"lon":10}],"radius":150,"wert":null}}],
         "targets":[],"trackers":[],"layers":[{"id":"lage","rev":1,"updatedAt":1,"updatedBy":"system","data":{"name":"Lage","art":"lage","status":"live","beschreibung":""}}],"messages":[],
         "operation":{"modus":"fahndung","funkkanal":"4711","titel":"","hinweise":"","a":null,"lkp":{"lat":53.5,"lon":10,"ts":1763190000000,"quelle":"a","targetId":null},"bestreifungSeit":1763190000000,"rev":4},
         "positions":[{"id":"g1","p":{"lat":53.5,"lon":10,"ts":1763190000000,"acc":5}}],"trackerPositions":[]}
        """
        guard case .snapshot(let snapshot) = try WireCodec.decode(Data(json.utf8)) else {
            Issue.record("Snapshot erwartet")
            return
        }
        #expect(snapshot.me.id == "g1")
        #expect(snapshot.members.first?.data.funkrufname == "P 35/24")
        #expect(snapshot.annotations.first?.data.typ == .kreis)
        #expect(snapshot.operation.modus == .fahndung)
        #expect(snapshot.operation.lkp?.quelle == "a")
        #expect(snapshot.positions.first?.p.spd == nil)
    }

    @Test func dekodiertEinzelneEreignisse() throws {
        let put = #"{"t":"put","kind":"message","entity":{"id":"n1","rev":1,"updatedAt":5,"updatedBy":"zentrale","data":{"text":"Hallo"}}}"#
        guard case .putMessage(let message) = try WireCodec.decode(Data(put.utf8)) else {
            Issue.record("Nachricht erwartet")
            return
        }
        #expect(message.data.text == "Hallo")

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
