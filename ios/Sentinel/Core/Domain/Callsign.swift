import Foundation

/// Funkrufname nach dem Muster "P 35/24": 1-3 Buchstaben, 1-3 Ziffern, Schrägstrich, 1-3 Ziffern.
enum Callsign {
    /// Liefert die normalisierte Schreibweise oder `nil`, wenn die Eingabe nicht dem Muster entspricht.
    static func normalize(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = trimmed.wholeMatch(of: #/^([A-Za-zÄÖÜäöü]{1,3})\s?(\d{1,3})/(\d{1,3})$/#) else { return nil }
        return "\(match.1.uppercased()) \(match.2)/\(match.3)"
    }

    static func isValid(_ input: String) -> Bool {
        normalize(input) != nil
    }
}

/// Funkkanal: 1 bis 5 Ziffern.
enum RadioChannel {
    static func isValid(_ input: String) -> Bool {
        input.wholeMatch(of: #/\d{1,5}/#) != nil
    }
}
