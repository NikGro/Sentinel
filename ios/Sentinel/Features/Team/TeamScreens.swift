import SwiftUI

/// Kräfte und Fahrzeuge des Einsatzes.
struct TeamScreen: View {
    @Environment(LageStore.self) private var lage
    @State private var vehicleEditor: VehicleEditorContext?

    var body: some View {
        NavigationStack {
            List {
                Section("Kräfte") {
                    ForEach(lage.sortedMembers) { member in
                        NavigationLink {
                            MemberQuickLook(member: member)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MemberRow(member: member)
                        }
                    }
                }

                Section {
                    ForEach(lage.sortedVehicles) { vehicle in
                        NavigationLink {
                            VehicleDetail(vehicleId: vehicle.id)
                        } label: {
                            VehicleRow(vehicle: vehicle)
                        }
                    }
                    Button("Fahrzeug anlegen", systemImage: "plus") {
                        vehicleEditor = VehicleEditorContext(id: LageStore.newId(), vehicle: Vehicle(bezeichnung: ""), isNew: true)
                    }
                } header: {
                    Text("Fahrzeuge")
                } footer: {
                    Text("Einsteigen bindet das Fahrzeug an Ihren Standort. Beim Aussteigen bleibt es am aktuellen Ort stehen.")
                }
            }
            .navigationTitle("Team")
            .sheet(item: $vehicleEditor) { context in
                VehicleEditor(context: context)
            }
        }
    }
}

private struct MemberRow: View {
    let member: Versioned<Member>
    @Environment(LageStore.self) private var lage

