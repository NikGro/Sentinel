import SwiftUI

/// Eigenes Profil anlegen oder bearbeiten.
struct ProfileEditor: View {
    enum Mode {
        case create, edit
    }

    let mode: Mode

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var callsign = ""
    @State private var unit = ""
    @State private var phone = ""
    @State private var photo: String?
    @State private var showsContactPicker = false
    @State private var showsSignOut = false
    @State private var didLoad = false

    // Optionales erstes Fahrzeug (nur beim Anlegen).
    @State private var addsVehicle = false
    @State private var vehicleName = ""
    @State private var vehiclePlate = ""
    @State private var vehicleDescription = ""
    @State private var vehiclePhoto: String?

    private var normalizedCallsign: String? { Callsign.normalize(callsign) }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !unit.trimmingCharacters(in: .whitespaces).isEmpty
            && normalizedCallsign != nil
            && (!addsVehicle || !vehicleTitle.isEmpty)
    }

    private var vehicleTitle: String {
        let explicit = vehicleName.trimmingCharacters(in: .whitespaces)
        return explicit.isEmpty ? vehiclePlate.trimmingCharacters(in: .whitespaces) : explicit
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textContentType(.name)
                TextField("Funkrufname, z. B. P 35/24", text: $callsign)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("Dienststelle", text: $unit)
            } header: {
                Text("Pflichtangaben")
            } footer: {
                if !callsign.isEmpty, normalizedCallsign == nil {
                    Text("Funkrufname: 1 bis 3 Buchstaben, 1 bis 3 Ziffern, Schrägstrich, 1 bis 3 Ziffern.")
                        .foregroundStyle(.red)
                }
            }

            Section {
                PhotoField(title: "Profilbild", blobId: $photo)
                HStack {
                    TextField("Handynummer", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    Button("Aus Kontakten", systemImage: "person.crop.circle.badge.plus") { showsContactPicker = true }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Nummer aus Kontakten übernehmen")
                }
            } header: {
                Text("Optional")
            } footer: {
                Text("Tipp: Über das Kontakte-Symbol die eigene Karte wählen, dann wird die Nummer übernommen. Die Tastatur schlägt die eigene Nummer ebenfalls vor.")
            }

            if mode == .create {
                Section {
                    Toggle("Fahrzeug gleich mit anlegen", isOn: $addsVehicle.animation())
                    if addsVehicle {
                        TextField("Bezeichnung, z. B. Golf grau", text: $vehicleName)
                        TextField("Kennzeichen", text: $vehiclePlate)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        TextField("Beschreibung", text: $vehicleDescription, axis: .vertical)
                            .lineLimit(1...4)
                        PhotoField(title: "Fahrzeugbild", blobId: $vehiclePhoto)
                    }
                } header: {
                    Text("Fahrzeug")
                } footer: {
                    Text("Fahrzeuge sind eigene Objekte: Sie steigen ein und aus, das Fahrzeug bleibt am Ort des Aussteigens stehen. Weitere Fahrzeuge unter „Team“.")
                }
            } else {
                Section {
                    Button("Dieses Gerät abmelden", role: .destructive) { showsSignOut = true }
                }
            }
        }
        .navigationTitle(mode == .create ? "Profil anlegen" : "Profil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(mode == .create ? "Fertig" : "Sichern", action: save)
                    .disabled(!isValid)
            }
            if mode == .create {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abmelden") { showsSignOut = true }
                }
            }
        }
        .sheet(isPresented: $showsContactPicker) {
            ContactNumberPicker { phone = PhoneNumber.sanitize($0) }
                .ignoresSafeArea()
        }
        .confirmationDialog("Dieses Gerät vom Server abmelden?", isPresented: $showsSignOut, titleVisibility: .visible) {
            Button("Abmelden", role: .destructive) { model.signOut() }
        } message: {
            Text("Alle Einsatzdaten werden von diesem Gerät entfernt. Für eine erneute Anmeldung wird der Zugangscode benötigt.")
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !didLoad, let me = lage.me?.data else { return }
        didLoad = true
        name = me.name
        callsign = me.funkrufname
        unit = me.dienststelle
        phone = me.telefon
        photo = me.fotoBlob
    }

    private func save() {
        guard let selfId = lage.selfId, let normalizedCallsign else { return }
        let member = Member(
            name: name.trimmingCharacters(in: .whitespaces),
            funkrufname: normalizedCallsign,
            dienststelle: unit.trimmingCharacters(in: .whitespaces),
            telefon: PhoneNumber.sanitize(phone),
            fotoBlob: photo,
            fahrzeugId: lage.me?.data.fahrzeugId
        )
        guard lage.put(member, id: selfId) else { return }
        if mode == .create, addsVehicle {
            let vehicleId = LageStore.newId()
            let vehicle = Vehicle(
                bezeichnung: vehicleTitle,
                kennzeichen: vehiclePlate.trimmingCharacters(in: .whitespaces),
                beschreibung: vehicleDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                fotoBlob: vehiclePhoto
            )
            if lage.put(vehicle, id: vehicleId) { lage.board(vehicleId: vehicleId) }
        }
        if mode == .edit { dismiss() }
    }
}
