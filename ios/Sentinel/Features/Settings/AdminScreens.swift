import SwiftUI

// Verwaltung in der App. Dieselben Funktionen wie in der Kommandozentrale, damit nichts nur im Browser geht.

/// Lädt den Verwaltungsstand vom Server und zeigt Fehler einheitlich an.
@MainActor
@Observable
final class AdminState {
    private(set) var status: APIClient.AdminStatus?
    var failure: String?
    var busy = false

    func reload(_ client: APIClient?) async {
        guard let client else { return }
        do {
            status = try await client.adminStatus()
        } catch {
            failure = error.localizedDescription
        }
    }

    func run(_ client: APIClient?, _ action: @escaping (APIClient) async throws -> Void) async {
        guard let client else { return }
        busy = true
        defer { busy = false }
        do {
            try await action(client)
            status = try await client.adminStatus()
        } catch {
            failure = error.localizedDescription
        }
    }
}

private struct FailureAlert: ViewModifier {
    @Bindable var state: AdminState

    func body(content: Content) -> some View {
        content.alert("Hinweis", isPresented: Binding(get: { state.failure != nil }, set: { if !$0 { state.failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.failure ?? "")
        }
    }
}

// MARK: Funkkanal, Einsatzinformationen, Lage zurücksetzen

struct SituationAdminScreen: View {
    @Environment(LageStore.self) private var lage
    @State private var title = ""
    @State private var notes = ""
    @State private var showsChannel = false
    @State private var showsReset = false
    @State private var resetTargets = false

    var body: some View {
        Form {
            Section("Funkkanal") {
                Button {
                    showsChannel = true
                } label: {
                    LabeledContent("Kanal", value: lage.operation.funkkanal ?? "nicht gesetzt")
                }
                .tint(.primary)
            }
            Section("Einsatzinformationen") {
                TextField("Titel", text: $title)
                TextField("Auftrag, Treffpunkt, Eigensicherung …", text: $notes, axis: .vertical)
                    .lineLimit(4...12)
                Button("Für alle übernehmen") {
                    lage.setSituation(title: String(title.prefix(80)), notes: String(notes.prefix(4000)))
                }
                .disabled(title == lage.operation.titel && notes == lage.operation.hinweise)
            }
            Section {
                Button("Bestreifung zurücksetzen", role: .destructive) { lage.resetCoverage() }
                Toggle("Ziele ebenfalls löschen", isOn: $resetTargets)
                Button("Lage zurücksetzen", role: .destructive) { showsReset = true }
            } header: {
                Text("Lage abschließen")
            } footer: {
                Text("Entfernt Markierungen der laufenden Lage, geladene Pakete, Chatnachrichten und Bestreifung. Dauerhafte Orte, Profile, Fahrzeuge, Tracker und Chaträume bleiben.")
            }
        }
        .navigationTitle("Einsatz")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            title = lage.operation.titel
            notes = lage.operation.hinweise
        }
        .sheet(isPresented: $showsChannel) {
            ChannelEditor(current: lage.operation.funkkanal)
                .presentationDetents([.height(260)])
        }
        .alert("Lage für alle zurücksetzen?", isPresented: $showsReset) {
            Button("Abbrechen", role: .cancel) {}
            Button("Zurücksetzen", role: .destructive) { lage.resetSituation(includingTargets: resetTargets) }
        } message: {
            Text("Das kann nicht rückgängig gemacht werden.")
        }
    }
}

// MARK: Ebenen, Pakete, Argus Predict

struct LayersAdminScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @State private var state = AdminState()
    @State private var newPackage = ""
    @State private var argusProject = ""
    @State private var argusDay = Date.now
    @State private var argusFrom = Calendar.current.component(.hour, from: .now)
    @State private var argusTo = 23
    @State private var argusTop = 40
    @State private var argusDraft = false

