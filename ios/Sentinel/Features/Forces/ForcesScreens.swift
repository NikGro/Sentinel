import SwiftUI

/// Kräfte: Fahnder und die Fahrzeugflotte. Fahnder schalten sich selbst aktiv; Fahrzeuge kann jeder für den Einsatz schalten.
struct ForcesScreen: View {
    @Environment(LageStore.self) private var lage
    @State private var vehicleEditor: VehicleEditorContext?
    @State private var vehicleToDelete: Versioned<Vehicle>?
    @State private var openVehicle: String?
    @State private var query = ""

    /// Suche über Spitzname, Name, Dienststelle bzw. Funkrufname, Kennzeichen und Beschreibung.
    private var members: [Versioned<Member>] {
        lage.sortedMembers.filter { m in [m.data.spitzname, m.data.name, m.data.dienststelle].contains { $0.matches(search: query) } }
    }

    private var vehicles: [Versioned<Vehicle>] {
        lage.sortedVehicles.filter { v in [v.data.funkrufname, v.data.kennzeichen, v.data.bezeichnung].contains { $0.matches(search: query) } }
    }

    private func newVehicle() {
        vehicleEditor = VehicleEditorContext(id: LageStore.newId(), vehicle: Vehicle(funkrufname: ""), isNew: true)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if members.isEmpty { Text(query.isEmpty ? "Noch keine Fahnder." : "Kein Treffer.").foregroundStyle(.secondary) }
                    ForEach(members) { member in
                        NavigationLink {
                            MemberQuickLook(member: member)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            MemberRow(member: member)
                        }
                    }
                } header: {
                    Text("Fahnder")
                } footer: {
                    Text("Jeder Fahnder legt sich beim ersten Start selbst an und schaltet unter Mehr den Ruhemodus.")
                }

                Section {
                    if vehicles.isEmpty, !query.isEmpty { Text("Kein Treffer.").foregroundStyle(.secondary) }
                    ForEach(vehicles) { vehicle in
                        HStack(spacing: 12) {
                            Button {
                                openVehicle = vehicle.id
                            } label: {
                                HStack {
                                    VehicleRow(vehicle: vehicle)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.borderless)
                            .tint(.primary)
                            // Im heutigen Einsatz dabei: direkt in der Liste schaltbar.
                            Toggle("Im Einsatz", isOn: Binding(
                                get: { vehicle.data.aktiv },
                                set: { value in
                                    var next = vehicle.data
                                    next.aktiv = value
                                    lage.put(next, id: vehicle.id)
                                }
                            ))
                            .labelsHidden()
                            .accessibilityLabel("\(vehicle.data.funkrufname) im Einsatz")
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Löschen", systemImage: "trash", role: .destructive) {
                                lage.delete(Vehicle.self, id: vehicle.id)
                            }
                        }
                    }
                } header: {
                    Text("Fahrzeuge")
                } footer: {
                    Text("Fahrzeuge bleiben dauerhaft angelegt; mit dem Schalter kommen sie in den heutigen Einsatz. Steigt der letzte Insasse aus, bleibt das Fahrzeug an Ort und Stelle.")
                }
            }
            .navigationTitle("Kräfte")
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                TabHeader(title: "Kräfte", query: $query, prompt: "Spitzname, Funkrufname, Kennzeichen") {
                    Button("Fahrzeug anlegen", systemImage: "plus", action: newVehicle)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationDestination(item: $openVehicle) { id in
                VehicleDetail(vehicleId: id)
            }
            .alert(
                "Fahrzeug „\(vehicleToDelete?.data.funkrufname ?? "")“ für alle löschen?",
                isPresented: Binding(get: { vehicleToDelete != nil }, set: { if !$0 { vehicleToDelete = nil } })
            ) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    if let vehicle = vehicleToDelete { lage.delete(Vehicle.self, id: vehicle.id) }
                }
            }
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
            Avatar(blobId: member.data.fotoBlob, fallbackText: member.data.spitzname, size: 44, tint: lage.isOnline(member.id) && member.data.aktiv ? .green : .gray)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.data.spitzname)
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
                Text("\(member.data.name), \(member.data.dienststelle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Label(member.data.aktiv ? lage.mobilityDescription(of: member.data) : "Ruhemodus", systemImage: member.data.aktiv ? member.data.fortbewegung.symbolName : "moon.zzz.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(member.data.aktiv ? 1 : 0.6)
    }
}

struct VehicleRow: View {
    let vehicle: Versioned<Vehicle>
    @Environment(LageStore.self) private var lage

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(blobId: vehicle.data.fotoBlob) {
                ZStack {
                    Theme.force.opacity(0.2)
                    Image(systemName: "car.fill")
                        .foregroundStyle(Theme.force)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.data.funkrufname)
                    .font(.headline)
                Text(occupancy)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(vehicle.data.aktiv ? 1 : 0.55)
    }

