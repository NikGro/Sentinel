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

    func update(query: String, near region: MKCoordinateRegion?) {
        failure = nil
        if let region { completer.region = region }
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
        completer.resultTypes = [.address, .pointOfInterest]
        let normalized = Self.normalizedAddress(query)
        if normalized.count >= 2 {
            completer.queryFragment = normalized
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
        let text = suggestion?.title ?? query
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
            if let near { request.region = MKCoordinateRegion(center: near.coordinate, latitudinalMeters: 40_000, longitudinalMeters: 40_000) }
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
