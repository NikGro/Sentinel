import CoreLocation
import Foundation

// Fachliches Datenmodell. Die Feldnamen entsprechen dem Protokoll des Sentinel-Servers
// (siehe server/src/schemas.ts), deshalb sind sie deutsch.

enum ZielArt: String, Codable, CaseIterable, Identifiable, Sendable {
    case person, fahrzeug, objekt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .person: "Zielperson"
        case .fahrzeug: "Zielfahrzeug"
        case .objekt: "Zielobjekt"
        }
    }

    var symbolName: String {
        switch self {
        case .person: "person.fill"
        case .fahrzeug: "car.fill"
        case .objekt: "house.fill"
        }
    }

    var plural: String {
        switch self {
        case .person: "Zielpersonen"
        case .fahrzeug: "Zielfahrzeuge"
        case .objekt: "Zielobjekte"
        }
    }
}

/// Zielperson, Zielfahrzeug oder Zielobjekt. Erscheint auf der Karte, sobald ein Standort oder Tracker bekannt ist.
struct Target: LageEntity {
    static let kind = "target"
    var art: ZielArt = .person
    var bezeichnung: String = ""
    var vorname: String = ""
    var nachname: String = ""
    var geburtsdatum: String?
    var geburtsort: String = ""
    var staatsangehoerigkeit: String = ""
    var anschrift: String = ""
    var merkmale: String = ""
    var fotoBlob: String?
    var kennzeichen: String = ""
    var fahrzeugBeschreibung: String = ""
    var fahrzeugFotoBlob: String?
    var sachverhalt: String = ""
    var hinweise: String = ""
    var massnahmen: String = ""
    var trackerId: String?
    var standort: TimedPoint?
    /// Weitere Fotos und Dateien.
    var anhaenge: [ChatAttachment] = []
    /// Zielperson unterwegs: zu Fuß oder gebunden an ÖPNV-Fahrzeug, Zielfahrzeug oder Zielobjekt.
    var bindung: TargetBinding?
    /// Woher der Standort kommt, solange das Ziel nicht in etwas eingestiegen ist.
    var quelle: LocationSource?
    /// Standortverlauf aufzeichnen.
    var aufzeichnung: Bool = true
    /// Gruppe im Ziele-Tab (höchstens eine); `nil` ungruppiert.
    var gruppeId: String?

    init(art: ZielArt = .person, bezeichnung: String = "", vorname: String = "", nachname: String = "") {
        self.art = art
        self.bezeichnung = bezeichnung
        self.vorname = vorname
        self.nachname = nachname
    }

