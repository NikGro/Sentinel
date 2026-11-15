import MapKit
import SwiftUI

/// Ziele (Personen, Fahrzeuge, Objekte): jederzeit schnell aufrufbar, von allen bearbeitbar.
struct TargetListScreen: View {
    @Environment(LageStore.self) private var lage
    @State private var editing: TargetEditorContext?

    var body: some View {
        NavigationStack {
            List {
                ForEach(lage.sortedTargets) { target in
                    NavigationLink(value: target.id) {
                        TargetRow(target: target)
                    }
                }
            }
            .overlay {
                if lage.targets.isEmpty {
                    ContentUnavailableView {
                        Label("Keine Ziele", systemImage: "person.crop.rectangle.stack")
                    } description: {
                        Text("Zielpersonen, Zielfahrzeuge und Zielobjekte lassen sich hier oder über das Plus auf der Karte anlegen. Alle im Einsatz sehen und bearbeiten dieselben Angaben.")
                    } actions: {
                        Button("Zielperson anlegen") { editing = TargetEditorContext(id: LageStore.newId(), target: Target(art: .person), isNew: true) }
                            .buttonStyle(.glassProminent)
                    }
                }
            }
            .navigationTitle("Ziele")
            .navigationDestination(for: String.self) { id in
                TargetDetail(targetId: id)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(ZielArt.allCases) { art in
                            Button(art.title, systemImage: art.symbolName) {
                                editing = TargetEditorContext(id: LageStore.newId(), target: Target(art: art), isNew: true)
                            }
                        }
                    } label: {
                        Label("Ziel anlegen", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editing) { context in
                TargetEditor(context: context)
            }
        }
    }
}

struct TargetEditorContext: Identifiable {
    let id: String
    let target: Target
    let isNew: Bool
}

private struct TargetRow: View {
    let target: Versioned<Target>
    @Environment(LageStore.self) private var lage

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(blobId: target.data.fotoBlob) {
                ZStack {
                    Theme.target.opacity(0.2)
                    Image(systemName: target.data.art.symbolName)
                        .foregroundStyle(Theme.target)
                }
            }
            .frame(width: 52, height: 64)
            .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(target.data.displayName)
                    .font(.headline)
                if let age = target.data.age() {
                    Text("\(age) Jahre")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !target.data.kennzeichen.isEmpty {
                    Text(target.data.kennzeichen)
                        .font(.caption.monospaced().weight(.semibold))
                }
                if let position = lage.position(ofTarget: target) {
                    Label(position.fromTracker ? "Tracker aktiv" : "Standort gesetzt", systemImage: position.fromTracker ? "dot.radiowaves.left.and.right" : "mappin")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

/// Vollständiges Profil eines Ziels.
struct TargetDetail: View {
    let targetId: String
    /// Standort auf der Karte neu setzen; nur verfügbar, wenn die Detailansicht über der Karte liegt.
    var placeOnMap: ((String) -> Void)?

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @State private var editing: TargetEditorContext?

    var body: some View {
        if let target = lage.targets[targetId] {
            content(target)
        } else {
            ContentUnavailableView("Ziel wurde entfernt", systemImage: "person.slash")
        }
    }

    private func content(_ entity: Versioned<Target>) -> some View {
        let target = entity.data
        return List {
            Section {
                HStack(alignment: .top, spacing: 16) {
                    RemoteImage(blobId: target.fotoBlob) {
                        ZStack {
                            Theme.target.opacity(0.2)
                            Image(systemName: target.art.symbolName)
                                .font(.largeTitle)
                                .foregroundStyle(Theme.target)
                        }
                    }
                    .frame(width: 110, height: 140)
                    .clipShape(.rect(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(target.displayName)
                            .font(.title3.weight(.bold))
                        Text(target.art.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.target)
                        if let birthDate = target.birthDate, let age = target.age() {
                            Text("\(birthDate.formatted(date: .numeric, time: .omitted)), \(age) Jahre")
                                .font(.subheadline)
                        }
                        if !target.geburtsort.isEmpty {
                            Text("geb. in \(target.geburtsort)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if !target.staatsangehoerigkeit.isEmpty {
                            Text(target.staatsangehoerigkeit)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            Section("Standort") {
                if let position = lage.position(ofTarget: entity) {
                    LabeledContent(position.fromTracker ? "Tracker" : "Von Hand gesetzt", value: Format.ago(position.date))
                    Button("Hinführen", systemImage: "location.north.line.fill") {
                        model.navigate(to: .target(entity.id))
                        dismiss()
                    }
                } else {
                    Text("Kein Standort bekannt.")
                        .foregroundStyle(.secondary)
                }
                if let placeOnMap, target.trackerId == nil {
                    Button(target.standort == nil ? "Standort auf Karte setzen" : "Standort neu setzen", systemImage: "hand.tap") {
                        placeOnMap(entity.id)
                        dismiss()
                    }
                }
            }

            if !target.anschrift.isEmpty || target.art == .objekt {
                Section("Anschrift") {
                    if !target.anschrift.isEmpty {
                        Text(target.anschrift)
                            .textSelection(.enabled)
                    }
                    LookAroundCard(address: target.anschrift, point: lage.position(ofTarget: entity)?.point)
                }
            }
            TextSection(title: "Optische Merkmale", text: target.merkmale)

            if !target.kennzeichen.isEmpty || !target.fahrzeugBeschreibung.isEmpty || target.fahrzeugFotoBlob != nil {
                Section("Fahrzeug") {
                    if !target.kennzeichen.isEmpty {
                        LabeledContent("Kennzeichen") {
                            Text(target.kennzeichen)
                                .font(.body.monospaced().weight(.semibold))
                        }
                    }
                    if !target.fahrzeugBeschreibung.isEmpty { Text(target.fahrzeugBeschreibung) }
                    if target.fahrzeugFotoBlob != nil {
                        RemoteImage(blobId: target.fahrzeugFotoBlob) { Color.secondary.opacity(0.15) }
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }
            }

            TextSection(title: "Sachverhalt", text: target.sachverhalt)
            TextSection(title: "Hinweise", text: target.hinweise)
            TextSection(title: "Zu treffende Maßnahmen", text: target.massnahmen)

            Section {
                Text("Zuletzt geändert von \(lage.name(of: entity.updatedBy)), \(Format.ago(entity.updatedDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(target.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Bearbeiten") { editing = TargetEditorContext(id: entity.id, target: target, isNew: false) }
            }
        }
        .sheet(item: $editing) { context in
            TargetEditor(context: context)
        }
    }
}

private struct TextSection: View {
    let title: String
    let text: String

    var body: some View {
        if !text.isEmpty {
            Section(title) {
                Text(text)
                    .textSelection(.enabled)
            }
        }
    }
}

struct TargetEditor: View {
    let context: TargetEditorContext

    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @State private var target: Target
    @State private var hasBirthDate: Bool
    @State private var birthDate: Date
    @State private var showsDelete = false

    init(context: TargetEditorContext) {
        self.context = context
        _target = State(initialValue: context.target)
        _hasBirthDate = State(initialValue: context.target.birthDate != nil)
        _birthDate = State(initialValue: context.target.birthDate ?? Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Art", selection: $target.art) {
                        ForEach(ZielArt.allCases) { art in
                            Label(art.title, systemImage: art.symbolName).tag(art)
                        }
                    }
                    if target.art != .person {
                        TextField(target.art == .fahrzeug ? "Bezeichnung, z. B. BMW 3er dunkelblau" : "Bezeichnung, z. B. Wohnung Musterstraße", text: $target.bezeichnung)
                    }
                    if target.standort != nil {
                        HStack {
                            Label("Standort von Hand gesetzt", systemImage: "mappin")
                            Spacer()
                            Button("Entfernen", role: .destructive) { target.standort = nil }
                                .buttonStyle(.borderless)
                        }
                    }
                }

                Section(target.art == .person ? "Person" : "Personenbezug (optional)") {
                    TextField("Vorname", text: $target.vorname)
                    TextField("Nachname", text: $target.nachname)
                    Toggle("Geburtsdatum bekannt", isOn: $hasBirthDate.animation())
                    if hasBirthDate {
                        DatePicker("Geburtsdatum", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                    }
                    TextField("Geburtsort", text: $target.geburtsort)
                    TextField("Staatsangehörigkeit", text: $target.staatsangehoerigkeit)
                    TextField("Anschrift", text: $target.anschrift, axis: .vertical)
                        .lineLimit(1...3)
                    PhotoField(title: "Bild", blobId: $target.fotoBlob)
                }

                Section("Optische Merkmale") {
                    TextField("Größe, Statur, Haare, Kleidung …", text: $target.merkmale, axis: .vertical)
                        .lineLimit(2...8)
                }

                Section("Fahrzeug") {
                    TextField("Kennzeichen", text: $target.kennzeichen)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Beschreibung", text: $target.fahrzeugBeschreibung, axis: .vertical)
                        .lineLimit(1...4)
                    PhotoField(title: "Fahrzeugbild", blobId: $target.fahrzeugFotoBlob)
                }

                Section("Sachverhalt") {
                    TextField("Sachverhalt", text: $target.sachverhalt, axis: .vertical)
                        .lineLimit(3...12)
                }
                Section("Hinweise") {
                    TextField("Hinweise, Eigensicherung", text: $target.hinweise, axis: .vertical)
                        .lineLimit(2...10)
                }
                Section("Zu treffende Maßnahmen") {
                    TextField("Maßnahmen", text: $target.massnahmen, axis: .vertical)
                        .lineLimit(2...10)
                }

                Section {
                    Picker("GPS-Tracker", selection: $target.trackerId) {
                        Text("Keiner").tag(String?.none)
                        ForEach(lage.trackers.values.sorted { $0.data.name < $1.data.name }) { tracker in
                            Text("\(tracker.data.name) (\(tracker.data.providerTitle))").tag(String?.some(tracker.id))
                        }
                    }
                } footer: {
                    Text("Tracker werden unter Mehr, Tracker verwaltet. Mit Tracker erscheint das Ziel live auf der Karte; der von Hand gesetzte Standort tritt dann zurück.")
                }

                if !context.isNew {
                    Section {
                        Button("Ziel löschen", systemImage: "trash", role: .destructive) { showsDelete = true }
                    }
                }
            }
            .navigationTitle(context.isNew ? "Neu: \(target.art.title)" : "\(target.art.title) bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(target.vorname.isEmpty && target.nachname.isEmpty && target.merkmale.isEmpty && target.bezeichnung.isEmpty && target.kennzeichen.isEmpty && target.anschrift.isEmpty)
                }
            }
            .confirmationDialog("Ziel für alle löschen?", isPresented: $showsDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    lage.delete(Target.self, id: context.id)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        var result = target
        result.birthDate = hasBirthDate ? birthDate : nil
        if lage.put(result, id: context.id) { dismiss() }
    }
}

/// Look-Around-Vorschau (Straßenansicht von Apple Karten) für eine Anschrift oder einen Standort, sofern Apple dort Aufnahmen hat.
struct LookAroundCard: View {
    let address: String
    let point: GeoPoint?

    @State private var scene: MKLookAroundScene?
    @State private var loaded = false

    var body: some View {
        Group {
            if let scene {
                LookAroundPreview(initialScene: scene)
                    .frame(height: 180)
                    .clipShape(.rect(cornerRadius: 12))
            } else if loaded {
                Label("Keine Straßenansicht verfügbar", systemImage: "binoculars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .task(id: "\(address)|\(point?.lat ?? 0)|\(point?.lon ?? 0)") {
            loaded = false
            scene = await Self.loadScene(address: address, point: point)
            loaded = true
        }
    }

    private static func loadScene(address: String, point: GeoPoint?) async -> MKLookAroundScene? {
        var coordinate = point?.coordinate
        if coordinate == nil, !address.isEmpty {
            let placemarks = try? await CLGeocoder().geocodeAddressString(address)
            coordinate = placemarks?.first?.location?.coordinate
        }
        guard let coordinate else { return nil }
        return try? await MKLookAroundSceneRequest(coordinate: coordinate).scene
    }
}
