import SwiftUI

/// Editor-Abschnitte für ÖPNV-Linie und ÖPNV-Fahrzeug: Linie suchen (in der Nähe oder per Name), Richtung wählen,
/// Start- und Endhalt antippen, Abfahrt und Takt festlegen. Schreibt Halte und Linie direkt in die Markierung.
struct TransitObjectSection: View {
    @Binding var object: MapObject
    /// Ort, an dem angelegt wurde: dort werden Linien vorgeschlagen und der nächste Halt als Start gewählt.
    let origin: GeoPoint?

    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var hits: [LineHit] = []
    @State private var line: TransitLine?
    @State private var start = 0
    @State private var end = 0
    @State private var choosingEnd = false
    @State private var isLoading = false
    @State private var failure: String?

    private var isVehicle: Bool { object.typ == .oepnvfahrzeug }

    /// Ebenen der Strecke als Auswahl für die Pillen; mindestens eine bleibt an.
    private var layers: Binding<Set<TransitLayerPart>> {
        Binding(
            get: {
                let choice = object.ebenen ?? TransitLayerChoice()
                return Set(TransitLayerPart.allCases.filter { choice[keyPath: $0.keyPath] })
            },
            set: { parts in
                guard !parts.isEmpty else { return }
                var choice = TransitLayerChoice()
                for part in TransitLayerPart.allCases { choice[keyPath: part.keyPath] = parts.contains(part) }
                object.ebenen = choice
                // Mit Strecke oder Haltestellen bleibt sie stehen; nur das Fahrzeug verschwindet nach der Ankunft.
                if choice.strecke || choice.halte { object.ablauf = nil }
            }
        )
    }

