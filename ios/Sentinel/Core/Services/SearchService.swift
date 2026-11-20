import MapKit
import Observation

/// Freie Ortssuche über Apple Karten mit Autovervollständigung.
///
/// - Hausnummer zuerst wird verstanden: "12 Musterstraße" sucht nach "Musterstraße 12".
/// - Kreuzungen mit „/“, „&“, „Ecke“, „x“ oder „und“: „Heegbarg Ecke Wentzelplatz“. Den Kreuzungspunkt ermittelt der
///   Sentinel-Server aus den Kartendaten und verzeiht dabei Tipp- und Hörfehler („Hegbark“).
/// - Reihenfolge: Straßen und Adressen zuerst, dann Örtlichkeiten, dann Haltestellen.
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
        /// Bereits geprüfter Ort (Kreuzung oder Hausnummer): wird direkt übernommen.
        fileprivate var point: GeoPoint?
    }

    struct Place: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String
        let point: GeoPoint
        /// Stimmen Straße und Hausnummer mit der Eingabe überein? Nur dann startet die Navigation ohne Rückfrage.
        var matchesQuery = true
    }

    /// Zerlegt "Hegbarg 1" bzw. "Hegbarg 1, Hamburg" in Straße und Hausnummer; ohne Hausnummer `nil`.
    nonisolated static func streetAndNumber(_ text: String) -> (street: String, number: String)? {
        let first = text.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? text
        guard let match = first.wholeMatch(of: #/(.+?)\s+(\d+\s?[a-zA-Z]?)/#) else { return nil }
        return (String(match.1), String(match.2).replacingOccurrences(of: " ", with: "").lowercased())
    }

    /// Vergleichbare Schreibweise eines Straßennamens: "Musterstr." und "Musterstraße" gelten als gleich.
    nonisolated static func normalizedStreet(_ name: String) -> String {
        var value = name.lowercased().replacingOccurrences(of: "ß", with: "ss")
        value = value.replacing(#/str\.?$/#, with: "strasse")
        return value.filter { $0.isLetter || $0.isNumber }
    }

    /// Anschriften: Straßen, Hausnummern, Kreuzungen.
    private(set) var suggestions: [Suggestion] = []
    /// Örtlichkeiten: Geschäfte, Behörden, Plätze.
    private(set) var placeSuggestions: [Suggestion] = []
    private(set) var isSearching = false
    /// Vorschläge werden gerade auf Existenz geprüft (Kreuzung, Hausnummer).
    private(set) var isValidating = false
    var failure: String?
    /// Für die Prüfung von Kreuzungen über den Server und als Bezugspunkt.
    @ObservationIgnored var client: APIClient?
    @ObservationIgnored var near: GeoPoint?
    @ObservationIgnored private var validation: Task<Void, Never>?

    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    /// Örtlichkeiten (Geschäfte, Behörden, Plätze) getrennt, damit Straßen immer vorn stehen.
    @ObservationIgnored private let placeCompleter = MKLocalSearchCompleter()
    @ObservationIgnored private var addressResults: [Suggestion] = []
    @ObservationIgnored private var placeResults: [Suggestion] = []
    @ObservationIgnored private var intersectionPrefix: String?
    /// Bei Kreuzungen: zweiter Straßenname, wie eingegeben.
    @ObservationIgnored private var typedSecondStreet = ""
    /// Hausnummer, die vorn eingegeben wurde und an die vervollständigte Straße angehängt wird.
    @ObservationIgnored private var leadingHouseNumber: String?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        placeCompleter.delegate = self
        placeCompleter.resultTypes = .pointOfInterest
    }

    /// Teilt eine Kreuzung in zwei Straßennamen: „A / B“, „A & B“, „A Ecke B“, „A x B“, „A und B“, „Kreuzung A B“
    /// geht nicht (zu mehrdeutig). Hausnummern („Musterstraße 12“) sind keine Kreuzung.
    nonisolated static func intersectionParts(_ text: String) -> (String, String)? {
        let separators = [#/\s*[\/&]\s*/#, #/\s+(?i:ecke|x|und|u\.)\s+/#]
        for separator in separators {
            if let match = text.firstMatch(of: separator) {
                let a = text[..<match.range.lowerBound].trimmingCharacters(in: .whitespaces)
                let b = text[match.range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !a.isEmpty { return (a, b) }
            }
        }
        // Am Ende getippt: „Heegbarg Ecke“ – die zweite Straße kommt noch.
        if let match = text.firstMatch(of: #/\s+(?i:ecke)\s*$/#) {
            let a = text[..<match.range.lowerBound].trimmingCharacters(in: .whitespaces)
            if !a.isEmpty { return (a, "") }
        }
        return nil
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
            // Kreuzung: Querstraßen der ersten Straße einmal vom Server holen, die zweite filtert nur noch lokal.
            intersectionPrefix = a
            typedSecondStreet = b
            placeSuggestions = []
            // Eine andere Straße als bisher: laufende Abfrage abbrechen; dieselbe Straße lädt einfach weiter.
            if crossingRequest != nil, crossingRequest != a.lowercased() {
                validation?.cancel()
                crossingRequest = nil
            }
            showCrossings(of: a)
            return
        }
        validation?.cancel()
        isValidating = false
        intersectionPrefix = nil
        crossingRequest = nil
        placeSuggestions = []
        placeResults = []
        if let (number, street) = Self.leadingNumber(query) {
            // Hausnummer vorn: nur die Straße vervollständigen und die Nummer wieder anhängen.
            leadingHouseNumber = number
            completer.resultTypes = .address
            if street.count >= 2 { completer.queryFragment = street } else { suggestions = [] }
            return
        }
        leadingHouseNumber = nil
        completer.resultTypes = .address
        placeCompleter.region = completer.region
        placeCompleter.regionPriority = .required
        if query.trimmingCharacters(in: .whitespaces).count >= 2 {
            completer.queryFragment = query
            placeCompleter.queryFragment = query
        } else {
            suggestions = []
            addressResults = []
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        let isPlaces = completer === placeCompleter
        Task { @MainActor in
            if isPlaces {
                // Örtlichkeiten (Geschäfte, Behörden, Plätze) in einem eigenen Bereich; nur im freien Suchmodus.
                guard self.intersectionPrefix == nil, self.leadingHouseNumber == nil else { return }
                self.placeResults = results.prefix(8).map { Suggestion(title: $0.title, subtitle: $0.subtitle, completion: $0) }
                self.mergeSuggestions()
                return
            }
            // Kreuzungen kommen aus der Querstraßen-Liste des Servers, nicht aus der Vervollständigung.
            if self.intersectionPrefix != nil { return }
            if let number = self.leadingHouseNumber {
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
                // Nur Straßen, in denen es diese Hausnummer wirklich gibt.
                let candidates = self.suggestions
                self.suggestions = []
                self.validate { _, near in
                    var kept: [Suggestion] = []
                    for var suggestion in candidates.prefix(5) {
                        if Task.isCancelled { return kept }
                        let text = suggestion.query ?? suggestion.title
                        let region = near.map { CLCircularRegion(center: $0.coordinate, radius: 50_000, identifier: "umkreis") }
                        let placemarks = try? await CLGeocoder().geocodeAddressString(text, in: region, preferredLocale: Locale(identifier: "de_DE"))
                        if let placemark = placemarks?.first(where: { Self.matches($0, text) && $0.subThoroughfare != nil }), let location = placemark.location {
                            suggestion.point = GeoPoint(location.coordinate)
                            kept.append(suggestion)
                        }
                    }
                    return kept
                }
            } else {
                self.addressResults = results.prefix(10).map { Suggestion(title: $0.title, subtitle: $0.subtitle, completion: $0) }
                self.mergeSuggestions()
            }
        }
    }

    /// Anschriften und Örtlichkeiten getrennt; was in beiden vorkommt, nur bei den Anschriften.
    private func mergeSuggestions() {
        suggestions = addressResults
        let addresses = Set(addressResults.map { "\($0.title)|\($0.subtitle)" })
        placeSuggestions = placeResults.filter { !addresses.contains("\($0.title)|\($0.subtitle)") }
    }

    // MARK: Kreuzungen

    /// Querstraßen je Straße (in Kleinschreibung), wie der Server sie geliefert hat.
    @ObservationIgnored private var crossingCache: [String: APIClient.CrossingStreets] = [:]
    /// Straße, deren Querstraßen gerade geladen werden.
    @ObservationIgnored private var crossingRequest: String?

    /// Querstraßen von `a`, gefiltert nach dem bisher getippten zweiten Namen. Nur der erste Aufruf je Straße geht an
    /// den Server; jede weitere Eingabe filtert sofort.
    private func showCrossings(of a: String) {
        let key = a.lowercased()
        if let cached = crossingCache[key] {
            isValidating = false
            suggestions = Self.crossingSuggestions(cached, filter: typedSecondStreet)
            if suggestions.isEmpty, typedSecondStreet.count >= 3 { checkTypedCrossing(a, typedSecondStreet) }
            return
        }
        // Läuft schon für diese Straße: Das Ergebnis filtert dann nach der aktuellen Eingabe.
        if crossingRequest == key { return }
        guard a.count >= 2, let client else {
            suggestions = []
            return
        }
        validation?.cancel()
        crossingRequest = key
        suggestions = []
        isValidating = true
        let near = near ?? GeoPoint(lat: 53.57, lon: 10)
        validation = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let result = try? await client.crossingStreets(a, near: near)
            guard !Task.isCancelled, crossingRequest == key else { return }
            crossingRequest = nil
            isValidating = false
            if let result { crossingCache[key] = result }
            suggestions = result.map { Self.crossingSuggestions($0, filter: typedSecondStreet) } ?? []
            if result == nil { failure = "Kreuzungssuche zurzeit nicht erreichbar." }
        }
    }

    /// Querstraßen als Vorschläge, passend zur Eingabe; ohne Eingabe alle, nächstgelegene zuerst.
    nonisolated static func crossingSuggestions(_ crossings: APIClient.CrossingStreets, filter: String) -> [Suggestion] {
        crossings.strassen
            .filter { filter.isEmpty || $0.name.matches(search: filter) || normalizedStreet($0.name).hasPrefix(normalizedStreet(filter)) }
            .prefix(20)
            .compactMap { street in
                guard let point = street.punkte.first else { return nil }
                var suggestion = Suggestion(title: "\(crossings.a) / \(street.name)", subtitle: "Kreuzung", completion: nil)
                suggestion.point = point
                return suggestion
            }
    }

    /// Nichts in der Liste passt (z. B. Tippfehler im zweiten Namen): einmal unscharf beim Server nachfragen.
    private func checkTypedCrossing(_ a: String, _ b: String) {
        validate { client, near in
            guard let crossing = try? await client?.intersection(a, b, near: near ?? GeoPoint(lat: 53.57, lon: 10)), let first = crossing.punkte.first else { return [] }
            var suggestion = Suggestion(title: "\(crossing.a ?? a) / \(crossing.b ?? b)", subtitle: "Kreuzung", completion: nil)
            suggestion.point = first
            return [suggestion]
        }
    }

    /// Prüft Vorschläge im Hintergrund; neue Eingaben brechen die laufende Prüfung ab.
    private func validate(_ check: @escaping (APIClient?, GeoPoint?) async -> [Suggestion]) {
        validation?.cancel()
        suggestions = []
        isValidating = true
        let client = client, near = near
        validation = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let kept = await check(client, near)
            guard !Task.isCancelled else { return }
            suggestions = kept
            isValidating = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.suggestions = [] }
    }

    nonisolated static func matches(_ placemark: CLPlacemark, _ text: String) -> Bool {
        guard let wanted = streetAndNumber(text) else { return true }
        guard let street = placemark.thoroughfare else { return false }
        let number = (placemark.subThoroughfare ?? "").replacingOccurrences(of: " ", with: "").lowercased()
        return normalizedStreet(street) == normalizedStreet(wanted.street) && (number.isEmpty || number == wanted.number)
    }

    /// Adresssuche über den Geocoder als zweite Quelle, wenn die Ortssuche keine passende Straße liefert.
    private func geocode(_ text: String, near: GeoPoint?) async -> [Place] {
        let region = near.map { CLCircularRegion(center: $0.coordinate, radius: 30_000, identifier: "umkreis") }
        guard let placemarks = try? await CLGeocoder().geocodeAddressString(text, in: region, preferredLocale: Locale(identifier: "de_DE")) else { return [] }
        return placemarks.compactMap { placemark in
            guard let location = placemark.location else { return nil }
            return Place(
                title: [placemark.thoroughfare, placemark.subThoroughfare].compactMap { $0 }.joined(separator: " "),
                subtitle: [placemark.postalCode, placemark.locality].compactMap { $0 }.joined(separator: " "),
                point: GeoPoint(location.coordinate),
                matchesQuery: Self.matches(placemark, text)
            )
        }
    }

    /// Löst einen Vorschlag oder eine freie Eingabe in Orte auf.
    func resolve(_ suggestion: Suggestion?, query: String, near: GeoPoint?, client: APIClient?) async -> [Place] {
        isSearching = true
        defer { isSearching = false }
        let text = suggestion?.query ?? suggestion?.title ?? query
        if let suggestion, let point = suggestion.point {
            return [Place(title: suggestion.title, subtitle: suggestion.subtitle, point: point)]
        }
        if let (a, b) = Self.intersectionParts(text), !b.isEmpty {
            guard let client, let near else {
                failure = "Für die Kreuzungssuche wird der eigene Standort benötigt."
                return []
            }
            do {
                let crossing = try await client.intersection(a, b, near: near)
                let points = crossing.punkte
                if points.isEmpty { failure = "Keine Kreuzung von \(a) und \(b) in der Nähe gefunden." }
                let title = "\(crossing.a ?? a) / \(crossing.b ?? b)"
                return points.enumerated().map { index, point in
                    Place(title: title, subtitle: points.count > 1 ? "Kreuzungspunkt \(index + 1)" : "Kreuzung", point: point)
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
            var places = response.mapItems.map { item in
                Place(
                    title: item.name ?? text,
                    subtitle: [item.placemark.thoroughfare, item.placemark.subThoroughfare, item.placemark.locality].compactMap { $0 }.joined(separator: " "),
                    point: GeoPoint(item.placemark.coordinate),
                    matchesQuery: Self.matches(item.placemark, text)
                )
            }
            // Treffer mit falscher Straße (z. B. "Hempbarg" statt "Hegbarg") nicht übernehmen, sondern genauer suchen.
            if Self.streetAndNumber(text) != nil, !places.contains(where: \.matchesQuery) {
                let geocoded = await geocode(text, near: near)
                if !geocoded.isEmpty { places = geocoded + places }
            }
            places.sort { $0.matchesQuery && !$1.matchesQuery }
            if places.isEmpty { failure = "Nichts gefunden." }
            return places
        } catch {
            failure = "Nichts gefunden."
            return []
        }
    }
}
