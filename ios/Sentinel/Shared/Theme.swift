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

    static let aPosition = Color.red
    static let target = Color(hex: "#FF375F")
    static let coverage = Color(hex: "#FF9F0A")

    static func color(for mode: ReachMode) -> Color {
        switch mode {
        case .fuss: .green
        case .kfz: .red
        case .oepnv: .blue
        }
    }

    static func color(for modus: Modus) -> Color {
        switch modus {
        case .observation: .red
        case .fahndung: .orange
        case .oberflaeche: .blue
        }
    }
}

enum Format {
    static func distance(_ meters: Double) -> String {
        Measurement(value: meters, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "vor 3 Min." bzw. "gerade eben".
    static func ago(_ date: Date, now: Date = .now) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 20 { return "gerade eben" }
        if seconds < 90 { return "vor 1 Min." }
        if seconds < 3600 { return "vor \(Int(seconds / 60)) Min." }
        if seconds < 86_400 { return "vor \(Int(seconds / 3600)) Std." }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
