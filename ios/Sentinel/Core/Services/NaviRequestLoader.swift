import CoreLocation
import Foundation
import MapKit
@preconcurrency import FerrostarCore

/// Netzwerkschicht des Navigationskerns. Sie
/// - meldet das Gerät beim eigenen Server an (Routen kommen von dort, nicht von Dritten),
/// - teilt dem Server mit, ob mit Sonderrechten gefahren wird (er wägt dann ab, ob sich der Regelbruch lohnt),
/// - legt ohne Sonderrechte Apples Weg mit aktueller Verkehrslage als Vorgabe fest: Valhalla kennt keine Staus,
///   Apple schon. Der Server rechnet dann genau diesen Weg und liefert die Abbiegehinweise dazu.
final class NaviRequestLoader: URLRequestLoading, @unchecked Sendable {
    private let token: String
    private let lock = NSLock()
    private var specialRights = false
    private var walking = false
    private var usedSpecialRights = false
    private var ratio: Double = 1

    init(token: String) {
        self.token = token
    }

    func configure(specialRights: Bool, walking: Bool) {
        lock.withLock {
            self.specialRights = specialRights
            self.walking = walking
        }
    }

    /// Wurde die zuletzt geladene Route mit Sonderrechten gerechnet?
    var lastRouteUsedSpecialRights: Bool { lock.withLock { usedSpecialRights } }

    /// Verhältnis der Fahrzeit mit Verkehrslage (Apple) zur Fahrzeit ohne (Valhalla), für eine ehrliche Ankunftszeit.
    var trafficRatio: Double { lock.withLock { ratio } }

    func loadData(with urlRequest: URLRequest) async throws -> (Data, URLResponse) {
        let (specialRights, walking) = lock.withLock { (self.specialRights, self.walking) }
        var request = urlRequest
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        guard let body = request.httpBody, var json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else {
            return try await send(request)
        }
        json["sentinel"] = ["sonderrechte": specialRights]
        if walking { json["costing"] = "pedestrian" }

        // Immer die direkt gerechnete Route; ohne Sonderrechte mit dem Auto zusätzlich Apples verkehrsabhängigen Weg
        // als Vorgabe. Beides läuft gleichzeitig.
        var plain = request
        plain.httpBody = try JSONSerialization.data(withJSONObject: json)
        async let direct = send(plain)
        var guide: TrafficGuide?
        if !specialRights, !walking, let locations = json["locations"] as? [[String: Any]], locations.count >= 2 {
            guide = await TrafficGuide.make(from: locations[0], to: locations[locations.count - 1])
        }
        let (data, response) = try await direct
        if let guide, !guide.vias.isEmpty, var locations = json["locations"] as? [[String: Any]] {
            locations.insert(contentsOf: guide.vias, at: 1)
            var guidedJSON = json
            guidedJSON["locations"] = locations
            var guided = request
            guided.httpBody = try JSONSerialization.data(withJSONObject: guidedJSON)
            if let result = try? await send(guided), Self.isPlausible(result.0, comparedTo: data, guide: guide) {
                record(result.1, data: result.0, guide: guide)
                return result
            }
        }
        record(response, data: data, guide: guide)
        return (data, response)
    }

    /// Die Route mit Apples Vorgabe gilt nur, wenn sie nicht spürbar länger ist als ohne Vorgabe und als Apples eigene
    /// Route. Ein Durchfahrtspunkt auf der falschen Fahrbahn führt sonst zu Schleifen und Wenden.
    static func isPlausible(_ guided: Data, comparedTo direct: Data, guide: TrafficGuide) -> Bool {
        guard let guidedDistance = distance(guided), let directDistance = distance(direct) else { return false }
        return guidedDistance <= directDistance * 1.15 + 200 && guidedDistance <= guide.distance * 1.15 + 200
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }

    private func record(_ response: URLResponse, data: Data, guide: TrafficGuide?) {
        let special = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "x-sentinel-sonderrechte") == "1"
        var nextRatio = 1.0
        if let guide, let duration = Self.duration(data), duration > 0 {
            // Nicht unter die Zeit ohne Verkehr gehen und Ausreißer begrenzen.
            nextRatio = min(max(guide.travelTime / duration, 1), 3)
        }
        lock.withLock {
            usedSpecialRights = special
            ratio = nextRatio
        }
    }

    private static func routeObject(_ data: Data) -> [String: Any]? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let routes = json["routes"] as? [[String: Any]] else { return nil }
        return routes.first
    }

    static func distance(_ data: Data) -> Double? { routeObject(data)?["distance"] as? Double }
    static func duration(_ data: Data) -> Double? { routeObject(data)?["duration"] as? Double }
}

/// Apples Route mit Verkehrslage als Folge von Durchfahrtspunkten für den eigenen Server.
struct TrafficGuide {
    var vias: [[String: Any]]
    var distance: CLLocationDistance
    var travelTime: TimeInterval

    /// Abstand der Durchfahrtspunkte; genug, um Apples Weg festzulegen, ohne den Server mit Punkten zu fluten.
    static let spacing: CLLocationDistance = 1200

    static func make(from start: [String: Any], to end: [String: Any]) async -> TrafficGuide? {
        guard let a = coordinate(start), let b = coordinate(end) else { return nil }
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: a.latitude, longitude: a.longitude), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: b.latitude, longitude: b.longitude), address: nil)
        request.transportType = .automobile
        request.departureDate = .now
        // Höchstens vier Sekunden warten; sonst ohne Vorgabe weiter.
        let route = await withTaskGroup(of: MKRoute?.self) { group in
            group.addTask { try? await MKDirections(request: request).calculate().routes.first }
            group.addTask {
                try? await Task.sleep(for: .seconds(4))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        guard let route else { return nil }
        return TrafficGuide(vias: vias(along: route.polyline), distance: route.distance, travelTime: route.expectedTravelTime)
    }

    private static func coordinate(_ location: [String: Any]) -> CLLocationCoordinate2D? {
        guard let lat = location["lat"] as? Double, let lon = location["lon"] as? Double else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Punkte in gleichmäßigem Abstand, jeweils mit Fahrtrichtung, damit der Server die richtige Richtungsfahrbahn wählt.
    static func vias(along polyline: MKPolyline) -> [[String: Any]] {
        let count = polyline.pointCount
        guard count > 2 else { return [] }
        let points = polyline.points()
        var coordinates: [CLLocationCoordinate2D] = []
        coordinates.reserveCapacity(count)
        for i in 0..<count { coordinates.append(points[i].coordinate) }

        var total: CLLocationDistance = 0
        for i in 1..<count { total += distance(coordinates[i - 1], coordinates[i]) }
        guard total > spacing * 1.5 else { return [] }

        var result: [[String: Any]] = []
        var travelled: CLLocationDistance = 0
        var nextMark = spacing
        for i in 1..<count {
            let segment = distance(coordinates[i - 1], coordinates[i])
            travelled += segment
            // Nicht zu nah an Start und Ziel, dort entscheidet ohnehin der Standort.
            guard travelled >= nextMark, total - travelled > 400 else { continue }
            nextMark = travelled + spacing
            result.append([
                "lat": coordinates[i].latitude,
                "lon": coordinates[i].longitude,
                "type": "through",
                "heading": Int(bearing(coordinates[i - 1], coordinates[i]).rounded()) % 360,
                "heading_tolerance": 60,
            ])
            if result.count >= 20 { break }
        }
        return result
    }

    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    static func bearing(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
