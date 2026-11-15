import SwiftUI

/// Markierung benennen, gestalten, verschieben oder löschen. Jeder darf jede Markierung bearbeiten.
struct MapObjectEditor: View {
    let context: EditorContext
    /// Startet das Verschieben per Tipp auf die Karte.
    let startMoving: (String) -> Void

    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @State private var object: MapObject
    @State private var radiusText: String

    init(context: EditorContext, startMoving: @escaping (String) -> Void) {
        self.context = context
        self.startMoving = startMoving
        _object = State(initialValue: context.object)
        _radiusText = State(initialValue: context.object.radius.map { String(Int($0)) } ?? "")
    }

    private var availableLayers: [Versioned<Layer>] {
        lage.sortedLayers.filter { $0.data.art != "argus" }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(object.typ == .text ? "Text" : "Bezeichnung", text: $object.titel)
                    TextField("Notiz", text: $object.notiz, axis: .vertical)
                        .lineLimit(1...5)
                }

                Section("Farbe") {
                    HStack(spacing: 0) {
                        ForEach(Theme.palette, id: \.hex) { entry in
                            Button {
                                object.farbe = entry.hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: entry.hex))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if object.farbe.uppercased() == entry.hex {
                                            Circle().stroke(.primary, lineWidth: 3).padding(-4)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(entry.name)
                            .accessibilityAddTraits(object.farbe.uppercased() == entry.hex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                if object.typ == .marker {
                    Section("Symbol") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                            ForEach(Theme.markerSymbols, id: \.self) { symbol in
                                Button {
                                    object.symbol = symbol
                                } label: {
                                    Image(systemName: symbol)
                                        .font(.system(size: 16, weight: .semibold))
                                        .frame(width: 34, height: 34)
                                        .background(isSelected(symbol) ? Color(hex: object.farbe).opacity(0.35) : Color.secondary.opacity(0.12), in: .circle)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(isSelected(symbol) ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if object.typ == .kreis {
                    Section("Radius in Metern") {
                        TextField("Radius", text: $radiusText)
                            .keyboardType(.numberPad)
                    }
                }

                Section {
                    Picker("Ebene", selection: $object.layerId) {
                        ForEach(availableLayers) { layer in
                            Label(layer.data.name, systemImage: layer.data.symbolName).tag(layer.id)
                        }
                    }
                } footer: {
                    Text("„Dauerhafte Orte“ bleiben erhalten, wenn die Lage zurückgesetzt wird.")
                }

                if !context.isNew {
                    Section {
                        Button("Auf der Karte verschieben", systemImage: "arrow.up.and.down.and.arrow.left.and.right") {
                            startMoving(context.id)
                            dismiss()
                        }
                        Button("Löschen", systemImage: "trash", role: .destructive) {
                            lage.deleteMapObject(id: context.id)
                            dismiss()
                        }
                    } footer: {
                        if let current = lage.mapObjects[context.id] {
                            Text("Zuletzt geändert von \(lage.name(of: current.updatedBy)), \(Format.ago(current.updatedDate))")
                        }
                    }
                }
            }
            .navigationTitle(context.isNew ? "Neu: \(object.typ.title)" : object.typ.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(object.typ == .text && object.titel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func isSelected(_ symbol: String) -> Bool {
        object.symbol == symbol || (object.symbol.isEmpty && symbol == "mappin")
    }

    private func save() {
        var result = object
        result.titel = String(result.titel.trimmingCharacters(in: .whitespaces).prefix(80))
        result.notiz = String(result.notiz.prefix(1000))
        if result.typ == .kreis {
            result.radius = min(max(Double(radiusText) ?? 150, 5), 100_000)
        }
        lage.saveMapObject(result, id: context.id)
        dismiss()
    }
}
