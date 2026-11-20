import MapKit
import SwiftUI

// Ziel anlegen und bearbeiten: Angaben, Standort, Tracker und „unterwegs“-Bindung.

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
            .sheet(isPresented: $showsPicker) {
                LocationPickerSheet(title: "Standort wählen", initial: target.standort?.point ?? lage.targets[context.id].flatMap { lage.position(ofTarget: $0)?.point }) { point in
                    target.standort = TimedPoint(point)
                }
            }
        }
    }

    // MARK: Unterwegs

    private var bindingArt: Binding<TargetBinding.Art> {
        Binding(
            get: { target.bindung?.art ?? .fuss },
            set: { art in
                target.bindung = art == .fuss ? nil : TargetBinding(art: art, zielId: target.bindung?.art == art ? target.bindung?.zielId : nil)
            }
        )
    }

    /// Bezugspunkt für die Sortierung: Standort der Person, sonst der eigene.
    private var personPoint: GeoPoint? { target.standort?.point ?? lage.targets[context.id].flatMap { lage.position(ofTarget: $0)?.point } ?? model.myPoint }

    /// Mögliche Ziele zur gewählten Art, nächstgelegene zuerst (höchstens zehn).
    private var candidates: [(id: String, title: String, subtitle: String, symbol: String, distance: Double?)] {
        let art = target.bindung?.art ?? .fuss
        var list: [(id: String, title: String, subtitle: String, symbol: String, point: GeoPoint?)] = []
        switch art {
        case .fuss:
            return []
        case .oepnv:
            list = lage.mapObjects.values.filter { $0.data.typ == .oepnvfahrzeug && !$0.data.isExpired() }.map { object in
                (object.id, object.data.titel.isEmpty ? (object.data.linie?.ref ?? "ÖPNV-Fahrzeug") : object.data.titel,
                 object.data.linie.map { "\($0.ref) Richtung \($0.richtung)" } ?? "ÖPNV-Fahrzeug",
                 object.data.linie?.symbolName ?? "bus.fill", lage.position(ofObject: object.data))
            }
        case .fahrzeug, .objekt:
            let wanted: ZielArt = art == .fahrzeug ? .fahrzeug : .objekt
            list = lage.sortedTargets.filter { $0.data.art == wanted && $0.id != context.id }.map { other in
                (other.id, other.data.displayName, other.data.art.title, other.data.art.symbolName, lage.position(ofTarget: other)?.point)
            }
        }
        let reference = personPoint
        return list
            .map { item in
                let distance: Double? = if let r = reference, let p = item.point { r.distance(to: p) } else { nil }
                return (id: item.id, title: item.title, subtitle: item.subtitle, symbol: item.symbol, distance: distance)
            }
            .sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
            .prefix(10)
            .map { $0 }
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
            if (target.bindung?.art ?? .fuss) != .fuss {
                if candidates.isEmpty {
                    Text(target.bindung?.art == .oepnv ? "Kein ÖPNV-Fahrzeug angelegt. Über das Plus auf der Karte anlegen." : "Kein passendes Ziel angelegt.")
                        .foregroundStyle(.secondary)
                }
                ForEach(candidates, id: \.id) { candidate in
                    Button {
                        target.bindung = TargetBinding(art: target.bindung?.art ?? .fuss, zielId: candidate.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: candidate.symbol)
                                .foregroundStyle(.tint)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.title)
                                Text(candidate.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let distance = candidate.distance {
                                Text(Format.distance(distance))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            if target.bindung?.zielId == candidate.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .tint(.primary)
                }
            }
        } header: {
            Text("Unterwegs")
        } footer: {
            Text("Zu Fuß, im ÖPNV, im Fahrzeug oder im Gebäude. Zugeordnet folgt die Person dessen Standort; mehrere Personen können demselben Fahrzeug oder Objekt zugeordnet sein.")
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
