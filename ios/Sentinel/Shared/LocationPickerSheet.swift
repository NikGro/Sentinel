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
                        SearchField(text: $address, prompt: "Adresse eingeben")
                            .onSubmit { Task { await findAddress() } }
                        if isSearching { ProgressView() }
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
            }
        }
    }

    private func findAddress() async {
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
