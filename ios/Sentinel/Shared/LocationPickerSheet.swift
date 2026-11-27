import CoreLocation
import MapKit
import SwiftUI

/// Standort wählen, genauso wie auf der Lagekarte: Ort antippen (Vorschau), bei Bedarf per Adresse hinspringen,
/// dann „Übernehmen“.
struct LocationPickerSheet: View {
    let title: String
    let initial: GeoPoint?
    let pick: (GeoPoint) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// Eigene Kartensteuerung wie auf der Lagekarte.
    @State private var engine = MapEngine()
    @State private var point: GeoPoint?
    @State private var address = ""
    @State private var isSearching = false
    @State private var failure: String?
    /// Dieselben Vorschläge wie die Suche auf der Karte (Anschriften, Kreuzungen, Orte und Firmen).
    @State private var search = SearchService()
    /// Gewählter Vorschlag steht im Feld: keine neuen Vorschläge dazu suchen.
    @State private var settled = false

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(initialPosition: .camera(MapCamera(centerCoordinate: (initial ?? model.myPoint ?? GeoPoint(lat: 53.5511, lon: 9.9937)).coordinate, distance: 1200)), interactionModes: []) {
                    UserAnnotation()
                    if let point { PlacementPreview(point: point) }
                }
                .mapControls { MapCompass() }
                .mapEngine(engine)
                .onTapGesture { location in
                    if let coordinate = proxy.convert(location, from: .local) {
                        withAnimation(.snappy) { point = GeoPoint(coordinate) }
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: Theme.barSpacing) {
                    HStack {
                        SearchField(text: $address, prompt: "Adresse, Ort oder Kreuzung")
                            .onSubmit { Task { await findAddress() } }
                        if isSearching || search.isValidating { ProgressView() }
                    }
                    let suggestions = Array((search.suggestions + search.placeSuggestions).prefix(6))
                    if !address.trimmingCharacters(in: .whitespaces).isEmpty, !suggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(suggestions) { suggestion in
                                Button {
                                    Task { await take(suggestion) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(suggestion.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                if suggestion.id != suggestions.last?.id { Divider().padding(.leading, 14) }
                            }
                        }
                        .glassEffect(.regular, in: .rect(cornerRadius: 18))
                    }
                    if let failure {
                        Text(failure)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                    }
                    PlacementBar(hint: point == nil ? "Ort antippen" : "Antippen verschiebt den Ort", canConfirm: point != nil, confirm: {
                        guard let point else { return }
                        pick(point)
                        dismiss()
                    }, cancel: { dismiss() })
                }
                .padding(.horizontal, Theme.barInset)
                .padding(.vertical, 8)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                point = initial
                search.client = model.client
            }
            .onChange(of: address) { _, text in
                if settled {
                    settled = false
                    return
                }
                let reference = point ?? model.myPoint
                search.near = reference
                search.update(query: text, near: reference.map { MKCoordinateRegion(center: $0.coordinate, latitudinalMeters: 40_000, longitudinalMeters: 40_000) })
            }
        }
    }

    /// Vorschlag übernehmen: wie auf der Karte auflösen und den Punkt dorthin setzen.
    private func take(_ suggestion: SearchService.Suggestion) async {
        isSearching = true
        defer { isSearching = false }
        let places = await search.resolve(suggestion, query: address, near: point ?? model.myPoint, client: model.client)
        guard let place = places.first else {
            failure = "Ort nicht gefunden."
            return
        }
        failure = nil
        settled = true
        address = place.title
        search.update(query: "", near: nil)
        engine.fly(to: MapCamera(centerCoordinate: place.point.coordinate, distance: 600))
        withAnimation(.easeInOut(duration: 0.6)) { point = place.point }
    }

    private func findAddress() async {
        // Gibt es Vorschläge, gilt der erste (wie in der Kartensuche); sonst Apples Adresssuche.
        if let first = (search.suggestions + search.placeSuggestions).first {
            await take(first)
            return
        }
        let query = address.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        let reference = point ?? model.myPoint
        let near = reference.map { CLCircularRegion(center: $0.coordinate, radius: 50_000, identifier: "umgebung") }
        let placemarks = try? await CLGeocoder().geocodeAddressString(query, in: near, preferredLocale: Locale(identifier: "de_DE"))
        guard let coordinate = placemarks?.first?.location?.coordinate else {
            failure = "Adresse nicht gefunden."
            return
        }
        failure = nil
        engine.fly(to: MapCamera(centerCoordinate: coordinate, distance: 600))
        withAnimation(.easeInOut(duration: 0.6)) { point = GeoPoint(coordinate) }
    }
}
