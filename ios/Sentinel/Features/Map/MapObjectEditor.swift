import SwiftUI

/// Markierung benennen, gestalten, verschieben oder löschen. Jeder darf jede Markierung bearbeiten.
struct MapObjectEditor: View {
    let context: EditorContext
    /// Startet das Verschieben per Tipp auf die Karte.
    let startMoving: (String) -> Void

    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var object: MapObject
    @State private var radiusText: String
    /// Schnellwahl „vor x Minuten“; `nil`, sobald die Zeit von Hand gesetzt wurde.
    @State private var minutesAgo: Int? = 0
    /// Beim neuen Fahndungsraum: Haltestellen im Umkreis gleich mit anzeigen.
    @State private var addsStops = false
    @State private var stopsRadius = 500.0
    /// Lebensdauer in Sekunden ab dem Sichern; 0 unbegrenzt, -1 den bisherigen Ablauf behalten.
    @State private var lifetime: Int

    private static let lifetimes: [(seconds: Int, title: String)] = [
        (0, "Unbegrenzt"), (900, "15 Minuten"), (1800, "30 Minuten"), (3600, "1 Stunde"), (7200, "2 Stunden"),
        (14_400, "4 Stunden"), (28_800, "8 Stunden"), (43_200, "12 Stunden"), (86_400, "24 Stunden"),
        (259_200, "3 Tage"), (604_800, "7 Tage"),
    ]

    init(context: EditorContext, startMoving: @escaping (String) -> Void) {
        self.context = context
        self.startMoving = startMoving
        _object = State(initialValue: context.object)
        _radiusText = State(initialValue: context.object.radius.map { String(Int($0)) } ?? "")
        _lifetime = State(initialValue: context.object.ablauf == nil ? 0 : -1)
    }

    private var availableLayers: [Versioned<Layer>] {
        lage.sortedLayers.filter { $0.data.art != "argus" && settings.canEdit(layerId: $0.id) }
    }

    private var locked: Bool { !settings.canEdit(layerId: context.object.layerId) }

    private var sinceBinding: Binding<Date> {
        Binding(
            get: { object.since ?? .now },
            set: {
                object.zeit = (min($0, .now).timeIntervalSince1970 * 1000).rounded()
                minutesAgo = nil
            }
        )
    }

    var body: some View {
        NavigationStack {
            if locked { lockedView } else { form }
        }
    }