    var body: some View {
        if object.fahrt != nil || (object.linie != nil && object.linie?.id.allSatisfy(\.isNumber) == false) {
            // Aus der ÖPNV-Karte übernommen: Halte und Zeiten kommen aus dem Fahrplan, nichts von Hand einzustellen.
            Section("Echte Fahrt") {
                if let ref = object.linie {
                    HStack(spacing: 10) {
                        LineBadge(line: ref.badge, size: 15)
                        Text("Richtung \(ref.richtung)")
                    }
                }
                if let names = object.haltNamen, let first = names.first, let last = names.last {
                    LabeledContent("Strecke", value: "\(first) → \(last)")
                }
                // Ebenen der Strecke, jederzeit änderbar.
                if object.typ == .oepnvlinie {
                    PillPicker(items: TransitLayerPart.allCases, selection: layers, title: \.title, symbol: \.symbol, minimum: 1)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
                Text("Zeiten und Verspätungen führt der Server laufend nach (Transitous).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if object.linie == nil || (line == nil && isLoading) {
            search
        } else {
            chosenLine
            if let line, isVehicle { stops(line) }
            if !isVehicle, let names = object.haltNamen, let first = names.first, let last = names.last {
                Section("Strecke") {
                    LabeledContent("Ganze Linie", value: "\(first) → \(last)")
                    LabeledContent("Halte", value: "\(names.count)")
                }
            }
            timing
        }
        if let failure {
            Section { Label(failure, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
        }
    }

    // MARK: Linie suchen

    private var search: some View {
        Section {
            TextField("Liniennummer suchen, z. B. 369, U3, S1", text: $query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
            if isLoading { ProgressView() }
            ForEach(hits) { hit in
                Button {
                    Task { await choose(hit) }
                } label: {
                    HStack(spacing: 12) {
                        LineBadge(line: hit.badge, size: 15)
                            .frame(minWidth: 52, alignment: .leading)
                        Text("Richtung \(hit.richtung)")
                            .lineLimit(2)
                        Spacer()
                        if let meter = hit.meter {
                            Text(Format.distance(meter)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
        } header: {
            Text(query.isEmpty ? "Linien in der Nähe" : "Linien")
        } footer: {
            Text("Jede Fahrtrichtung ist ein eigener Eintrag.")
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(250))
            await searchLines()
        }
    }

    private func searchLines() async {
        guard let client = model.client else { return }
        do {
            hits = try await client.lines(query: query, near: origin).lines
            failure = hits.isEmpty && !query.isEmpty ? "Keine passende Linie gefunden." : nil
        } catch {
            // Abgebrochen heißt nur: Eingabe geändert, neue Suche läuft. Kein Fehler.
            if Task.isCancelled || (error as? URLError)?.code == .cancelled || error is CancellationError { return }
            failure = "Linien konnten nicht geladen werden."
        }
    }

    private func choose(_ hit: LineHit) async {
        object.linie = TransitRef(id: hit.id, ref: hit.ref, typ: hit.typ, richtung: hit.richtung, farbe: hit.farbe)
        object.farbe = LineBadge.routeHex(hit.badge)
        await load(hit.id, fresh: true)
    }

    private func load(_ id: String, fresh: Bool) async {
        guard let client = model.client else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await client.line(id: id)
            line = loaded
            if fresh {
                let anchor = origin ?? object.punkte.first
                start = anchor.flatMap { a in loaded.halte.indices.min { loaded.halte[$0].point.distance(to: a) < loaded.halte[$1].point.distance(to: a) } } ?? 0
                // ÖPNV-Linie: immer die ganze Linie von Anfang bis Ende.
                if !isVehicle { start = 0 }
                end = loaded.halte.count - 1
                if start >= loaded.halte.count - 1 { start = max(0, loaded.halte.count - 2) }
                if object.titel.isEmpty { object.titel = "\(loaded.ref) → \(loaded.nach)" }
            } else if let first = object.punkte.first, let last = object.punkte.last {
                // Bestehenden Abschnitt in der geladenen Linie wiederfinden.
                start = loaded.halte.firstIndex { $0.point.distance(to: first) < 30 } ?? 0
                end = loaded.halte.lastIndex { $0.point.distance(to: last) < 30 } ?? loaded.halte.count - 1
            }
            apply()
            failure = nil
        } catch {
            failure = "Linie konnte nicht geladen werden."
        }
    }

    private func apply() {
        guard let line, line.halte.count >= 2 else { return }
        let last = line.halte.count - 1
        let lower = min(min(start, end), last - 1)
        let upper = min(max(max(start, end), lower + 1), last)
        let section = Array(line.halte[lower...upper])
        object.punkte = section.map(\.point)
        object.haltNamen = section.map(\.name)
        // Fahrweg zwischen Start- und Endhalt ausschneiden.
        let path = line.path
        if let indices = TransitSimulation.stopIndices([section[0].point, section[section.count - 1].point], on: path), indices[0] < indices[1] {
            object.weg = Array(path[indices[0]...indices[1]])
        } else {
            object.weg = nil
        }
        updateExpiry()
    }

    /// Ein Fahrzeug löscht sich fünf Minuten nach der geschätzten Ankunft am letzten Halt.
    private func updateExpiry() {
        guard isVehicle, let ref = object.linie, let departure = object.since else { return }
        let end = departure.addingTimeInterval(TransitSimulation.duration(object.punkte, typ: ref.typ, path: object.weg ?? []) + 300)
        object.ablauf = (end.timeIntervalSince1970 * 1000).rounded()
    }

    // MARK: Gewählte Linie

    private var chosenLine: some View {
        Section("Linie") {
            if let ref = object.linie {
                HStack(spacing: 12) {
                    LineBadge(line: ref.badge, size: 15)
                        .frame(minWidth: 52, alignment: .leading)
                    Text("Richtung \(ref.richtung)")
                        .lineLimit(2)
                    Spacer()
                    Button("Andere Linie") {
                        object.linie = nil
                        line = nil
                        hits = []
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .task(id: object.linie?.id) {
            if let id = object.linie?.id, line?.id != id { await load(id, fresh: false) }
        }
    }

    private func stops(_ line: TransitLine) -> some View {
        Section {
            if !isVehicle {
                Picker("Antippen setzt", selection: $choosingEnd) {
                    Text("Start").tag(false)
                    Text("Ende").tag(true)
                }
                .pickerStyle(.segmented)
            }
            ForEach(Array(line.halte.enumerated()), id: \.offset) { index, stop in
                let lower = min(start, end), upper = max(start, end)
                let inside = index >= lower && index <= upper
                Button {
                    if choosingEnd, !isVehicle { end = index } else {
                        start = index
                        if isVehicle { end = line.halte.count - 1 } else if end <= start { end = min(start + 5, line.halte.count - 1) }
                        if !isVehicle { choosingEnd = true }
                    }
                    apply()
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(inside ? Color(hex: object.transitHex) : Color.secondary.opacity(0.25))
                            .frame(width: 10, height: 10)
                        Text(stop.name.isEmpty ? "Halt \(index + 1)" : stop.name)
                            .foregroundStyle(inside ? .primary : .secondary)
                        Spacer()
                        if index == lower { Text("Start").font(.caption.weight(.bold)).foregroundStyle(.tint) }
                        if index == upper { Text("Ende").font(.caption.weight(.bold)).foregroundStyle(.tint) }
                    }
                }
                .tint(.primary)
            }
        } header: {
            Text("Halte (\(object.punkte.count) gewählt)")
        } footer: {
            Text(isVehicle ? "Halt antippen, an dem das Fahrzeug abfährt; es fährt bis zur Endhaltestelle." : "Start und Ende antippen; angezeigt werden alle Halte dazwischen.")
        }
    }

    // MARK: Abfahrt und Takt

    private var departureBinding: Binding<Date> {
        Binding(
            get: { object.since ?? .now },
            set: {
                object.zeit = ($0.timeIntervalSince1970 * 1000).rounded()
                updateExpiry()
            }
        )
    }

    @ViewBuilder private var timing: some View {
        if isVehicle {
            Section {
                HStack {
                    DatePicker("Abfahrt am Start", selection: departureBinding, displayedComponents: [.hourAndMinute])
                    Button("Jetzt") { departureBinding.wrappedValue = .now }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                }
                if let ref = object.linie, let departure = object.since {
                    LabeledContent("Ankunft Endhalt", value: Format.time(departure.addingTimeInterval(TransitSimulation.duration(object.punkte, typ: ref.typ, path: object.weg ?? []))))
                }
            } footer: {
                Text("Die Position wird nach typischem Tempo geschätzt (keine Echtzeitdaten). Das Fahrzeug löscht sich nach der Ankunft selbst.")
            }
        } else {
            Section {
                Toggle("Fahrzeuge im Takt einblenden", isOn: Binding(
                    get: { object.takt != nil },
                    set: { on in
                        object.takt = on ? 10 : nil
                        if on, object.zeit == nil { object.zeit = (Date.now.timeIntervalSince1970 * 1000).rounded() }
                    }
                ))
                if let takt = object.takt {
                    Stepper("Alle \(takt) Minuten", value: Binding(get: { takt }, set: { object.takt = $0 }), in: 2...60)
                    DatePicker("Eine Abfahrt am Start", selection: departureBinding, displayedComponents: [.hourAndMinute])
                }
            } footer: {
                Text("Eingeblendete Fahrzeuge sind nach Takt und typischem Tempo geschätzt (keine Echtzeitdaten). Antippen legt eines als ÖPNV-Fahrzeug an.")
            }
        }
    }
}

/// Ebene einer ÖPNV-Strecke, für die Pillen-Auswahl.
enum TransitLayerPart: String, CaseIterable, Identifiable {
    case fahrzeug, strecke, halte

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fahrzeug: "Fahrzeug"
        case .strecke: "Strecke"
        case .halte: "Haltestellen"
        }
    }

    var symbol: String {
        switch self {
        case .fahrzeug: "bus.fill"
        case .strecke: "point.bottomleft.forward.to.point.topright.scurvepath"
        case .halte: "h.circle.fill"
        }
    }

    var keyPath: WritableKeyPath<TransitLayerChoice, Bool> {
        switch self {
        case .fahrzeug: \.fahrzeug
        case .strecke: \.strecke
        case .halte: \.halte
        }
    }
}
