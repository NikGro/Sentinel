import CoreLocation
import Foundation
import Testing
@testable import Sentinel

struct InstanceProtocolTests {
    @Test func snapshotNenntInstanzUndAlleInstanzen() throws {
        let json = """
        {"t":"snapshot","self":{"id":"g1","role":"fahnder"},"server":{"version":"0.13.0","routing":true},"online":[],
         "instanz":"nord",
         "instances":[{"id":"haupt","rev":1,"updatedAt":1,"updatedBy":"system","data":{"name":"Hauptlage","art":"einsatz","beschreibung":"","mitglieder":[],"erstelltVon":"system"}},
                      {"id":"nord","rev":1,"updatedAt":1,"updatedBy":"g1","data":{"name":"Nord","art":"einsatz","mitglieder":["g1"]}},
                      {"id":"p1","rev":1,"updatedAt":1,"updatedBy":"g1","data":{"name":"Bahnhof","art":"paket"}}],
         "members":[{"id":"g1","rev":1,"updatedAt":1,"updatedBy":"g1","data":{"name":"Test","spitzname":"Falke","dienststelle":"PK 35","instanz":"nord"}}],
         "vehicles":[],"annotations":[],"targets":[],"trackers":[],"layers":[],"rooms":[],"messages":[],
         "operation":{"funkkanal":null,"titel":"","hinweise":"","a":null,"ueberschlagen":{"teilnehmer":[],"zuweisungen":{},"naechste":[]},"rev":0},
         "positions":[],"trackerPositions":[]}
        """
        guard case .snapshot(let snapshot) = try WireCodec.decode(Data(json.utf8)) else {
            Issue.record("Snapshot erwartet")
            return
        }
        #expect(snapshot.instanz == "nord")
        #expect(snapshot.instances.count == 3)
        #expect(snapshot.instances.first { $0.id == "p1" }?.data.isPackage == true)
        #expect(snapshot.instances.first { $0.id == "nord" }?.data.mitglieder == ["g1"])
        #expect(snapshot.members.first?.data.instanz == "nord")
    }

    @Test func snapshotEinesAelterenServersGiltAlsHauptlage() throws {
        let json = """
        {"t":"snapshot","self":{"id":"g1","role":"fahnder"},"server":{"version":"0.11.0","routing":false},"online":[],
         "members":[{"id":"g1","rev":1,"updatedAt":1,"updatedBy":"g1","data":{"name":"Test","spitzname":"Falke","dienststelle":"PK 35"}}],
         "vehicles":[],"annotations":[],"targets":[],"trackers":[],"layers":[],"rooms":[],"messages":[],
         "operation":{"funkkanal":null,"titel":"","hinweise":"","a":null,"ueberschlagen":{"teilnehmer":[],"zuweisungen":{},"naechste":[]},"rev":0},
         "positions":[],"trackerPositions":[]}
        """
        guard case .snapshot(let snapshot) = try WireCodec.decode(Data(json.utf8)) else {
            Issue.record("Snapshot erwartet")
            return
        }
        #expect(snapshot.instanz == Instance.mainId)
        #expect(snapshot.instances.isEmpty)
        #expect(snapshot.members.first?.data.instanz == Instance.mainId)
    }

    @Test func hinweisAusAndererInstanz() throws {
        let json = #"{"t":"hinweis","instanz":"nord","name":"Nord","art":"sos","memberId":"g2","spitzname":"Adler"}"#
        guard case .notice(let notice) = try WireCodec.decode(Data(json.utf8)) else {
            Issue.record("Hinweis erwartet")
            return
        }
        #expect(notice.instanz == "nord")
        #expect(notice.art == "sos")
        #expect(notice.spitzname == "Adler")
    }

    @Test func instanzAenderungKommtAlsEreignis() throws {
        let json = #"{"t":"put","kind":"instance","entity":{"id":"nord","rev":2,"updatedAt":5,"updatedBy":"g1","data":{"name":"Nord","art":"einsatz","beschreibung":"","mitglieder":["g1","g2"],"erstelltVon":"g1"}}}"#
        guard case .putInstance(let instance) = try WireCodec.decode(Data(json.utf8)) else {
            Issue.record("Instanz erwartet")
            return
        }
        #expect(instance.data.mitglieder.count == 2)
    }
}

@MainActor
struct PermanentLayerTests {
    @Test func dauerhafteOrteNurImSonderbereichBearbeitbar() {
        let settings = LocalSettings(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        #expect(settings.canEdit(layerId: Layer.lageId))
        #expect(!settings.canEdit(layerId: Layer.dauerhaftId))
        #expect(settings.defaultLayerId == Layer.lageId)
        settings.permanentLayerUnlocked = true
        #expect(settings.canEdit(layerId: Layer.dauerhaftId))
        #expect(!settings.canEdit(layerId: Layer.lageId), "Im Sonderbereich ist nur die Ebene der dauerhaften Orte änderbar")
        #expect(settings.defaultLayerId == Layer.dauerhaftId)
    }
}

struct TransitGeometryTests {
    @Test func entfernungEntsprichtCoreLocation() {
        let a = GeoPoint(lat: 53.55, lon: 9.99)
        let b = GeoPoint(lat: 48.14, lon: 11.58)
        let reference = CLLocation(latitude: a.lat, longitude: a.lon).distance(from: CLLocation(latitude: b.lat, longitude: b.lon))
        #expect(abs(a.distance(to: b) - reference) / reference < 0.005)
    }

    @Test func schnelleEntfernungStimmtAufStadtgroesse() {
        let a = GeoPoint(lat: 53.55, lon: 10.0)
        let b = GeoPoint(lat: 53.56, lon: 10.02)
        let precise = a.distance(to: b)
        #expect(abs(TransitSimulation.meters(a, b) - precise) / precise < 0.01)
    }

    @Test func halteWerdenAufDemFahrwegGefundenUndZwischengespeichert() throws {
        let path = (0...100).map { GeoPoint(lat: 53.55 + Double($0) * 0.0002, lon: 10.0) }
        let stops = [path[0], path[50], path[100]]
        let first = try #require(TransitSimulation.stopIndices(stops, on: path))
        #expect(first == [0, 50, 100])
        #expect(TransitSimulation.stopIndices(stops, on: path) == first, "Zweite Abfrage liefert dasselbe aus dem Zwischenspeicher")
        // Ein Halt weit neben dem Fahrweg: keine Zuordnung.
        #expect(TransitSimulation.stopIndices([path[0], GeoPoint(lat: 53.0, lon: 10.0)], on: path) == nil)
    }

    @Test func echteZeitenBestimmenDiePosition() throws {
        let path = (0...100).map { GeoPoint(lat: 53.55 + Double($0) * 0.0002, lon: 10.0) }
        let stops = [path[0], path[100]]
        let start = 1_700_000_000_000.0
        let times: [Double?] = [start, start + 600_000]
        let halfway = try #require(TransitSimulation.state(stops, path: path, times: times, at: Date(timeIntervalSince1970: (start + 300_000) / 1000)))
        #expect(abs(halfway.point.lat - path[50].lat) < 0.0002)
        #expect(TransitSimulation.state(stops, path: path, times: times, at: Date(timeIntervalSince1970: (start - 60_000) / 1000)) == nil)
    }
}
