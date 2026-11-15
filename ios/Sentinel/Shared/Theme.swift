import SwiftUI

extension Color {
    /// Farbe aus "#RRGGBB". Ungültige Angaben ergeben Orange.
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            self = .orange
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// Gestaltungskonstanten der App.
enum Theme {
    /// Farbauswahl für Markierungen (Systemfarben, gut unterscheidbar auf Karte und Satellitenbild).
    static let palette: [(name: String, hex: String)] = [
        ("Orange", "#FF9F0A"), ("Rot", "#FF453A"), ("Gelb", "#FFD60A"), ("Grün", "#30D158"),
        ("Türkis", "#64D2FF"), ("Blau", "#0A84FF"), ("Violett", "#BF5AF2"), ("Weiß", "#F2F2F7"),
    ]

    /// Symbole für Marker (SF Symbols).
    static let markerSymbols: [String] = [
        "mappin", "flag.fill", "eye.fill", "house.fill", "building.2.fill", "car.fill", "figure.walk",
        "person.fill", "exclamationmark.triangle.fill", "camera.fill", "door.left.hand.open", "p.circle.fill",
        "tram.fill", "cross.fill", "star.fill", "xmark.circle.fill",
    ]

    /// Akzent der App, passend zum Petrol der Kommandozentrale.
    static let accent = Color(hex: "#2F7D77")
    static let force = Color(hex: "#30A46C")
    static let aPosition = Color.red
    static let target = Color(hex: "#FF375F")
    static let coverage = Color(hex: "#FF9F0A")

    /// Einheitliche Höhe aller Leisten und Eingabefelder über der Tableiste (Suche, A-Position, Fortbewegung, Lageleiste, Chat).
    static let barHeight: CGFloat = 50
    /// Einheitlicher Durchmesser runder Glasknöpfe.
    static let roundButton: CGFloat = 50
    /// Seitlicher Abstand, bündig mit der schwebenden Tableiste.
    static let barInset: CGFloat = 22
    /// Abstand zwischen gestapelten Leisten.
    static let barSpacing: CGFloat = 8

    static func color(for mode: ReachMode) -> Color {
        switch mode {
        case .fuss: .green
        case .kfz: .red
        case .oepnv: .blue
        }
    }
}

enum Format {
    /// Die App ist durchgehend deutsch, unabhängig von der Sprache des Geräts.
    static let locale = Locale(identifier: "de_DE")

    static func distance(_ meters: Double) -> String {
        Measurement(value: meters, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road).locale(locale))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .narrow).locale(locale))
    }

    /// Dauer als Minuten und Sekunden, z. B. "1:05".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale))
    }

    /// "vor 3 Min." bzw. "gerade eben".
    static func ago(_ date: Date, now: Date = .now) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 20 { return "gerade eben" }
        if seconds < 90 { return "vor 1 Min." }
        if seconds < 3600 { return "vor \(Int(seconds / 60)) Min." }
        if seconds < 86_400 { return "vor \(Int(seconds / 3600)) Std." }
        return dateTime(date)
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale))
    }
}
