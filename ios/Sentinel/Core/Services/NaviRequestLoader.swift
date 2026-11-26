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
    private var parallel: ParallelHint?
    private var avoided = false

    init(token: String) {
        self.token = token
    }

    func configure(specialRights: Bool, walking: Bool, parallel: ParallelHint? = nil) {
        lock.withLock {
            self.specialRights = specialRights
            self.walking = walking
            self.parallel = parallel
        }
    }

    /// Hat der Server die Straße des Ziels bei der zuletzt geladenen Route gemieden (Parallel-Modus)?
    var lastRouteAvoidedTargetStreet: Bool { lock.withLock { avoided } }

    /// Wurde die zuletzt geladene Route mit Sonderrechten gerechnet?
    var lastRouteUsedSpecialRights: Bool { lock.withLock { usedSpecialRights } }

    /// Verhältnis der Fahrzeit mit Verkehrslage (Apple) zur Fahrzeit ohne (Valhalla), für eine ehrliche Ankunftszeit.
    var trafficRatio: Double { lock.withLock { ratio } }

    func loadData(with urlRequest: URLRequest) async throws -> (Data, URLResponse) {
        let (specialRights, walking, parallel) = lock.withLock { (self.specialRights, self.walking, self.parallel) }
        var request = urlRequest
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        guard let body = request.httpBody, var json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else {
            return try await send(request)
        }
        var sentinel: [String: Any] = ["sonderrechte": specialRights]
        if let parallel {
            sentinel["parallel"] = ["lat": parallel.point.lat, "lon": parallel.point.lon, "kurs": parallel.heading, "meter": parallel.meters]
        }
        json["sentinel"] = sentinel
        if walking { json["costing"] = "pedestrian" }

        // Immer die direkt gerechnete Route; mit dem Auto zusätzlich Apples Weg mit Verkehrslage, Sperrungen und
        // Baustellen (Apple kennt sie, Valhalla nicht) als Vorgabe. Beides läuft gleichzeitig.
        var plain = request
        plain.httpBody = try JSONSerialization.data(withJSONObject: json)
        async let direct = send(plain)
        var guide: TrafficGuide?
        if !walking, parallel == nil, let locations = json["locations"] as? [[String: Any]], locations.count >= 2 {
            guide = await TrafficGuide.make(from: locations[0], to: locations[locations.count - 1])
        }
        let (data, response) = try await direct
        // Durchfahrtspunkte entlang Apples Weg, zusätzlich dicht dort, wo Apple von der direkten Route abweicht: Eine
        // kurze Umleitung um eine Baustelle läge sonst zwischen zwei weit auseinanderliegenden Punkten und Valhalla
        // führe wieder mitten hindurch.
        let vias = guide?.vias(avoiding: Self.coordinates(data)) ?? []
        if let guide, !vias.isEmpty, var locations = json["locations"] as? [[String: Any]] {
            locations.insert(contentsOf: vias, at: 1)
            var guidedJSON = json
            guidedJSON["locations"] = locations
            var guided = request
            guided.httpBody = try JSONSerialization.data(withJSONObject: guidedJSON)
            if let result = try? await send(guided), Self.isPlausible(result.0, comparedTo: data, guide: guide, specialRights: specialRights) {
                record(result.1, data: result.0, guide: guide)
                return result
            }
        }
        record(response, data: data, guide: guide)
        return (data, response)
    }

    /// Gilt die Route mit Apples Vorgabe?
    /// - Sie muss Apples eigenem Weg entsprechen (nicht spürbar länger), sonst ist ein Durchfahrtspunkt auf der falschen
    ///   Fahrbahn gelandet (Schleifen), und darf nicht öfter wenden als die direkte Route.
    /// - Ohne Sonderrechte: Ist sie länger als die direkte Route, gilt sie trotzdem, wenn Apple selbst einen Umweg
    ///   fährt: Dann umfährt Apple eine Sperrung, Baustelle oder einen Stau (vorher wurde genau das verworfen).
    /// - Mit Sonderrechten folgt die Route Apple nur bei deutlichem Umweg (dann ist vorn etwas gesperrt); sonst bleibt
    ///   die schnellere Route mit Sonderrechten.
    static func isPlausible(_ guided: Data, comparedTo direct: Data, guide: TrafficGuide, specialRights: Bool = false) -> Bool {
        guard let guidedDistance = distance(guided), let directDistance = distance(direct) else { return false }
        if uTurns(guided) > uTurns(direct) { return false }
        guard guidedDistance <= guide.distance * 1.10 + 120 else { return false }
        if specialRights { return guide.distance > directDistance * 1.35 + 300 }
        return guidedDistance <= directDistance * 1.10 + 120 || guide.distance >= directDistance * 1.05
    }

    /// Anzahl der Wendemanöver in einer Route (OSRM-Format: Richtung „uturn“).
    static func uTurns(_ data: Data) -> Int {
        guard let legs = routeObject(data)?["legs"] as? [[String: Any]] else { return 0 }
        return legs.reduce(0) { count, leg in
            let steps = leg["steps"] as? [[String: Any]] ?? []
            return count + steps.filter { step in
                let maneuver = step["maneuver"] as? [String: Any]
                return (maneuver?["modifier"] as? String) == "uturn" || ((maneuver?["type"] as? String)?.contains("uturn") ?? false)
            }.count
        }
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }

    private func record(_ response: URLResponse, data: Data, guide: TrafficGuide?) {
        let http = response as? HTTPURLResponse
        let special = http?.value(forHTTPHeaderField: "x-sentinel-sonderrechte") == "1"
        let avoidedStreet = http?.value(forHTTPHeaderField: "x-sentinel-parallel") == "1"
        var nextRatio = 1.0
        if let guide, let duration = Self.duration(data), duration > 0 {
            // Nicht unter die Zeit ohne Verkehr gehen und Ausreißer begrenzen.
            nextRatio = min(max(guide.travelTime / duration, 1), 3)
        }
        lock.withLock {
            usedSpecialRights = special
            avoided = avoidedStreet
            ratio = nextRatio
        }
    }

    private static func routeObject(_ data: Data) -> [String: Any]? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let routes = json["routes"] as? [[String: Any]] else { return nil }
        return routes.first
    }

    static func distance(_ data: Data) -> Double? { routeObject(data)?["distance"] as? Double }

    /// Linienzug der ersten Route (OSRM-Format: Polyline mit sechs Nachkommastellen oder GeoJSON).
    static func coordinates(_ data: Data) -> [CLLocationCoordinate2D] {
        guard let geometry = routeObject(data)?["geometry"] else { return [] }
        if let encoded = geometry as? String { return decodePolyline6(encoded) }
        if let json = geometry as? [String: Any], let points = json["coordinates"] as? [[Double]] {
            return points.compactMap { $0.count >= 2 ? CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) : nil }
        }
        return []
    }

    static func decodePolyline6(_ encoded: String) -> [CLLocationCoordinate2D] {
        let bytes = Array(encoded.utf8)
        var index = 0, lat = 0, lon = 0
        var result: [CLLocationCoordinate2D] = []
        func next() -> Int? {
            var value = 0, shift = 0
            while index < bytes.count {
                let byte = Int(bytes[index]) - 63
                index += 1
                value |= (byte & 0x1f) << shift
                shift += 5
                if byte < 0x20 { return (value & 1) != 0 ? ~(value >> 1) : value >> 1 }
            }
            return nil
        }
        while index < bytes.count {
            guard let dLat = next(), let dLon = next() else { break }
            lat += dLat
            lon += dLon
            result.append(CLLocationCoordinate2D(latitude: Double(lat) / 1e6, longitude: Double(lon) / 1e6))
        }
        return result
    }
    static func duration(_ data: Data) -> Double? { routeObject(data)?["duration"] as? Double }
}