    private enum CodingKeys: String, CodingKey {
        case art, bezeichnung, vorname, nachname, geburtsdatum, geburtsort, staatsangehoerigkeit, anschrift, merkmale, fotoBlob
        case kennzeichen, fahrzeugBeschreibung, fahrzeugFotoBlob, sachverhalt, hinweise, massnahmen, trackerId, standort, anhaenge
        case bindung, quelle, aufzeichnung, gruppeId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) throws -> String { try c.decodeIfPresent(String.self, forKey: key) ?? "" }
        art = (try? c.decodeIfPresent(ZielArt.self, forKey: .art)) ?? .person
        bezeichnung = try text(.bezeichnung)
        vorname = try text(.vorname)
        nachname = try text(.nachname)
        geburtsdatum = try c.decodeIfPresent(String.self, forKey: .geburtsdatum)
        geburtsort = try text(.geburtsort)
        staatsangehoerigkeit = try text(.staatsangehoerigkeit)
        anschrift = try text(.anschrift)
        merkmale = try text(.merkmale)
        fotoBlob = try c.decodeIfPresent(String.self, forKey: .fotoBlob)
        kennzeichen = try text(.kennzeichen)
        fahrzeugBeschreibung = try text(.fahrzeugBeschreibung)
        fahrzeugFotoBlob = try c.decodeIfPresent(String.self, forKey: .fahrzeugFotoBlob)
        sachverhalt = try text(.sachverhalt)
        hinweise = try text(.hinweise)
        massnahmen = try text(.massnahmen)
        trackerId = try c.decodeIfPresent(String.self, forKey: .trackerId)
        standort = try c.decodeIfPresent(TimedPoint.self, forKey: .standort)
        anhaenge = (try? c.decodeIfPresent([ChatAttachment].self, forKey: .anhaenge)) ?? []
        bindung = try? c.decodeIfPresent(TargetBinding.self, forKey: .bindung)
        quelle = try? c.decodeIfPresent(LocationSource.self, forKey: .quelle)
        aufzeichnung = (try? c.decodeIfPresent(Bool.self, forKey: .aufzeichnung)) ?? true
        gruppeId = try? c.decodeIfPresent(String.self, forKey: .gruppeId)
    }

    /// Zweite Zeile unter dem Namen: beim Zielfahrzeug die Bezeichnung (der Name ist das Kennzeichen), sonst ein
    /// Kennzeichen, falls eingetragen.
    var secondaryName: String? {
        switch art {
        case .fahrzeug:
            return !kennzeichen.isEmpty && !bezeichnung.isEmpty ? bezeichnung : nil
        case .person, .objekt:
            return kennzeichen.isEmpty ? nil : kennzeichen
        }
    }

    var displayName: String {
        switch art {
        case .person:
            let full = [vorname, nachname].filter { !$0.isEmpty }.joined(separator: " ")
            return full.isEmpty ? "Unbekannte Person" : full
        case .fahrzeug:
            return [kennzeichen, bezeichnung].first { !$0.isEmpty } ?? "Zielfahrzeug"
        case .objekt:
            return [bezeichnung, anschrift].first { !$0.isEmpty } ?? "Zielobjekt"
        }
    }

    private static let birthFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var birthDate: Date? {
        get { geburtsdatum.flatMap { Self.birthFormat.date(from: $0) } }
        set { geburtsdatum = newValue.map { Self.birthFormat.string(from: $0) } }
    }

    /// Geburtsdatum als deutscher Text "TT.MM.JJJJ"; leer heißt unbekannt.
    var birthDateText: String {
        guard let birthDate else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: birthDate)
    }

    /// Liest "4.5.1990", "04.05.1990" oder "04051990"; `nil`, wenn kein gültiges Datum.
    static func parseBirthDate(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        var parts = trimmed.split(whereSeparator: { $0 == "." || $0 == "/" || $0 == "-" || $0 == " " }).map(String.init)
        if parts.count == 1, trimmed.count == 8, trimmed.allSatisfy(\.isNumber) {
            let chars = Array(trimmed)
            parts = [String(chars[0..<2]), String(chars[2..<4]), String(chars[4..<8])]
        }
        guard parts.count == 3, let day = Int(parts[0]), let month = Int(parts[1]), var year = Int(parts[2]) else { return nil }
        if parts[2].count == 2 {
            let current = Calendar.current.component(.year, from: .now) % 100
            year += year > current ? 1900 : 2000
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components), date <= .now, year >= 1900 else { return nil }
        return date
    }

    /// Alle Freitexte in einem Feld. Ältere Stände mit getrennten Feldern werden mit Überschriften zusammengeführt.
    var notes: String {
        let extra = [
            (art == .objekt ? "Beschreibung" : "Merkmale", merkmale),
            (art == .fahrzeug ? "Besonderheiten" : "Fahrzeug", fahrzeugBeschreibung),
            ("Sachverhalt", sachverhalt),
        ]
        let after = [("Maßnahmen", massnahmen)]
        let trimmed = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard (extra + after).contains(where: { !trimmed($0.1).isEmpty }) else { return hinweise }
        return (extra + [("Hinweise", hinweise)] + after)
            .filter { !trimmed($0.1).isEmpty }
            .map { "\($0.0): \(trimmed($0.1))" }
            .joined(separator: "\n\n")
    }

    /// Bringt ein Ziel auf das aktuelle Modell: ein Freitextfeld, alle Fotos in einer Liste.
    mutating func normalize() {
        hinweise = notes
        merkmale = ""
        fahrzeugBeschreibung = ""
        sachverhalt = ""
        massnahmen = ""
        for blob in [fahrzeugFotoBlob, fotoBlob].compactMap({ $0 }) where !anhaenge.contains(where: { $0.blobId == blob }) {
            anhaenge.insert(ChatAttachment(blobId: blob, art: .bild, name: "Foto.jpg", mime: "image/jpeg", groesse: 0), at: 0)
        }
        fahrzeugFotoBlob = nil
        fotoBlob = anhaenge.first(where: { $0.art == .bild })?.blobId
    }

    static func age(of birthDate: Date, at reference: Date = .now) -> Int? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return calendar.dateComponents([.year], from: birthDate, to: reference).year
    }

    /// Alter in vollen Jahren zum Stichtag.
    func age(at reference: Date = .now) -> Int? {
        guard let birthDate else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return calendar.dateComponents([.year], from: birthDate, to: reference).year
    }
}

