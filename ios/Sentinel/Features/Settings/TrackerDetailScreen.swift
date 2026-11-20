import SwiftUI

/// Alles zu einem Tracker: Zustand (so weit er ihn meldet), Einstellungen, Befehle per Datenverbindung und SMS,
/// Zuordnungen, Verlauf und die zuletzt empfangenen Nachrichten.
struct TrackerDetailScreen: View {
    let trackerId: String
    /// Port des Tracker-Empfangs auf dem Server (für den SMS-Befehl „Server setzen“).
    var h02Port: Int?

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var status: TrackerStatus?
    @State private var receiving = true
    @State private var name = ""
    @State private var phone = ""
    @State private var pin = ""
    @State private var apn = ""
    @State private var customCommand = ""
    @State private var interval = 30
    @State private var busy = false
    @State private var message: String?
    @State private var confirmsDelete = false

    private var tracker: Versioned<Tracker>? { lage.trackers[trackerId] }

    var body: some View {
        if let tracker {
            content(tracker)
        } else {
            ContentUnavailableView("Tracker wurde entfernt", systemImage: "sensor.tag.radiowaves.forward")
        }
    }

    private func content(_ tracker: Versioned<Tracker>) -> some View {
        Form {
            stateSection(tracker.data)
            deviceSection(tracker)
            usageSection
            if tracker.data.isSinoTrack {
                commandSection(tracker.data)
                smsSection(tracker.data)
            }
            messagesSection
            Section {
                Button("Tracker löschen", systemImage: "trash", role: .destructive) { confirmsDelete = true }
            } footer: {
                Text("Ziele an diesem Tracker bleiben an seiner letzten Position stehen.")
            }
        }
        .navigationTitle(tracker.data.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = tracker.data.name
            phone = tracker.data.telefon ?? ""
            pin = tracker.data.smsPin ?? ""
            interval = tracker.data.intervall ?? 30
        }
        .task {
            // Zustand laufend nachladen, solange die Ansicht offen ist.
            while !Task.isCancelled {
                await reload()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .alert("Hinweis", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
        .confirmationDialog("Tracker löschen?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                lage.delete(Tracker.self, id: trackerId)
                dismiss()
            }
        }
    }

    // MARK: Zustand

    @ViewBuilder private func stateSection(_ tracker: Tracker) -> some View {
        Section {
            if let status {
                if tracker.isSinoTrack {
                    LabeledContent("Verbindung") {
                        Text(status.verbunden ? "Meldet sich" : "Keine Meldung seit 2 Min.")
                            .foregroundStyle(status.verbunden ? Color.green : Color.secondary)
                    }
                }
                LabeledContent("Letzter Kontakt", value: status.lastContact.map { "\(Format.time($0)), \(Format.ago($0))" } ?? "noch keiner")
                if let fix = status.position {
                    LabeledContent("Letzte Position", value: Format.ago(fix.date))
                    if let speed = fix.spd {
                        LabeledContent("Geschwindigkeit", value: "\(Int((speed * 3.6).rounded())) km/h")
                    }
                }
                if let gps = status.gps {
                    LabeledContent("GPS", value: gps ? "Empfang" : "Kein Empfang")
                }
                if let akku = status.akku {
                    LabeledContent("Akku") {
                        Text("\(akku) %" + (status.spannung.map { String(format: " (%.1f V)", $0).replacingOccurrences(of: ".", with: ",") } ?? ""))
                            .foregroundStyle(akku < 20 ? Color.red : Color.secondary)
                    }
                }
                if let signal = status.signal {
                    LabeledContent("Mobilfunk", value: "\(signal) %")
                }
                if let satellites = status.satelliten {
                    LabeledContent("Satelliten", value: "\(satellites)")
                }
                if let ignition = status.zuendung {
                    LabeledContent("Zündung", value: ignition ? "An" : "Aus")
                }
                if let powerCut = status.stromAus {
                    LabeledContent("Stromversorgung", value: powerCut ? "Unterbrochen (Akku)" : "Angeschlossen")
                }
                if let alarm = status.alarm {
                    Label(alarm, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                if let raw = status.statusRoh {
                    LabeledContent("Statuswort", value: raw)
                        .font(.footnote.monospaced())
                }
            } else {
                ProgressView()
            }
        } header: {
            Text("Zustand")
        } footer: {
            Text(tracker.isSinoTrack
                ? "Akku, Empfang und Satelliten melden SinoTrack-Geräte in eigenen Statusnachrichten, Zündung und Stromversorgung im Statuswort. Nicht jedes Modell meldet alles; was fehlt, kam vom Gerät noch nicht."
                : "PAJ meldet Position und, je nach Gerät, den Akkustand über das PAJ-Portal.")
        }
    }

    // MARK: Gerät

    private func deviceSection(_ tracker: Versioned<Tracker>) -> some View {
        Section("Gerät") {
            TextField("Name", text: $name)
                .onSubmit { save { $0.name = String(name.trimmingCharacters(in: .whitespaces).prefix(60)) } }
            LabeledContent("Anbieter", value: tracker.data.providerTitle)
            LabeledContent("Kennung") {
                Text(tracker.data.kennung)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }
            if let email = tracker.data.kontoEmail, !email.isEmpty {
                LabeledContent("PAJ-Konto", value: email)
            }
            if tracker.data.isSinoTrack {
                TextField("Rufnummer der SIM-Karte", text: $phone)
                    .keyboardType(.phonePad)
                    .onSubmit { save { $0.telefon = phone.trimmingCharacters(in: .whitespaces) } }
                TextField("SMS-PIN (ab Werk 0000)", text: $pin)
                    .keyboardType(.numberPad)
                    .onSubmit { save { $0.smsPin = pin.trimmingCharacters(in: .whitespaces) } }
            }
            Toggle("Verlauf aufzeichnen", isOn: Binding(
                get: { tracker.data.records },
                set: { on in save { $0.aufzeichnung = on } }
            ))
            HistoryButton(subject: SpurSubject(art: .tracker, id: tracker.id))
            if name != tracker.data.name || phone != (tracker.data.telefon ?? "") || pin != (tracker.data.smsPin ?? "") {
                Button("Änderungen sichern", systemImage: "checkmark") {
                    save {
                        $0.name = String(name.trimmingCharacters(in: .whitespaces).prefix(60))
                        $0.telefon = phone.trimmingCharacters(in: .whitespaces)
                        $0.smsPin = pin.trimmingCharacters(in: .whitespaces)
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    /// Wo der Tracker gerade steckt: Ziele, Fahrzeuge, Marker.
    @ViewBuilder private var usageSection: some View {
        let targets = lage.sortedTargets.filter { $0.data.trackerId == trackerId }
        let vehicles = lage.vehicles.values.filter { $0.data.trackerId == trackerId }
        let markers = lage.mapObjects.values.filter { $0.data.trackerId == trackerId }
        Section {
            if targets.isEmpty, vehicles.isEmpty, markers.isEmpty {
                Text("Keinem Ziel, Fahrzeug oder Marker zugeordnet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(targets) { Label($0.data.displayName, systemImage: $0.data.art.symbolName) }
            ForEach(Array(vehicles)) { Label($0.data.funkrufname, systemImage: "car.fill") }
            ForEach(Array(markers)) { Label($0.data.titel.isEmpty ? $0.data.typ.title : $0.data.titel, systemImage: "mappin") }
        } header: {
            Text("Zugeordnet")
        } footer: {
            Text("Zuordnen beim Ziel (Standortquelle), beim Fahrzeug oder beim Marker.")
        }
    }

    // MARK: Befehle

    private func commandSection(_ tracker: Tracker) -> some View {
        Section {
            HStack {
                Picker("Sendeintervall", selection: $interval) {
                    ForEach([10, 20, 30, 60, 120, 300, 600], id: \.self) { seconds in
                        Text(seconds < 60 ? "\(seconds) s" : "\(seconds / 60) min").tag(seconds)
                    }
                }
                Button("Senden") { send(.init(art: "intervall", sekunden: interval)) }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
            Button("Alarm scharf schalten", systemImage: "lock.shield") { send(.init(art: "scharf")) }
            Button("Alarm unscharf schalten", systemImage: "lock.open") { send(.init(art: "unscharf")) }
            VStack(alignment: .leading, spacing: 6) {
                TextField("*HQ,\(tracker.kennung),…#", text: $customCommand, axis: .vertical)
                    .font(.callout.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Eigenen Befehl senden", systemImage: "paperplane") { send(.init(art: "eigen", text: customCommand)) }
                    .disabled(!customCommand.hasPrefix("*HQ,\(tracker.kennung),") || !customCommand.hasSuffix("#"))
            }
        } header: {
            Text("Befehle über die Datenverbindung")
        } footer: {
            Text(receiving
                ? "Geht sofort raus, wenn der Tracker verbunden ist, sonst mit seiner nächsten Meldung. Eigene Befehle im H02-Format, z. B. aus der Anleitung des Geräts. Die Motorsperre ist bewusst nicht enthalten."
                : "Der Tracker-Empfang ist auf dem Server abgeschaltet; Befehle gehen nur per SMS.")
        }
        .disabled(busy || !receiving)
    }

    /// SMS-Befehle der SinoTrack-Geräte (öffnen die Nachrichten-App mit vorbereitetem Text; vor dem Senden änderbar).
    private func smsSection(_ tracker: Tracker) -> some View {
        let devicePin = (tracker.smsPin ?? "").isEmpty ? "0000" : tracker.smsPin!
        let host = model.credentials?.serverURL.host() ?? "server"
        let number = (tracker.telefon ?? "").filter { $0.isNumber || $0 == "+" }
        let commands: [(String, String)] = [
            ("Server und Port setzen", "804\(devicePin) \(host) \(h02Port.map(String.init) ?? "<Port>")"),
            ("Datenverbindung (GPRS) an", "710\(devicePin)"),
            ("Sendeintervall \(interval) s", "805\(devicePin) \(interval)"),
            ("Einstellungen abfragen", "RCONF"),
        ]
        return Section {
            if number.isEmpty {
                Text("Rufnummer der SIM-Karte oben eintragen, dann lassen sich SMS-Befehle direkt verschicken.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(commands, id: \.1) { command in
                    Button {
                        sms(number, command.1)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(command.0)
                            Text(command.1)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                HStack {
                    TextField("APN des Mobilfunkanbieters", text: $apn)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("APN setzen") { sms(number, "803\(devicePin) \(apn)") }
                        .disabled(apn.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        } header: {
            Text("Befehle per SMS")
        } footer: {
            Text("Übliche SinoTrack-Befehle (ST-901/903). Die Nachrichten-App öffnet sich mit dem fertigen Text; vor dem Senden lässt er sich noch ändern. Die Antwort kommt per SMS auf dieses Telefon.")
        }
    }

    // MARK: Nachrichten

    @ViewBuilder private var messagesSection: some View {
        if let messages = status?.nachrichten, !messages.isEmpty {
            Section {
                ForEach(messages, id: \.self) { message in
                    VStack(alignment: .leading, spacing: 2) {
                        Label("\(message.richtung == "ein" ? "Vom Gerät" : "An das Gerät"), \(Format.time(message.date))",
                              systemImage: message.richtung == "ein" ? "arrow.down.circle" : "arrow.up.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(message.richtung == "ein" ? Color.secondary : Color.accentColor)
                        Text(message.text)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                }
            } header: {
                Text("Letzte Nachrichten")
            } footer: {
                Text("Rohdaten, wie sie am Server ankommen; nur bis zum nächsten Neustart des Servers.")
            }
        }
    }

    // MARK: Aktionen

    private func reload() async {
        guard let client = model.client, let result = try? await client.trackerStatus(id: trackerId) else { return }
        status = result.status
        receiving = result.empfang
    }

    private func save(_ change: (inout Tracker) -> Void) {
        guard var next = tracker?.data else { return }
        change(&next)
        lage.put(next, id: trackerId)
    }

    private func send(_ command: APIClient.TrackerCommand) {
        guard let client = model.client else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let immediate = try await client.sendTrackerCommand(id: trackerId, command)
                message = immediate ? "Befehl gesendet." : "Der Tracker ist gerade nicht verbunden; der Befehl geht mit seiner nächsten Meldung raus."
                await reload()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func sms(_ number: String, _ text: String) {
        var components = URLComponents()
        components.scheme = "sms"
        components.path = number
        components.queryItems = [URLQueryItem(name: "body", value: text)]
        // iOS erwartet „sms:NUMMER&body=…“.
        if let string = components.string?.replacingOccurrences(of: "?body=", with: "&body="), let url = URL(string: string) { openURL(url) }
    }
}