/// Apples Route mit Verkehrslage als Folge von Durchfahrtspunkten für den eigenen Server.
struct TrafficGuide {
    /// Apples Weg.
    var path: [CLLocationCoordinate2D]
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
        return TrafficGuide(path: coordinates(of: route.polyline), distance: route.distance, travelTime: route.expectedTravelTime)
    }

    private static func coordinate(_ location: [String: Any]) -> CLLocationCoordinate2D? {
        guard let lat = location["lat"] as? Double, let lon = location["lon"] as? Double else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func vias(avoiding direct: [CLLocationCoordinate2D]) -> [[String: Any]] {
        Self.vias(along: path, avoiding: direct)
    }

    static func coordinates(of polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        let points = polyline.points()
        return (0..<polyline.pointCount).map { points[$0].coordinate }
    }

    static func vias(along polyline: MKPolyline) -> [[String: Any]] {
        vias(along: coordinates(of: polyline), avoiding: [])
    }

    /// Punkte in gleichmäßigem Abstand, jeweils mit Fahrtrichtung, damit der Server die richtige Richtungsfahrbahn wählt.
    /// Weicht Apples Weg von der direkten Route ab (mehr als 60 m entfernt), kommt in jede Abweichung ein eigener Punkt:
    /// So folgt die Route auch kurzen Umleitungen um Baustellen und Sperrungen.
    static func vias(along coordinates: [CLLocationCoordinate2D], avoiding direct: [CLLocationCoordinate2D]) -> [[String: Any]] {
        let count = coordinates.count
        guard count > 2 else { return [] }

        var along: [CLLocationDistance] = [0]
        for i in 1..<count { along.append(along[i - 1] + distance(coordinates[i - 1], coordinates[i])) }
        let total = along[count - 1]

        func via(_ i: Int) -> (at: CLLocationDistance, location: [String: Any]) {
            let from = coordinates[max(i - 1, 0)], to = coordinates[i == 0 ? 1 : i]
            return (along[i], [
                "lat": coordinates[i].latitude,
                "lon": coordinates[i].longitude,
                "type": "through",
                "heading": Int(bearing(from, to).rounded()) % 360,
                "heading_tolerance": 45,
                // Nur Straßen direkt am Punkt: sonst rastet er auf einer parallelen Neben- oder Sackgasse ein.
                "radius": 20,
            ])
        }

        // Abweichungen: zusammenhängende Abschnitte weit weg von der direkten Route, je ein Punkt in der Mitte.
        var detours: [(at: CLLocationDistance, location: [String: Any])] = []
        if direct.count > 1 {
            let directPoints = direct.map(MKMapPoint.init)
            var runStart: Int?
            for i in 0..<count {
                let off = Self.distance(from: MKMapPoint(coordinates[i]), to: directPoints) > 60
                if off, runStart == nil { runStart = i }
                if (!off || i == count - 1), let start = runStart {
                    let end = off ? i : i - 1
                    let middle = (start + end) / 2
                    if along[middle] > 30, total - along[middle] > 30 { detours.append(via(middle)) }
                    runStart = nil
                }
            }
        }

        // Gleichmäßige Punkte, nicht zu nah an Start, Ziel und den Abweichungspunkten.
        var regular: [(at: CLLocationDistance, location: [String: Any])] = []
        if total > spacing * 1.5 {
            var nextMark = spacing
            for i in 1..<count where along[i] >= nextMark && total - along[i] > 400 {
                nextMark = along[i] + spacing
                if detours.contains(where: { abs($0.at - along[i]) < 300 }) { continue }
                regular.append(via(i))
            }
        }
        // Höchstens 20 (der Server nimmt 25 Orte); Abweichungen gehen vor.
        let chosen = Array(detours.prefix(20)) + Array(regular.prefix(max(0, 20 - detours.count)))
        return chosen.sorted { $0.at < $1.at }.map(\.location)
    }

    /// Kürzester Abstand eines Punkts zu einem Linienzug in Metern.
    static func distance(from p: MKMapPoint, to line: [MKMapPoint]) -> CLLocationDistance {
        var best = CLLocationDistance.greatestFiniteMagnitude
        for i in 1..<line.count {
            let a = line[i - 1], b = line[i]
            let dx = b.x - a.x, dy = b.y - a.y
            let l2 = dx * dx + dy * dy
            let t = l2 > 0 ? min(max(((p.x - a.x) * dx + (p.y - a.y) * dy) / l2, 0), 1) : 0
            best = min(best, p.distance(to: MKMapPoint(x: a.x + dx * t, y: a.y + dy * t)))
        }
        return best
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

/// Parallel-Modus: Position und Fahrtrichtung des Ziels; der Server meidet seine Straße auf `meters` voraus.
struct ParallelHint: Equatable, Sendable {
    var point: GeoPoint
    var heading: Double
    var meters: Double
}
