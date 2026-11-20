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

    private(set) var suggestions: [Suggestion] = []
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
        validation?.cancel()
        isValidating = false
        // Vorschläge nur aus der Nähe: Wer „Heg“ tippt, meint den Hegpark um die Ecke, nicht einen Ort weit weg.
        completer.region = region ?? Self.fallbackRegion
        completer.regionPriority = .required
        if let (a, b) = Self.intersectionParts(query) {
            // Zweiten Straßennamen vervollständigen, den ersten voranstellen.
            intersectionPrefix = a
            typedSecondStreet = b
            completer.resultTypes = .address
            if b.count >= 2 {
                completer.queryFragment = b
            } else {
                suggestions = []
            }
            return
        }
        intersectionPrefix = nil
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
                // Örtlichkeiten nur im freien Suchmodus, hinter den Straßen.
                guard self.intersectionPrefix == nil, self.leadingHouseNumber == nil else { return }
                self.placeResults = results.prefix(8).map { Suggestion(title: $0.title, subtitle: $0.subtitle, completion: $0) }
                self.mergeSuggestions()
                return
            }
            if let prefix = self.intersectionPrefix {
                // Für Kreuzungen nur den Straßennamen ohne Ort übernehmen.
                var seen = Set<String>()
                // Die Eingabe selbst zuerst prüfen: Apple vervollständigt nicht jeden (auch falsch geschriebenen) Namen,
                // der Server ordnet ihn trotzdem der richtigen Straße zu.
                let typed = self.typedSecondStreet
                if !typed.isEmpty { seen.insert(typed) }
                let typedCandidate: [(String, Suggestion)] = typed.count >= 3 ? [(typed, Suggestion(title: "\(prefix) / \(typed)", subtitle: "Kreuzung", completion: nil))] : []
                let candidates: [(String, Suggestion)] = typedCandidate + results.compactMap { result in
                    let street = result.title.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? result.title
                    guard seen.insert(street).inserted else { return nil }
                    return (street, Suggestion(title: "\(prefix) / \(street)", subtitle: "Kreuzung", completion: nil))
                }
                // Nur Kreuzungen zeigen, an denen beide Straßen wirklich aufeinandertreffen; Namen so, wie der Server sie
                // gefunden hat (Tippfehler korrigiert). Gleiche Kreuzungen erscheinen nur einmal.
                self.validate { client, near in
                    var kept: [Suggestion] = []
                    var found = Set<String>()
                    for (street, suggestion) in candidates.prefix(7) {
                        if Task.isCancelled { return kept }
                        guard let crossing = try? await client?.intersection(prefix, street, near: near ?? GeoPoint(lat: 53.57, lon: 10)),
                              let first = crossing.punkte.first else { continue }
                        let title = "\(crossing.a ?? prefix) / \(crossing.b ?? street)"
                        guard found.insert(title).inserted else { continue }
                        var corrected = Suggestion(title: title, subtitle: suggestion.subtitle, completion: nil)
                        corrected.point = first
                        kept.append(corrected)
                    }
                    return kept
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

    /// Straßen und Adressen zuerst, dann Örtlichkeiten; gleiche Titel nur einmal.
    private func mergeSuggestions() {
        var seen = Set<String>()
        suggestions = (addressResults + placeResults).filter { seen.insert("\($0.title)|\($0.subtitle)").inserted }.prefix(14).map { $0 }
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