    private var lockedView: some View {
        List {
            NavigateHereSection {
                model.navigate(to: .object(context.id))
                dismiss()
            }
            Section {
                Label("Dauerhafte Orte sind gesperrt", systemImage: "lock.fill")
                Text("Zum Bearbeiten unter Mehr „Dauerhafte Orte bearbeiten“ einschalten.")
                    .foregroundStyle(.secondary)
            }
            if !object.notiz.isEmpty { Section("Notiz") { Text(object.notiz) } }
            if let attachments = object.anhaenge, !attachments.isEmpty {
                AttachmentsSection(attachments: .constant(attachments), editable: false)
            }
        }
        .navigationTitle(object.titel.isEmpty ? object.typ.title : object.titel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }
            }
        }
    }

    private var form: some View {
            // Navigieren steht in der Übersicht der Markierung, nicht in den Einstellungen.
            Form {
                if object.typ == .fahndungsraum {
                    Section {
                        DatePicker("Datum und Uhrzeit", selection: sinceBinding, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach([0, 5, 10, 15, 30, 45, 60], id: \.self) { minutes in
                                // Einmalige Aktion: setzt die Zeit, bleibt aber nicht ausgewählt.
                                Button {
                                    minutesAgo = minutes
                                    object.zeit = (Date.now.addingTimeInterval(TimeInterval(-minutes * 60)).timeIntervalSince1970 * 1000).rounded()
                                } label: {
                                    Text(minutes == 0 ? "Jetzt" : "vor \(minutes)")
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .tint(.accentColor)
                                .accessibilityLabel(minutes == 0 ? "Jetzt" : "vor \(minutes) Minuten")
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Letzte Sichtung")
                    } footer: {
                        Text("Knöpfe: Minuten vor jetzt. Ab diesem Zeitpunkt wächst der Raum, in dem sich die Zielperson zu Fuß, mit dem ÖPNV oder dem Fahrzeug befinden kann.")
                    }

                    if context.isNew {
                        Section {
                            Toggle("Haltestellen im Umkreis", systemImage: "bus.fill", isOn: $addsStops)
                            if addsStops {
                                Picker("Umkreis", selection: $stopsRadius) {
                                    ForEach([300.0, 500, 1000, 2000], id: \.self) { meter in
                                        Text(Format.distance(meter)).tag(meter)
                                    }
                                }
                            }
                        } footer: {
                            Text("Zeigt zusätzlich alle Bus- und Bahnhaltestellen rund um den Ort der letzten Sichtung.")
                        }
                    }
                }

                if object.typ.isTransit {
                    TransitObjectSection(object: $object, origin: context.object.punkte.first)
                }
                if object.typ == .haltestelle {
                    StopMatchSection(object: $object)
                }

                Section {
                    TextField(object.typ == .text ? "Text" : "Bezeichnung", text: $object.titel)
                    TextField("Notiz", text: $object.notiz, axis: .vertical)
                        .lineLimit(1...5)
                }

                if ![.text, .haltestellen, .fahndungsraum, .geofence, .verlauf].contains(object.typ) {
                    AttachmentsSection(attachments: Binding(get: { object.anhaenge ?? [] }, set: { object.anhaenge = $0 }))
                }

                if object.isOwnTrack {
                    // Einstellung der Standortspur: Farbe nach Alter oder nach Häufigkeit (über alle Fahnder).
                    Section {
                        Picker("Farbe nach", selection: Binding(
                            get: { object.ownTrackByFrequency },
                            set: { object.symbol = $0 ? MapObject.ownTrackFrequencySymbol : MapObject.ownTrackSymbol }
                        )) {
                            Text("Alter").tag(false)
                            Text("Häufigkeit").tag(true)
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Standortspur")
                    } footer: {
                        Text(object.ownTrackByFrequency
                             ? "Blau einmal gefahren, Rot fünfmal und öfter; Fahrten aller Fahnder mit Standortspur zählen zusammen."
                             : "Blau alt, Rot neu.")
                    }
                }

                if !object.isOwnTrack {
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

                if object.typ == .haltestellen {
                    Section("Umkreis") {
                        HStack(spacing: 12) {
                            Slider(
                                value: Binding(
                                    get: { min(max(Double(radiusText) ?? 500, 100), 3000) },
                                    set: { radiusText = String(Int(($0 / 50).rounded() * 50)) }
                                ),
                                in: 100...3000
                            )
                            TextField("Meter", text: $radiusText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 64)
                            Text("m")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if object.typ == .geofence {
                    GeofenceSection(object: $object, radiusText: $radiusText)
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

                if object.typ != .oepnvfahrzeug {
                Section {
                    Picker("Lebensdauer", systemImage: "timer", selection: $lifetime) {
                        if let expiry = context.object.expiry {
                            Text("Bis \(Format.dateTime(expiry))").tag(-1)
                        }
                        ForEach(Self.lifetimes.indices, id: \.self) { index in
                            Text(Self.lifetimes[index].title).tag(Self.lifetimes[index].seconds)
                        }
                    }
                } footer: {
                    Text(lifetime == 0 ? "Bleibt, bis sie jemand löscht." : "Löscht sich danach von selbst, damit die Karte übersichtlich bleibt.")
                }
                }

                if !context.isNew {
                    Section {
                        if !object.typ.isTransit {
                        Button("Auf der Karte verschieben", systemImage: "arrow.up.and.down.and.arrow.left.and.right") {
                                startMoving(context.id)
                                dismiss()
                            }
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
                        .disabled(
                            (object.typ == .text && object.titel.trimmingCharacters(in: .whitespaces).isEmpty)
                                || (object.typ.isTransit && (object.linie == nil || object.punkte.count < 2))
                                || (object.typ == .geofence && (object.ziele ?? []).isEmpty)
                        )
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
        if result.typ == .kreis || (result.typ == .geofence && result.radius != nil) {
            result.radius = min(max(Double(radiusText) ?? 150, 5), 100_000)
        }
        if result.typ == .haltestellen {
            result.radius = min(max(Double(radiusText) ?? 500, 50), 5000)
        }
        switch object.typ == .oepnvfahrzeug ? -1 : lifetime {
        case -1: break
        case 0: result.ablauf = nil
        default: result.ablauf = (Date.now.addingTimeInterval(TimeInterval(lifetime)).timeIntervalSince1970 * 1000).rounded()
        }
        lage.saveMapObject(result, id: context.id)
        if context.isNew, result.typ == .fahndungsraum, addsStops, let point = result.punkte.first {
            var stops = MapObject(layerId: result.layerId, typ: .haltestellen, titel: "Haltestellen", farbe: "#0A84FF", punkte: [point], radius: stopsRadius)
            stops.ablauf = result.ablauf
            lage.saveMapObject(stops, id: LageStore.newId())
        }
        dismiss()
    }
}

/// Geofence: Auslöser, überwachte Ziele und Radius.
private struct GeofenceSection: View {
    @Binding var object: MapObject
    @Binding var radiusText: String
    @Environment(LageStore.self) private var lage

    private var selected: Set<String> { Set(object.ziele ?? []) }

    var body: some View {
        Section {
            Picker("Alarm beim", selection: Binding(get: { object.ausloeser ?? "verlassen" }, set: { object.ausloeser = $0 })) {
                Text("Verlassen").tag("verlassen")
                Text("Betreten").tag("betreten")
            }
            .pickerStyle(.segmented)
            if object.radius != nil {
                HStack {
                    Text("Radius")
                    Spacer()
                    TextField("Meter", text: $radiusText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("m").foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Alarm")
        } footer: {
            Text(object.alarmsOnEntry
                 ? "Betritt eines der Ziele den Bereich, bekommen alle in der Instanz einen Alarm."
                 : "Verlässt eines der Ziele den Bereich, bekommen alle in der Instanz einen Alarm.")
        }
        Section {
            if lage.sortedTargets.isEmpty {
                Text("Noch keine Ziele angelegt.").foregroundStyle(.secondary)
            }
            ForEach(lage.sortedTargets) { target in
                Button {
                    var next = selected
                    if next.contains(target.id) { next.remove(target.id) } else { next.insert(target.id) }
                    object.ziele = lage.sortedTargets.map(\.id).filter(next.contains)
                } label: {
                    HStack {
                        Label(target.data.displayName, systemImage: target.data.art.symbolName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selected.contains(target.id) {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .accessibilityAddTraits(selected.contains(target.id) ? .isSelected : [])
            }
        } header: {
            Text("Überwachte Ziele")
        } footer: {
            Text("Ausgewertet auf dem Server, der Alarm erreicht alle Verbundenen in der Instanz.")
        }
        .onAppear { if object.ausloeser == nil { object.ausloeser = "verlassen" } }
    }
}

/// Haltestelle von Hand gesetzt: echte Haltestellen in der Nähe vorschlagen und eine davon übernehmen.
private struct StopMatchSection: View {
    @Binding var object: MapObject
    @Environment(AppModel.self) private var model
    @State private var nearby: [NearbyStop] = []
    @State private var loaded = false

    var body: some View {
        Section {
            if !loaded {
                ProgressView()
            } else if nearby.isEmpty {
                Text("Keine bekannte Haltestelle in der Nähe.")
                    .foregroundStyle(.secondary)
            }
            ForEach(nearby.prefix(8)) { stop in
                Button {
                    object.titel = stop.name
                    object.punkte = [stop.point]
                    if let line = stop.linien.first {
                        object.linie = TransitRef(id: "", ref: line.ref, typ: line.typ, richtung: "", farbe: line.farbe)
                    }
                } label: {
                    HStack(spacing: 10) {
                        StationSymbol(lines: stop.linien, size: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stop.name)
                            LineBadges(lines: stop.linien)
                        }
                        Spacer()
                        Text(Format.distance(stop.meter))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if object.titel == stop.name {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .tint(.primary)
            }
        } header: {
            Text("Echte Haltestelle zuordnen")
        } footer: {
            Text("Übernimmt Name, genaue Lage und Linien der gewählten Haltestelle.")
        }
        .task {
            guard let point = object.punkte.first, let client = model.client else { loaded = true; return }
            nearby = (try? await client.stops(near: point, radius: 400)) ?? []
            loaded = true
        }
    }
}
