import MapKit
import SwiftUI

// Ziel anlegen und bearbeiten: Angaben, Standort, Tracker und „unterwegs“-Bindung.

struct TargetEditor: View {
    let context: TargetEditorContext
    /// Nach dem Sichern, mit der Kennung des Ziels (z. B. um ein neu angelegtes Ziel gleich zu verbinden).
    var onSave: ((String) -> Void)?

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
    /// Gewählte Art beim Einsteigen: öffnet die Auswahl des Fahrzeugs bzw. Objekts.
    @State private var boarding: TargetBinding.Art?
    @State private var relationEditing: RelationEditorContext?

    init(context: TargetEditorContext, onSave: ((String) -> Void)? = nil) {
        self.context = context
        self.onSave = onSave
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
                    }
                case .fahrzeug:
                    Section("Fahrzeug") {
                        TextField("Fahrzeug, z. B. BMW 3er dunkelblau", text: $target.bezeichnung)
                        TextField("Kennzeichen", text: $target.kennzeichen)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                case .objekt:
                    Section("Objekt") {
                        TextField("Objekt, z. B. Mehrfamilienhaus, Firmengebäude", text: $target.bezeichnung)
                        // Vorschläge während der Eingabe; ein gewählter Vorschlag setzt auch den Standort.
                        AddressCompletionField(address: $target.anschrift, near: target.standort?.point ?? model.myPoint) { point in
                            target.standort = TimedPoint(point)
                            target.quelle = .hand
                        }
                    }
                }

                legacySection

                if !lage.targetGroups.isEmpty {
                    Section {
                        Picker("Gruppe", selection: $target.gruppeId) {
                            Text("Keine").tag(String?.none)
                            ForEach(lage.sortedTargetGroups) { group in
                                Text(group.data.name).tag(Optional(group.id))
                            }
                        }
                    }
                }

