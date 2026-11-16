import SwiftUI

/// Kurzübersicht zu einem angetippten Kartenobjekt.
struct QuickLookSheet: View {
    let selection: MapSelection
    /// Standort eines Ziels auf der Karte neu setzen.
    let placeTarget: (String) -> Void
    /// Markierung per Tipp auf die Karte verschieben.
    let moveObject: (String) -> Void

    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch selection {
                case .member(let id):
                    if let member = lage.members[id] { MemberQuickLook(member: member) } else { gone }
                case .vehicle(let id):
                    if lage.vehicles[id] != nil { VehicleDetail(vehicleId: id) } else { gone }
                case .target(let id):
                    if lage.targets[id] != nil { TargetDetail(targetId: id, placeOnMap: placeTarget) } else { gone }
                case .object(let id):
                    if let object = lage.mapObjects[id] { MapObjectInfo(id: id, object: object.data, startMoving: moveObject) } else { gone }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Links Schließen, rechts Bearbeiten: einheitlich für alle Ansichten über der Karte.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
        // Gelöscht (auch von anderen): die Ansicht schließt sich.
        .onChange(of: exists) { _, now in
            if !now { dismiss() }
        }
    }

    private var exists: Bool {
        switch selection {
        case .member(let id): lage.members[id] != nil
        case .vehicle(let id): lage.vehicles[id] != nil
        case .target(let id): lage.targets[id] != nil
        case .object(let id): lage.mapObjects[id] != nil
        }
    }

    private var gone: some View {
        ContentUnavailableView("Nicht mehr vorhanden", systemImage: "questionmark.circle")
    }
}

/// Schnellübersicht eines Fahnders mit Anruf- und Navigationsknopf.
struct MemberQuickLook: View {
    let member: Versioned<Member>

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    private var position: Position? { lage.positions[member.id] }