    var body: some View {
        HStack(spacing: 12) {
            Avatar(blobId: member.data.fotoBlob, fallbackText: member.data.funkrufname, size: 44, tint: lage.isOnline(member.id) ? .green : .gray)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.data.funkrufname)
                        .font(.headline)
                    if lage.operation.a?.memberId == member.id {
                        Text("A")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .background(Theme.aPosition, in: .capsule)
                    }
                    if member.id == lage.selfId {
                        Text("Sie")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(member.data.name) · \(member.data.dienststelle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let vehicle = member.data.fahrzeugId.flatMap({ lage.vehicles[$0] }) {
                    Label(vehicle.data.bezeichnung, systemImage: "car.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct VehicleRow: View {
    let vehicle: Versioned<Vehicle>
    @Environment(LageStore.self) private var lage

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(blobId: vehicle.data.fotoBlob) {
                ZStack {
                    Color.indigo.opacity(0.2)
                    Image(systemName: "car.fill")
                        .foregroundStyle(.indigo)
                }
            }
            .frame(width: 56, height: 44)
            .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.data.bezeichnung)
                    .font(.headline)
                if !vehicle.data.kennzeichen.isEmpty {
                    Text(vehicle.data.kennzeichen)
                        .font(.caption.monospaced().weight(.semibold))
                }
                Text(occupancy)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var occupancy: String {
        let names = lage.occupants(of: vehicle.id).map(\.data.funkrufname)
        return names.isEmpty ? "Unbesetzt" : "Besetzt: \(names.joined(separator: ", "))"
    }
}

/// Fahrzeug mit Ein-/Aussteigen, Standort und Tracker.
struct VehicleDetail: View {
    let vehicleId: String

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @State private var editor: VehicleEditorContext?

    var body: some View {
        if let vehicle = lage.vehicles[vehicleId] {
            content(vehicle)
        } else {
            ContentUnavailableView("Fahrzeug wurde entfernt", systemImage: "car")
        }
    }

    private func content(_ vehicle: Versioned<Vehicle>) -> some View {
        let isAboard = lage.me?.data.fahrzeugId == vehicle.id
        let position = lage.position(ofVehicle: vehicle)
        return List {
            if vehicle.data.fotoBlob != nil {
                RemoteImage(blobId: vehicle.data.fotoBlob) { Color.secondary.opacity(0.15) }
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipShape(.rect(cornerRadius: 12))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                Button {
                    if isAboard { lage.leaveVehicle() } else { lage.board(vehicleId: vehicle.id) }
                } label: {
                    Label(isAboard ? "Aussteigen" : "Einsteigen", systemImage: isAboard ? "figure.walk.departure" : "car.side.arrowtriangle.down.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(isAboard ? .orange : .accentColor)
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("Fahrzeug") {
                if !vehicle.data.kennzeichen.isEmpty {
                    LabeledContent("Kennzeichen") {
                        Text(vehicle.data.kennzeichen)
                            .font(.body.monospaced().weight(.semibold))
                    }
                }
                if !vehicle.data.beschreibung.isEmpty { Text(vehicle.data.beschreibung) }
                LabeledContent("Besatzung") {
                    let names = lage.occupants(of: vehicle.id).map(\.data.funkrufname)
                    Text(names.isEmpty ? "Unbesetzt" : names.joined(separator: ", "))
                }
            }

            Section("Standort") {
                if let position {
                    LabeledContent("Quelle", value: position.source)
                    LabeledContent("Stand", value: Format.ago(position.date))
                    Button("Hinführen", systemImage: "location.north.line.fill") {
                        model.navigate(to: .vehicle(vehicle.id))
                        dismiss()
                    }
                } else {
                    Text("Noch kein Standort bekannt.")
                        .foregroundStyle(.secondary)
                }
                if let tracker = vehicle.data.trackerId.flatMap({ lage.trackers[$0] }) {
                    LabeledContent("GPS-Tracker", value: "\(tracker.data.name) (\(tracker.data.providerTitle))")
                }
            }
        }
        .navigationTitle(vehicle.data.bezeichnung)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Bearbeiten") { editor = VehicleEditorContext(id: vehicle.id, vehicle: vehicle.data, isNew: false) }
            }
        }
        .sheet(item: $editor) { context in
            VehicleEditor(context: context)
        }
    }
}

struct VehicleEditorContext: Identifiable {
    let id: String
    let vehicle: Vehicle
    let isNew: Bool
}

struct VehicleEditor: View {
    let context: VehicleEditorContext

    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @State private var vehicle: Vehicle
    @State private var boardsAfterSave = true
    @State private var showsDelete = false

    init(context: VehicleEditorContext) {
        self.context = context
        _vehicle = State(initialValue: context.vehicle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bezeichnung, z. B. Golf grau", text: $vehicle.bezeichnung)
                    TextField("Kennzeichen", text: $vehicle.kennzeichen)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Beschreibung", text: $vehicle.beschreibung, axis: .vertical)
                        .lineLimit(1...4)
                    PhotoField(title: "Fahrzeugbild", blobId: $vehicle.fotoBlob)
                }

                Section {
                    Picker("GPS-Tracker", selection: $vehicle.trackerId) {
                        Text("Keiner").tag(String?.none)
                        ForEach(lage.trackers.values.sorted { $0.data.name < $1.data.name }) { tracker in
                            Text("\(tracker.data.name) (\(tracker.data.providerTitle))").tag(String?.some(tracker.id))
                        }
                    }
                } footer: {
                    Text("Mit Tracker meldet das Fahrzeug seinen Standort selbst, auch wenn das Einsteigen vergessen wurde.")
                }

                if context.isNew {
                    Section {
                        Toggle("Nach dem Anlegen einsteigen", isOn: $boardsAfterSave)
                    }
                } else {
                    Section {
                        Button("Fahrzeug löschen", systemImage: "trash", role: .destructive) { showsDelete = true }
                    }
                }
            }
            .navigationTitle(context.isNew ? "Neues Fahrzeug" : "Fahrzeug bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(vehicle.bezeichnung.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Fahrzeug für alle löschen?", isPresented: $showsDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    lage.delete(Vehicle.self, id: context.id)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        var result = vehicle
        result.bezeichnung = result.bezeichnung.trimmingCharacters(in: .whitespaces)
        guard lage.put(result, id: context.id) else { return }
        if context.isNew, boardsAfterSave { lage.board(vehicleId: context.id) }
        dismiss()
    }
}
