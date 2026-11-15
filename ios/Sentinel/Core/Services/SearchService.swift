import MapKit
import Observation

/// Freie Ortssuche über Apple Karten mit Autovervollständigung.
///
/// - Hausnummer zuerst wird verstanden: "12 Musterstraße" sucht nach "Musterstraße 12".
/// - Kreuzungen mit "&" oder "/": "Mönckebergstraße / Steinstraße". Beide Straßennamen werden einzeln vervollständigt,
///   den Kreuzungspunkt ermittelt der Sentinel-Server aus den Kartendaten.
@MainActor
@Observable
final class SearchService: NSObject, MKLocalSearchCompleterDelegate {
    struct Suggestion: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String
        fileprivate let completion: MKLocalSearchCompletion?
        /// Bei „Hausnummer zuerst“: Suchtext für die Auflösung, z. B. "Hegpark 3, Hamburg".
        fileprivate var query: String?
    }

    struct Place: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String
        let point: GeoPoint
    }

    private(set) var suggestions: [Suggestion] = []
    private(set) var isSearching = false
    var failure: String?

    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private var intersectionPrefix: String?
    /// Hausnummer, die vorn eingegeben wurde und an die vervollständigte Straße angehängt wird.
    @ObservationIgnored private var leadingHouseNumber: String?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Teilt eine Eingabe an "&" oder "/" in zwei Straßennamen.
    nonisolated static func intersectionParts(_ text: String) -> (String, String)? {
        guard let separator = text.firstIndex(where: { $0 == "&" || $0 == "/" }) else { return nil }
        let a = text[..<separator].trimmingCharacters(in: .whitespaces)
        let b = text[text.index(after: separator)...].trimmingCharacters(in: .whitespaces)
        return a.isEmpty ? nil : (a, b)
    }

    /// "12 Musterstraße" wird zu "Musterstraße 12"; andere Eingaben bleiben unverändert.
    nonisolated static func normalizedAddress(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let match = trimmed.wholeMatch(of: #/(\d+\s?[a-zA-Z]?)\s+(\D.*)/#) else { return trimmed }
        return "\(match.2) \(match.1)"
    }

    /// Bevorzugtes Suchgebiet ohne eigenen Standort: Hamburg und Umland.
    private static let fallbackRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 53.57, longitude: 10.0),
        latitudinalMeters: 60_000, longitudinalMeters: 80_000
    )

    /// Trennt "3 Heg" in Hausnummer und Straßenanfang.
    nonisolated static func leadingNumber(_ text: String) -> (number: String, street: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let match = trimmed.wholeMatch(of: #/(\d+\s?[a-zA-Z]?)\s+(\D.*)/#) else { return nil }
        return (String(match.1).replacingOccurrences(of: " ", with: ""), String(match.2))
    }

    func update(query: String, near region: MKCoordinateRegion?) {
        failure = nil
        // Vorschläge nur aus der Nähe: Wer „Heg“ tippt, meint den Hegpark um die Ecke, nicht einen Ort weit weg.
        completer.region = region ?? Self.fallbackRegion
        completer.regionPriority = .required
        if let (a, b) = Self.intersectionParts(query) {
            // Zweiten Straßennamen vervollständigen, den ersten voranstellen.
            intersectionPrefix = a
            completer.resultTypes = .address
            if b.count >= 2 {
                completer.queryFragment = b
            } else {
                suggestions = []
            }
            return
        }
        intersectionPrefix = nil
        if let (number, street) = Self.leadingNumber(query) {
            // Hausnummer vorn: nur die Straße vervollständigen und die Nummer wieder anhängen.
            leadingHouseNumber = number
            completer.resultTypes = .address
            if street.count >= 2 { completer.queryFragment = street } else { suggestions = [] }
            return
        }
        leadingHouseNumber = nil
        completer.resultTypes = [.address, .pointOfInterest]
        if query.trimmingCharacters(in: .whitespaces).count >= 2 {
            completer.queryFragment = query
        } else {
            suggestions = []
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            if let prefix = self.intersectionPrefix {
                // Für Kreuzungen nur den Straßennamen ohne Ort übernehmen.
                var seen = Set<String>()
                self.suggestions = results.compactMap { result in
                    let street = result.title.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? result.title
                    guard seen.insert(street).inserted else { return nil }
                    return Suggestion(title: "\(prefix) / \(street)", subtitle: "Kreuzung", completion: nil)
                }
            } else if let number = self.leadingHouseNumber {
                var seen = Set<String>()
                self.suggestions = results.compactMap { result in
                    let street = result.title.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? result.title
                    // Bereits mit Nummer vervollständigte Treffer nicht doppelt ergänzen.
                    let base = street.replacing(#/\s+\d+\s?[a-zA-Z]?$/#, with: "")
                    let city = result.subtitle.components(separatedBy: ",").last?.trimmingCharacters(in: .whitespaces) ?? ""
                    guard seen.insert("\(base)|\(city)").inserted else { return nil }
                    var suggestion = Suggestion(title: "\(base) \(number)", subtitle: result.subtitle, completion: nil)
                    suggestion.query = [base + " " + number, city].filter { !$0.isEmpty }.joined(separator: ", ")
                    return suggestion
                }.prefix(10).map { $0 }
            } else {
                self.suggestions = results.prefix(12).map { Suggestion(title: $0.title, subtitle: $0.subtitle, completion: $0) }
            }
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.suggestions = [] }
    }

    /// Löst einen Vorschlag oder eine freie Eingabe in Orte auf.
    func resolve(_ suggestion: Suggestion?, query: String, near: GeoPoint?, client: APIClient?) async -> [Place] {
        isSearching = true
        defer { isSearching = false }
        let text = suggestion?.query ?? suggestion?.title ?? query
        if let (a, b) = Self.intersectionParts(text), !b.isEmpty {
            guard let client, let near else {
                failure = "Für die Kreuzungssuche wird der eigene Standort benötigt."
                return []
            }
            do {
                let points = try await client.intersections(a, b, near: near)
                if points.isEmpty { failure = "Keine Kreuzung von \(a) und \(b) in der Nähe gefunden." }
                return points.enumerated().map { index, point in
                    Place(title: "\(a) / \(b)", subtitle: points.count > 1 ? "Kreuzungspunkt \(index + 1)" : "Kreuzung", point: point)
                }
            } catch {
                failure = error.localizedDescription
                return []
            }
        }
        let request: MKLocalSearch.Request
        if let completion = suggestion?.completion {
            request = MKLocalSearch.Request(completion: completion)
        } else {
            request = MKLocalSearch.Request()
            request.naturalLanguageQuery = Self.normalizedAddress(text)
            request.region = near.map { MKCoordinateRegion(center: $0.coordinate, latitudinalMeters: 40_000, longitudinalMeters: 40_000) } ?? Self.fallbackRegion
            request.regionPriority = .required
        }
        do {
            let response = try await MKLocalSearch(request: request).start()
            let places = response.mapItems.map { item in
                Place(
                    title: item.name ?? text,
                    subtitle: [item.placemark.thoroughfare, item.placemark.subThoroughfare, item.placemark.locality].compactMap { $0 }.joined(separator: " "),
                    point: GeoPoint(item.placemark.coordinate)
                )
            }
            if places.isEmpty { failure = "Nichts gefunden." }
            return places
        } catch {
            failure = "Nichts gefunden."
            return []
        }
    }
}
