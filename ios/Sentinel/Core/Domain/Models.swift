import CoreLocation
import Foundation

// Fachliches Datenmodell. Die Feldnamen entsprechen dem Protokoll des Sentinel-Servers
// (siehe server/src/schemas.ts), deshalb sind sie deutsch.
// Hier: gemeinsame Bausteine, Kräfte, Fahrzeuge, Tracker, Ebenen, Instanzen, Chat und Einsatzzustand.

/// Ein gemeinsam bearbeitetes Objekt samt Versionsstand.
struct Versioned<T: Codable & Equatable & Sendable>: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var rev: Int
    var updatedAt: Double
    var updatedBy: String
    var data: T

    var updatedDate: Date { Date(timeIntervalSince1970: updatedAt / 1000) }
}

/// Objektarten, die über den Server synchronisiert werden.
protocol LageEntity: Codable, Equatable, Sendable {
    static var kind: String { get }
}

/// Wie ein Fahnder gerade unterwegs ist.
enum Fortbewegung: String, Codable, CaseIterable, Identifiable, Sendable {
    case fuss, fahrzeug, oepnv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fuss: "Zu Fuß"
        case .fahrzeug: "Fahrzeug"
        case .oepnv: "ÖPNV"
        }
    }

    var symbolName: String {
        switch self {
        case .fuss: "figure.walk"
        case .fahrzeug: "car.fill"
        case .oepnv: "tram.fill"
        }
    }
}

/// Gewählte Linie und Fahrtrichtung im öffentlichen Nahverkehr.
struct OepnvFahrt: Codable, Equatable, Hashable, Sendable {
    var linienId: String
    var linie: String
    var richtung: String
}

/// Fahnder. Jeder Fahnder hat ein eigenes Gerät; sein Standort kommt immer vom Telefon.
struct Member: LageEntity {
    static let kind = "member"
    var name: String
    var spitzname: String
    var dienststelle: String
    var telefon: String = ""
    var fotoBlob: String?
    var aktiv: Bool = true
    var fortbewegung: Fortbewegung = .fuss
    var fahrzeugId: String?
    var oepnv: OepnvFahrt?
    /// Aktive Instanz; ändert sich nur über `instanz.wechseln`.
    var instanz: String = Instance.mainId
    /// Eigenen Standortverlauf aufzeichnen (nur im Einsatz).
    var aufzeichnung: Bool = true

    init(name: String, spitzname: String, dienststelle: String, telefon: String = "", fotoBlob: String? = nil) {
        self.name = name
        self.spitzname = spitzname
        self.dienststelle = dienststelle
        self.telefon = telefon
        self.fotoBlob = fotoBlob
    }

    private enum CodingKeys: String, CodingKey {
        case name, spitzname, dienststelle, telefon, fotoBlob, aktiv, fortbewegung, fahrzeugId, oepnv, instanz, aufzeichnung
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        spitzname = try c.decodeIfPresent(String.self, forKey: .spitzname) ?? name
        dienststelle = try c.decodeIfPresent(String.self, forKey: .dienststelle) ?? ""
        telefon = try c.decodeIfPresent(String.self, forKey: .telefon) ?? ""
        fotoBlob = try c.decodeIfPresent(String.self, forKey: .fotoBlob)
        aktiv = try c.decodeIfPresent(Bool.self, forKey: .aktiv) ?? true
        fortbewegung = (try? c.decodeIfPresent(Fortbewegung.self, forKey: .fortbewegung)) ?? .fuss
        fahrzeugId = try c.decodeIfPresent(String.self, forKey: .fahrzeugId)
        oepnv = try c.decodeIfPresent(OepnvFahrt.self, forKey: .oepnv)
        instanz = try c.decodeIfPresent(String.self, forKey: .instanz) ?? Instance.mainId
        aufzeichnung = try c.decodeIfPresent(Bool.self, forKey: .aufzeichnung) ?? true
    }
}

/// Instanz: eigener Einsatz mit eigener Lage, eigenen Zielen, Chats und Einsatzzustand.
/// Ein Paket (`art == "paket"`) ist ein Vorbereitungsbereich, dessen Inhalt in einen Einsatz übernommen wird.
struct Instance: LageEntity {
    static let kind = "instance"
    static let mainId = "haupt"

    var name: String
    var art: String = "einsatz"
    var beschreibung: String = ""
    var mitglieder: [String] = []
    var erstelltVon: String = ""

    var isPackage: Bool { art == "paket" }

    private enum CodingKeys: String, CodingKey { case name, art, beschreibung, mitglieder, erstelltVon }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        art = try c.decodeIfPresent(String.self, forKey: .art) ?? "einsatz"
        beschreibung = try c.decodeIfPresent(String.self, forKey: .beschreibung) ?? ""
        mitglieder = try c.decodeIfPresent([String].self, forKey: .mitglieder) ?? []
        erstelltVon = try c.decodeIfPresent(String.self, forKey: .erstelltVon) ?? ""
    }
}

/// Fahrzeug der eigenen Kräfte. Bleibt dauerhaft angelegt und wird je Einsatz aktiv geschaltet.
struct Vehicle: LageEntity {
    static let kind = "vehicle"

    var funkrufname: String
    var bezeichnung: String = ""
    var kennzeichen: String = ""
    var beschreibung: String = ""
    var fotoBlob: String?
    var trackerId: String?
    var aktiv: Bool = true
    var abgestellt: TimedPoint?
    var aufzeichnung: Bool = true

