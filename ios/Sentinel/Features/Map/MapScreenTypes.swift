import MapKit
import SwiftUI

// Zustände und Werte der Lagekarte, die mehrere Bausteine teilen.

/// Was auf der Karte angetippt wurde und als Kurzübersicht erscheint.
enum MapSelection: Identifiable, Hashable {
    case member(String)
    case vehicle(String)
    case target(String)
    /// Angetippte Fläche ohne eigenen Griff, z. B. eine Argus-Prognosezelle.
    case object(String)

    var id: String {
        switch self {
        case .member(let id): "member-\(id)"
        case .vehicle(let id): "vehicle-\(id)"
        case .target(let id): "target-\(id)"
        case .object(let id): "object-\(id)"
        }
    }
}

/// Was ein Tipp auf die Karte gerade bewirkt.
enum MapTapMode: Equatable {
    case none
    case drawing(MapObject.Shape, points: [GeoPoint])
    case moving(objectId: String)
    /// Neues Ziel (Person, Fahrzeug, Objekt) an der getippten Stelle anlegen.
    case newTarget(ZielArt)
    /// Standort eines bestehenden Ziels neu setzen.
    case placingTarget(String)

    /// Einzelner Ort: erst als Vorschau zeigen, dann bestätigen.
    var needsConfirmation: Bool {
        switch self {
        case .none: false
        case .drawing(let shape, _): !shape.isMultiPoint
        case .moving, .newTarget, .placingTarget: true
        }
    }

    var hint: String? {
        switch self {
        case .none: nil
        case .drawing(let shape, let points):
            shape.isMultiPoint ? "\(shape.title): Punkte antippen (\(points.count) gesetzt)" : "\(shape.title): Ort antippen"
        case .moving: "Neuen Ort antippen"
        case .newTarget(let art): "\(art.title): Standort antippen"
        case .placingTarget: "Neuen Standort des Ziels antippen"
        }
    }
}

/// Was sich an einem Ort (z. B. einem Suchtreffer) direkt anlegen lässt.
enum PlaceableKind: Hashable, Identifiable {
    case shape(MapObject.Shape)
    case target(ZielArt)

    static let all: [PlaceableKind] = [
        .shape(.marker), .shape(.text), .shape(.kreis), .shape(.fahndungsraum), .shape(.haltestellen), .shape(.oepnvlinie), .shape(.oepnvfahrzeug),
        .target(.person), .target(.fahrzeug), .target(.objekt),
    ]

    var id: String {
        switch self {
        case .shape(let shape): "shape-\(shape.rawValue)"
        case .target(let art): "target-\(art.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .shape(.haltestellen): "Haltestellen im Umkreis"
        case .shape(let shape): shape.title
        case .target(let art): art.title
        }
    }
}

struct SearchPin: Equatable {
    let point: GeoPoint
    let title: String
}

struct EditorContext: Identifiable {
    let id: String
    let object: MapObject
    let isNew: Bool
}

/// Wie die Karte am eigenen Standort hängt. `nil` heißt frei: Die Karte bleibt, wie man sie hinschiebt und dreht.
enum CameraPin: Equatable {
    /// In Fahrt- bzw. Blickrichtung, nah und flach wie in einer Navi-App.
    case heading
    /// Norden oben, senkrecht von oben.
    case north

    var distance: CLLocationDistance { self == .heading ? 550 : 1500 }
    var pitch: Double { self == .heading ? 40 : 0 }

    /// Navigation: etwas höher als beim Anheften für mehr Überblick, gekippt wie in üblichen Navis.
    static let navigationDistance: CLLocationDistance = 1500
    static let navigationPitch: Double = 45
}

/// Letzter Tipp auf Formen bzw. Verläufe: zum Durchschalten übereinanderliegender Linien.
struct ShapeTap {
    let point: CGPoint
    let keys: [String]
    let index: Int
    let at: Date
}

/// Höhe der Kurzübersicht nach einem Tipp auf eine Strecke (etwa ein Drittel des Bildschirms).
enum QuickLookHeight {
    static let lowFraction: CGFloat = 0.3
    static let low = PresentationDetent.fraction(lowFraction)
}

/// Wo die Routenlinie beginnt: unter dem eigenen Punkt, mehrmals je Sekunde nachgeführt. Eigenes Objekt, damit nur
/// die Routenlinie neu gezeichnet wird, nicht der ganze Kartenbildschirm.
@MainActor
@Observable
final class RouteAnchor {
    var coordinate: CLLocationCoordinate2D?
    /// So viele Meter vor dem eigenen Punkt beginnt die Linie (etwa halbe Pfeillänge): Sie läuft vorne in den
    /// Navi-Pfeil hinein, hinten in seiner Kerbe steht nichts über.
    var lead: CLLocationDistance = 0
}

/// Letzte verlässliche Fahrtrichtung (im Auto bleibt sie an der Ampel stehen, statt dem Kompass zu folgen).
@MainActor
final class CourseMemory {
    var course: CLLocationDirection?
}
