import CoreLocation
import Foundation

// Weg-Zeit-Flächen und Bestreifung.

/// Fortbewegungsarten der Weg-Zeit-Berechnung.
enum ReachMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case fuss, kfz, oepnv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fuss: "Zu Fuß"
        case .kfz: "Kfz"
        case .oepnv: "ÖPNV"
        }
    }

    var symbolName: String {
        switch self {
        case .fuss: "figure.walk"
        case .kfz: "car.fill"
        case .oepnv: "tram.fill"
        }
    }
}

struct ReachArea: Codable, Equatable, Sendable, Identifiable {
    var modus: ReachMode
    var quelle: String
    /// Geschlossene Ringe als [Breite, Länge].
    var ringe: [[[Double]]]

    var id: String { modus.rawValue }
    var isModel: Bool { quelle == "modell" }
}

struct CoverageTrack: Codable, Equatable, Sendable {
    var memberId: String
    /// [Breite, Länge, Zeit in ms]
    var punkte: [[Double]]
}
