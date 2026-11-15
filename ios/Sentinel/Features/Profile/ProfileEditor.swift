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
    @State private var nickname = ""
    @State private var unit = ""
    @State private var phone = ""
    @State private var photo: String?
    @State private var showsContactPicker = false
    @State private var showsSignOut = false
    @State private var didLoad = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !unit.trimmingCharacters(in: .whitespaces).isEmpty
            && !nickname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textContentType(.name)
                TextField("Spitzname", text: $nickname)
                    .autocorrectionDisabled()
                TextField("Dienststelle", text: $unit)
            } header: {
                Text("Pflichtangaben")
            } footer: {
                Text("Der Spitzname erscheint auf der Karte, solange Sie zu Fuß unterwegs sind. Im Fahrzeug steht dort dessen Funkrufname.")
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

            if mode == .edit {
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
        nickname = me.spitzname
        unit = me.dienststelle
        phone = me.telefon
        photo = me.fotoBlob
    }

    private func save() {
        guard let selfId = lage.selfId else { return }
        var member = lage.me?.data ?? Member(name: "", spitzname: "", dienststelle: "")
        member.name = name.trimmingCharacters(in: .whitespaces)
        member.spitzname = String(nickname.trimmingCharacters(in: .whitespaces).prefix(30))
        member.dienststelle = unit.trimmingCharacters(in: .whitespaces)
        member.telefon = PhoneNumber.sanitize(phone)
        member.fotoBlob = photo
        guard lage.put(member, id: selfId) else { return }
        if mode == .edit { dismiss() }
    }
}
