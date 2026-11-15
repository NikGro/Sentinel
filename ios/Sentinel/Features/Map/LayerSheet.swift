import SwiftUI

/// Ebenen ein- und ausblenden. Die Auswahl gilt nur für dieses Gerät und beugt einer Informationsflut vor.
struct LayerSheet: View {
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(lage.sortedLayers) { layer in
                        Toggle(isOn: visibility(of: layer.id)) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(layer.data.name)
                                    Text(subtitle(for: layer))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: layer.data.symbolName)
                            }
                        }
                    }
                } header: {
                    Text("Ebenen")
                } footer: {
                    Text("Vorbereitete Pakete und Argus-Prognosen lädt die Kommandozentrale in die Lage. Hier bestimmen Sie nur, was Ihre Karte anzeigt.")
                }
            }
            .navigationTitle("Kartenebenen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func visibility(of layerId: String) -> Binding<Bool> {
        Binding(
            get: { !settings.hiddenLayers.contains(layerId) },
            set: { visible in
                if visible { settings.hiddenLayers.remove(layerId) } else { settings.hiddenLayers.insert(layerId) }
            }
        )
    }

    private func subtitle(for layer: Versioned<Layer>) -> String {
        let count = lage.mapObjects.values.filter { $0.data.layerId == layer.id }.count
        let kind = switch layer.data.art {
        case "dauerhaft": "Bleibt dauerhaft"
        case "paket": "Paket"
        case "argus": "Argus Predict"
        default: "Laufender Einsatz"
        }
        return "\(kind) · \(count) Objekte"
    }
}
