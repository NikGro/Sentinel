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
            Section {
                TextField("Auftrag, Treffpunkt, Eigensicherung …", text: $notes, axis: .vertical)
                    .lineLimit(4...12)
                    .clearable($notes)
                Button("Für alle übernehmen") {
                    lage.setSituation(title: String(title.prefix(80)), notes: String(notes.prefix(4000)))
                }
                .disabled(notes == lage.operation.hinweise)
            } header: {
                Text("Einsatzinformationen")
            } footer: {
                Text("Der Name der Lage ist der Name der Instanz; umbenennen unter Instanzen.")
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
    }
}

// MARK: Ebenen und Pakete

struct LayersAdminScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @State private var state = AdminState()
    @State private var importing: Versioned<Instance>?
    /// Ebene, deren Objekte nach Rückfrage gelöscht werden.
    @State private var clearing: Versioned<Layer>?

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
                        // Leeren bei jeder Ebene außer den dauerhaften Orten (die werden nur über das Hauptmenü bearbeitet).
                        if layer.id != Layer.dauerhaftId, objectCount(layer.id) > 0 {
                            Menu {
                                Button("Ebene leeren", systemImage: "trash", role: .destructive) { clearing = layer }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                            }
                            .accessibilityLabel("Weitere Aktionen für \(layer.data.name)")
                        }
                        if layer.id != Layer.lageId, layer.id != Layer.dauerhaftId {
                            Button(layer.data.isLive ? "Zurückziehen" : "Laden") {
                                var next = layer.data
                                next.status = layer.data.isLive ? "entwurf" : "live"
                                lage.put(next, id: layer.id)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                        }
                    }
                    .swipeActions {
                        if layer.id != Layer.lageId, layer.id != Layer.dauerhaftId {
                            Button("Löschen", systemImage: "trash", role: .destructive) { lage.delete(Layer.self, id: layer.id) }
                        }
                        if layer.id != Layer.dauerhaftId, objectCount(layer.id) > 0 {
                            Button("Leeren", systemImage: "eraser") { clearing = layer }
                                .tint(.orange)
                        }
                    }
                }
            } header: {
                Text("Ebenen")
            } footer: {
                Text("Entwürfe sind vorbereitet, aber noch auf keiner Karte zu sehen. „Laden“ zeigt sie allen im Einsatz.")
            }

            // Pakete entstehen über das Instanzenmenü; hier nur noch die Übernahme in den laufenden Einsatz.
            Section {
                if lage.packages.isEmpty {
                    Text("Noch keine Pakete in der Bibliothek.")
                        .foregroundStyle(.secondary)
                }
                ForEach(lage.packages) { package in
                    Button {
                        importing = package
                    } label: {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(package.data.name)
                                    if !package.data.beschreibung.isEmpty {
                                        Text(package.data.beschreibung)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            } icon: {
                                Image(systemName: "shippingbox.fill")
                            }
                            Spacer()
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(.tint)
                        }
                    }
                    .tint(.primary)
                    .disabled(lage.isPackageArea)
                }
            } header: {
                Text("Paket aus der Bibliothek importieren")
            } footer: {
                Text(lage.isPackageArea
                    ? "Gerade ist ein Paket geöffnet. Zum Importieren zuerst eine Einsatz-Instanz öffnen."
                    : "Kopiert alle Objekte des Pakets in „\(lage.currentInstance?.data.name ?? "diese Instanz")“. Pakete anlegen und bearbeiten über Instanzen › Pakete.")
            }

        }
        .navigationTitle("Ebenen und Pakete")
        .navigationBarTitleDisplayMode(.inline)
        .alert("„\(importing?.data.name ?? "")“ importieren?", isPresented: Binding(get: { importing != nil }, set: { if !$0 { importing = nil } })) {
            Button("Abbrechen", role: .cancel) {}
            Button("Importieren") {
                if let id = importing?.id { lage.importPackage(id) }
            }
        } message: {
            Text("Alle Objekte des Pakets werden in „\(lage.currentInstance?.data.name ?? "")“ kopiert und sind danach eigenständige Objekte dieser Instanz. Das lässt sich nicht rückgängig machen.")
        }
        .alert("„\(clearing?.data.name ?? "")“ leeren?", isPresented: Binding(get: { clearing != nil }, set: { if !$0 { clearing = nil } })) {
            Button("Abbrechen", role: .cancel) {}
            Button("Alle \(clearing.map { objectCount($0.id) } ?? 0) Objekte löschen", role: .destructive) {
                guard let layerId = clearing?.id, layerId != Layer.dauerhaftId else { return }
                for object in lage.mapObjects.values where object.data.layerId == layerId {
                    lage.deleteMapObject(id: object.id)
                }
            }
        } message: {
            Text("Alle Objekte dieser Ebene werden für alle in der Instanz gelöscht. Die Ebene selbst bleibt. Das lässt sich nicht rückgängig machen.")
        }
        .modifier(FailureAlert(state: state))
    }

    private func objectCount(_ layerId: String) -> Int {
        lage.mapObjects.values.filter { $0.data.layerId == layerId }.count
    }
}