                // Halter, Fahrer, Bewohner, Anschrift: als eigene Ziele angelegt und hier verbunden.
                if context.isNew {
                    Section("Beziehungen") {
                        Text("Nach dem Sichern lassen sich Personen, Fahrzeuge und Objekte verbinden.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    RelationsSection(targetId: context.id, opensTargets: false, editing: $relationEditing)
                }

                if target.art == .person {
                    bindingSection
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
            .relationEditor($relationEditing, ownId: context.id)
            .sheet(isPresented: $showsPicker) {
                LocationPickerSheet(title: "Standort wählen", initial: target.standort?.point ?? lage.targets[context.id].flatMap { lage.position(ofTarget: $0)?.point }) { point in
                    target.standort = TimedPoint(point)
                    target.quelle = .hand
                }
            }
        }
    }

    // MARK: Unterwegs

    /// Zu Fuß setzt sofort; ÖPNV, Fahrzeug und Gebäude fragen wie bei den Kräften, wohin die Person einsteigt.
    private var bindingArt: Binding<TargetBinding.Art> {
        Binding(
            get: { target.bindung?.art ?? .fuss },
            set: { art in
                if art == .fuss { target.bindung = nil } else { boarding = art }
            }
        )
    }

    /// Bezugspunkt für die Sortierung: Standort der Person, sonst der eigene.
    private var personPoint: GeoPoint? { target.standort?.point ?? lage.targets[context.id].flatMap { lage.position(ofTarget: $0)?.point } ?? model.myPoint }

    private func candidates(for art: TargetBinding.Art) -> [BoardingCandidate] {
        lage.boardingCandidates(for: art, excluding: context.id, near: personPoint)
    }

    /// Wohin die Person gerade eingestiegen ist, als lesbare Zeile.
    private var boardedTitle: String? {
        guard let binding = target.bindung, binding.art != .fuss else { return nil }
        guard let id = binding.zielId else { return binding.art == .fahrzeug ? "Anderes Fahrzeug" : nil }
        if let other = lage.targets[id] { return other.data.displayName }
        if let object = lage.mapObjects[id]?.data { return object.titel.isEmpty ? (object.linie?.ref ?? "ÖPNV-Fahrzeug") : object.titel }
        return nil
    }

    @ViewBuilder private var bindingSection: some View {
        Section {
            Picker("Unterwegs", selection: bindingArt) {
                ForEach(TargetBinding.Art.allCases) { art in
                    Image(systemName: art.symbolName)
                        .accessibilityLabel(art.title)
                        .tag(art)
                }
            }
            .pickerStyle(.segmented)
            if let art = target.bindung?.art, art != .fuss {
                Button { boarding = art } label: {
                    LabeledContent {
                        Text("Ändern")
                    } label: {
                        Label(boardedTitle ?? "Noch nicht gewählt", systemImage: art.symbolName)
                    }
                }
                .tint(.primary)
            }
        } header: {
            Text("Unterwegs")
        } footer: {
            Text("Wie bei den Kräften: Im Fahrzeug, im ÖPNV oder im Gebäude folgt die Person dessen Standort und erscheint auf der Karte nicht mehr einzeln.")
        }
        .sheet(item: $boarding) { art in
            let create: (() -> Void)? = art == .fahrzeug || art == .objekt ? { createAndBoard(art) } : nil
            BoardingSheet(
                art: art,
                candidates: candidates(for: art),
                selected: target.bindung?.art == art ? target.bindung?.zielId : nil,
                otherSelected: target.bindung?.art == .fahrzeug && target.bindung?.zielId == nil,
                pick: { id in target.bindung = TargetBinding(art: art, zielId: id) },
                createNew: create
            )
        }
    }

    /// Legt ein neues Zielfahrzeug bzw. Zielobjekt am Standort der Person an und setzt die Person hinein.
    private func createAndBoard(_ art: TargetBinding.Art) {
        let id = LageStore.newId()
        var other = Target(art: art == .fahrzeug ? .fahrzeug : .objekt)
        let name = target.displayName
        other.bezeichnung = art == .fahrzeug ? "Fahrzeug von \(name)" : "Gebäude von \(name)"
        if let point = personPoint { other.standort = TimedPoint(point) }
        lage.put(other, id: id)
        target.bindung = TargetBinding(art: art, zielId: id)
    }

    /// Frühere Freitextangaben (Halter beim Fahrzeug, Wohnanschrift und genutztes Fahrzeug bei der Person, Bewohner
    /// beim Objekt) bleiben sichtbar und lassen sich leeren, sobald sie als Beziehung angelegt sind.
    @ViewBuilder private var legacySection: some View {
        let address = target.art != .objekt && !target.anschrift.isEmpty
        let person = target.art != .person && !(target.vorname.isEmpty && target.nachname.isEmpty)
        let plate = target.art == .person && !target.kennzeichen.isEmpty
        if address || person || plate {
            Section {
                if person {
                    LabeledContent("Person", value: [target.vorname, target.nachname].filter { !$0.isEmpty }.joined(separator: " "))
                }
                if address {
                    LabeledContent("Anschrift", value: target.anschrift)
                }
                if plate {
                    LabeledContent("Genutztes Fahrzeug", value: target.kennzeichen)
                }
                Button("Frühere Angaben entfernen", systemImage: "eraser", role: .destructive) {
                    if person { target.vorname = ""; target.nachname = "" }
                    if address { target.anschrift = "" }
                    if plate { target.kennzeichen = "" }
                }
            } header: {
                Text("Frühere Angaben")
            } footer: {
                Text("Bitte als eigenes Ziel anlegen und unter „Beziehungen“ verbinden, danach hier entfernen.")
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
                    Button("Mein Standort", systemImage: "location.fill") {
                        target.standort = TimedPoint(mine)
                        target.quelle = .hand
                    }
                }
                if target.supportsDynamicSource {
                Picker(selection: Binding(
                    get: { target.trackerId },
                    set: { id in
                        target.trackerId = id
                        target.quelle = id == nil ? .hand : .tracker
                    }
                )) {
                    Text("Kein Tracker").tag(String?.none)
                    ForEach(lage.trackers.values.sorted { $0.data.name < $1.data.name }) { tracker in
                        Text("\(tracker.data.name) (\(tracker.data.providerTitle))").tag(String?.some(tracker.id))
                    }
                } label: {
                    Label("GPS-Tracker", systemImage: "antenna.radiowaves.left.and.right")
                }
                .pickerStyle(.menu)
                }
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
        if lage.put(result, id: context.id) {
            onSave?(context.id)
            dismiss()
        }
    }
}
