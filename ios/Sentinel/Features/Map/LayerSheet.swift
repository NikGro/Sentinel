import SwiftUI

/// Ebenen ein- und ausblenden. Die Auswahl gilt nur für dieses Gerät und beugt einer Informationsflut vor.
struct LayerSheet: View {
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var showsClear = false

    private var hasSearchArea: Bool { lage.mapObjects.values.contains { $0.data.typ == .fahndungsraum && !$0.data.isExpired() } }
    private var lageObjects: [String] { lage.mapObjects.values.filter { $0.data.layerId == Layer.lageId }.map(\.id) }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            List {
                Section {
                    Toggle("Bestreifte Wege", systemImage: "road.lanes", isOn: Binding(
                        get: { settings.showsCoverage },
                        set: { on in
                            settings.showsCoverage = on
                            // Ausschalten setzt die Bestreifung zurück; eingeschaltet zählt sie ab jetzt neu.
                            if !on { lage.resetCoverage() }
                        }
                    ))
                } header: {
                    Text("Bestreifung")
                } footer: {
                    Text("Zeigt die gefahrenen Wege der eigenen Kräfte ab dem Einschalten. Ausschalten setzt die Bestreifung für alle zurück.")
                }

                if hasSearchArea {
                Section {
                    ForEach(ReachMode.allCases) { mode in
                        Toggle(isOn: Binding(get: { settings.isReachEnabled(mode) }, set: { _ in settings.toggleReach(mode) })) {
                            Label(mode.title, systemImage: mode.symbolName)
                        }
                        .tint(Theme.color(for: mode))
                    }
                } header: {
                    Text("Fahndungsraum")
                } footer: {
                    Text("Wie weit die Zielperson seit der letzten Sichtung gekommen sein kann, je Fortbewegungsart.")
                }
                }

                Section {
                    ForEach(lage.sortedLayers.filter(\.data.isLive)) { layer in
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
                    Text("Hier bestimmen Sie nur, was Ihre Karte anzeigt. Pakete laden und Argus-Prognosen importieren: Mehr, Ebenen und Pakete.")
                }

                Section {
                    Button("Lage-Ebene leeren", systemImage: "trash", role: .destructive) { showsClear = true }
                        .disabled(lageObjects.isEmpty)
                } footer: {
                    Text("Entfernt alle Markierungen der Ebene „Lage“ für alle. Dauerhafte Orte, Pakete und Ziele bleiben.")
                }
            }
            .alert("Lage-Ebene für alle leeren?", isPresented: $showsClear) {
                Button("Abbrechen", role: .cancel) {}
                Button("Leeren", role: .destructive) {
                    for id in lageObjects { lage.deleteMapObject(id: id) }
                }
            } message: {
                Text("\(lageObjects.count) Markierungen werden gelöscht. Das lässt sich nicht rückgängig machen.")
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
