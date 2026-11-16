import CoreLocation
import MapKit
import SwiftUI

/// Standort wählen: Karte unter das Fadenkreuz schieben oder eine Adresse eintippen, dann übernehmen.
struct LocationPickerSheet: View {
    let title: String
    let initial: GeoPoint?
    let pick: (GeoPoint) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var camera: MapCameraPosition = .automatic
    @State private var center: CLLocationCoordinate2D?
    @State private var address = ""
    @State private var isSearching = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Map(position: $camera) {
                UserAnnotation()
            }
            .mapControls { MapCompass() }
            .onMapCameraChange(frequency: .continuous) { context in
                center = context.region.center
            }
            .overlay {
                // Fadenkreuz: die Spitze der Nadel sitzt genau in der Kartenmitte.
                Image(systemName: "mappin")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.red)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                    .offset(y: -18)
                    .allowsHitTesting(false)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Adresse eingeben", text: $address)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await findAddress() } }
                        if isSearching { ProgressView() }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    if let failure {
                        Text(failure)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    guard let center else { return }
                    pick(GeoPoint(center))
                    dismiss()
                } label: {
                    Label("Standort übernehmen", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .disabled(center == nil)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .onAppear {
                let start = initial ?? model.myPoint ?? GeoPoint(lat: 53.5511, lon: 9.9937)
                center = start.coordinate
                camera = .camera(MapCamera(centerCoordinate: start.coordinate, distance: 1200))
            }
        }
    }

    private func findAddress() async {
        let query = address.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        let near = center.map { CLCircularRegion(center: $0, radius: 50_000, identifier: "umgebung") }
        let placemarks = try? await CLGeocoder().geocodeAddressString(query, in: near, preferredLocale: Locale(identifier: "de_DE"))
        guard let coordinate = placemarks?.first?.location?.coordinate else {
            failure = "Adresse nicht gefunden."
            return
        }
        failure = nil
        withAnimation(.easeInOut(duration: 0.6)) {
            camera = .camera(MapCamera(centerCoordinate: coordinate, distance: 600))
        }
    }
}
