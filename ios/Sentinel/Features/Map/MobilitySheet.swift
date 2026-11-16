import SwiftUI

/// Fortbewegung wählen: zu Fuß, in einem Fahrzeug der eigenen Kräfte oder mit einer ÖPNV-Linie samt Fahrtrichtung.
struct MobilitySheet: View {
    /// Vorgewählte Art, z. B. beim Antippen von „Fahrzeug“ auf der Karte.
    var initialMode: Fortbewegung?

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Fortbewegung = .fuss
    @State private var query = ""
    @State private var lines: [LineHit] = []
    @State private var linesAvailable = true
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                // Auf der Karte wurde die Art schon gewählt: hier nur noch Fahrzeug bzw. Linie aussuchen.
                if initialMode == nil {
                Section {
                    Picker("Fortbewegung", selection: $mode) {
                        ForEach(Fortbewegung.allCases) { art in
                            Label(art.title, systemImage: art.symbolName).tag(art)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }
                }

                switch mode {
                case .fuss:
                    Section {
                        Button {
                            lage.setMobility(.fuss)
                            dismiss()
                        } label: {
                            Label("Ich bin zu Fuß unterwegs", systemImage: "figure.walk")
                        }
                    } footer: {
                        Text("Wer zuletzt ein Fahrzeug verlässt, lässt es an Ort und Stelle zurück.")
                    }
                case .fahrzeug:
                    vehicleSection
                case .oepnv:
                    transitSection
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .onAppear { mode = initialMode ?? lage.me?.data.fortbewegung ?? .fuss }
            .task(id: "\(mode.rawValue)|\(query)") {
                guard mode == .oepnv else { return }
                try? await Task.sleep(for: .milliseconds(250))
                await loadLines()
            }
        }
    }

    @ViewBuilder private var vehicleSection: some View {
        Section {
            if lage.activeVehicles.isEmpty {
                Text("Kein Fahrzeug aktiv. Fahrzeuge werden unter Kräfte angelegt und für den Einsatz eingeschaltet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(lage.activeVehicles) { vehicle in
                Button {
                    lage.setMobility(.fahrzeug, vehicleId: vehicle.id)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vehicle.data.funkrufname)
                                .font(.headline)
                            let crew = lage.occupants(of: vehicle.id).map(\.data.spitzname)
                            Text(crew.isEmpty ? "Frei" : "Besetzt: \(crew.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if lage.me?.data.fahrzeugId == vehicle.id, lage.me?.data.fortbewegung == .fahrzeug {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .tint(.primary)
            }
        } header: {
            Text("In welchem Fahrzeug?")
        }
    }

    @ViewBuilder private var transitSection: some View {
        Section {
            TextField("Linie suchen, z. B. U3, 269, RB81", text: $query)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        } footer: {
            Text(query.isEmpty ? "Ohne Eingabe werden Linien an Haltestellen in der Nähe vorgeschlagen." : "Jede Fahrtrichtung erscheint einzeln.")
        }
        Section(query.isEmpty ? "In der Nähe" : "Treffer") {
            if isLoading { ProgressView() }
            if !linesAvailable {
                Text("Die ÖPNV-Linien werden auf dem Server noch geladen. Bitte später erneut versuchen.")
                    .foregroundStyle(.secondary)
            } else if lines.isEmpty, !isLoading {
                Text(query.isEmpty ? "Keine Haltestelle in der Nähe gefunden." : "Keine passende Linie.")
                    .foregroundStyle(.secondary)
            }
            ForEach(lines) { line in
                Button {
                    lage.setMobility(.oepnv, transit: OepnvFahrt(linienId: line.id, linie: line.ref, richtung: line.richtung))
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: line.symbolName)
                            .foregroundStyle(.tint)
                            .frame(width: 26)
                        Text(line.ref)
                            .font(.headline)
                            .frame(minWidth: 44, alignment: .leading)
                        Text("Richtung \(line.richtung)")
                            .lineLimit(2)
                        Spacer()
                        if let meter = line.meter {
                            Text(Format.distance(meter))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
        }
    }

    private var title: String {
        switch initialMode {
        case .fahrzeug: "Fahrzeug wählen"
        case .oepnv: "Linie wählen"
        default: "Fortbewegung"
        }
    }

    private func loadLines() async {
        guard let client = model.client else { return }
        isLoading = true
        defer { isLoading = false }
        if let result = try? await client.lines(query: query, near: model.myPoint) {
            lines = result.lines
            linesAvailable = result.available
        }
    }
}