    var body: some View {
        List {
            // Hinführen und Anrufen ganz oben, getrennt vom Rest.
            if member.id != lage.selfId, position != nil || PhoneNumber.callURL(member.data.telefon) != nil {
                Section {
                HStack(spacing: 12) {
                        if let url = PhoneNumber.callURL(member.data.telefon), member.id != lage.selfId {
                            Button { openURL(url) } label: {
                                Label("Anrufen", systemImage: "phone.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glass)
                            .tint(.green)
                        }
                        if position != nil, member.id != lage.selfId {
                            Button {
                                model.navigate(to: .member(member.id))
                                dismiss()
                            } label: {
                                Label("Hinführen", systemImage: "location.north.line.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)
                        }
                    }
                    .controlSize(.large)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
            }
            Section {
                HStack(spacing: 16) {
                    Avatar(blobId: member.data.fotoBlob, fallbackText: member.data.spitzname, size: 72, tint: lage.isOnline(member.id) && member.data.aktiv ? .green : .gray)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.data.spitzname)
                            .font(.title2.weight(.bold))
                        Text(member.data.name)
                        Text(member.data.dienststelle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)

            }

            Section("Status") {
                LabeledContent("Dienst", value: member.data.aktiv ? (lage.isOnline(member.id) ? "Verbunden" : "Nicht verbunden") : "Ruhemodus")
                LabeledContent("Unterwegs", value: lage.mobilityDescription(of: member.data))
                if let position {
                    LabeledContent("Position", value: Format.ago(position.date))
                    if let speed = position.spd, speed > 1 {
                        LabeledContent("Geschwindigkeit", value: "\(Int(speed * 3.6)) km/h")
                    }
                } else {
                    LabeledContent("Position", value: "unbekannt")
                }
                if lage.operation.a?.memberId == member.id {
                    Label { Text("Hält die A-Position") } icon: { ASymbol(size: 22) }
                        .foregroundStyle(Theme.aPosition)
                    if member.id == lage.selfId {
                        Button("A abgeben", role: .destructive) {
                            lage.releaseA()
                            dismiss()
                        }
                    }
                }
                if !member.data.telefon.isEmpty {
                    LabeledContent("Handynummer", value: member.data.telefon)
                }
            }

            if let vehicle = lage.vehicle(of: member.data) {
                Section("Fahrzeug") {
                    NavigationLink {
                        VehicleDetail(vehicleId: vehicle.id)
                    } label: {
                        VehicleRow(vehicle: vehicle)
                    }
                }
            }
        }
        .navigationTitle(member.data.spitzname)
    }
}

/// Ansicht einer Markierung, Form oder Prognosezelle. Bearbeiten (mit Verschieben und Löschen) über den Knopf oben rechts.
struct MapObjectInfo: View {
    let id: String
    let object: MapObject
    /// Startet das Verschieben per Tipp auf die Karte.
    let startMoving: (String) -> Void

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var editing: EditorContext?

    private var isCell: Bool { object.wert != nil }
    private var title: String { object.titel.isEmpty ? (isCell ? "Prognosezelle" : object.typ.title) : object.titel }
    private var layer: Versioned<Layer>? { lage.layers[object.layerId] }
    private var editable: Bool { !isCell && layer?.data.art != "argus" && settings.canEdit(layerId: object.layerId) }

    var body: some View {
        List {
            NavigateHereSection {
                model.navigate(to: .object(id))
                dismiss()
            }
            Section {
                HStack(spacing: 14) {
                    symbol
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.title3.weight(.bold))
                        Text([object.titel.isEmpty ? nil : (isCell ? "Prognosezelle" : object.typ.title), layer?.data.name].compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)
            }

            if object.typ == .fahndungsraum || object.radius != nil || object.trackerId != nil || object.expiry != nil {
                Section {
                    if object.typ == .fahndungsraum, let since = object.since {
                        LabeledContent("Letzte Sichtung", value: "\(Format.time(since)), \(Format.ago(since))")
                    }
                    if let radius = object.radius, object.typ == .kreis || object.typ == .haltestellen {
                        LabeledContent("Umkreis", value: Format.distance(radius))
                    }
                    if let trackerId = object.trackerId {
                        LabeledContent("Standort", value: "Tracker \(lage.trackers[trackerId]?.data.name ?? "unbekannt")")
                    }
                    if let expiry = object.expiry {
                        LabeledContent("Löscht sich", value: Format.expiry(expiry))
                    }
                }
            }

            if let wert = object.wert {
                Section {
                    LabeledContent("Prognosefaktor", value: wert.formatted(.number.precision(.fractionLength(1)).locale(Format.locale)))
                } footer: {
                    Text("Wie viel wahrscheinlicher hier ein Ereignis ist als im Durchschnitt des Gebiets.")
                }
            }
            if !object.notiz.isEmpty {
                Section(isCell ? "Details" : "Notiz") {
                    Text(object.notiz)
                        .textSelection(.enabled)
                }
            }
            if let attachments = object.anhaenge, !attachments.isEmpty {
                AttachmentsSection(attachments: .constant(attachments), editable: false)
            }

            Section {
                if !editable, !isCell, layer?.data.art != "argus" {
                    Label("Dauerhafte Orte sind gesperrt. Zum Bearbeiten unter Mehr „Dauerhafte Orte bearbeiten“ einschalten.", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let current = lage.mapObjects[id] {
                    Text("Zuletzt geändert von \(lage.name(of: current.updatedBy)), \(Format.ago(current.updatedDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            if editable {
                ToolbarItem(placement: .primaryAction) {
                    Button("Bearbeiten") { editing = EditorContext(id: id, object: object, isNew: false) }
                }
            }
        }
        .sheet(item: $editing) { context in
            MapObjectEditor(context: context, startMoving: startMoving)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder private var symbol: some View {
        let color = Color(hex: object.farbe)
        if object.typ == .marker || object.typ == .text || object.typ == .haltestellen {
            Image(systemName: object.typ == .marker ? (object.symbol.isEmpty ? "mappin" : object.symbol) : object.typ.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color, in: .circle)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(color, lineWidth: 2))
                .frame(width: 44, height: 44)
        }
    }
}