    private var occupancy: String {
        guard vehicle.data.aktiv else { return "Nicht im Einsatz" }
        let names = lage.occupants(of: vehicle.id).map(\.data.spitzname)
        return names.isEmpty ? "Unbesetzt" : "Besetzt: \(names.joined(separator: ", "))"
    }
}

/// Fahrzeug mit Aktiv-Schalter, Besatzung, Standort und Tracker.
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
        let position = lage.position(ofVehicle: vehicle)
        return List {
            if position != nil {
                NavigateHereSection {
                    model.navigate(to: .vehicle(vehicle.id))
                    dismiss()
                }
            }
            if vehicle.data.fotoBlob != nil {
                RemoteImage(blobId: vehicle.data.fotoBlob) { Color.secondary.opacity(0.15) }
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipShape(.rect(cornerRadius: 12))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                Toggle("Im heutigen Einsatz", isOn: Binding(
                    get: { vehicle.data.aktiv },
                    set: { active in
                        var next = vehicle.data
                        next.aktiv = active
                        lage.put(next, id: vehicle.id)
                    }
                ))
                Toggle("Verlauf aufzeichnen", isOn: Binding(
                    get: { vehicle.data.aufzeichnung },
                    set: { on in
                        var next = vehicle.data
                        next.aufzeichnung = on
                        lage.put(next, id: vehicle.id)
                    }
                ))
                HistoryButton(subject: SpurSubject(art: .vehicle, id: vehicle.id))
            }

            Section("Fahrzeug") {
                if !vehicle.data.bezeichnung.isEmpty { Text(vehicle.data.bezeichnung) }
                if !vehicle.data.kennzeichen.isEmpty {
                    LabeledContent("Kennzeichen") {
                        Text(vehicle.data.kennzeichen)
                            .font(.body.monospaced().weight(.semibold))
                    }
                }
                LabeledContent("Besatzung") {
                    let names = lage.occupants(of: vehicle.id).map(\.data.spitzname)
                    Text(names.isEmpty ? "Unbesetzt" : names.joined(separator: ", "))
                }
            }

            Section("Standort") {
                if let position {
                    LabeledContent("Quelle", value: position.source)
                    LabeledContent("Stand", value: Format.ago(position.date))
                } else {
                    Text("Noch kein Standort bekannt.")
                        .foregroundStyle(.secondary)
                }
                if let tracker = vehicle.data.trackerId.flatMap({ lage.trackers[$0] }) {
                    LabeledContent("GPS-Tracker", value: "\(tracker.data.name) (\(tracker.data.providerTitle))")
                }
            }
        }
        .navigationTitle(vehicle.data.funkrufname)
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
    @State private var showsDelete = false

    init(context: VehicleEditorContext) {
        self.context = context
        _vehicle = State(initialValue: context.vehicle)
    }

    private var callsignValid: Bool {
        !vehicle.funkrufname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Funkrufname, z. B. P 35/24", text: $vehicle.funkrufname)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Kennzeichen", text: $vehicle.kennzeichen)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Beschreibung, z. B. Golf grau, Dachbox", text: $vehicle.bezeichnung, axis: .vertical)
                        .lineLimit(1...4)
                    PhotoField(title: "Fahrzeugbild", blobId: $vehicle.fotoBlob)
                } footer: {
                    if !vehicle.funkrufname.isEmpty, Callsign.normalize(vehicle.funkrufname) == nil {
                        Text("Empfohlen ist das Format „P 35/24“.")
                    }
                }

                Section {
                    Toggle("Im heutigen Einsatz", isOn: $vehicle.aktiv)
                    Picker("GPS-Tracker", selection: $vehicle.trackerId) {
                        Text("Keiner").tag(String?.none)
                        ForEach(lage.trackers.values.sorted { $0.data.name < $1.data.name }) { tracker in
                            Text("\(tracker.data.name) (\(tracker.data.providerTitle))").tag(String?.some(tracker.id))
                        }
                    }
                } footer: {
                    Text("Mit Tracker meldet das Fahrzeug seinen Standort selbst, auch wenn niemand eingetragen ist.")
                }

                if !context.isNew {
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
                        .disabled(!callsignValid)
                }
            }
            .alert("Fahrzeug für alle löschen?", isPresented: $showsDelete) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    lage.delete(Vehicle.self, id: context.id)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        var result = vehicle
        result.funkrufname = Callsign.normalize(result.funkrufname) ?? result.funkrufname.trimmingCharacters(in: .whitespaces)
        // Früher getrennte Beschreibung mit übernehmen, damit nichts verloren geht.
        let parts = [result.bezeichnung, result.beschreibung].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        result.bezeichnung = String(parts.joined(separator: ", ").prefix(300))
        result.beschreibung = ""
        if lage.put(result, id: context.id) { dismiss() }
    }
}
