import MapKit
import SwiftUI

// Anschrift mit Vorschlägen während der Eingabe (Anschriften, Firmen und Orte, ÖPNV-Stationen), ohne Objekte aus der Lage.

/// Vorschläge von Apple Karten für eine angefangene Anschrift.
@MainActor
@Observable
final class AddressCompleter: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var results: [MKLocalSearchCompletion] = []
    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(_ text: String, near region: MKCoordinateRegion?) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            results = []
            completer.cancel()
            return
        }
        if let region { completer.region = region }
        completer.queryFragment = trimmed
    }

    func clear() {
        results = []
        completer.cancel()
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let next = Array(completer.results.prefix(6))
        Task { @MainActor in self.results = next }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.results = [] }
    }

    /// Ort und vollständige Anschrift zu einem Vorschlag.
    static func resolve(_ completion: MKLocalSearchCompletion) async -> (point: GeoPoint, address: String)? {
        guard let item = try? await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start().mapItems.first else { return nil }
        let point = GeoPoint(item.placemark.coordinate)
        let mark = item.placemark
        let streetLine = [mark.thoroughfare, mark.subThoroughfare].compactMap { $0 }.joined(separator: " ")
        let cityLine = [mark.postalCode, mark.locality].compactMap { $0 }.joined(separator: " ")
        let joined = [streetLine, cityLine].filter { !$0.isEmpty }.joined(separator: ", ")
        let full: String? = joined.isEmpty ? nil : joined
        let address: String
        if completion.subtitle.isEmpty || item.pointOfInterestCategory == nil {
            address = full ?? [completion.title, completion.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
        } else {
            // Firma oder Station: Name vorn, dann die Anschrift.
            address = [completion.title, full].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        }
        return (point, address)
    }
}

/// Eingabefeld für die Anschrift eines Zielobjekts; ein gewählter Vorschlag setzt Anschrift und Standort.
struct AddressCompletionField: View {
    @Binding var address: String
    let near: GeoPoint?
    let picked: (GeoPoint) -> Void

    @State private var completer = AddressCompleter()
    @State private var resolving = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            TextField("Anschrift oder Firma suchen", text: $address, axis: .vertical)
                .lineLimit(1...3)
                .textContentType(.fullStreetAddress)
                .focused($focused)
            if focused, !address.isEmpty {
                Button {
                    address = ""
                    completer.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, height: 22)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Feld leeren")
            }
        }
        .onChange(of: address) { _, text in
            guard focused else { return }
            completer.update(text, near: near.map { MKCoordinateRegion(center: $0.coordinate, latitudinalMeters: 40_000, longitudinalMeters: 40_000) })
        }
        .onChange(of: focused) { _, now in if !now { completer.clear() } }
        if focused {
            ForEach(completer.results, id: \.self) { result in
                Button {
                    Task { await pick(result) }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(result.title)
                            .foregroundStyle(.primary)
                        if !result.subtitle.isEmpty {
                            Text(result.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(resolving)
            }
        }
    }

    private func pick(_ result: MKLocalSearchCompletion) async {
        resolving = true
        defer { resolving = false }
        guard let resolved = await AddressCompleter.resolve(result) else { return }
        completer.clear()
        focused = false
        address = resolved.address
        picked(resolved.point)
    }
}
