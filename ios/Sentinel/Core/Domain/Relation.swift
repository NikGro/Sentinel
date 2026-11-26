import Foundation

/// Beziehung zwischen zwei Zielen (Person, Fahrzeug, Objekt), als eigener Datensatz: von beiden Seiten sichtbar und
/// bearbeitbar. Keine gesicherte Tatsache: Status und Herkunft halten fest, wie belastbar sie ist und woher sie stammt.
struct Relation: LageEntity {
    static let kind = "relation"
    var von: String
    var nach: String
    /// Z. B. Halter, Fahrer, Bewohner; leer heißt „verbunden“.
    var bezeichnung: String = ""
    var notiz: String = ""
    var status: Status = .vermutet
    /// Woher die Angabe stammt, z. B. „Halterabfrage“.
    var herkunft: String = ""

    enum Status: String, Codable, CaseIterable, Identifiable, Sendable {
        case vermutet, bestaetigt, beendet

        var id: String { rawValue }

        var title: String {
            switch self {
            case .vermutet: "Vermutet"
            case .bestaetigt: "Bestätigt"
            case .beendet: "Beendet"
            }
        }
    }

    init(von: String, nach: String) {
        self.von = von
        self.nach = nach
    }

    private enum CodingKeys: String, CodingKey { case von, nach, bezeichnung, notiz, status, herkunft }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        von = try c.decode(String.self, forKey: .von)
        nach = try c.decode(String.self, forKey: .nach)
        bezeichnung = try c.decodeIfPresent(String.self, forKey: .bezeichnung) ?? ""
        notiz = try c.decodeIfPresent(String.self, forKey: .notiz) ?? ""
        status = (try? c.decodeIfPresent(Status.self, forKey: .status)) ?? .vermutet
        herkunft = try c.decodeIfPresent(String.self, forKey: .herkunft) ?? ""
    }

    /// Das jeweils andere Ziel aus Sicht von `id`.
    func other(than id: String) -> String { von == id ? nach : von }

    /// Übliche Bezeichnungen, passend zu den beiden Zielarten (von dieser Seite aus gelesen: „<anderes> ist …“).
    static func suggestions(own: ZielArt, other: ZielArt) -> [String] {
        switch (own, other) {
        case (.fahrzeug, .person): ["Halter", "Fahrer", "Regelmäßiger Nutzer", "Insasse"]
        case (.person, .fahrzeug): ["Halter", "Fahrer", "Regelmäßiger Nutzer", "Insasse"]
        case (.person, .objekt), (.objekt, .person): ["Bewohner", "Eigentümer", "Regelmäßiger Aufenthaltsort", "Arbeitsstelle"]
        case (.fahrzeug, .objekt), (.objekt, .fahrzeug): ["Zulassungsanschrift", "Abstellort"]
        case (.person, .person): ["Kontaktperson", "Familie", "Mittäter"]
        default: ["Verbunden"]
        }
    }
}

/// Eine Beziehung aus Sicht eines Ziels, mit dem jeweils anderen Ziel.
struct RelatedTarget: Identifiable {
    let relation: Versioned<Relation>
    let other: Versioned<Target>

    var id: String { relation.id }
}