// MARK: Argus Predict

/// Prognose aus Argus Predict laden. Sie wird als Paket abgelegt und lässt sich von dort gezielt in einen Einsatz
/// übernehmen, statt direkt auf einer Karte zu landen.
struct ArgusImportScreen: View {
    @Environment(AppModel.self) private var model
    @State private var state = AdminState()
    @State private var argusProject = ""
    @State private var argusDay = Date.now
    @State private var argusFrom = Calendar.current.component(.hour, from: .now)
    @State private var argusTo = 23
    @State private var argusTop = 40
    @State private var done: Int?

    var body: some View {
        Form {
            Section {
                if let argus = state.status?.argus, argus.verfuegbar, !argus.projekte.isEmpty {
                    Picker("Projekt", selection: $argusProject) {
                        ForEach(argus.projekte) { Text($0.name).tag($0.name) }
                    }
                    DatePicker("Tag", selection: $argusDay, displayedComponents: .date)
                    Stepper("Von \(argusFrom) Uhr", value: $argusFrom, in: 0...23)
                    Stepper("Bis \(argusTo) Uhr", value: $argusTo, in: argusFrom...23)
                    Stepper("\(argusTop) Zellen", value: $argusTop, in: 5...150, step: 5)
                    Button("Als Paket anlegen", systemImage: "shippingbox") {
                        let day = Self.dayFormat.string(from: argusDay)
                        Task {
                            await state.run(model.client) { client in
                                done = try await client.importArgus(project: argusProject, day: day, fromHour: argusFrom, toHour: argusTo, top: argusTop, asDraft: false)
                            }
                        }
                    }
                    .disabled(argusProject.isEmpty || state.busy)
                } else {
                    Text(state.status == nil ? "Lade …" : "Argus Predict ist auf diesem Server nicht eingebunden.")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Die auffälligsten Prognosezellen eines Tages, z. B. für die Oberflächenfahndung. Sie kommen als Paket unter „Paket vorbereiten“ und lassen sich von dort in einen Einsatz übernehmen.")
            }
        }
        .navigationTitle("Argus Predict")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Paket angelegt", isPresented: Binding(get: { done != nil }, set: { if !$0 { done = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(done ?? 0) Prognosezellen liegen jetzt als Paket unter „Paket vorbereiten“.")
        }
        .task {
            await state.reload(model.client)
            if argusProject.isEmpty { argusProject = state.status?.argus.projekte.first?.name ?? "" }
        }
        .modifier(FailureAlert(state: state))
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
    @State private var addEmail = ""
    @State private var addPassword = ""
    @State private var statuses: [String: TrackerStatus] = [:]
    @State private var editing: String?

