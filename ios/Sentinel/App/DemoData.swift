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

    static func snapshot(modus: String, now: Date = .now) -> Data {
        let ts = Int(now.timeIntervalSince1970 * 1000)
        let lkp = modus == "fahndung" ? #"{"lat":53.5532,"lon":9.9921,"ts":\#(ts - 9 * 60_000),"quelle":"a","targetId":"t1"}"# : "null"
        let a = modus == "observation" ? #"{"memberId":"m2","seit":\#(ts - 4 * 60_000)}"# : "null"
        func member(_ id: String, _ name: String, _ callsign: String, vehicle: String = "null") -> String {
            #"{"id":"\#(id)","rev":1,"updatedAt":\#(ts),"updatedBy":"\#(id)","data":{"name":"\#(name)","funkrufname":"\#(callsign)","dienststelle":"PK 35","telefon":"+49 170 0000000","fotoBlob":null,"fahrzeugId":\#(vehicle)}}"#
        }
        func object(_ id: String, _ typ: String, _ titel: String, _ farbe: String, _ punkte: String, radius: String = "null") -> String {
            #"{"id":"\#(id)","rev":1,"updatedAt":\#(ts),"updatedBy":"zentrale","data":{"layerId":"lage","typ":"\#(typ)","titel":"\#(titel)","notiz":"","farbe":"\#(farbe)","symbol":"","punkte":\#(punkte),"radius":\#(radius),"wert":null}}"#
        }
        func position(_ id: String, _ lat: Double, _ lon: Double) -> String {
            #"{"id":"\#(id)","p":{"lat":\#(lat),"lon":\#(lon),"ts":\#(ts),"acc":5}}"#
        }
        let json = """
        {"t":"snapshot","self":{"id":"\(deviceId)","role":"fahnder"},"server":{"version":"demo","routing":true},
         "online":["\(deviceId)","m2","m3"],
         "members":[\(member(deviceId, "Anna Beispiel", "P 35/24", vehicle: "\"v1\"")),\(member("m2", "Ben Muster", "P 35/31")),\(member("m3", "Cem Probe", "P 35/7"))],
         "vehicles":[{"id":"v1","rev":1,"updatedAt":\(ts),"updatedBy":"\(deviceId)","data":{"bezeichnung":"Golf grau","kennzeichen":"HH AB 1234","beschreibung":"Dachreling","fotoBlob":null,"trackerId":null,"abgestellt":null}},
                     {"id":"v2","rev":1,"updatedAt":\(ts),"updatedBy":"m2","data":{"bezeichnung":"Passat schwarz","kennzeichen":"HH CD 567","beschreibung":"","fotoBlob":null,"trackerId":null,"abgestellt":{"lat":53.5489,"lon":9.9872,"ts":\(ts - 600_000)}}}],
         "annotations":[\(object("o1", "marker", "Zielobjekt", "#FF453A", #"[{"lat":53.5511,"lon":9.9937}]"#)),
                        \(object("o2", "flaeche", "Innenhof", "#0A84FF", #"[{"lat":53.5522,"lon":9.9965},{"lat":53.5522,"lon":9.9992},{"lat":53.5508,"lon":9.9990},{"lat":53.5509,"lon":9.9963}]"#)),
                        \(object("o3", "linie", "Fluchtweg", "#FFD60A", #"[{"lat":53.5511,"lon":9.9937},{"lat":53.5498,"lon":9.9921},{"lat":53.5485,"lon":9.9930}]"#)),
                        \(object("o4", "kreis", "Treffpunkt", "#30D158", #"[{"lat":53.5541,"lon":9.9978}]"#, radius: "120"))],
         "targets":[{"id":"t1","rev":3,"updatedAt":\(ts),"updatedBy":"m2","data":{"vorname":"Max","nachname":"Mustermann","geburtsdatum":"1990-05-04","geburtsort":"Hamburg","staatsangehoerigkeit":"deutsch","anschrift":"Musterstraße 1, 20095 Hamburg","merkmale":"ca. 1,80 m, schlank, dunkle kurze Haare, schwarze Jacke","fotoBlob":null,"kennzeichen":"HH XY 99","fahrzeugBeschreibung":"BMW 3er, dunkelblau","fahrzeugFotoBlob":null,"sachverhalt":"Beispielsachverhalt für die Vorschau.","hinweise":"Eigensicherung beachten.","massnahmen":"Aufenthalt feststellen.","trackerId":null}}],
         "trackers":[],
         "layers":[{"id":"lage","rev":1,"updatedAt":1,"updatedBy":"system","data":{"name":"Lage","art":"lage","status":"live","beschreibung":""}},
                   {"id":"dauerhaft","rev":1,"updatedAt":1,"updatedBy":"system","data":{"name":"Dauerhafte Orte","art":"dauerhaft","status":"live","beschreibung":""}}],
         "messages":[{"id":"n1","rev":1,"updatedAt":\(ts - 120_000),"updatedBy":"m2","data":{"text":"Bin auf Position, Sicht auf den Eingang."}},
                     {"id":"n2","rev":1,"updatedAt":\(ts - 60_000),"updatedBy":"zentrale","data":{"text":"Verstanden. Kanal bleibt 4711."}}],
         "operation":{"modus":"\(modus)","funkkanal":"4711","titel":"Beispiellage","hinweise":"Nur Vorschau.","a":\(a),"lkp":\(lkp),"bestreifungSeit":null,"rev":1},
         "positions":[\(position(deviceId, 53.5499, 9.9951)),\(position("m2", 53.5532, 9.9921)),\(position("m3", 53.5478, 9.9989))],
         "trackerPositions":[]}
        """
        return Data(json.utf8)
    }

    /// Modus aus dem Startargument `-demo-modus <wert>`, sonst Observation.
    static var requestedMode: String {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demo-modus"), arguments.indices.contains(index + 1) else { return "observation" }
        return arguments[index + 1]
    }
}
#endif