    var body: some View {
        Form {
            Section {
                ForEach(lage.sortedLayers) { layer in
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(layer.data.name)
                                Text("\(objectCount(layer.id)) Objekte\(layer.data.isLive ? "" : ", Entwurf")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: layer.data.symbolName)
                        }
                        Spacer()
                        if layer.id != Layer.lageId, layer.id != Layer.dauerhaftId {
                            Button(layer.data.isLive ? "Zurückziehen" : "Laden") {
                                var next = layer.data
                                next.status = layer.data.isLive ? "entwurf" : "live"
                                lage.put(next, id: layer.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .swipeActions {
                        if layer.id != Layer.lageId, layer.id != Layer.dauerhaftId {
                            Button("Löschen", systemImage: "trash", role: .destructive) { lage.delete(Layer.self, id: layer.id) }
                        }
                    }
                }
            } header: {
                Text("Ebenen")
            } footer: {
                Text("Entwürfe sind vorbereitet, aber noch auf keiner Karte zu sehen. „Laden“ zeigt sie allen im Einsatz.")
            }

            Section {
                TextField("Name, z. B. Einsatz Dienstag", text: $newPackage)
                Button("Paket anlegen") {
                    let name = newPackage.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    lage.put(Layer(name: String(name.prefix(60)), art: "paket", status: "entwurf"), id: "paket-\(LageStore.newId().prefix(10))")
                    newPackage = ""
                }
                .disabled(newPackage.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("Paket vorbereiten")
            } footer: {
                Text("In einem Paket gesetzte Markierungen bleiben verborgen, bis es geladen wird. Ebene beim Anlegen einer Markierung wählen.")
            }

            Section {
                if let argus = state.status?.argus, argus.verfuegbar, !argus.projekte.isEmpty {
                    Picker("Projekt", selection: $argusProject) {
                        ForEach(argus.projekte) { Text($0.name).tag($0.name) }
                    }
                    DatePicker("Tag", selection: $argusDay, displayedComponents: .date)
                    Stepper("Von \(argusFrom) Uhr", value: $argusFrom, in: 0...23)
                    Stepper("Bis \(argusTo) Uhr", value: $argusTo, in: argusFrom...23)
                    Stepper("\(argusTop) Zellen", value: $argusTop, in: 5...150, step: 5)
                    Toggle("Zunächst als Entwurf", isOn: $argusDraft)
                    Button("Importieren") {
                        let day = Self.dayFormat.string(from: argusDay)
                        Task {
                            await state.run(model.client) { client in
                                _ = try await client.importArgus(project: argusProject, day: day, fromHour: argusFrom, toHour: argusTo, top: argusTop, asDraft: argusDraft)
                            }
                        }
                    }
                    .disabled(argusProject.isEmpty || state.busy)
                } else {
                    Text(state.status == nil ? "Lade …" : "Argus Predict ist auf diesem Server nicht eingebunden.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Argus Predict")
            } footer: {
                Text("Lädt die auffälligsten Prognosezellen eines Tages als eigene Ebene, z. B. für die Oberflächenfahndung.")
            }
        }
        .navigationTitle("Ebenen und Pakete")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await state.reload(model.client)
            if argusProject.isEmpty { argusProject = state.status?.argus.projekte.first?.name ?? "" }
        }
        .modifier(FailureAlert(state: state))
    }

    private func objectCount(_ layerId: String) -> Int {
        lage.mapObjects.values.filter { $0.data.layerId == layerId }.count
    }

    private static let dayFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: GPS-Tracker

struct TrackersAdminScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @State private var state = AdminState()
    @State private var renaming: Versioned<Tracker>?
    @State private var newName = ""
    @State private var addName = ""
    @State private var addProvider = "sinotrack"
    @State private var addId = ""
    @State private var pajEmail = ""
    @State private var pajPassword = ""
    @State private var pajDevices: [APIClient.PajDevice] = []

    private var trackers: [Versioned<Tracker>] { lage.trackers.values.sorted { $0.data.name < $1.data.name } }

    var body: some View {
        Form {
            Section {
                if trackers.isEmpty {
                    Text("Noch kein Tracker angelegt.")
                        .foregroundStyle(.secondary)
                }
                ForEach(trackers) { tracker in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tracker.data.name)
                                    .font(.headline)
                                Text("\(tracker.data.providerTitle), \(tracker.data.kennung)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Text(lage.trackerPositions[tracker.id].map { "Letzte Position \(Format.ago($0.date))" } ?? "Noch keine Position empfangen")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Menu {
                                Button("Umbenennen", systemImage: "pencil") {
                                    newName = tracker.data.name
                                    renaming = tracker
                                }
                                Button("Löschen", systemImage: "trash", role: .destructive) { lage.delete(Tracker.self, id: tracker.id) }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                            }
                        }
                        if tracker.data.anbieter == "sinotrack" {
                            Picker("Sendeintervall", selection: Binding(
                                get: { tracker.data.intervall ?? 0 },
                                set: { if $0 > 0 { lage.setTrackerInterval(tracker.id, seconds: $0) } }
                            )) {
                                Text("Unverändert").tag(0)
                                ForEach([10, 20, 30, 60, 120, 300, 600], id: \.self) { seconds in
                                    Text(seconds < 60 ? "\(seconds) s" : "\(seconds / 60) min").tag(seconds)
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                }
            } header: {
                Text("Tracker")
            } footer: {
                Text("Zugeordnet werden Tracker beim Ziel, beim Fahrzeug oder bei einem Marker. Das Intervall wird an SinoTrack-Geräte geschickt, sobald sie verbunden sind; PAJ-Geräte stellt man im PAJ-Portal ein.")
            }

            Section("Tracker anlegen") {
                TextField("Name, z. B. ST-901 Nr. 3", text: $addName)
                Picker("Anbieter", selection: $addProvider) {
                    Text("SinoTrack (direkt)").tag("sinotrack")
                    Text("PAJ").tag("paj")
                }
                TextField(addProvider == "paj" ? "Geräte-ID im PAJ-Portal" : "Geräte-ID (auf dem Tracker)", text: $addId)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Anlegen") {
                    add(name: addName, provider: addProvider, id: addId)
                    addName = ""
                    addId = ""
                }
                .disabled(addName.trimmingCharacters(in: .whitespaces).isEmpty || addId.wholeMatch(of: #/[0-9A-Za-z-]{4,32}/#) == nil)
            }

            if let status = state.status {
                Section {
                    if status.tracker.h02Port > 0 {
                        Text("SMS an die SIM des Trackers (Standardpasswort 0000):")
                        Text("8040000 \(model.credentials?.serverURL.host() ?? "server") \(status.tracker.h02Port)\n8030000 <APN>\n8050000 20")
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                        ForEach(status.tracker.unbekannt) { unknown in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(unknown.kennung)
                                        .font(.body.monospaced())
                                    Text("hat sich gemeldet, \(Format.ago(Date(timeIntervalSince1970: unknown.zuletzt / 1000)))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Übernehmen") { add(name: "SinoTrack \(unknown.kennung.suffix(4))", provider: "sinotrack", id: unknown.kennung) }
                                    .buttonStyle(.bordered)
                            }
                        }
                    } else {
                        Text("Der Tracker-Empfang ist auf diesem Server abgeschaltet.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("SinoTrack direkt")
                } footer: {
                    Text("Die Tracker senden direkt an den eigenen Server, ohne Hersteller-Server. Voraussetzung ist die Portweiterleitung am Router.")
                }

                Section {
                    if status.tracker.paj.aktiv {
                        Label("Verbunden", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        if let error = status.tracker.paj.fehler {
                            Text("Letzter Fehler: \(error)")
                                .foregroundStyle(.red)
                        }
                        Button("Geräte abrufen") {
                            Task { await state.run(model.client) { client in pajDevices = try await client.pajDevices() } }
                        }
                        ForEach(pajDevices) { device in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                    Text(device.kennung)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !trackers.contains(where: { $0.data.anbieter == "paj" && $0.data.kennung == device.kennung }) {
                                    Button("Übernehmen") { add(name: device.name, provider: "paj", id: device.kennung) }
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                        Button("Zugang entfernen", role: .destructive) {
                            Task { await state.run(model.client) { try await $0.removePaj() } }
                        }
                    } else {
                        TextField("E-Mail des PAJ-Kontos", text: $pajEmail)
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                        SecureField("Passwort", text: $pajPassword)
                            .textContentType(.password)
                        Button("Verbinden") {
                            let email = pajEmail
                            let password = pajPassword
                            Task {
                                await state.run(model.client) { try await $0.configurePaj(email: email, password: password) }
                                pajPassword = ""
                            }
                        }
                        .disabled(pajEmail.isEmpty || pajPassword.isEmpty)
                    }
                } header: {
                    Text("PAJ-Portal")
                } footer: {
                    Text("PAJ-Tracker melden sich nur beim Hersteller; Sentinel holt die Positionen dort alle 20 Sekunden ab. Die Zugangsdaten werden verschlüsselt auf dem Server gespeichert.")
                }
            }
        }
        .navigationTitle("GPS-Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .task { await state.reload(model.client) }
        .refreshable { await state.reload(model.client) }
        .modifier(FailureAlert(state: state))
        .alert("Tracker umbenennen", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Sichern") {
                if var tracker = renaming?.data, let id = renaming?.id, !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                    tracker.name = String(newName.trimmingCharacters(in: .whitespaces).prefix(60))
                    lage.put(tracker, id: id)
                }
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    private func add(name: String, provider: String, id: String) {
        lage.put(Tracker(name: String(name.trimmingCharacters(in: .whitespaces).prefix(60)), anbieter: provider, kennung: id.trimmingCharacters(in: .whitespaces)), id: LageStore.newId())
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await state.reload(model.client)
        }
    }
}

// MARK: Geräte und Zugangscode

struct DevicesAdminScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @State private var state = AdminState()
    @State private var showsCode = false
    @State private var deviceToRevoke: APIClient.AdminStatus.Device?

    var body: some View {
        Form {
            if let status = state.status {
                Section {
                    HStack {
                        Text(showsCode ? status.zugangscode : "••••••••••")
                            .font(.title3.monospaced())
                            .textSelection(.enabled)
                        Spacer()
                        Button(showsCode ? "Verbergen" : "Anzeigen") { showsCode.toggle() }
                            .buttonStyle(.bordered)
                    }
                    Button("Neuen Zugangscode erzeugen", role: .destructive) {
                        Task { await state.run(model.client) { _ = try await $0.rotateJoinCode() } }
                    }
                } header: {
                    Text("Zugangscode")
                } footer: {
                    Text("Mit diesem Code meldet sich ein neues Gerät einmalig an. Angemeldete Geräte bleiben beim Erneuern verbunden.")
                }

                Section {
                    ForEach(status.geraete.filter { !$0.revoked }) { device in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lage.members[device.id]?.data.spitzname ?? "Ohne Profil")
                                    .font(.headline)
                                Text("\(device.name), zuletzt \(Format.ago(Date(timeIntervalSince1970: device.lastSeen / 1000)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if device.id == lage.selfId {
                                Text("Dieses Gerät")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button("Sperren", role: .destructive) { deviceToRevoke = device }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                } header: {
                    Text("Angemeldete Geräte")
                } footer: {
                    Text("Sperren trennt das Gerät sofort und entfernt dessen Profil aus der Lage.")
                }

                Section("App-Verteilung") {
                    Text(status.sidestoreQuelle)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                    if let release = status.release {
                        LabeledContent("Aktuelle Version", value: "\(release.version) (\(release.build))")
                    }
                    if let oepnv = status.oepnv {
                        LabeledContent("ÖPNV-Linien", value: oepnv.linien > 0 ? "\(oepnv.linien) Fahrtrichtungen" : (oepnv.fehler ?? "werden geladen"))
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Geräte")
        .navigationBarTitleDisplayMode(.inline)
        .task { await state.reload(model.client) }
        .refreshable { await state.reload(model.client) }
        .modifier(FailureAlert(state: state))
        .alert(
            "Gerät „\(deviceToRevoke?.name ?? "")“ sperren?",
            isPresented: Binding(get: { deviceToRevoke != nil }, set: { if !$0 { deviceToRevoke = nil } })
        ) {
            Button("Abbrechen", role: .cancel) {}
            Button("Sperren", role: .destructive) {
                if let id = deviceToRevoke?.id { Task { await state.run(model.client) { try await $0.revokeDevice(id) } } }
            }
        }
    }
}