    init(funkrufname: String, bezeichnung: String = "", kennzeichen: String = "", beschreibung: String = "") {
        self.funkrufname = funkrufname
        self.bezeichnung = bezeichnung
        self.kennzeichen = kennzeichen
        self.beschreibung = beschreibung
    }

    private enum CodingKeys: String, CodingKey {
        case funkrufname, bezeichnung, kennzeichen, beschreibung, fotoBlob, trackerId, aktiv, abgestellt, aufzeichnung
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bezeichnung = try c.decodeIfPresent(String.self, forKey: .bezeichnung) ?? ""
        funkrufname = try c.decodeIfPresent(String.self, forKey: .funkrufname) ?? (bezeichnung.isEmpty ? "Fahrzeug" : bezeichnung)
        kennzeichen = try c.decodeIfPresent(String.self, forKey: .kennzeichen) ?? ""
        beschreibung = try c.decodeIfPresent(String.self, forKey: .beschreibung) ?? ""
        fotoBlob = try c.decodeIfPresent(String.self, forKey: .fotoBlob)
        trackerId = try c.decodeIfPresent(String.self, forKey: .trackerId)
        aktiv = try c.decodeIfPresent(Bool.self, forKey: .aktiv) ?? true
        abgestellt = try c.decodeIfPresent(TimedPoint.self, forKey: .abgestellt)
        aufzeichnung = try c.decodeIfPresent(Bool.self, forKey: .aufzeichnung) ?? true
    }

    /// Zusatzangabe unter dem Funkrufnamen.
    var subtitle: String {
        [bezeichnung, kennzeichen].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct Tracker: LageEntity {
    static let kind = "tracker"
    var name: String
    var anbieter: String
    var kennung: String
    var intervall: Int?
    /// PAJ: E-Mail des eigenen Kontos, falls für diesen Tracker eines hinterlegt ist.
    var kontoEmail: String?
    /// Rufnummer der SIM-Karte im Tracker und Geräte-PIN, für Befehle per SMS.
    var telefon: String?
    var smsPin: String?
    var aufzeichnung: Bool?

    var providerTitle: String { anbieter == "paj" ? "PAJ" : "SinoTrack" }
    var records: Bool { aufzeichnung ?? true }
    var isSinoTrack: Bool { anbieter == "sinotrack" }
}

struct Layer: LageEntity {
    static let kind = "layer"
    static let lageId = "lage"
    static let dauerhaftId = "dauerhaft"

    var name: String
    var art: String
    var status: String
    var beschreibung: String = ""

    var isLive: Bool { status == "live" }

    var symbolName: String {
        switch art {
        case "dauerhaft": "pin"
        case "paket": "shippingbox"
        case "argus": "chart.bar.xaxis"
        default: "scope"
        }
    }
}

struct ChatRoom: LageEntity {
    static let kind = "room"
    static let generalId = "allgemein"
    var name: String
}

struct ChatAttachment: Codable, Equatable, Sendable {
    enum Art: String, Codable, Sendable {
        case bild, audio, datei
    }

    var blobId: String
    var art: Art
    var name: String = ""
    var mime: String
    var groesse: Int
    var dauer: Double?
    /// Sprachnachricht: Lautstärkeverlauf (0 bis 1) für die Wellenform.
    var wellenform: [Double]?
}

struct ChatMessage: LageEntity {
    static let kind = "message"
    var roomId: String = ChatRoom.generalId
    var text: String = ""
    var anhang: ChatAttachment?

    init(roomId: String, text: String, anhang: ChatAttachment? = nil) {
        self.roomId = roomId
        self.text = text
        self.anhang = anhang
    }

    private enum CodingKeys: String, CodingKey {
        case roomId, text, anhang
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        roomId = try c.decodeIfPresent(String.self, forKey: .roomId) ?? ChatRoom.generalId
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        anhang = try c.decodeIfPresent(ChatAttachment.self, forKey: .anhang)
    }
}

struct LeapfrogStop: Codable, Equatable, Hashable, Sendable {
    var name: String
    var lat: Double
    var lon: Double

    var point: GeoPoint { GeoPoint(lat: lat, lon: lon) }
}

/// Gemeinsamer Zustand des laufenden Einsatzes.
struct OperationState: Codable, Equatable, Sendable {
    struct APosition: Codable, Equatable, Sendable {
        var memberId: String
        var seit: Double
    }

    /// Überschlagendes Anfahren der nächsten Haltestellen, solange die A im ÖPNV fährt.
    struct Leapfrog: Codable, Equatable, Sendable {
        var teilnehmer: [String] = []
        var zuweisungen: [String: LeapfrogStop] = [:]
        var naechste: [LeapfrogStop] = []
    }

    var funkkanal: String?
    var titel: String = ""
    var hinweise: String = ""
    var a: APosition?
    var ueberschlagen = Leapfrog()
    /// Notruf eines Fahnders.
    var sos: APosition?
    var rev: Int = 0

    init() {}

    private enum CodingKeys: String, CodingKey {
        case funkkanal, titel, hinweise, a, ueberschlagen, sos, rev
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        funkkanal = try c.decodeIfPresent(String.self, forKey: .funkkanal)
        titel = try c.decodeIfPresent(String.self, forKey: .titel) ?? ""
        hinweise = try c.decodeIfPresent(String.self, forKey: .hinweise) ?? ""
        a = try c.decodeIfPresent(APosition.self, forKey: .a)
        ueberschlagen = try c.decodeIfPresent(Leapfrog.self, forKey: .ueberschlagen) ?? Leapfrog()
        sos = try c.decodeIfPresent(APosition.self, forKey: .sos)
        rev = try c.decodeIfPresent(Int.self, forKey: .rev) ?? 0
    }
}