/// Wo eine Zielperson gerade ist: zu Fuß oder mit einem anderen Objekt unterwegs bzw. darin.
struct TargetBinding: Codable, Equatable, Hashable, Sendable {
    enum Art: String, Codable, CaseIterable, Identifiable, Sendable {
        case fuss, oepnv, fahrzeug, objekt

        var id: String { rawValue }

        var title: String {
            switch self {
            case .fuss: "Zu Fuß"
            case .oepnv: "ÖPNV"
            case .fahrzeug: "Fahrzeug"
            case .objekt: "Gebäude"
            }
        }

        var symbolName: String {
            switch self {
            case .fuss: "figure.walk"
            case .oepnv: "tram.fill"
            case .fahrzeug: "car.fill"
            case .objekt: "building.2.fill"
            }
        }
    }

    var art: Art
    /// Markierung (ÖPNV-Fahrzeug) bzw. Ziel (Zielfahrzeug, Zielobjekt).
    var zielId: String?
}

extension Target {
    /// Symbol auf der Karte: Zielfahrzeug Auto, Zielobjekt Haus, Zielperson nach Fortbewegung (zu Fuß, im Fahrzeug, im ÖPNV).
    var mapSymbol: String {
        if art == .fahrzeug { return Fortbewegung.fahrzeug.symbolName }
        if art == .objekt { return ZielArt.objekt.symbolName }
        guard let unterwegs = bindung?.art else { return Fortbewegung.fuss.symbolName }
        switch unterwegs {
        case .fahrzeug: return Fortbewegung.fahrzeug.symbolName
        case .oepnv: return Fortbewegung.oepnv.symbolName
        case .objekt: return ZielArt.objekt.symbolName
        case .fuss: return Fortbewegung.fuss.symbolName
        }
    }
}

/// Standortquelle eines Ziels (Zielperson oder Zielfahrzeug), solange es nicht in etwas eingestiegen ist.
enum LocationSource: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Von Hand gesetzt.
    case hand
    /// Vom verbundenen Tracker.
    case tracker
    /// Folgt der A-Position: wer die A hat, hat das Ziel im Blick.
    case a

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hand: "Von Hand"
        case .tracker: "Tracker"
        case .a: "A-Position"
        }
    }

    var symbolName: String {
        switch self {
        case .hand: "hand.tap.fill"
        case .tracker: "dot.radiowaves.left.and.right"
        case .a: "a.circle.fill"
        }
    }
}

extension Target {
    /// Gilt die gewählte Quelle? Ohne ausdrückliche Wahl zählt ein verbundener Tracker, sonst der gesetzte Standort.
    var effectiveSource: LocationSource { quelle ?? (trackerId != nil ? .tracker : .hand) }

    /// Kann dieses Ziel eine dynamische Standortquelle haben (Tracker, A-Position)? Zielpersonen und Zielfahrzeuge.
    var supportsDynamicSource: Bool { art != .objekt }
}

/// Gruppe von Zielen im Ziele-Tab, je Instanz ein- und ausblendbar.
struct TargetGroup: LageEntity {
    static let kind = "targetGroup"
    var name: String
}
