import Foundation

/// Anmeldung dieses Geräts am Sentinel-Server.
struct Credentials: Equatable, Sendable {
    var serverURL: URL
    var deviceId: String
    var token: String

    private static let tokenKey = "geraete-token"
    private static let deviceKey = "geraete-id"
    private static let serverKey = "server-url"

    /// Das Token liegt nur im Schlüsselbund, nie in den Einstellungen oder in Dateien.
    static func load() -> Credentials? {
        guard
            let token = Keychain.get(tokenKey),
            let deviceId = Keychain.get(deviceKey),
            let server = Keychain.get(serverKey).flatMap(URL.init(string:))
        else { return nil }
        return Credentials(serverURL: server, deviceId: deviceId, token: token)
    }

    func save() {
        Keychain.set(token, for: Self.tokenKey)
        Keychain.set(deviceId, for: Self.deviceKey)
        Keychain.set(serverURL.absoluteString, for: Self.serverKey)
    }

    static func clear() {
        [tokenKey, deviceKey, serverKey].forEach(Keychain.remove)
    }
}
