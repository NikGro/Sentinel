import Foundation

enum APIError: LocalizedError {
    case invalidServer
    case server(status: Int, message: String)
    case unauthorized
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidServer: "Die Serveradresse ist ungültig. Es werden nur verschlüsselte Verbindungen (https) akzeptiert."
        case .server(_, let message): message
        case .unauthorized: "Dieses Gerät ist nicht mehr angemeldet."
        case .transport(let message): "Server nicht erreichbar: \(message)"
        }
    }
}

/// HTTP-Zugriff auf den Sentinel-Server. Ohne Zwischenspeicher auf der Platte, ohne Cookies.
struct APIClient: Sendable {
    let baseURL: URL
    let token: String?

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 20
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    /// Prüft und vereinheitlicht eine eingegebene Serveradresse. Unverschlüsselte Adressen werden abgelehnt.
    static func normalizedServerURL(_ input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.contains("://") { text = "https://" + text }
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text), url.scheme == "https", let host = url.host(), !host.isEmpty else { return nil }
        return url
    }

    private struct Failure: Decodable {
        let fehler: String
    }

    private func request(_ method: String, _ path: String, body: Data? = nil, contentType: String = "application/json") async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.httpBody = body
        if body != nil { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport("Unerwartete Antwort") }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401, token != nil { throw APIError.unauthorized }
            let message = (try? JSONDecoder().decode(Failure.self, from: data))?.fehler ?? "Fehler \(http.statusCode)"
            throw APIError.server(status: http.statusCode, message: message)
        }
        return data
    }

    // MARK: Anmeldung

    struct Enrollment: Decodable {
        let deviceId: String
        let token: String
    }

    func enroll(code: String, deviceName: String) async throws -> Enrollment {
        let body = try JSONEncoder().encode(["code": code, "geraet": deviceName])
        return try JSONDecoder().decode(Enrollment.self, from: try await request("POST", "api/v1/enroll", body: body))
    }

    // MARK: Bilder

    private struct BlobID: Decodable {
        let id: String
    }

    func uploadImage(_ jpeg: Data) async throws -> String {
        try JSONDecoder().decode(BlobID.self, from: try await request("POST", "api/v1/blobs", body: jpeg, contentType: "image/jpeg")).id
    }

    func image(id: String) async throws -> Data {
        try await request("GET", "api/v1/blobs/\(id)")
    }

    // MARK: Fahndung

    private struct Coverage: Decodable {
        let tracks: [CoverageTrack]
    }

    func coverage() async throws -> [CoverageTrack] {
        try JSONDecoder().decode(Coverage.self, from: try await request("GET", "api/v1/coverage")).tracks
    }

    private struct ReachRequest: Encodable {
        let lat: Double
        let lon: Double
        let minuten: Double
        let modi: [ReachMode]
    }

    private struct ReachResponse: Decodable {
        let flaechen: [ReachArea]
    }

    func reach(from origin: GeoPoint, minutes: Double, modes: [ReachMode]) async throws -> [ReachArea] {
        let body = try JSONEncoder().encode(ReachRequest(lat: origin.lat, lon: origin.lon, minuten: minutes, modi: modes))
        return try JSONDecoder().decode(ReachResponse.self, from: try await request("POST", "api/v1/reach", body: body)).flaechen
    }

    // MARK: Routen auf dem eigenen Wegenetz

    struct ServerRoute: Decodable {
        struct Step: Decodable {
            let text: String
            let meter: Double
        }

        /// Linienzug als [Breite, Länge].
        let punkte: [[Double]]
        let meter: Double
        let sekunden: Double
        let anweisungen: [Step]
        let sonderrechte: Bool
    }

    private struct RouteRequest: Encodable {
        let von: GeoPoint
        let nach: GeoPoint
        let sonderrechte: Bool
        let zuFuss: Bool
    }

    func route(from origin: GeoPoint, to destination: GeoPoint, specialRights: Bool, walking: Bool) async throws -> ServerRoute {
        let body = try JSONEncoder().encode(RouteRequest(von: origin, nach: destination, sonderrechte: specialRights, zuFuss: walking))
        return try JSONDecoder().decode(ServerRoute.self, from: try await request("POST", "api/v1/route", body: body))
    }
}
