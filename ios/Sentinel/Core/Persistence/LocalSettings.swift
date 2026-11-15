import Foundation
import Observation

/// Einstellungen, die nur dieses Gerät betreffen (keine Einsatzdaten).
@MainActor
@Observable
final class LocalSettings {
    static let defaultServer = "https://sentinel.ng-lab.de"

    private let defaults: UserDefaults

    var sharesLocation: Bool { didSet { defaults.set(sharesLocation, forKey: "position.teilen") } }
    var appLockEnabled: Bool { didSet { defaults.set(appLockEnabled, forKey: "app.sperre") } }
    /// Ausgeblendete Ebenen, um die Karte übersichtlich zu halten.
    var hiddenLayers: Set<String> { didSet { defaults.set(Array(hiddenLayers), forKey: "ebenen.ausgeblendet") } }
    var disabledReachModes: Set<String> { didSet { defaults.set(Array(disabledReachModes), forKey: "wegzeit.aus") } }
    var showsCoverage: Bool { didSet { defaults.set(showsCoverage, forKey: "bestreifung.anzeigen") } }
    var mapStyle: MapStyleChoice { didSet { defaults.set(mapStyle.rawValue, forKey: "karte.stil") } }
    var showsTraffic: Bool { didSet { defaults.set(showsTraffic, forKey: "karte.verkehr") } }
    /// Die Ebene "Dauerhafte Orte" ist gesperrt, bis sie bewusst entsperrt wird. Gilt nur bis zum Neustart der App.
    var permanentLayerUnlocked = false
    var lastReadMessageAt: Double { didSet { defaults.set(lastReadMessageAt, forKey: "chat.gelesen") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["position.teilen": true, "bestreifung.anzeigen": false, "karte.verkehr": true])
        sharesLocation = defaults.bool(forKey: "position.teilen")
        appLockEnabled = defaults.bool(forKey: "app.sperre")
        hiddenLayers = Set(defaults.stringArray(forKey: "ebenen.ausgeblendet") ?? [])
        disabledReachModes = Set(defaults.stringArray(forKey: "wegzeit.aus") ?? [])
        showsCoverage = defaults.bool(forKey: "bestreifung.anzeigen")
        mapStyle = MapStyleChoice(rawValue: defaults.string(forKey: "karte.stil") ?? "") ?? .standard
        showsTraffic = defaults.bool(forKey: "karte.verkehr")
        lastReadMessageAt = defaults.double(forKey: "chat.gelesen")
    }

    /// Darf eine Markierung auf dieser Ebene bearbeitet werden?
    func canEdit(layerId: String) -> Bool {
        layerId != Layer.dauerhaftId || permanentLayerUnlocked
    }

    func isReachEnabled(_ mode: ReachMode) -> Bool {
        !disabledReachModes.contains(mode.rawValue)
    }

    func toggleReach(_ mode: ReachMode) {
        if disabledReachModes.contains(mode.rawValue) {
            disabledReachModes.remove(mode.rawValue)
        } else {
            disabledReachModes.insert(mode.rawValue)
        }
    }
}

/// Kartendarstellung. 3D-Gelände und Gebäude sind in allen Stilen aktiv.
enum MapStyleChoice: String, CaseIterable, Identifiable {
    case standard, hybrid, satellit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Karte"
        case .hybrid: "Hybrid"
        case .satellit: "Satellit"
        }
    }

    var symbolName: String {
        switch self {
        case .standard: "map"
        case .hybrid: "map.fill"
        case .satellit: "globe.europe.africa.fill"
        }
    }
}
