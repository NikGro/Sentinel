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
    var showsCoverage: Bool { didSet { defaults.set(showsCoverage, forKey: "bestreifung.zeigen") } }
    var mapStyleIsSatellite: Bool { didSet { defaults.set(mapStyleIsSatellite, forKey: "karte.satellit") } }
    var lastReadMessageAt: Double { didSet { defaults.set(lastReadMessageAt, forKey: "chat.gelesen") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["position.teilen": true, "bestreifung.zeigen": true])
        sharesLocation = defaults.bool(forKey: "position.teilen")
        appLockEnabled = defaults.bool(forKey: "app.sperre")
        hiddenLayers = Set(defaults.stringArray(forKey: "ebenen.ausgeblendet") ?? [])
        disabledReachModes = Set(defaults.stringArray(forKey: "wegzeit.aus") ?? [])
        showsCoverage = defaults.bool(forKey: "bestreifung.zeigen")
        mapStyleIsSatellite = defaults.bool(forKey: "karte.satellit")
        lastReadMessageAt = defaults.double(forKey: "chat.gelesen")
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
