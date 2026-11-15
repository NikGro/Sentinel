#if DEBUG
import Foundation

/// Beispiel-Lage für Oberflächentests und Vorschauen. Nur in Debug-Builds enthalten, nie in der ausgelieferten App.
/// Aktiviert wird sie über das Startargument `-demo`; dabei wird keine Verbindung aufgebaut.
enum DemoData {
    static let launchArgument = "-demo"
    static let deviceId = "demo-ich"

    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains(launchArgument) }

    static var credentials: Credentials {
        Credentials(serverURL: URL(string: "https://demo.invalid")!, deviceId: deviceId, token: "demo")
    }

    static func snapshot(now: Date = .now) -> Data {
        let ts = Int(now.timeIntervalSince1970 * 1000)
        func member(_ id: String, _ name: String, _ nick: String, art: String = "fuss", vehicle: String = "null", oepnv: String = "null") -> String {
            #"{"id":"\#(id)","rev":1,"updatedAt":\#(ts),"updatedBy":"\#(id)","data":{"name":"\#(name)","spitzname":"\#(nick)","dienststelle":"PK 35","telefon":"+49 170 0000000","fotoBlob":null,"aktiv":true,"fortbewegung":"\#(art)","fahrzeugId":\#(vehicle),"oepnv":\#(oepnv)}}"#
        }
        func object(_ id: String, _ typ: String, _ titel: String, _ farbe: String, _ punkte: String, radius: String = "null", zeit: String = "null") -> String {
            #"{"id":"\#(id)","rev":1,"updatedAt":\#(ts),"updatedBy":"zentrale","data":{"layerId":"lage","typ":"\#(typ)","titel":"\#(titel)","notiz":"","farbe":"\#(farbe)","symbol":"","punkte":\#(punkte),"radius":\#(radius),"wert":null,"zeit":\#(zeit),"trackerId":null}}"#
        }
        func position(_ id: String, _ lat: Double, _ lon: Double) -> String {
            #"{"id":"\#(id)","p":{"lat":\#(lat),"lon":\#(lon),"ts":\#(ts),"acc":5}}"#
        }
        let u3 = #"{"linienId":"1","linie":"U3","richtung":"Barmbek"}"#
        let json = """
        {"t":"snapshot","self":{"id":"\(deviceId)","role":"fahnder"},"server":{"version":"demo","routing":true},
         "online":["\(deviceId)","m2","m3"],
         "members":[\(member(deviceId, "Anna Beispiel", "Falke")),\(member("m2", "Ben Muster", "Adler", art: "oepnv", oepnv: u3)),\(member("m3", "Cem Probe", "Bussard", art: "fahrzeug", vehicle: "\"v1\""))],
         "vehicles":[{"id":"v1","rev":1,"updatedAt":\(ts),"updatedBy":"m3","data":{"funkrufname":"P 35/24","bezeichnung":"Golf grau","kennzeichen":"HH AB 1234","beschreibung":"Dachreling","fotoBlob":null,"trackerId":null,"aktiv":true,"abgestellt":null}},
                     {"id":"v2","rev":1,"updatedAt":\(ts),"updatedBy":"m2","data":{"funkrufname":"P 35/31","bezeichnung":"Passat schwarz","kennzeichen":"HH CD 567","beschreibung":"","fotoBlob":null,"trackerId":null,"aktiv":true,"abgestellt":{"lat":53.5489,"lon":9.9872,"ts":\(ts - 600_000)}}}],
         "annotations":[\(object("o1", "marker", "Treffpunkt", "#FF453A", #"[{"lat":53.5511,"lon":9.9937}]"#)),
                        \(object("o2", "flaeche", "Innenhof", "#0A84FF", #"[{"lat":53.5522,"lon":9.9965},{"lat":53.5522,"lon":9.9992},{"lat":53.5508,"lon":9.9990},{"lat":53.5509,"lon":9.9963}]"#)),
                        \(object("o4", "fahndungsraum", "Letzte Sichtung", "#C97C7C", #"[{"lat":53.5541,"lon":9.9978}]"#, zeit: "\(ts - 9 * 60_000)"))],
         "targets":[{"id":"t1","rev":3,"updatedAt":\(ts),"updatedBy":"m2","data":{"art":"person","bezeichnung":"","vorname":"Max","nachname":"Mustermann","geburtsdatum":"1990-05-04","geburtsort":"Hamburg","staatsangehoerigkeit":"deutsch","anschrift":"Musterstraße 1, 20095 Hamburg","merkmale":"ca. 1,80 m, schlank, dunkle kurze Haare, schwarze Jacke","fotoBlob":null,"kennzeichen":"","fahrzeugBeschreibung":"","fahrzeugFotoBlob":null,"sachverhalt":"Beispielsachverhalt für die Vorschau.","hinweise":"Eigensicherung beachten.","massnahmen":"Aufenthalt feststellen.","trackerId":null,"standort":{"lat":53.5532,"lon":9.9921,"ts":\(ts)}}},
                    {"id":"t2","rev":1,"updatedAt":\(ts),"updatedBy":"m2","data":{"art":"objekt","bezeichnung":"Wohnung Musterstraße","anschrift":"Mönckebergstraße 7, 20095 Hamburg","standort":{"lat":53.5506,"lon":9.9990,"ts":\(ts)}}}],
         "trackers":[],
         "layers":[{"id":"lage","rev":1,"updatedAt":1,"updatedBy":"system","data":{"name":"Lage","art":"lage","status":"live","beschreibung":""}},
                   {"id":"dauerhaft","rev":1,"updatedAt":1,"updatedBy":"system","data":{"name":"Dauerhafte Orte","art":"dauerhaft","status":"live","beschreibung":""}}],
         "rooms":[{"id":"allgemein","rev":1,"updatedAt":1,"updatedBy":"system","data":{"name":"Allgemein"}},{"id":"r1","rev":1,"updatedAt":1,"updatedBy":"m2","data":{"name":"Team Nord"}}],
         "messages":[{"id":"n1","rev":1,"updatedAt":\(ts - 120_000),"updatedBy":"m2","data":{"roomId":"allgemein","text":"Bin auf Position, Sicht auf den Eingang.","anhang":null}},
                     {"id":"n2","rev":1,"updatedAt":\(ts - 60_000),"updatedBy":"zentrale","data":{"roomId":"allgemein","text":"Verstanden. Kanal bleibt 4711.","anhang":null}}],
         "operation":{"funkkanal":"4711","titel":"Beispiellage","hinweise":"Nur Vorschau.","a":{"memberId":"m2","seit":\(ts - 4 * 60_000)},"ueberschlagen":{"teilnehmer":[],"zuweisungen":{},"naechste":[{"name":"Mönckebergstraße","lat":53.5506,"lon":9.9990},{"name":"Steinstraße","lat":53.5502,"lon":10.0034}]},"rev":1},
         "positions":[\(position(deviceId, 53.5499, 9.9951)),\(position("m2", 53.5532, 9.9921)),\(position("m3", 53.5478, 9.9989))],
         "trackerPositions":[]}
        """
        return Data(json.utf8)
    }
}
#endif
