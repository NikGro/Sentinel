import SentinelKern
import SwiftUI

/// Erste Einrichtung: Server und Zugangscode. Das Profil folgt nach erfolgreicher Anmeldung.
struct Einrichtung: View {
    @Environment(AppModell.self) private var modell
    @State private var server = ""
    @State private var code = ""
    @State private var fehler: String?
    @State private var laeuft = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 56))
                            .foregroundStyle(.tint)
                        Text("SENTINEL")
                            .font(.largeTitle.weight(.bold))
                            .tracking(4)
                        Text("Gemeinsame Lagekarte für Observation und Fahndung")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Serveradresse", text: $server)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("Serveradresse")
                    TextField("Zugangscode", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("Zugangscode")
                } footer: {
                    if let fehler { Text(fehler).foregroundStyle(.red) }
                }
                Section {
                    Button {
                        laeuft = true
                        fehler = nil
                        Task {
                            do { try await modell.anmelden(server: server, code: code) } catch { fehler = error.localizedDescription }
                            laeuft = false
                        }
                    } label: {
                        Group { if laeuft { ProgressView() } else { Text("Anmelden").font(.headline) } }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(laeuft || server.isEmpty || code.count < 4)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
        }
    }
}

/// Verbindungsaufbau; man kann sich abmelden (z. B. falscher Server).
struct Verbinde: View {
    @Environment(AppModell.self) private var modell

    var body: some View {
        VStack(spacing: 20) {
            ProgressView().controlSize(.large)
            Text("Verbinde mit dem Server …").font(.headline)
            Button("Abmelden", role: .destructive) { modell.abmelden() }
                .buttonStyle(.bordered)
        }
    }
}

/// Eigenes Profil anlegen (Name, Spitzname, Dienststelle, Handynummer).
struct ProfilAnlegen: View {
    @Environment(AppModell.self) private var modell
    @State private var name = ""
    @State private var spitzname = ""
    @State private var dienststelle = ""
    @State private var telefon = ""
    @State private var uebernahme: Versioniert<Fahnder>?
    @State private var fehler: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Spitzname", text: $spitzname)
                    TextField("Dienststelle", text: $dienststelle)
                    TextField("Handynummer", text: $telefon).keyboardType(.phonePad)
                } footer: {
                    Text("So sehen dich die anderen auf der Karte und in der Kräfteliste.")
                }
                // Bestehendes Profil übernehmen (etwa nach einem Gerätewechsel)
                let uebernehmbar = Kraefteansicht.shared.uebernehmbar(stand: modell.stand)
                if !uebernehmbar.isEmpty {
                    Section {
                        ForEach(uebernehmbar, id: \.id) { f in
                            Button { uebernahme = f } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.data.spitzname).foregroundStyle(.primary)
                                    Text([f.data.name, f.data.dienststelle].filter { !$0.isEmpty }.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let fehler { Text(fehler).foregroundStyle(.red) }
                    } header: { Text("Oder ein bestehendes Profil übernehmen") }
                }
            }
            .confirmationDialog("Profil übernehmen?", isPresented: Binding(get: { uebernahme != nil }, set: { if !$0 { uebernahme = nil } }), titleVisibility: .visible, presenting: uebernahme) { f in
                Button("Übernehmen") {
                    fehler = nil
                    Task {
                        do { try await modell.api?.profilUebernehmen(id: f.id) } catch { fehler = "Übernehmen fehlgeschlagen." }
                    }
                }
            } message: { f in
                Text("Dieses Gerät wird „\(f.data.spitzname)“. Das alte Gerät wird abgemeldet.")
            }
            .navigationTitle("Profil anlegen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        guard let id = modell.zugang?.geraetId else { return }
                        let profil = Fahnder(name: name, spitzname: spitzname, dienststelle: dienststelle, telefon: telefon, fotoBlob: nil, aktiv: true,
                                             fortbewegung: .fuss, fahrzeugId: nil, oepnv: nil, instanz: Instanz.companion.HAUPT, fahrzeugSeit: nil, aufzeichnung: true)
                        _ = modell.lage.setzen(art: .fahnder, id: id, daten: profil)
                    }
                    .disabled(name.isEmpty || spitzname.isEmpty || dienststelle.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abmelden", role: .destructive) { modell.abmelden() }
                }
            }
        }
    }
}