    private var canAdd: Bool {
        guard !addName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if addProvider == "paj" {
            return addId.wholeMatch(of: #/[0-9]{1,15}/#) != nil && addEmail.contains("@") && !addPassword.isEmpty
        }
        return addId.wholeMatch(of: #/[0-9A-Za-z-]{4,32}/#) != nil
    }

    private func subtitle(of tracker: Tracker) -> String {
        let base = "\(tracker.providerTitle), \(tracker.kennung)"
        guard let email = tracker.kontoEmail, !email.isEmpty else { return base }
        return base + " · " + email
    }

    /// PAJ-Tracker mit eigenem Konto: Der Server prüft das Konto und legt den Tracker erst dann an.
    private func addPaj() {
        let name = String(addName.trimmingCharacters(in: .whitespaces).prefix(60))
        let id = addId.trimmingCharacters(in: .whitespaces)
        let email = addEmail.trimmingCharacters(in: .whitespaces)
        let password = addPassword
        Task {
            await state.run(model.client) { client in
                try await client.addPajTracker(id: LageStore.newId(), name: name, kennung: id, email: email, password: password)
                addName = ""
                addId = ""
                addPassword = ""
            }
        }
    }

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
                                Text(subtitle(of: tracker.data))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Text(lage.trackerPositions[tracker.id].map { "Letzte Position \(Format.ago($0.date))" } ?? "Noch keine Position empfangen")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let status = statuses[tracker.id] { TrackerStatusLine(status: status, sinoTrack: tracker.data.isSinoTrack) }
                            }
                            Spacer()
                            Menu {
                                Button("Bearbeiten", systemImage: "slider.horizontal.3") { editing = tracker.id }
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
                    }
                    .contentShape(.rect)
                    .onTapGesture { editing = tracker.id }
                }
            } header: {
                Text("Tracker")
            } footer: {
                Text("Antippen oder „Bearbeiten“ zeigt Zustand, Einstellungen und Befehle. Zugeordnet werden Tracker beim Ziel, beim Fahrzeug oder bei einem Marker.")
            }

            Section {
                TextField("Name, z. B. ST-901 Nr. 3", text: $addName)
                    .clearable($addName)
                Picker("Anbieter", selection: $addProvider) {
                    Text("SinoTrack (direkt)").tag("sinotrack")
                    Text("PAJ").tag("paj")
                }
                TextField(addProvider == "paj" ? "Geräte-ID im PAJ-Portal" : "Geräte-ID (auf dem Tracker)", text: $addId)
                    .keyboardType(addProvider == "paj" ? .numberPad : .asciiCapable)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .clearable($addId)
                if addProvider == "paj" {
                    TextField("E-Mail des PAJ-Kontos", text: $addEmail)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .clearable($addEmail)
                    SecureField("Passwort des PAJ-Kontos", text: $addPassword)
                        .textContentType(.password)
                }
                Button {
                    if addProvider == "paj" { addPaj() } else {
                        add(name: addName, provider: addProvider, id: addId)
                        addName = ""
                        addId = ""
                    }
                } label: {
                    if state.busy { ProgressView() } else { Text(addProvider == "paj" ? "Prüfen und anlegen" : "Anlegen") }
                }
                .disabled(!canAdd || state.busy)
            } header: {
                Text("Tracker anlegen")
            } footer: {
                if addProvider == "paj" {
                    Text("Jeder PAJ-Tracker gehört zu einem PAJ-Konto, meist dem des Fahnders. Die Zugangsdaten gelten nur für diesen Tracker und werden verschlüsselt auf dem Server gespeichert. Vorher wird geprüft, ob das Gerät zu diesem Konto gehört.")
                }
            }

            if let status = state.status {
                Section {
                    if status.tracker.h02Port > 0 {
                        LabeledContent("Empfang", value: "\(model.credentials?.serverURL.host() ?? "Server"), Port \(status.tracker.h02Port)")
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
                                    .buttonBorderShape(.capsule)
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
                                        .buttonBorderShape(.capsule)
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
                            .clearable($pajEmail)
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
        .task {
            // Zustand der Tracker (Akku, Verbindung) laufend aktualisieren.
            while !Task.isCancelled {
                if let result = try? await model.client?.trackerStatuses() { statuses = result }
                try? await Task.sleep(for: .seconds(15))
            }
        }
        .navigationDestination(item: $editing) { id in
            TrackerDetailScreen(trackerId: id)
        }
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
                            .buttonBorderShape(.capsule)
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
                                    .buttonBorderShape(.capsule)
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

/// Kurzer Zustand eines Trackers in der Liste: Verbindung, Akku, GPS.
struct TrackerStatusLine: View {
    let status: TrackerStatus
    let sinoTrack: Bool

    var body: some View {
        HStack(spacing: 10) {
            if sinoTrack {
                Label(status.verbunden ? "Meldet sich" : "Offline", systemImage: status.verbunden ? "circle.fill" : "circle")
                    .foregroundStyle(status.verbunden ? Color.green : Color.secondary)
            }
            if let akku = status.akku {
                Label("\(akku) %", systemImage: status.batterySymbol)
                    .foregroundStyle(akku < 20 ? Color.red : Color.secondary)
            }
            if let gps = status.gps, !gps {
                Label("Kein GPS", systemImage: "location.slash")
                    .foregroundStyle(.orange)
            }
            if let alarm = status.alarm {
                Label(alarm, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .labelStyle(.titleAndIcon)
    }
}
