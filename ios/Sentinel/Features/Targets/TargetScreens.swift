import MapKit
import SwiftUI

/// Ziele (Personen, Fahrzeuge, Objekte): jederzeit schnell aufrufbar, von allen bearbeitbar.
struct TargetListScreen: View {
    @Environment(LageStore.self) private var lage
    @State private var editing: TargetEditorContext?
    @State private var targetToDelete: Versioned<Target>?

    var body: some View {
        NavigationStack {
            List {
                ForEach(lage.sortedTargets) { target in
                    NavigationLink(value: target.id) {
                        TargetRow(target: target)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Löschen", systemImage: "trash", role: .destructive) {
                            lage.delete(Target.self, id: target.id)
                        }
                    }
                }
            }
            .alert(
                "„\(targetToDelete?.data.displayName ?? "")“ für alle löschen?",
                isPresented: Binding(get: { targetToDelete != nil }, set: { if !$0 { targetToDelete = nil } })
            ) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    if let target = targetToDelete { lage.delete(Target.self, id: target.id) }
                }
            } message: {
                Text("Das Ziel verschwindet bei allen Kräften und in der Kommandozentrale.")
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
/// Alle Fotos eines Ziels, auch aus älteren Einzelbildfeldern.
func allAttachments(_ target: Target) -> [ChatAttachment] {
    var copy = target
    copy.normalize()
    return copy.anhaenge
}

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
            if lage.position(ofTarget: entity) != nil {
                NavigateHereSection {
                    model.navigate(to: .target(entity.id))
                    dismiss()
                }
            }
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
            if !target.kennzeichen.isEmpty {
                Section {
                    LabeledContent(target.art == .person ? "Genutztes Fahrzeug" : "Kennzeichen") {
                        Text(target.kennzeichen)
                            .font(.body.monospaced().weight(.semibold))
                    }
                }
            }

            TextSection(title: "Notizen", text: target.notes)

            if !allAttachments(target).isEmpty {
                AttachmentsSection(attachments: .constant(allAttachments(target)), editable: false, marksTitlePhoto: true)
            }

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

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss
    @State private var target: Target
    /// Geburtsdatum als Text; leer heißt unbekannt.
    @State private var birthText: String
    @State private var showsDelete = false
    @State private var showsPicker = false
    @State private var isGeocoding = false
    @State private var locationFailure: String?

    init(context: TargetEditorContext) {
        self.context = context
        var target = context.target
        target.normalize()
        _target = State(initialValue: target)
        _birthText = State(initialValue: target.birthDateText)
    }

    private var birthDate: Date? { Target.parseBirthDate(birthText) }
    private var birthTextInvalid: Bool { !birthText.trimmingCharacters(in: .whitespaces).isEmpty && birthDate == nil }

    private var isEmpty: Bool {
        [target.vorname, target.nachname, target.bezeichnung, target.kennzeichen, target.anschrift, target.hinweise]
            .allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } && target.anhaenge.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Die Art steht fest: Sie wurde beim Anlegen gewählt (Zielperson, Zielfahrzeug oder Zielobjekt).
                switch target.art {
                case .person:
                    Section("Person") {
                        TextField("Vorname", text: $target.vorname)
                        TextField("Nachname", text: $target.nachname)
                        HStack {
                            TextField("Geburtsdatum (TT.MM.JJJJ)", text: $birthText)
                                .keyboardType(.numbersAndPunctuation)
                            if let birthDate, let age = Target.age(of: birthDate) {
                                Text("\(age) Jahre")
                                    .foregroundStyle(.secondary)
                            } else if birthTextInvalid {
                                Text("Datum prüfen")
                                    .foregroundStyle(.red)
                            }
                        }
                        TextField("Geburtsort", text: $target.geburtsort)
                        TextField("Staatsangehörigkeit", text: $target.staatsangehoerigkeit)
                        TextField("Anschrift", text: $target.anschrift, axis: .vertical)
                            .lineLimit(1...3)
                        TextField("Kennzeichen eines genutzten Fahrzeugs", text: $target.kennzeichen)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                case .fahrzeug:
                    Section("Fahrzeug") {
                        TextField("Fahrzeug, z. B. BMW 3er dunkelblau", text: $target.bezeichnung)
                        TextField("Kennzeichen", text: $target.kennzeichen)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                    Section("Halter oder Fahrer (optional)") {
                        TextField("Vorname", text: $target.vorname)
                        TextField("Nachname", text: $target.nachname)
                        TextField("Anschrift", text: $target.anschrift, axis: .vertical)
                            .lineLimit(1...3)
                    }
                case .objekt:
                    Section("Objekt") {
                        TextField("Objekt, z. B. Mehrfamilienhaus, Firmengebäude", text: $target.bezeichnung)
                        TextField("Anschrift", text: $target.anschrift, axis: .vertical)
                            .lineLimit(1...3)
                    }
                    Section("Bewohner oder Verantwortliche (optional)") {
                        TextField("Vorname", text: $target.vorname)
                        TextField("Nachname", text: $target.nachname)
                    }
                }

                AttachmentsSection(attachments: $target.anhaenge, marksTitlePhoto: true)

                Section("Notizen") {
                    TextField(notesPrompt, text: $target.hinweise, axis: .vertical)
                        .lineLimit(4...20)
                }

                locationSection

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
                        .disabled(isEmpty || birthTextInvalid)
                }
            }
            .alert("Ziel für alle löschen?", isPresented: $showsDelete) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    lage.delete(Target.self, id: context.id)
                    dismiss()
                }
            }
            .sheet(isPresented: $showsPicker) {
                LocationPickerSheet(title: "Standort wählen", initial: target.standort?.point ?? lage.targets[context.id].flatMap { lage.position(ofTarget: $0)?.point }) { point in
                    target.standort = TimedPoint(point)
                }
            }
        }
    }

    private var notesPrompt: String {
        switch target.art {
        case .person: "Merkmale, Kleidung, Sachverhalt, Hinweise, Eigensicherung, Maßnahmen …"
        case .fahrzeug: "Besonderheiten, Sachverhalt, Hinweise, Maßnahmen …"
        case .objekt: "Zugänge, Etage, Klingelschild, Sachverhalt, Hinweise, Maßnahmen …"
        }
    }

    // MARK: Standort

    private var trackerName: String? {
        target.trackerId.flatMap { id in lage.trackers[id].map { "\($0.data.name) (\($0.data.providerTitle))" } }
    }

    @ViewBuilder private var locationSection: some View {
        Section {
            if let trackerName {
                LabeledContent {
                    Text("live")
                } label: {
                    Label("Tracker \(trackerName)", systemImage: "antenna.radiowaves.left.and.right")
                }
            }
            if let standort = target.standort {
                LabeledContent {
                    Text(Format.ago(standort.date))
                } label: {
                    Label("Von Hand gesetzt", systemImage: "mappin")
                }
                Map(initialPosition: .camera(MapCamera(centerCoordinate: standort.point.coordinate, distance: 700)), interactionModes: []) {
                    Marker("", systemImage: target.art.symbolName, coordinate: standort.point.coordinate)
                        .tint(Theme.target)
                }
                .id("\(standort.lat),\(standort.lon)")
                .frame(height: 130)
                .clipShape(.rect(cornerRadius: 12))
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            if trackerName == nil, target.standort == nil {
                Label("Kein Standort, das Ziel erscheint noch nicht auf der Karte.", systemImage: "mappin.slash")
                    .foregroundStyle(.secondary)
            }
            if let locationFailure {
                Label(locationFailure, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Menu {
                Button("Auf der Karte oder per Adresse wählen …", systemImage: "map") { showsPicker = true }
                if !target.anschrift.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Anschrift als Standort", systemImage: "house") { Task { await geocodeAddress() } }
                }
                if let mine = model.myPoint {
                    Button("Mein Standort", systemImage: "location.fill") { target.standort = TimedPoint(mine) }
                }
                Picker(selection: $target.trackerId) {
                    Text("Kein Tracker").tag(String?.none)
                    ForEach(lage.trackers.values.sorted { $0.data.name < $1.data.name }) { tracker in
                        Text("\(tracker.data.name) (\(tracker.data.providerTitle))").tag(String?.some(tracker.id))
                    }
                } label: {
                    Label("GPS-Tracker", systemImage: "antenna.radiowaves.left.and.right")
                }
                .pickerStyle(.menu)
                if target.standort != nil {
                    Divider()
                    Button("Von Hand gesetzten Standort entfernen", systemImage: "trash", role: .destructive) { target.standort = nil }
                }
            } label: {
                HStack {
                    Label(target.standort == nil && target.trackerId == nil ? "Standort festlegen" : "Standort ändern", systemImage: "mappin.and.ellipse")
                    Spacer()
                    if isGeocoding { ProgressView() }
                }
            }
        } header: {
            Text("Standort")
        } footer: {
            Text("Mit Tracker erscheint das Ziel live auf der Karte; der von Hand gesetzte Standort tritt dann zurück. Tracker werden unter Mehr, Tracker verwaltet.")
        }
    }

    private func geocodeAddress() async {
        isGeocoding = true
        defer { isGeocoding = false }
        let placemarks = try? await CLGeocoder().geocodeAddressString(target.anschrift, in: nil, preferredLocale: Locale(identifier: "de_DE"))
        if let coordinate = placemarks?.first?.location?.coordinate {
            target.standort = TimedPoint(GeoPoint(coordinate))
            locationFailure = nil
        } else {
            locationFailure = "Die Anschrift wurde nicht gefunden."
        }
    }

    private func save() {
        var result = target
        result.birthDate = birthDate
        result.fahrzeugFotoBlob = nil
        result.fotoBlob = result.anhaenge.first(where: { $0.art == .bild })?.blobId
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
