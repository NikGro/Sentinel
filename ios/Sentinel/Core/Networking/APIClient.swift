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
        configuration.timeoutIntervalForRequest = 30
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

    private func request(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil, contentType: String = "application/json") async throws -> Data {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw APIError.invalidServer }
        var request = URLRequest(url: url)
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

    private func json<T: Decodable>(_ type: T.Type, _ method: String, _ path: String, query: [URLQueryItem] = []) async throws -> T {
        try JSONDecoder().decode(T.self, from: try await request(method, path, query: query))
    }

    private func json<T: Decodable, B: Encodable>(_ type: T.Type, _ method: String, _ path: String, query: [URLQueryItem] = [], body: B) async throws -> T {
        try JSONDecoder().decode(T.self, from: try await request(method, path, query: query, body: try JSONEncoder().encode(body)))
    }

    // MARK: Anmeldung

    struct Enrollment: Decodable {
        let deviceId: String
        let token: String
    }

    func enroll(code: String, deviceName: String) async throws -> Enrollment {
        try await json(Enrollment.self, "POST", "api/v1/enroll", body: ["code": code, "geraet": deviceName])
    }

    // MARK: Dateien

    struct UploadedBlob: Decodable {
        let id: String
        let mime: String
        let groesse: Int
    }

    func upload(_ data: Data, contentType: String) async throws -> UploadedBlob {
        try JSONDecoder().decode(UploadedBlob.self, from: try await request("POST", "api/v1/blobs", body: data, contentType: contentType))
    }

    func uploadImage(_ jpeg: Data) async throws -> String {
        try await upload(jpeg, contentType: "image/jpeg").id
    }

    func blob(id: String) async throws -> Data {
        try await request("GET", "api/v1/blobs/\(id)")
    }

    func image(id: String) async throws -> Data {
        try await blob(id: id)
    }

    // MARK: Bestreifung, Weg-Zeit, Routen

    private struct Coverage: Decodable {
        let tracks: [CoverageTrack]
    }

    func coverage() async throws -> [CoverageTrack] {
        try await json(Coverage.self, "GET", "api/v1/coverage").tracks
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
        try await json(ReachResponse.self, "POST", "api/v1/reach", body: ReachRequest(lat: origin.lat, lon: origin.lon, minuten: minutes, modi: modes)).flaechen
    }

    struct ServerRoute: Decodable {
        struct Step: Decodable {
            let text: String
            let meter: Double
            let index: Int?
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
        try await json(ServerRoute.self, "POST", "api/v1/route", body: RouteRequest(von: origin, nach: destination, sonderrechte: specialRights, zuFuss: walking))
    }

    // MARK: ÖPNV und Kreuzungen

    private struct LineSearch: Decodable {
        let linien: [LineHit]
        let verfuegbar: Bool
    }

    func lines(query: String, near: GeoPoint?) async throws -> (lines: [LineHit], available: Bool) {
        var items = [URLQueryItem(name: "q", value: query)]
        if let near {
            items.append(URLQueryItem(name: "lat", value: String(near.lat)))
            items.append(URLQueryItem(name: "lon", value: String(near.lon)))
        }
        let result = try await json(LineSearch.self, "GET", "api/v1/oepnv/linien", query: items)
        return (result.linien, result.verfuegbar)
    }

    func line(id: String) async throws -> TransitLine {
        try await json(TransitLine.self, "GET", "api/v1/oepnv/linien/\(id)")
    }

    private struct StopsNearby: Decodable {
        let haltestellen: [NearbyStop]
    }

    func stops(near point: GeoPoint, radius: Double) async throws -> [NearbyStop] {
        try await json(
            StopsNearby.self,
            "GET",
            "api/v1/oepnv/haltestellen",
            query: [
                URLQueryItem(name: "lat", value: String(point.lat)), URLQueryItem(name: "lon", value: String(point.lon)),
                URLQueryItem(name: "radius", value: String(Int(radius))),
            ]
        ).haltestellen
    }

    // MARK: Deutschlandweiter ÖPNV (Transitous über den eigenen Server)

    private struct LiveVehicles: Decodable {
        let fahrzeuge: [LiveSegment]
        let zuGross: Bool
    }

    private struct LiveStops: Decodable {
        let haltestellen: [LiveStop]
    }

    private struct Departures: Decodable {
        let abfahrten: [LiveDeparture]
    }

    private static func box(_ min: GeoPoint, _ max: GeoPoint) -> [URLQueryItem] {
        [
            URLQueryItem(name: "minLat", value: String(min.lat)), URLQueryItem(name: "minLon", value: String(min.lon)),
            URLQueryItem(name: "maxLat", value: String(max.lat)), URLQueryItem(name: "maxLon", value: String(max.lon)),
        ]
    }

    /// Fahrende Fahrzeuge im Ausschnitt; `tooLarge`, wenn der Ausschnitt zu groß ist.
    func liveVehicles(min: GeoPoint, max: GeoPoint, zoom: Int) async throws -> (segments: [LiveSegment], tooLarge: Bool) {
        let result = try await json(LiveVehicles.self, "GET", "api/v1/oepnv/live", query: Self.box(min, max) + [URLQueryItem(name: "zoom", value: String(zoom))])
        return (result.fahrzeuge, result.zuGross)
    }

    func liveStops(min: GeoPoint, max: GeoPoint) async throws -> [LiveStop] {
        try await json(LiveStops.self, "GET", "api/v1/oepnv/live/haltestellen", query: Self.box(min, max)).haltestellen
    }

    func trip(id: String) async throws -> TripDetail {
        try await json(TripDetail.self, "GET", "api/v1/oepnv/fahrt", query: [URLQueryItem(name: "id", value: id)])
    }

    private struct Plans: Decodable {
        let verbindungen: [TransitPlan]
    }

    func transitPlans(from: GeoPoint, to: GeoPoint) async throws -> [TransitPlan] {
        try await json(Plans.self, "GET", "api/v1/oepnv/verbindung", query: [
            URLQueryItem(name: "vonLat", value: String(from.lat)), URLQueryItem(name: "vonLon", value: String(from.lon)),
            URLQueryItem(name: "nachLat", value: String(to.lat)), URLQueryItem(name: "nachLon", value: String(to.lon)),
        ]).verbindungen
    }

    func departures(stopId: String) async throws -> [LiveDeparture] {
        try await json(Departures.self, "GET", "api/v1/oepnv/abfahrten", query: [URLQueryItem(name: "halt", value: stopId)]).abfahrten
    }

    /// Haltestellen nach Namen, mit den dort haltenden Linien.
    func searchStops(_ query: String, near: GeoPoint?) async throws -> [NearbyStop] {
        var items = [URLQueryItem(name: "q", value: query)]
        if let near {
            items.append(URLQueryItem(name: "lat", value: String(near.lat)))
            items.append(URLQueryItem(name: "lon", value: String(near.lon)))
        }
        return try await json(StopsNearby.self, "GET", "api/v1/oepnv/haltestellen/suche", query: items).haltestellen
    }

    /// Kreuzung zweier Straßen: Kreuzungspunkte und die tatsächlichen Straßennamen. Bei Tipp- oder Hörfehlern
    /// („Hegbark“) ordnet der Server der ähnlichsten Straße der Umgebung zu und nennt den richtigen Namen („Heegbarg“).
    struct Crossing: Decodable {
        let punkte: [GeoPoint]
        let a: String?
        let b: String?
    }

    func intersection(_ a: String, _ b: String, near: GeoPoint) async throws -> Crossing {
        try await json(
            Crossing.self,
            "GET",
            "api/v1/kreuzung",
            query: [
                URLQueryItem(name: "a", value: a), URLQueryItem(name: "b", value: b),
                URLQueryItem(name: "lat", value: String(near.lat)), URLQueryItem(name: "lon", value: String(near.lon)),
            ]
        )
    }

    // MARK: Verwaltung (auch in der App verfügbar)

    struct AdminStatus: Decodable {
        struct Device: Decodable, Identifiable {
            let id: String
            let name: String
            let lastSeen: Double
            let revoked: Bool
        }

        struct UnknownTracker: Decodable, Identifiable {
            let kennung: String
            let zuletzt: Double
            var id: String { kennung }
        }

        struct Trackers: Decodable {
            struct Paj: Decodable {
                let aktiv: Bool
                let fehler: String?
            }

            let h02Port: Int
            let unbekannt: [UnknownTracker]
            let paj: Paj
        }

        struct ArgusProject: Decodable, Identifiable, Hashable {
            let name: String
            let tage: [String]
            var id: String { name }
        }

        struct Argus: Decodable {
            let verfuegbar: Bool
            let projekte: [ArgusProject]
        }

        struct Oepnv: Decodable {
            let linien: Int
            let stand: Double?
            let fehler: String?
        }

        struct Release: Decodable {
            let version: String
            let build: String
        }

        let zugangscode: String
        let geraete: [Device]
        let tracker: Trackers
        let argus: Argus
        let routing: Bool
        let oepnv: Oepnv?
        let release: Release?
        let sidestoreQuelle: String
    }

    func adminStatus() async throws -> AdminStatus {
        try await json(AdminStatus.self, "GET", "api/v1/admin/status")
    }

    private struct JoinCode: Decodable {
        let zugangscode: String
    }

    func rotateJoinCode() async throws -> String {
        try await json(JoinCode.self, "POST", "api/v1/admin/zugangscode").zugangscode
    }

    func revokeDevice(_ id: String) async throws {
        _ = try await request("POST", "api/v1/admin/geraete/\(id)/sperren")
    }

    func configurePaj(email: String, password: String) async throws {
        _ = try await request("PUT", "api/v1/admin/paj", body: try JSONEncoder().encode(["email": email, "passwort": password]))
    }

    func removePaj() async throws {
        _ = try await request("DELETE", "api/v1/admin/paj")
    }

    private struct SpeedLimit: Decodable { let kmh: Int? }

    /// Tempolimit der Straße an einem Ort (OpenStreetMap über den eigenen Server); `nil` unbekannt oder unbegrenzt.
    func speedLimit(at point: GeoPoint) async throws -> Int? {
        try await json(SpeedLimit.self, "GET", "api/v1/tempolimit", query: [
            URLQueryItem(name: "lat", value: String(point.lat)), URLQueryItem(name: "lon", value: String(point.lon)),
        ]).kmh
    }

    private struct CrossStreetsRequest: Encodable { let punkte: [GeoPoint] }
    private struct CrossStreetsResult: Decodable { let strassen: [CrossStreet] }

    /// Querstraßen entlang einer Route (OpenStreetMap über den eigenen Server).
    func crossStreets(along points: [GeoPoint]) async throws -> [CrossStreet] {
        try await json(CrossStreetsResult.self, "POST", "api/v1/route/querstrassen", body: CrossStreetsRequest(punkte: points)).strassen
    }

    private struct PajTrackerRequest: Encodable {
        let id: String
        let name: String
        let kennung: String
        let email: String
        let passwort: String
    }

    private struct PajTrackerResult: Decodable {}

    /// Legt einen PAJ-Tracker mit eigenem Konto an; der Server prüft vorher, ob das Gerät zum Konto gehört.
    func addPajTracker(id: String, name: String, kennung: String, email: String, password: String) async throws {
        _ = try await json(PajTrackerResult.self, "POST", "api/v1/trackers/paj", body: PajTrackerRequest(id: id, name: name, kennung: kennung, email: email, passwort: password))
    }

    struct PajDevice: Decodable, Identifiable {
        let kennung: String
        let name: String
        var id: String { kennung }
    }

    private struct PajDevices: Decodable {
        let geraete: [PajDevice]
    }

    func pajDevices() async throws -> [PajDevice] {
        try await json(PajDevices.self, "GET", "api/v1/admin/paj/geraete").geraete
    }

    private struct ArgusRequest: Encodable {
        let projekt: String
        let datum: String
        let vonStunde: Int
        let bisStunde: Int
        let top: Int
        let alsEntwurf: Bool
    }

    private struct ArgusResult: Decodable {
        let zellen: Int
    }

    func importArgus(project: String, day: String, fromHour: Int, toHour: Int, top: Int, asDraft: Bool) async throws -> Int {
        try await json(ArgusResult.self, "POST", "api/v1/admin/argus/import", body: ArgusRequest(projekt: project, datum: day, vonStunde: fromHour, bisStunde: toHour, top: top, alsEntwurf: asDraft)).zellen
    }
}
